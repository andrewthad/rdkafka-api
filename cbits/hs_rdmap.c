/*
 * librdkafka - The Apache Kafka C/C++ library
 *
 * Copyright (c) 2020 Magnus Edenhill
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
#include "hs_rdsysqueue.h"
#include "hs_rdstring.h"
#include "hs_rdmap.h"


static RD_INLINE int rd_map_elem_cmp(const rd_map_elem_t *a,
                                     const rd_map_elem_t *b,
                                     const rd_map_t *rmap) {
        int r = a->hash - b->hash;
        if (r != 0)
                return r;
        return rmap->rmap_cmp(a->key, b->key);
}

static void rd_map_elem_destroy(rd_map_t *rmap, rd_map_elem_t *elem) {
        rd_assert(rmap->rmap_cnt > 0);
        rmap->rmap_cnt--;
        if (rmap->rmap_destroy_key)
                rmap->rmap_destroy_key((void *)elem->key);
        if (rmap->rmap_destroy_value)
                rmap->rmap_destroy_value((void *)elem->value);
        LIST_REMOVE(elem, hlink);
        LIST_REMOVE(elem, link);
        rd_free(elem);
}

static rd_map_elem_t *
rd_map_find(const rd_map_t *rmap, int *bktp, const rd_map_elem_t *skel) {
        int bkt = skel->hash % rmap->rmap_buckets.cnt;
        rd_map_elem_t *elem;

        if (bktp)
                *bktp = bkt;

        LIST_FOREACH(elem, &rmap->rmap_buckets.p[bkt], hlink) {
                if (!rd_map_elem_cmp(skel, elem, rmap))
                        return elem;
        }

        return NULL;
}


/**
 * @brief Create and return new element based on \p skel without value set.
 */
static rd_map_elem_t *
rd_map_insert(rd_map_t *rmap, int bkt, const rd_map_elem_t *skel) {
        rd_map_elem_t *elem;

        elem       = rd_calloc(1, sizeof(*elem));
        elem->hash = skel->hash;
        elem->key  = skel->key; /* takes ownership of key */
        LIST_INSERT_HEAD(&rmap->rmap_buckets.p[bkt], elem, hlink);
        LIST_INSERT_HEAD(&rmap->rmap_iter, elem, link);
        rmap->rmap_cnt++;

        return elem;
}


rd_map_elem_t *rd_map_set(rd_map_t *rmap, void *key, void *value) {
        rd_map_elem_t skel = {.key = key, .hash = rmap->rmap_hash(key)};
        rd_map_elem_t *elem;
        int bkt;

        if (!(elem = rd_map_find(rmap, &bkt, &skel))) {
                elem = rd_map_insert(rmap, bkt, &skel);
        } else {
                if (elem->value && rmap->rmap_destroy_value)
                        rmap->rmap_destroy_value((void *)elem->value);
                if (rmap->rmap_destroy_key)
                        rmap->rmap_destroy_key(key);
        }

        elem->value = value; /* takes ownership of value */

        return elem;
}


void *rd_map_get(const rd_map_t *rmap, const void *key) {
        const rd_map_elem_t skel = {.key  = (void *)key,
                                    .hash = rmap->rmap_hash(key)};
        rd_map_elem_t *elem;

        if (!(elem = rd_map_find(rmap, NULL, &skel)))
                return NULL;

        return (void *)elem->value;
}


void rd_map_delete(rd_map_t *rmap, const void *key) {
        const rd_map_elem_t skel = {.key  = (void *)key,
                                    .hash = rmap->rmap_hash(key)};
        rd_map_elem_t *elem;
        int bkt;

        if (!(elem = rd_map_find(rmap, &bkt, &skel)))
                return;

        rd_map_elem_destroy(rmap, elem);
}


void rd_map_copy(rd_map_t *dst,
                 const rd_map_t *src,
                 rd_map_copy_t *key_copy,
                 rd_map_copy_t *value_copy) {
        const rd_map_elem_t *elem;

        RD_MAP_FOREACH_ELEM(elem, src) {
                rd_map_set(
                    dst, key_copy ? key_copy(elem->key) : (void *)elem->key,
                    value_copy ? value_copy(elem->value) : (void *)elem->value);
        }
}


void rd_map_iter_begin(const rd_map_t *rmap, const rd_map_elem_t **elem) {
        *elem = LIST_FIRST(&rmap->rmap_iter);
}

size_t rd_map_cnt(const rd_map_t *rmap) {
        return (size_t)rmap->rmap_cnt;
}

rd_bool_t rd_map_is_empty(const rd_map_t *rmap) {
        return rmap->rmap_cnt == 0;
}


/**
 * @brief Calculates the number of desired buckets and returns
 *        a struct with pre-allocated buckets.
 */
struct rd_map_buckets rd_map_alloc_buckets(size_t expected_cnt) {
        static const int max_depth      = 15;
        static const int bucket_sizes[] = {
            5,     11,    23,     47,     97,   199, /* default */
            409,   823,   1741,   3469,   6949, 14033,
            28411, 57557, 116731, 236897, -1};
        struct rd_map_buckets buckets = RD_ZERO_INIT;
        int i;

        if (!expected_cnt) {
                buckets.cnt = 199;
        } else {
                /* Strive for an average (at expected element count) depth
                 * of 15 elements per bucket, but limit the maximum
                 * bucket count to the maximum value in bucket_sizes above.
                 * When a real need arise we'll change this to a dynamically
                 * growing hash map instead, but this will do for now. */
                buckets.cnt = bucket_sizes[0];
                for (i = 1; bucket_sizes[i] != -1 &&
                            (int)expected_cnt / max_depth > bucket_sizes[i];
                     i++)
                        buckets.cnt = bucket_sizes[i];
        }

        rd_assert(buckets.cnt > 0);

        buckets.p = rd_calloc(buckets.cnt, sizeof(*buckets.p));

        return buckets;
}


void rd_map_init(rd_map_t *rmap,
                 size_t expected_cnt,
                 int (*cmp)(const void *a, const void *b),
                 unsigned int (*hash)(const void *key),
                 void (*destroy_key)(void *key),
                 void (*destroy_value)(void *value)) {

        memset(rmap, 0, sizeof(*rmap));
        rmap->rmap_buckets       = rd_map_alloc_buckets(expected_cnt);
        rmap->rmap_cmp           = cmp;
        rmap->rmap_hash          = hash;
        rmap->rmap_destroy_key   = destroy_key;
        rmap->rmap_destroy_value = destroy_value;
}

void rd_map_clear(rd_map_t *rmap) {
        rd_map_elem_t *elem;

        while ((elem = LIST_FIRST(&rmap->rmap_iter)))
                rd_map_elem_destroy(rmap, elem);
}

void rd_map_destroy(rd_map_t *rmap) {
        rd_map_clear(rmap);
        rd_free(rmap->rmap_buckets.p);
}


int rd_map_str_cmp(const void *a, const void *b) {
        return strcmp((const char *)a, (const char *)b);
}

/**
 * @brief A djb2 string hasher.
 */
unsigned int rd_map_str_hash(const void *key) {
        const char *str = key;
        return rd_string_hash(str, -1);
}
