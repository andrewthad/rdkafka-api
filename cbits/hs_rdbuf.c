/*
 * librdkafka - Apache Kafka C library
 *
 * Copyright (c) 2017 Magnus Edenhill
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */


#include "hs_rd.h"
#include "hs_rdbuf.h"
#include "hs_rdlog.h"
#include "hs_rdcrc32.h"
#include "hs_crc32c.h"


static size_t
rd_buf_get_writable0(rd_buf_t *rbuf, rd_segment_t **segp, void **p);


/**
 * @brief Destroy the segment and free its payload.
 *
 * @remark Will NOT unlink from buffer.
 */
static void rd_segment_destroy(rd_segment_t *seg) {
        /* Free payload */
        if (seg->seg_free && seg->seg_p)
                seg->seg_free(seg->seg_p);

        if (seg->seg_flags & RD_SEGMENT_F_FREE)
                rd_free(seg);
}

/**
 * @brief Initialize segment with absolute offset, backing memory pointer,
 *        and backing memory size.
 * @remark The segment is NOT linked.
 */
static void rd_segment_init(rd_segment_t *seg, void *mem, size_t size) {
        memset(seg, 0, sizeof(*seg));
        seg->seg_p    = mem;
        seg->seg_size = size;
}


/**
 * @brief Append segment to buffer
 *
 * @remark Will set the buffer position to the new \p seg if no existing wpos.
 * @remark Will set the segment seg_absof to the current length of the buffer.
 */
static rd_segment_t *rd_buf_append_segment(rd_buf_t *rbuf, rd_segment_t *seg) {
        TAILQ_INSERT_TAIL(&rbuf->rbuf_segments, seg, seg_link);
        rbuf->rbuf_segment_cnt++;
        seg->seg_absof = rbuf->rbuf_len;
        rbuf->rbuf_len += seg->seg_of;
        rbuf->rbuf_size += seg->seg_size;

        /* Update writable position */
        if (!rbuf->rbuf_wpos)
                rbuf->rbuf_wpos = seg;
        else
                rd_buf_get_writable0(rbuf, NULL, NULL);

        return seg;
}



/**
 * @brief Attempt to allocate \p size bytes from the buffers extra buffers.
 * @returns the allocated pointer which MUST NOT be freed, or NULL if
 *          not enough memory.
 * @remark the returned pointer is memory-aligned to be safe.
 */
static void *extra_alloc(rd_buf_t *rbuf, size_t size) {
        size_t of = RD_ROUNDUP(rbuf->rbuf_extra_len, 8); /* FIXME: 32-bit */
        void *p;

        if (of + size > rbuf->rbuf_extra_size)
                return NULL;

        p = rbuf->rbuf_extra + of; /* Aligned pointer */

        rbuf->rbuf_extra_len = of + size;

        return p;
}



/**
 * @brief Get a pre-allocated segment if available, or allocate a new
 *        segment with the extra amount of \p size bytes allocated for payload.
 *
 *        Will not append the segment to the buffer.
 */
static rd_segment_t *rd_buf_alloc_segment0(rd_buf_t *rbuf, size_t size) {
        rd_segment_t *seg;

        /* See if there is enough room in the extra buffer for
         * allocating the segment header and the buffer,
         * or just the segment header, else fall back to malloc. */
        if ((seg = extra_alloc(rbuf, sizeof(*seg) + size))) {
                rd_segment_init(seg, size > 0 ? seg + 1 : NULL, size);

        } else if ((seg = extra_alloc(rbuf, sizeof(*seg)))) {
                rd_segment_init(seg, size > 0 ? rd_malloc(size) : NULL, size);
                if (size > 0)
                        seg->seg_free = rd_free;

        } else if ((seg = rd_malloc(sizeof(*seg) + size))) {
                rd_segment_init(seg, size > 0 ? seg + 1 : NULL, size);
                seg->seg_flags |= RD_SEGMENT_F_FREE;

        } else
                rd_assert(!*"segment allocation failure");

        return seg;
}

/**
 * @brief Allocate between \p min_size .. \p max_size of backing memory
 *        and add it as a new segment to the buffer.
 *
 *        The buffer position is updated to point to the new segment.
 *
 *        The segment will be over-allocated if permitted by max_size
 *        (max_size == 0 or max_size > min_size).
 */
static rd_segment_t *
rd_buf_alloc_segment(rd_buf_t *rbuf, size_t min_size, size_t max_size) {
        rd_segment_t *seg;

        /* Over-allocate if allowed. */
        if (min_size != max_size || max_size == 0)
                max_size = RD_MAX(sizeof(*seg) * 4,
                                  RD_MAX(min_size * 2, rbuf->rbuf_size / 2));

        seg = rd_buf_alloc_segment0(rbuf, max_size);

        rd_buf_append_segment(rbuf, seg);

        return seg;
}


/**
 * @brief Ensures that \p size bytes will be available
 *        for writing and the position will be updated to point to the
 *        start of this contiguous block.
 */
