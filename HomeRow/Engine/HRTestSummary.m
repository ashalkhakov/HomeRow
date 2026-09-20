/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * HomeRow is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version.  It comes with ABSOLUTELY NO WARRANTY.  See COPYING.
 */
#import "HRTestSummary.h"
#include <math.h>

@implementation HRTestSummary

- (double)keystrokeOverhead
{
    double all = (double)(_correctKeystrokes + _incorrectKeystrokes + _deletions);
    if (all <= 0.0) return 0.0;
    /* what stands, right, at the end: the correct characters and the separators between the words */
    double productive = (double)(_correctCharacters + _separatorsTyped);
    return MAX(0.0, MIN(1.0, 1.0 - productive / all));
}

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
