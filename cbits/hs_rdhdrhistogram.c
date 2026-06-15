/*
 * This license covers this C port of
 * Coda Hale's Golang HdrHistogram https://github.com/codahale/hdrhistogram
 * at revision 3a0bb77429bd3a61596f5e8a3172445844342120
 *
 * ----------------------------------------------------------------------------
 *
 * The MIT License (MIT)
 *
 * Copyright (c) 2014 Coda Hale
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

/*
 * librdkafka - Apache Kafka C library
 *
 * Copyright (c) 2018, Magnus Edenhill
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
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

/**
 * Minimal C Hdr_Histogram based on Coda Hale's Golang implementation.
 * https://github.com/codahale/hdr_histogram
 *
 *
 * A Histogram is a lossy data structure used to record the distribution of
 * non-normally distributed data (like latency) with a high degree of accuracy
 * and a bounded degree of precision.
 *
 *
 */

#include "hs_rd.h"

#include <stdlib.h>
#include <string.h>
#include <math.h>

#include "hs_rdhdrhistogram.h"
#include "hs_rdfloat.h"

void rd_hdr_histogram_destroy(rd_hdr_histogram_t *hdr) {
        rd_free(hdr);
}

rd_hdr_histogram_t *rd_hdr_histogram_new(int64_t minValue,
                                         int64_t maxValue,
                                         int significantFigures) {
        rd_hdr_histogram_t *hdr;
        int64_t largestValueWithSingleUnitResolution;
        int32_t subBucketCountMagnitude;
        int32_t subBucketHalfCountMagnitude;
        int32_t unitMagnitude;
        int32_t subBucketCount;
        int32_t subBucketHalfCount;
        int64_t subBucketMask;
        int64_t smallestUntrackableValue;
        int32_t bucketsNeeded = 1;
        int32_t bucketCount;
        int32_t countsLen;

        if (significantFigures < 1 || significantFigures > 5)
                return NULL;

        largestValueWithSingleUnitResolution =
            (int64_t)(2.0 * pow(10.0, (double)significantFigures));

        subBucketCountMagnitude =
            (int32_t)ceil(log2((double)largestValueWithSingleUnitResolution));

        subBucketHalfCountMagnitude = RD_MAX(subBucketCountMagnitude, 1) - 1;

        unitMagnitude = (int32_t)RD_MAX(floor(log2((double)minValue)), 0);

        subBucketCount =
            (int32_t)pow(2, (double)subBucketHalfCountMagnitude + 1.0);

        subBucketHalfCount = subBucketCount / 2;

        subBucketMask = (int64_t)(subBucketCount - 1) << unitMagnitude;

        /* Determine exponent range needed to support the trackable
         * value with no overflow: */
        smallestUntrackableValue = (int64_t)subBucketCount << unitMagnitude;
        while (smallestUntrackableValue < maxValue) {
                smallestUntrackableValue <<= 1;
                bucketsNeeded++;
        }

        bucketCount = bucketsNeeded;
        countsLen   = (bucketCount + 1) * (subBucketCount / 2);
        hdr = rd_calloc(1, sizeof(*hdr) + (sizeof(*hdr->counts) * countsLen));
        hdr->counts        = (int64_t *)(hdr + 1);
        hdr->allocatedSize = sizeof(*hdr) + (sizeof(*hdr->counts) * countsLen);

        hdr->lowestTrackableValue        = minValue;
        hdr->highestTrackableValue       = maxValue;
        hdr->unitMagnitude               = unitMagnitude;
        hdr->significantFigures          = significantFigures;
        hdr->subBucketHalfCountMagnitude = subBucketHalfCountMagnitude;
        hdr->subBucketHalfCount          = subBucketHalfCount;
        hdr->subBucketMask               = subBucketMask;
        hdr->subBucketCount              = subBucketCount;
        hdr->bucketCount                 = bucketCount;
        hdr->countsLen                   = countsLen;
        hdr->totalCount                  = 0;
        hdr->lowestOutOfRange            = minValue;
        hdr->highestOutOfRange           = maxValue;

        return hdr;
}

/**
 * @brief Deletes all recorded values and resets histogram.
 */
void rd_hdr_histogram_reset(rd_hdr_histogram_t *hdr) {
        int32_t i;
        hdr->totalCount = 0;
        for (i = 0; i < hdr->countsLen; i++)
                hdr->counts[i] = 0;
}



static RD_INLINE int32_t rd_hdr_countsIndex(const rd_hdr_histogram_t *hdr,
                                            int32_t bucketIdx,
                                            int32_t subBucketIdx) {
        int32_t bucketBaseIdx = (bucketIdx + 1)
                                << hdr->subBucketHalfCountMagnitude;
        int32_t offsetInBucket = subBucketIdx - hdr->subBucketHalfCount;
        return bucketBaseIdx + offsetInBucket;
}