void rd_buf_write_ensure_contig(rd_buf_t *rbuf, size_t size) {
        rd_segment_t *seg = rbuf->rbuf_wpos;

        if (seg) {
                void *p;
                size_t remains = rd_segment_write_remains(seg, &p);

                if (remains >= size)
                        return; /* Existing segment has enough space. */

                /* Future optimization:
                 * If existing segment has enough remaining space to warrant
                 * a split, do it, before allocating a new one. */
        }

        /* Allocate new segment */
        rbuf->rbuf_wpos = rd_buf_alloc_segment(rbuf, size, size);
}

/**
 * @brief Ensures that at least \p size bytes will be available for
 *        a future write.
 *
 *        Typically used prior to a call to rd_buf_get_write_iov()
 */
void rd_buf_write_ensure(rd_buf_t *rbuf, size_t min_size, size_t max_size) {
        size_t remains;
        while ((remains = rd_buf_write_remains(rbuf)) < min_size)
                rd_buf_alloc_segment(rbuf, min_size - remains,
                                     max_size ? max_size - remains : 0);
}


/**
 * @returns the segment at absolute offset \p absof, or NULL if out of range.
 *
 * @remark \p hint is an optional segment where to start looking, such as
 *         the current write or read position.
 */
rd_segment_t *rd_buf_get_segment_at_offset(const rd_buf_t *rbuf,
                                           const rd_segment_t *hint,
                                           size_t absof) {
        const rd_segment_t *seg = hint;

        if (unlikely(absof >= rbuf->rbuf_len))
                return NULL;

        /* Only use current write position if possible and if it helps */
        if (!seg || absof < seg->seg_absof)
                seg = TAILQ_FIRST(&rbuf->rbuf_segments);

        do {
                if (absof >= seg->seg_absof &&
                    absof < seg->seg_absof + seg->seg_of) {
                        rd_dassert(seg->seg_absof <= rd_buf_len(rbuf));
                        return (rd_segment_t *)seg;
                }
        } while ((seg = TAILQ_NEXT(seg, seg_link)));

        return NULL;
}


/**
 * @brief Split segment \p seg at absolute offset \p absof, appending
 *        a new segment after \p seg with its memory pointing to the
 *        memory starting at \p absof.
 *        \p seg 's memory will be shorted to the \p absof.
 *
 *        The new segment is NOT appended to the buffer.
 *
 * @warning MUST ONLY be used on the LAST segment
 *
 * @warning if a segment is inserted between these two splitted parts
 *          it is imperative that the later segment's absof is corrected.
 *
 * @remark The seg_free callback is retained on the original \p seg
 *         and is not copied to the new segment, but flags are copied.
 */
static rd_segment_t *
rd_segment_split(rd_buf_t *rbuf, rd_segment_t *seg, size_t absof) {
        rd_segment_t *newseg;
        size_t relof;

        rd_assert(seg == rbuf->rbuf_wpos);
        rd_assert(absof >= seg->seg_absof &&
                  absof <= seg->seg_absof + seg->seg_of);

        relof = absof - seg->seg_absof;

        newseg = rd_buf_alloc_segment0(rbuf, 0);

        /* Add later part of split bytes to new segment */
        newseg->seg_p     = seg->seg_p + relof;
        newseg->seg_of    = seg->seg_of - relof;
        newseg->seg_size  = seg->seg_size - relof;
        newseg->seg_absof = SIZE_MAX; /* Invalid */
        newseg->seg_flags |= seg->seg_flags;

        /* Remove earlier part of split bytes from previous segment */
        seg->seg_of   = relof;
        seg->seg_size = relof;

        /* newseg's length will be added to rbuf_len in append_segment(),
         * so shave it off here from seg's perspective. */
        rbuf->rbuf_len -= newseg->seg_of;
        rbuf->rbuf_size -= newseg->seg_size;

        return newseg;
}



/**
 * @brief Unlink and destroy a segment, updating the \p rbuf
 *        with the decrease in length and capacity.
 */
static void rd_buf_destroy_segment(rd_buf_t *rbuf, rd_segment_t *seg) {
        rd_assert(rbuf->rbuf_segment_cnt > 0 && rbuf->rbuf_len >= seg->seg_of &&
                  rbuf->rbuf_size >= seg->seg_size);

        TAILQ_REMOVE(&rbuf->rbuf_segments, seg, seg_link);
        rbuf->rbuf_segment_cnt--;
        rbuf->rbuf_len -= seg->seg_of;
        rbuf->rbuf_size -= seg->seg_size;
        if (rbuf->rbuf_wpos == seg)
                rbuf->rbuf_wpos = NULL;

        rd_segment_destroy(seg);
}


/**
 * @brief Free memory associated with the \p rbuf, but not the rbuf itself.
 *        Segments will be destroyed.
 */
