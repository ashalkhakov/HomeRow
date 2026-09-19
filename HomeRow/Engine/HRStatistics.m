/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * HomeRow is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version.  It comes with ABSOLUTELY NO WARRANTY.  See COPYING.
 */
#import "HRStatistics.h"

@implementation HRStatSample

- (HRStatKind)kind
{
    if ([_mode isEqualToString:@"lesson"]) return HRStatKindCourse;
    if ([_mode isEqualToString:@"code"]) return HRStatKindCode;
    return HRStatKindTests;
}

@end

@implementation HRStatDay
@end

@implementation HRStatKey

- (double)errorRate
{
    NSUInteger total = _hits + _misses;
    return total > 0 ? (double)_misses / (double)total : 0.0;
}

@end

@implementation HRStatistics
{
    NSTimeZone *_timeZone;
}

- (instancetype)initWithSamples:(NSArray *)samples kind:(HRStatKind)kind days:(NSUInteger)days
                            now:(NSDate *)now timeZone:(NSTimeZone *)timeZone
{
    if ((self = [super init])) {
        _timeZone = timeZone ?: [NSTimeZone localTimeZone];
        NSDate *cutoff = days > 0 ? [now dateByAddingTimeInterval:-(NSTimeInterval)days * 86400.0] : nil;
        NSMutableArray *kept = [NSMutableArray array];
        for (HRStatSample *s in samples) {
            if (!s.date) continue;
            if (kind != HRStatKindAll && [s kind] != kind) continue;
            if (cutoff && [s.date compare:cutoff] == NSOrderedAscending) continue;
            [kept addObject:s];
        }
        [kept sortUsingComparator:^NSComparisonResult(HRStatSample *a, HRStatSample *b) {
            return [a.date compare:b.date];
        }];
        _samples = [kept copy];

        double wpmTime = 0.0, accuracyTime = 0.0;
        for (HRStatSample *s in _samples) {
            /* a result without a duration still counts as a test; give it
             * a second so that it cannot divide by zero or vanish */
            NSTimeInterval d = s.duration > 0.0 ? s.duration : 1.0;
            _totalDuration += s.duration;
            wpmTime += s.wpm * d;
            accuracyTime += s.accuracy * d;
            _bestWpm = MAX(_bestWpm, s.wpm);
        }
        _count = [_samples count];
        NSTimeInterval weight = 0.0;
        for (HRStatSample *s in _samples) weight += s.duration > 0.0 ? s.duration : 1.0;
        if (weight > 0.0) {
            _averageWpm = wpmTime / weight;
            _averageAccuracy = accuracyTime / weight;
        }
        NSUInteger recent = MIN((NSUInteger)10, _count);
        for (NSUInteger i = _count - recent; i < _count; i++) _recentWpm += ((HRStatSample *)_samples[i]).wpm;
        if (recent > 0) _recentWpm /= (double)recent;
    }
    return self;
}

- (NSArray *)movingAverageOfKey:(NSString *)key window:(NSUInteger)window
{
    if (window == 0) window = 1;
    NSMutableArray *out = [NSMutableArray arrayWithCapacity:_count];
    double sum = 0.0;
    for (NSUInteger i = 0; i < _count; i++) {
        sum += [[_samples[i] valueForKey:key] doubleValue];
        if (i >= window) sum -= [[_samples[i - window] valueForKey:key] doubleValue];
        [out addObject:@(sum / (double)MIN(i + 1, window))];
    }
    return out;
}

/* Days are counted by hand -- seconds since the reference date, shifted by
 * the zone's offset at that moment, over 86400 -- and not with NSCalendar:
 * gnustep-base's NSCalendar does nothing at all unless it was built with
 * ICU.  A day with a DST change in it is an hour off at one end, which for
 * "how much did I type that day" does not matter. */
- (long)dayNumberOfDate:(NSDate *)date
{
    double local = [date timeIntervalSinceReferenceDate] + (double)[_timeZone secondsFromGMTForDate:date];
    return (long)floor(local / 86400.0);
}