static RD_INLINE int64_t rd_hdr_getCountAtIndex(const rd_hdr_histogram_t *hdr,
                                                int32_t bucketIdx,
                                                int32_t subBucketIdx) {
        return hdr->counts[rd_hdr_countsIndex(hdr, bucketIdx, subBucketIdx)];
}


static RD_INLINE int64_t bitLen(int64_t x) {
        int64_t n = 0;
        for (; x >= 0x8000; x >>= 16)
                n += 16;
        if (x >= 0x80) {
                x >>= 8;
                n += 8;
        }
        if (x >= 0x8) {
                x >>= 4;
                n += 4;
        }
        if (x >= 0x2) {
                x >>= 2;
                n += 2;
        }
        if (x >= 0x1)
                n++;
        return n;
}


static RD_INLINE int32_t rd_hdr_getBucketIndex(const rd_hdr_histogram_t *hdr,
                                               int64_t v) {
        int64_t pow2Ceiling = bitLen(v | hdr->subBucketMask);
        return (int32_t)(pow2Ceiling - (int64_t)hdr->unitMagnitude -
                         (int64_t)(hdr->subBucketHalfCountMagnitude + 1));
}

static RD_INLINE int32_t rd_hdr_getSubBucketIdx(const rd_hdr_histogram_t *hdr,
                                                int64_t v,
                                                int32_t idx) {
        return (int32_t)(v >> ((int64_t)idx + (int64_t)hdr->unitMagnitude));
}

static RD_INLINE int64_t rd_hdr_valueFromIndex(const rd_hdr_histogram_t *hdr,
                                               int32_t bucketIdx,
                                               int32_t subBucketIdx) {
        return (int64_t)subBucketIdx
               << ((int64_t)bucketIdx + hdr->unitMagnitude);
}

static RD_INLINE int64_t
rd_hdr_sizeOfEquivalentValueRange(const rd_hdr_histogram_t *hdr, int64_t v) {
        int32_t bucketIdx      = rd_hdr_getBucketIndex(hdr, v);
        int32_t subBucketIdx   = rd_hdr_getSubBucketIdx(hdr, v, bucketIdx);
        int32_t adjustedBucket = bucketIdx;
        if (unlikely(subBucketIdx >= hdr->subBucketCount))
                adjustedBucket++;
        return (int64_t)1 << (hdr->unitMagnitude + (int64_t)adjustedBucket);
}

static RD_INLINE int64_t
rd_hdr_lowestEquivalentValue(const rd_hdr_histogram_t *hdr, int64_t v) {
        int32_t bucketIdx    = rd_hdr_getBucketIndex(hdr, v);
        int32_t subBucketIdx = rd_hdr_getSubBucketIdx(hdr, v, bucketIdx);
        return rd_hdr_valueFromIndex(hdr, bucketIdx, subBucketIdx);
}


static RD_INLINE int64_t
rd_hdr_nextNonEquivalentValue(const rd_hdr_histogram_t *hdr, int64_t v) {
        return rd_hdr_lowestEquivalentValue(hdr, v) +
               rd_hdr_sizeOfEquivalentValueRange(hdr, v);
}


static RD_INLINE int64_t
rd_hdr_highestEquivalentValue(const rd_hdr_histogram_t *hdr, int64_t v) {
        return rd_hdr_nextNonEquivalentValue(hdr, v) - 1;
}

static RD_INLINE int64_t
rd_hdr_medianEquivalentValue(const rd_hdr_histogram_t *hdr, int64_t v) {
        return rd_hdr_lowestEquivalentValue(hdr, v) +
               (rd_hdr_sizeOfEquivalentValueRange(hdr, v) >> 1);
}


static RD_INLINE int32_t rd_hdr_countsIndexFor(const rd_hdr_histogram_t *hdr,
                                               int64_t v) {
        int32_t bucketIdx    = rd_hdr_getBucketIndex(hdr, v);
        int32_t subBucketIdx = rd_hdr_getSubBucketIdx(hdr, v, bucketIdx);
        return rd_hdr_countsIndex(hdr, bucketIdx, subBucketIdx);
}



typedef struct rd_hdr_iter_s {
        const rd_hdr_histogram_t *hdr;
        int bucketIdx;
        int subBucketIdx;
        int64_t countAtIdx;
        int64_t countToIdx;
        int64_t valueFromIdx;
        int64_t highestEquivalentValue;
} rd_hdr_iter_t;

#define RD_HDR_ITER_INIT(hdr)                                                  \
        { .hdr = hdr, .subBucketIdx = -1 }