void rd_buf_destroy(rd_buf_t *rbuf) {
        rd_segment_t *seg, *tmp;

#if ENABLE_DEVEL
        /* FIXME */
        if (rbuf->rbuf_len > 0 && 0) {
                size_t overalloc = rbuf->rbuf_size - rbuf->rbuf_len;
                float fill_grade =
                    (float)rbuf->rbuf_len / (float)rbuf->rbuf_size;

                printf("fill grade: %.2f%% (%" PRIusz
                       " bytes over-allocated)\n",
                       fill_grade * 100.0f, overalloc);
        }
#endif


        TAILQ_FOREACH_SAFE(seg, &rbuf->rbuf_segments, seg_link, tmp) {
                rd_segment_destroy(seg);
        }

        if (rbuf->rbuf_extra)
                rd_free(rbuf->rbuf_extra);
}


/**
 * @brief Same as rd_buf_destroy() but also frees the \p rbuf itself.
 */
void rd_buf_destroy_free(rd_buf_t *rbuf) {
        rd_buf_destroy(rbuf);
        rd_free(rbuf);
}

/**
 * @brief Initialize buffer, pre-allocating \p fixed_seg_cnt segments
 *        where the first segment will have a \p buf_size of backing memory.
 *
 *        The caller may rearrange the backing memory as it see fits.
 */
void rd_buf_init(rd_buf_t *rbuf, size_t fixed_seg_cnt, size_t buf_size) {
        size_t totalloc = 0;

        memset(rbuf, 0, sizeof(*rbuf));
        TAILQ_INIT(&rbuf->rbuf_segments);

        if (!fixed_seg_cnt) {
                assert(!buf_size);
                return;
        }

        /* Pre-allocate memory for a fixed set of segments that are known
         * before-hand, to minimize the number of extra allocations
         * needed for well-known layouts (such as headers, etc) */
        totalloc += RD_ROUNDUP(sizeof(rd_segment_t), 8) * fixed_seg_cnt;

        /* Pre-allocate extra space for the backing buffer. */
        totalloc += buf_size;

        rbuf->rbuf_extra_size = totalloc;
        rbuf->rbuf_extra      = rd_malloc(rbuf->rbuf_extra_size);
}


/**
 * @brief Allocates a buffer object and initializes it.
 * @sa rd_buf_init()
 */
rd_buf_t *rd_buf_new(size_t fixed_seg_cnt, size_t buf_size) {
        rd_buf_t *rbuf = rd_malloc(sizeof(*rbuf));
        rd_buf_init(rbuf, fixed_seg_cnt, buf_size);
        return rbuf;
}


/**
 * @brief Convenience writer iterator interface.
 *
 *        After writing to \p p the caller must update the written length
 *        by calling rd_buf_write(rbuf, NULL, written_length)
 *
 * @returns the number of contiguous writable bytes in segment
 *          and sets \p *p to point to the start of the memory region.
 */
static size_t
rd_buf_get_writable0(rd_buf_t *rbuf, rd_segment_t **segp, void **p) {
        rd_segment_t *seg;

        for (seg = rbuf->rbuf_wpos; seg; seg = TAILQ_NEXT(seg, seg_link)) {
                size_t len = rd_segment_write_remains(seg, p);

                /* Even though the write offset hasn't changed we
                 * avoid future segment scans by adjusting the
                 * wpos here to the first writable segment. */
                rbuf->rbuf_wpos = seg;
                if (segp)
                        *segp = seg;

                if (unlikely(len == 0))
                        continue;

                /* Also adjust absof if the segment was allocated
                 * before the previous segment's memory was exhausted
                 * and thus now might have a lower absolute offset
                 * than the previos segment's now higher relative offset. */
                if (seg->seg_of == 0 && seg->seg_absof < rbuf->rbuf_len)
                        seg->seg_absof = rbuf->rbuf_len;

                return len;
        }

        return 0;
}

size_t rd_buf_get_writable(rd_buf_t *rbuf, void **p) {
        rd_segment_t *seg;
        return rd_buf_get_writable0(rbuf, &seg, p);
}



/**
 * @brief Write \p payload of \p size bytes to current position
 *        in buffer. A new segment will be allocated and appended
 *        if needed.
 *
 * @returns the write position where payload was written (pre-write).
 *          Returning the pre-positition allows write_update() to later
 *          update the same location, effectively making write()s
 *          also a place-holder mechanism.
 *
 * @remark If \p payload is NULL only the write position is updated,
 *         in this mode it is required for the buffer to have enough
 *         memory for the NULL write (as it would otherwise cause
 *         uninitialized memory in any new segments allocated from this
 *         function).
 */
size_t rd_buf_write(rd_buf_t *rbuf, const void *payload, size_t size) {
        size_t remains = size;
        size_t initial_absof;
        const char *psrc = (const char *)payload;

        initial_absof = rbuf->rbuf_len;

        /* Ensure enough space by pre-allocating segments. */
        rd_buf_write_ensure(rbuf, size, 0);

        while (remains > 0) {
                void *p           = NULL;
                rd_segment_t *seg = NULL;
                size_t segremains = rd_buf_get_writable0(rbuf, &seg, &p);
                size_t wlen       = RD_MIN(remains, segremains);

                rd_dassert(seg == rbuf->rbuf_wpos);
                rd_dassert(wlen > 0);
                rd_dassert(seg->seg_p + seg->seg_of <= (char *)p &&
                           (char *)p < seg->seg_p + seg->seg_size);

                if (payload) {
                        memcpy(p, psrc, wlen);
                        psrc += wlen;
                }

                seg->seg_of += wlen;
                rbuf->rbuf_len += wlen;
                remains -= wlen;
        }

        rd_assert(remains == 0);

        return initial_absof;
}