- (NSArray *)days
{
    if (_count == 0) return @[];
    NSMutableArray *out = [NSMutableArray array];
    long first = [self dayNumberOfDate:((HRStatSample *)_samples[0]).date];
    long last = [self dayNumberOfDate:((HRStatSample *)[_samples lastObject]).date];
    NSUInteger i = 0;
    for (long number = first; number <= last; number++) {
        HRStatDay *d = [[HRStatDay alloc] init];
        /* noon: safely inside the day whatever the offset does */
        NSDate *noon = [NSDate dateWithTimeIntervalSinceReferenceDate:(double)number * 86400.0 + 43200.0];
        d.day = [NSDate dateWithTimeIntervalSinceReferenceDate:
                 (double)number * 86400.0 - (double)[_timeZone secondsFromGMTForDate:noon]];
        double wpmTime = 0.0, accuracyTime = 0.0, weight = 0.0;
        while (i < _count && [self dayNumberOfDate:((HRStatSample *)_samples[i]).date] <= number) {
            HRStatSample *s = _samples[i++];
            NSTimeInterval w = s.duration > 0.0 ? s.duration : 1.0;
            d.count++;
            d.duration += s.duration;
            wpmTime += s.wpm * w;
            accuracyTime += s.accuracy * w;
            weight += w;
        }
        if (weight > 0.0) {
            d.wpm = wpmTime / weight;
            d.accuracy = accuracyTime / weight;
        }
        [out addObject:d];
    }
    return out;
}

+ (NSArray *)keysFromCounts:(NSDictionary *)counts minimumPresses:(NSUInteger)minimumPresses
{
    NSMutableArray *keys = [NSMutableArray array];
    for (NSString *ch in counts) {
        HRStatKey *k = [[HRStatKey alloc] init];
        k.character = ch;
        k.hits = [counts[ch][@"hits"] unsignedIntegerValue];
        k.misses = [counts[ch][@"misses"] unsignedIntegerValue];
        if (k.hits + k.misses < minimumPresses) continue;
        [keys addObject:k];
    }
    [keys sortUsingComparator:^NSComparisonResult(HRStatKey *a, HRStatKey *b) {
        double ra = [a errorRate], rb = [b errorRate];
        if (ra != rb) return ra > rb ? NSOrderedAscending : NSOrderedDescending;
        if (a.misses != b.misses) return a.misses > b.misses ? NSOrderedAscending : NSOrderedDescending;
        return [a.character compare:b.character];
    }];
    return keys;
}

+ (NSString *)shortStringForDate:(NSDate *)date timeZone:(NSTimeZone *)timeZone
{
    if (!date) return @"";
    NSTimeZone *zone = timeZone ?: [NSTimeZone localTimeZone];
    double local = [date timeIntervalSince1970] + (double)[zone secondsFromGMTForDate:date];
    long z = (long)floor(local / 86400.0) + 719468;
    /* days -> civil date (Howard Hinnant's algorithm, proleptic Gregorian) */
    long era = (z >= 0 ? z : z - 146096) / 146097;
    long doe = z - era * 146097;
    long yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
    long doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    long mp = (5 * doy + 2) / 153;
    long day = doy - (153 * mp + 2) / 5 + 1;
    long month = mp < 10 ? mp + 3 : mp - 9;
    static NSString * const names[] = {@"Jan", @"Feb", @"Mar", @"Apr", @"May", @"Jun",
                                       @"Jul", @"Aug", @"Sep", @"Oct", @"Nov", @"Dec"};
    return [NSString stringWithFormat:@"%@ %ld", names[month - 1], day];
}

+ (NSString *)stringForDuration:(NSTimeInterval)duration
{
    long seconds = (long)(duration + 0.5);
    if (seconds < 60) return [NSString stringWithFormat:@"%ld s", seconds];
    long minutes = (seconds + 30) / 60;
    if (minutes < 60) return [NSString stringWithFormat:@"%ld min", minutes];
    return [NSString stringWithFormat:@"%ld h %02ld min", minutes / 60, minutes % 60];
}

@end