static int rd_hdr_iter_next(rd_hdr_iter_t *it) {
        const rd_hdr_histogram_t *hdr = it->hdr;

        if (unlikely(it->countToIdx >= hdr->totalCount))
                return 0;

        it->subBucketIdx++;
        if (unlikely(it->subBucketIdx >= hdr->subBucketCount)) {
                it->subBucketIdx = hdr->subBucketHalfCount;
                it->bucketIdx++;
        }

        if (unlikely(it->bucketIdx >= hdr->bucketCount))
                return 0;

        it->countAtIdx =
            rd_hdr_getCountAtIndex(hdr, it->bucketIdx, it->subBucketIdx);
        it->countToIdx += it->countAtIdx;
        it->valueFromIdx =
            rd_hdr_valueFromIndex(hdr, it->bucketIdx, it->subBucketIdx);
        it->highestEquivalentValue =
            rd_hdr_highestEquivalentValue(hdr, it->valueFromIdx);

        return 1;
}


double rd_hdr_histogram_stddev(rd_hdr_histogram_t *hdr) {
        double mean;
        double geometricDevTotal = 0.0;
        rd_hdr_iter_t it         = RD_HDR_ITER_INIT(hdr);

        if (hdr->totalCount == 0)
                return 0;

        mean = rd_hdr_histogram_mean(hdr);


        while (rd_hdr_iter_next(&it)) {
                double dev;

                if (it.countAtIdx == 0)
                        continue;

                dev =
                    (double)rd_hdr_medianEquivalentValue(hdr, it.valueFromIdx) -
                    mean;
                geometricDevTotal += (dev * dev) * (double)it.countAtIdx;
        }

        return sqrt(geometricDevTotal / (double)hdr->totalCount);
}


/**
 * @returns the approximate maximum recorded value.
 */
int64_t rd_hdr_histogram_max(const rd_hdr_histogram_t *hdr) {
        int64_t vmax     = 0;
        rd_hdr_iter_t it = RD_HDR_ITER_INIT(hdr);

        while (rd_hdr_iter_next(&it)) {
                if (it.countAtIdx != 0)
                        vmax = it.highestEquivalentValue;
        }
        return rd_hdr_highestEquivalentValue(hdr, vmax);
}

/**
 * @returns the approximate minimum recorded value.
 */
int64_t rd_hdr_histogram_min(const rd_hdr_histogram_t *hdr) {
        int64_t vmin     = 0;
        rd_hdr_iter_t it = RD_HDR_ITER_INIT(hdr);

        while (rd_hdr_iter_next(&it)) {
                if (it.countAtIdx != 0 && vmin == 0) {
                        vmin = it.highestEquivalentValue;
                        break;
                }
        }
        return rd_hdr_lowestEquivalentValue(hdr, vmin);
}

/**
 * @returns the approximate arithmetic mean of the recorded values.
 */
double rd_hdr_histogram_mean(const rd_hdr_histogram_t *hdr) {
        int64_t total    = 0;
        rd_hdr_iter_t it = RD_HDR_ITER_INIT(hdr);

        if (hdr->totalCount == 0)
                return 0.0;

        while (rd_hdr_iter_next(&it)) {
                if (it.countAtIdx != 0)
                        total += it.countAtIdx * rd_hdr_medianEquivalentValue(
                                                     hdr, it.valueFromIdx);
        }
        return (double)total / (double)hdr->totalCount;
}



/**
 * @brief Records the given value.
 *
 * @returns 1 if value was recorded or 0 if value is out of range.
 */

int rd_hdr_histogram_record(rd_hdr_histogram_t *hdr, int64_t v) {
        int32_t idx = rd_hdr_countsIndexFor(hdr, v);

        if (idx < 0 || hdr->countsLen <= idx) {
                hdr->outOfRangeCount++;
                if (v > hdr->highestOutOfRange)
                        hdr->highestOutOfRange = v;
                if (v < hdr->lowestOutOfRange)
                        hdr->lowestOutOfRange = v;
                return 0;
        }

        hdr->counts[idx]++;
        hdr->totalCount++;

        return 1;
}


/**
 * @returns the recorded value at the given quantile (0..100).
 */
int64_t rd_hdr_histogram_quantile(const rd_hdr_histogram_t *hdr, double q) {
        int64_t total = 0;
        int64_t countAtPercentile;
        rd_hdr_iter_t it = RD_HDR_ITER_INIT(hdr);

        if (q > 100.0)
                q = 100.0;

        countAtPercentile =
            (int64_t)(((q / 100.0) * (double)hdr->totalCount) + 0.5);

        while (rd_hdr_iter_next(&it)) {
                total += it.countAtIdx;
                if (total >= countAtPercentile)
                        return rd_hdr_highestEquivalentValue(hdr,
                                                             it.valueFromIdx);
        }

        return 0;
}