/**
 * @brief Write \p slice to \p rbuf
 *
 * @remark The slice position will be updated.
 *
 * @returns the number of bytes witten (always slice length)
 */
size_t rd_buf_write_slice(rd_buf_t *rbuf, rd_slice_t *slice) {
        const void *p;
        size_t rlen;
        size_t sum = 0;

        while ((rlen = rd_slice_reader(slice, &p))) {
                size_t r;
                r = rd_buf_write(rbuf, p, rlen);
                rd_dassert(r != 0);
                sum += r;
        }

        return sum;
}



/**
 * @brief Write \p payload of \p size at absolute offset \p absof
 *        WITHOUT updating the total buffer length.
 *
 *        This is used to update a previously written region, such
 *        as updating the header length.
 *
 * @returns the number of bytes written, which may be less than \p size
 *          if the update spans multiple segments.
 */
static size_t rd_segment_write_update(rd_segment_t *seg,
                                      size_t absof,
                                      const void *payload,
                                      size_t size) {
        size_t relof;
        size_t wlen;

        rd_dassert(absof >= seg->seg_absof);
        relof = absof - seg->seg_absof;
        rd_assert(relof <= seg->seg_of);
        wlen = RD_MIN(size, seg->seg_of - relof);
        rd_dassert(relof + wlen <= seg->seg_of);

        memcpy(seg->seg_p + relof, payload, wlen);

        return wlen;
}



/**
 * @brief Write \p payload of \p size at absolute offset \p absof
 *        WITHOUT updating the total buffer length.
 *
 *        This is used to update a previously written region, such
 *        as updating the header length.
 */
size_t rd_buf_write_update(rd_buf_t *rbuf,
                           size_t absof,
                           const void *payload,
                           size_t size) {
        rd_segment_t *seg;
        const char *psrc = (const char *)payload;
        size_t of;

        /* Find segment for offset */
        seg = rd_buf_get_segment_at_offset(rbuf, rbuf->rbuf_wpos, absof);
        rd_assert(seg && *"invalid absolute offset");

        for (of = 0; of < size; seg = TAILQ_NEXT(seg, seg_link)) {
                rd_assert(seg->seg_absof <= rd_buf_len(rbuf));
                size_t wlen = rd_segment_write_update(seg, absof + of,
                                                      psrc + of, size - of);
                of += wlen;
        }

        rd_dassert(of == size);

        return of;
}



/**
 * @brief Push reference memory segment to current write position.
 */
void rd_buf_push0(rd_buf_t *rbuf,
                  const void *payload,
                  size_t size,
                  void (*free_cb)(void *),
                  rd_bool_t writable) {
        rd_segment_t *prevseg, *seg, *tailseg = NULL;

        if ((prevseg = rbuf->rbuf_wpos) &&
            rd_segment_write_remains(prevseg, NULL) > 0) {
                /* If the current segment still has room in it split it
                 * and insert the pushed segment in the middle (below). */
                tailseg = rd_segment_split(
                    rbuf, prevseg, prevseg->seg_absof + prevseg->seg_of);
        }

        seg           = rd_buf_alloc_segment0(rbuf, 0);
        seg->seg_p    = (char *)payload;
        seg->seg_size = size;
        seg->seg_of   = size;
        seg->seg_free = free_cb;
        if (!writable)
                seg->seg_flags |= RD_SEGMENT_F_RDONLY;

        rd_buf_append_segment(rbuf, seg);

        if (tailseg)
                rd_buf_append_segment(rbuf, tailseg);
}



/**
 * @brief Erase \p size bytes at \p absof from buffer.
 *
 * @returns the number of bytes erased.
 *
 * @remark This is costly since it forces a memory move.
 */
