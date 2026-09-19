/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * This library is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2.1 of the License, or (at
 * your option) any later version.  See COPYING.LIB.
 */
#import "HRTestSummary.h"
#include <math.h>

@implementation HRTestSummary
@end

@implementation HRScorer

+ (double)wpmForCharacters:(NSUInteger)characters duration:(NSTimeInterval)seconds
{
    if (seconds <= 0.0) return 0.0;
    return ((double)characters / 5.0) * (60.0 / seconds);
}

+ (double)consistencyForSamples:(NSArray *)samples
{
    NSUInteger n = [samples count];
    if (n < 2) return n == 1 ? 100.0 : 0.0;
    double sum = 0.0;
    for (NSNumber *s in samples) sum += [s doubleValue];
    double mean = sum / (double)n;
    if (mean <= 0.0) return 0.0;
    double sq = 0.0;
    for (NSNumber *s in samples) {
        double d = [s doubleValue] - mean;
        sq += d * d;
    }
    double cv = sqrt(sq / (double)n) / mean;
    double k = cv + pow(cv, 3) / 3.0 + pow(cv, 5) / 5.0;
    return 100.0 * (1.0 - tanh(k));
}

@end