size_t rd_buf_erase(rd_buf_t *rbuf, size_t absof, size_t size) {
        rd_segment_t *seg, *next = NULL;
        size_t of;

        /* Find segment for offset */
        seg = rd_buf_get_segment_at_offset(rbuf, NULL, absof);

        /* Adjust segments until size is exhausted, then continue scanning to
         * update the absolute offset. */
        for (of = 0; seg && of < size; seg = next) {
                /* Example:
                 *   seg_absof = 10
                 *   seg_of    = 7
                 *   absof     = 12
                 *   of        = 1
                 *   size      = 4
                 *
                 * rof          = 3   relative segment offset where to erase
                 * eraseremains = 3   remaining bytes to erase
                 * toerase      = 3   available bytes to erase in segment
                 * segremains   = 1   remaining bytes in segment after to
                 *                    the right of the erased part, i.e.,
                 *                    the memory that needs to be moved to the
                 *                    left.
                 */
                /** Relative offset in segment for the absolute offset */
                size_t rof = (absof + of) - seg->seg_absof;
                /** How much remains to be erased */
                size_t eraseremains = size - of;
                /** How much can be erased from this segment */
                size_t toerase = RD_MIN(seg->seg_of - rof, eraseremains);
                /** How much remains in the segment after the erased part */
                size_t segremains = seg->seg_of - (rof + toerase);

                next = TAILQ_NEXT(seg, seg_link);

                seg->seg_absof -= of;

                if (unlikely(toerase == 0))
                        continue;

                if (unlikely((seg->seg_flags & RD_SEGMENT_F_RDONLY)))
                        RD_BUG("rd_buf_erase() called on read-only segment");

                if (likely(segremains > 0))
                        memmove(seg->seg_p + rof, seg->seg_p + rof + toerase,
                                segremains);

                seg->seg_of -= toerase;
                rbuf->rbuf_len -= toerase;

                of += toerase;

                /* If segment is now empty, remove it */
                if (seg->seg_of == 0)
                        rd_buf_destroy_segment(rbuf, seg);
        }

        /* Update absolute offset of remaining segments */
        for (seg = next; seg; seg = TAILQ_NEXT(seg, seg_link)) {
                rd_assert(seg->seg_absof >= of);
                seg->seg_absof -= of;
        }

        rbuf->rbuf_erased += of;

        return of;
}



/**
 * @brief Do a write-seek, updating the write position to the given
 *        absolute \p absof.
 *
 * @warning Any sub-sequent segments will be destroyed.
 *
 * @returns -1 if the offset is out of bounds, else 0.
 */
int rd_buf_write_seek(rd_buf_t *rbuf, size_t absof) {
        rd_segment_t *seg, *next;
        size_t relof;

        seg = rd_buf_get_segment_at_offset(rbuf, rbuf->rbuf_wpos, absof);
        if (unlikely(!seg))
                return -1;

        relof = absof - seg->seg_absof;
        if (unlikely(relof > seg->seg_of))
                return -1;

        /* Destroy sub-sequent segments in reverse order so that
         * destroy_segment() length checks are correct.
         * Will decrement rbuf_len et.al. */
        for (next = TAILQ_LAST(&rbuf->rbuf_segments, rd_segment_head);
             next != seg;) {
                rd_segment_t *this = next;
                next = TAILQ_PREV(this, rd_segment_head, seg_link);
                rd_buf_destroy_segment(rbuf, this);
        }

        /* Update relative write offset */
        seg->seg_of     = relof;
        rbuf->rbuf_wpos = seg;
        rbuf->rbuf_len  = seg->seg_absof + seg->seg_of;

        rd_assert(rbuf->rbuf_len == absof);

        return 0;
}


/**
 * @brief Set up the iovecs in \p iovs (of size \p iov_max) with the writable
 *        segments from the buffer's current write position.
 *
 * @param iovcntp will be set to the number of populated \p iovs[]
 * @param size_max limits the total number of bytes made available.
 *                 Note: this value may be overshot with the size of one
 *                       segment.
 *
 * @returns the total number of bytes in the represented segments.
 *
 * @remark the write position will NOT be updated.
 */
size_t rd_buf_get_write_iov(const rd_buf_t *rbuf,
                            struct iovec *iovs,
                            size_t *iovcntp,
                            size_t iov_max,
                            size_t size_max) {
        const rd_segment_t *seg;
        size_t iovcnt = 0;
        size_t sum    = 0;

        for (seg = rbuf->rbuf_wpos; seg && iovcnt < iov_max && sum < size_max;
             seg = TAILQ_NEXT(seg, seg_link)) {
                size_t len;
                void *p;

                len = rd_segment_write_remains(seg, &p);
                if (unlikely(len == 0))
                        continue;

                iovs[iovcnt].iov_base  = p;
                iovs[iovcnt++].iov_len = len;

                sum += len;
        }

        *iovcntp = iovcnt;

        return sum;
}



/**
 * @name Slice reader interface
 *
 * @{
 */

/**
 * @brief Initialize a new slice of \p size bytes starting at \p seg with
 *        relative offset \p rof.
 *
 * @returns 0 on success or -1 if there is not at least \p size bytes available
 *          in the buffer.
 */
int rd_slice_init_seg(rd_slice_t *slice,
                      const rd_buf_t *rbuf,
                      const rd_segment_t *seg,
                      size_t rof,
                      size_t size) {
        /* Verify that \p size bytes are indeed available in the buffer. */
        if (unlikely(rbuf->rbuf_len < (seg->seg_absof + rof + size)))
                return -1;

        slice->buf   = rbuf;
        slice->seg   = seg;
        slice->rof   = rof;
        slice->start = seg->seg_absof + rof;
        slice->end   = slice->start + size;

        rd_assert(seg->seg_absof + rof >= slice->start &&
                  seg->seg_absof + rof <= slice->end);

        rd_assert(slice->end <= rd_buf_len(rbuf));

        return 0;
}

/**
 * @brief Initialize new slice of \p size bytes starting at offset \p absof
 *
 * @returns 0 on success or -1 if there is not at least \p size bytes available
 *          in the buffer.
 */
int rd_slice_init(rd_slice_t *slice,
                  const rd_buf_t *rbuf,
                  size_t absof,
                  size_t size) {
        const rd_segment_t *seg =
            rd_buf_get_segment_at_offset(rbuf, NULL, absof);
        if (unlikely(!seg))
                return -1;

        return rd_slice_init_seg(slice, rbuf, seg, absof - seg->seg_absof,
                                 size);
}

/**
 * @brief Initialize new slice covering the full buffer \p rbuf
 */
void rd_slice_init_full(rd_slice_t *slice, const rd_buf_t *rbuf) {
        int r = rd_slice_init(slice, rbuf, 0, rd_buf_len(rbuf));
        rd_assert(r == 0);
}



/**
 * @sa rd_slice_reader() rd_slice_peeker()
 */
size_t rd_slice_reader0(rd_slice_t *slice, const void **p, int update_pos) {
        size_t rof = slice->rof;
        size_t rlen;
        const rd_segment_t *seg;

        /* Find segment with non-zero payload */
        for (seg = slice->seg;
             seg && seg->seg_absof + rof < slice->end && seg->seg_of == rof;
             seg = TAILQ_NEXT(seg, seg_link))
                rof = 0;

        if (unlikely(!seg || seg->seg_absof + rof >= slice->end))
                return 0;

        *p   = (const void *)(seg->seg_p + rof);
        rlen = RD_MIN(seg->seg_of - rof, rd_slice_remains(slice));

        if (update_pos) {
                if (slice->seg != seg) {
                        rd_assert(seg->seg_absof + rof >= slice->start &&
                                  seg->seg_absof + rof + rlen <= slice->end);
                        slice->seg = seg;
                        slice->rof = rlen;
                } else {
                        slice->rof += rlen;
                }
        }

        return rlen;
}


/**
 * @brief Convenience reader iterator interface.
 *
 *        Call repeatedly from while loop until it returns 0.
 *
 * @param slice slice to read from, position will be updated.
 * @param p will be set to the start of \p *rlenp contiguous bytes of memory
 * @param rlenp will be set to the number of bytes available in \p p
 *
 * @returns the number of bytes read, or 0 if slice is empty.
 */
size_t rd_slice_reader(rd_slice_t *slice, const void **p) {
        return rd_slice_reader0(slice, p, 1 /*update_pos*/);
}

/**
 * @brief Identical to rd_slice_reader() but does NOT update the read position
 */
size_t rd_slice_peeker(const rd_slice_t *slice, const void **p) {
        return rd_slice_reader0((rd_slice_t *)slice, p, 0 /*dont update_pos*/);
}



/**
 * @brief Read \p size bytes from current read position,
 *        advancing the read offset by the number of bytes copied to \p dst.
 *
 *        If there are less than \p size remaining in the buffer
 *        then 0 is returned and no bytes are copied.
 *
 * @returns \p size, or 0 if \p size bytes are not available in buffer.
 *
 * @remark This performs a complete read, no partitial reads.
 *
 * @remark If \p dst is NULL only the read position is updated.
 */
size_t rd_slice_read(rd_slice_t *slice, void *dst, size_t size) {
        size_t remains = size;
        char *d        = (char *)dst; /* Possibly NULL */
        size_t rlen;
        const void *p;
        size_t orig_end = slice->end;

        if (unlikely(rd_slice_remains(slice) < size))
                return 0;

        /* Temporarily shrink slice to offset + \p size */
        slice->end = rd_slice_abs_offset(slice) + size;

        while ((rlen = rd_slice_reader(slice, &p))) {
                rd_dassert(remains >= rlen);
                if (dst) {
                        memcpy(d, p, rlen);
                        d += rlen;
                }
                remains -= rlen;
        }

        rd_dassert(remains == 0);

        /* Restore original size */
        slice->end = orig_end;

        return size;
}


/**
 * @brief Read \p size bytes from absolute slice offset \p offset
 *        and store in \p dst, without updating the slice read position.
 *
 * @returns \p size if the offset and size was within the slice, else 0.
 */
size_t
rd_slice_peek(const rd_slice_t *slice, size_t offset, void *dst, size_t size) {
        rd_slice_t sub = *slice;

        if (unlikely(rd_slice_seek(&sub, offset) == -1))
                return 0;

        return rd_slice_read(&sub, dst, size);
}


/**
 * @brief Read a varint-encoded unsigned integer from \p slice,
 *        storing the decoded number in \p nump on success (return value > 0).
 *
 * @returns the number of bytes read on success or 0 in case of
 *          buffer underflow.
 */
size_t rd_slice_read_uvarint(rd_slice_t *slice, uint64_t *nump) {
        uint64_t num = 0;
        int shift    = 0;
        size_t rof   = slice->rof;
        const rd_segment_t *seg;

        /* Traverse segments, byte for byte, until varint is decoded
         * or no more segments available (underflow). */
        for (seg = slice->seg; seg; seg = TAILQ_NEXT(seg, seg_link)) {
                for (; rof < seg->seg_of; rof++) {
                        unsigned char oct;

                        if (unlikely(seg->seg_absof + rof >= slice->end))
                                return 0; /* Underflow */

                        oct = *(const unsigned char *)(seg->seg_p + rof);

                        num |= (uint64_t)(oct & 0x7f) << shift;
                        shift += 7;

                        if (!(oct & 0x80)) {
                                /* Done: no more bytes expected */
                                *nump = num;

                                /* Update slice's read pointer and offset */
                                if (slice->seg != seg)
                                        slice->seg = seg;
                                slice->rof = rof + 1; /* including the +1 byte
                                                       * that was just read */

                                return shift / 7;
                        }
                }

                rof = 0;
        }

        return 0; /* Underflow */
}


/**
 * @returns a pointer to \p size contiguous bytes at the current read offset.
 *          If there isn't \p size contiguous bytes available NULL will
 *          be returned.
 *
 * @remark The read position is updated to point past \p size.
 */
const void *rd_slice_ensure_contig(rd_slice_t *slice, size_t size) {
        void *p;

        if (unlikely(rd_slice_remains(slice) < size ||
                     slice->rof + size > slice->seg->seg_of))
                return NULL;

        p = slice->seg->seg_p + slice->rof;

        rd_slice_read(slice, NULL, size);

        return p;
}



/**
 * @brief Sets the slice's read position. The offset is the slice offset,
 *        not buffer offset.
 *
 * @returns 0 if offset was within range, else -1 in which case the position
 *          is not changed.
 */
int rd_slice_seek(rd_slice_t *slice, size_t offset) {
        const rd_segment_t *seg;
        size_t absof = slice->start + offset;

        if (unlikely(absof >= slice->end))
                return -1;

        seg = rd_buf_get_segment_at_offset(slice->buf, slice->seg, absof);
        rd_assert(seg);

        slice->seg = seg;
        slice->rof = absof - seg->seg_absof;
        rd_assert(seg->seg_absof + slice->rof >= slice->start &&
                  seg->seg_absof + slice->rof <= slice->end);

        return 0;
}


/**
 * @brief Narrow the current slice to \p size, saving
 *        the original slice state info \p save_slice.
 *
 *        Use rd_slice_widen() to restore the saved slice
 *        with the read count updated from the narrowed slice.
 *
 *        This is useful for reading a sub-slice of a larger slice
 *        without having to pass the lesser length around.
 *
 * @returns 1 if enough underlying slice buffer memory is available, else 0.
 */
int rd_slice_narrow(rd_slice_t *slice, rd_slice_t *save_slice, size_t size) {
        if (unlikely(slice->start + size > slice->end))
                return 0;
        *save_slice = *slice;
        slice->end  = slice->start + size;
        rd_assert(rd_slice_abs_offset(slice) <= slice->end);
        return 1;
}

/**
 * @brief Same as rd_slice_narrow() but using a relative size \p relsize
 *        from the current read position.
 */
int rd_slice_narrow_relative(rd_slice_t *slice,
                             rd_slice_t *save_slice,
                             size_t relsize) {
        return rd_slice_narrow(slice, save_slice,
                               rd_slice_offset(slice) + relsize);
}


/**
 * @brief Restore the original \p save_slice size from a previous call to
 *        rd_slice_narrow(), while keeping the updated read pointer from
 *        \p slice.
 */
void rd_slice_widen(rd_slice_t *slice, const rd_slice_t *save_slice) {
        slice->end = save_slice->end;
}


/**
 * @brief Copy the original slice \p orig to \p new_slice and adjust
 *        the new slice length to \p size.
 *
 *        This is a side-effect free form of rd_slice_narrow() which is not to
 *        be used with rd_slice_widen().
 *
 * @returns 1 if enough underlying slice buffer memory is available, else 0.
 */
int rd_slice_narrow_copy(const rd_slice_t *orig,
                         rd_slice_t *new_slice,
                         size_t size) {
        if (unlikely(orig->start + size > orig->end))
                return 0;
        *new_slice     = *orig;
        new_slice->end = orig->start + size;
        rd_assert(rd_slice_abs_offset(new_slice) <= new_slice->end);
        return 1;
}

/**
 * @brief Same as rd_slice_narrow_copy() but with a relative size from
 *        the current read position.
 */
int rd_slice_narrow_copy_relative(const rd_slice_t *orig,
                                  rd_slice_t *new_slice,
                                  size_t relsize) {
        return rd_slice_narrow_copy(orig, new_slice,
                                    rd_slice_offset(orig) + relsize);
}



/**
 * @brief Set up the iovec \p iovs (of size \p iov_max) with the readable
 *        segments from the slice's current read position.
 *
 * @param iovcntp will be set to the number of populated \p iovs[]
 * @param size_max limits the total number of bytes made available.
 *                 Note: this value may be overshot with the size of one
 *                       segment.
 *
 * @returns the total number of bytes in the represented segments.
 *
 * @remark will NOT update the read position.
 */
size_t rd_slice_get_iov(const rd_slice_t *slice,
                        struct iovec *iovs,
                        size_t *iovcntp,
                        size_t iov_max,
                        size_t size_max) {
        const void *p;
        size_t rlen;
        size_t iovcnt   = 0;
        size_t sum      = 0;
        rd_slice_t copy = *slice; /* Use a copy of the slice so we dont
                                   * update the position for the caller. */

        while (sum < size_max && iovcnt < iov_max &&
               (rlen = rd_slice_reader(&copy, &p))) {
                iovs[iovcnt].iov_base  = (void *)p;
                iovs[iovcnt++].iov_len = rlen;

                sum += rlen;
        }

        *iovcntp = iovcnt;

        return sum;
}



/**
 * @brief CRC32 calculation of slice.
 *
 * @returns the calculated CRC
 *
 * @remark the slice's position is updated.
 */
uint32_t rd_slice_crc32(rd_slice_t *slice) {
        rd_crc32_t crc;
        const void *p;
        size_t rlen;

        crc = rd_crc32_init();

        while ((rlen = rd_slice_reader(slice, &p)))
                crc = rd_crc32_update(crc, p, rlen);

        return (uint32_t)rd_crc32_finalize(crc);
}

/**
 * @brief Compute CRC-32C of segments starting at at buffer position \p absof,
 *        also supporting the case where the position/offset is not at the
 *        start of the first segment.
 *
 * @remark the slice's position is updated.
 */
uint32_t rd_slice_crc32c(rd_slice_t *slice) {
        const void *p;
        size_t rlen;
        uint32_t crc = 0;

        while ((rlen = rd_slice_reader(slice, &p)))
                crc = rd_crc32c(crc, (const char *)p, rlen);

        return crc;
}



/**
 * @name Debugging dumpers
 *
 *
 */

static void rd_segment_dump(const rd_segment_t *seg,
                            const char *ind,
                            size_t relof,
                            int do_hexdump) {
        fprintf(stderr,
                "%s((rd_segment_t *)%p): "
                "p %p, of %" PRIusz
                ", "
                "absof %" PRIusz ", size %" PRIusz ", free %p, flags 0x%x\n",
                ind, seg, seg->seg_p, seg->seg_of, seg->seg_absof,
                seg->seg_size, seg->seg_free, seg->seg_flags);
        rd_assert(relof <= seg->seg_of);
        if (do_hexdump)
                rd_hexdump(stderr, "segment", seg->seg_p + relof,
                           seg->seg_of - relof);
}

void rd_buf_dump(const rd_buf_t *rbuf, int do_hexdump) {
        const rd_segment_t *seg;

        fprintf(stderr,
                "((rd_buf_t *)%p):\n"
                " len %" PRIusz " size %" PRIusz ", %" PRIusz "/%" PRIusz
                " extra memory used\n",
                rbuf, rbuf->rbuf_len, rbuf->rbuf_size, rbuf->rbuf_extra_len,
                rbuf->rbuf_extra_size);

        if (rbuf->rbuf_wpos) {
                fprintf(stderr, " wpos:\n");
                rd_segment_dump(rbuf->rbuf_wpos, "  ", 0, 0);
        }

        if (rbuf->rbuf_segment_cnt > 0) {
                size_t segcnt = 0;

                fprintf(stderr, " %" PRIusz " linked segments:\n",
                        rbuf->rbuf_segment_cnt);
                TAILQ_FOREACH(seg, &rbuf->rbuf_segments, seg_link) {
                        rd_segment_dump(seg, "  ", 0, do_hexdump);
                        segcnt++;
                        rd_assert(segcnt <= rbuf->rbuf_segment_cnt);
                }
        }
}

void rd_slice_dump(const rd_slice_t *slice, int do_hexdump) {
        const rd_segment_t *seg;
        size_t relof;

        fprintf(stderr,
                "((rd_slice_t *)%p):\n"
                "  buf %p (len %" PRIusz "), seg %p (absof %" PRIusz
                "), "
                "rof %" PRIusz ", start %" PRIusz ", end %" PRIusz
                ", size %" PRIusz ", offset %" PRIusz "\n",
                slice, slice->buf, rd_buf_len(slice->buf), slice->seg,
                slice->seg ? slice->seg->seg_absof : 0, slice->rof,
                slice->start, slice->end, rd_slice_size(slice),
                rd_slice_offset(slice));
        relof = slice->rof;

        for (seg = slice->seg; seg; seg = TAILQ_NEXT(seg, seg_link)) {
                rd_segment_dump(seg, "  ", relof, do_hexdump);
                relof = 0;
        }
}

