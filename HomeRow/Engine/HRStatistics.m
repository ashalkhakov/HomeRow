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

- (instancetype)init
{
    if ((self = [super init])) _overhead = -1.0;
    return self;
}

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

- (NSTimeInterval)averageTime
{
    return _timedHits > 0 ? _totalTime / (double)_timedHits : 0.0;
}

@end

NSString * const HRKeyClassLetters = @"letters";
NSString * const HRKeyClassCapitals = @"capitals";
NSString * const HRKeyClassDigits = @"digits";
NSString * const HRKeyClassBrackets = @"brackets";
NSString * const HRKeyClassOperators = @"operators";
NSString * const HRKeyClassPunctuation = @"punctuation";
NSString * const HRKeyClassWhitespace = @"whitespace";

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
        double overheadTime = 0.0, overheadWeight = 0.0;
        for (HRStatSample *s in _samples) {
            if (s.overhead < 0.0) continue;
            NSTimeInterval d = s.duration > 0.0 ? s.duration : 1.0;
            overheadTime += s.overhead * d;
            overheadWeight += d;
        }
        _averageOverhead = overheadWeight > 0.0 ? overheadTime / overheadWeight : -1.0;
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
        k.timedHits = [counts[ch][@"timed"] unsignedIntegerValue];
        k.totalTime = [counts[ch][@"time"] doubleValue];
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

+ (NSString *)classOfCharacter:(NSString *)character
{
    if ([character length] == 0) return HRKeyClassPunctuation;
    if ([character isEqualToString:@" "] || [character isEqualToString:@"\n"] || [character isEqualToString:@"\t"]) return HRKeyClassWhitespace;
    unichar c = [character characterAtIndex:0];
    if ([[NSCharacterSet decimalDigitCharacterSet] characterIsMember:c]) return HRKeyClassDigits;
    if ([@"()[]{}<>" rangeOfString:character].location != NSNotFound && [character length] == 1) return HRKeyClassBrackets;
    if ([@"+-*/=%&|^~!?:@#$\\" rangeOfString:character].location != NSNotFound && [character length] == 1) return HRKeyClassOperators;
    if ([[NSCharacterSet letterCharacterSet] characterIsMember:c]) {
        return [[NSCharacterSet uppercaseLetterCharacterSet] characterIsMember:c] ? HRKeyClassCapitals : HRKeyClassLetters;
    }
    return HRKeyClassPunctuation;
}

+ (NSArray *)keyClassesFromCounts:(NSDictionary *)counts
{
    NSMutableDictionary *byClass = [NSMutableDictionary dictionary];
    for (NSString *ch in counts) {
        NSString *name = [self classOfCharacter:ch];
        HRStatKey *k = byClass[name];
        if (!k) { k = [[HRStatKey alloc] init]; k.character = name; byClass[name] = k; }
        k.hits += [counts[ch][@"hits"] unsignedIntegerValue];
        k.misses += [counts[ch][@"misses"] unsignedIntegerValue];
        k.timedHits += [counts[ch][@"timed"] unsignedIntegerValue];
        k.totalTime += [counts[ch][@"time"] doubleValue];
    }
    NSMutableArray *rows = [NSMutableArray array];
    for (NSString *name in @[HRKeyClassLetters, HRKeyClassCapitals, HRKeyClassDigits, HRKeyClassBrackets,
                             HRKeyClassOperators, HRKeyClassPunctuation, HRKeyClassWhitespace]) {
        HRStatKey *k = byClass[name];
        if (k && k.hits + k.misses > 0) [rows addObject:k];
    }
    return rows;
}

+ (NSString *)lineForKeyClasses:(NSArray *)classes names:(NSDictionary *)names
{
    NSMutableArray *parts = [NSMutableArray array];
    for (HRStatKey *k in classes) {
        NSString *name = names[k.character] ?: k.character;
        if (k.timedHits > 0) {
            [parts addObject:[NSString stringWithFormat:@"%@ %.0f%% %.0f ms", name, [k errorRate] * 100.0, [k averageTime] * 1000.0]];
        } else {
            [parts addObject:[NSString stringWithFormat:@"%@ %.0f%%", name, [k errorRate] * 100.0]];
        }
    }
    return [parts componentsJoinedByString:@"    "];
}

+ (NSArray *)slowKeysFromCounts:(NSDictionary *)counts minimumTimed:(NSUInteger)minimumTimed
{
    NSMutableArray *keys = [NSMutableArray array];
    for (HRStatKey *k in [self keysFromCounts:counts minimumPresses:0]) {
        if (k.timedHits == 0 || k.timedHits < minimumTimed) continue;
        [keys addObject:k];
    }
    [keys sortUsingComparator:^NSComparisonResult(HRStatKey *a, HRStatKey *b) {
        double ta = [a averageTime], tb = [b averageTime];
        if (ta != tb) return ta > tb ? NSOrderedAscending : NSOrderedDescending;
        return [a.character compare:b.character];
    }];
    return keys;
}

+ (NSTimeInterval)averageKeyTimeInCounts:(NSDictionary *)counts
{
    double time = 0.0, timed = 0.0;
    for (NSString *ch in counts) {
        time += [counts[ch][@"time"] doubleValue];
        timed += [counts[ch][@"timed"] doubleValue];
    }
    return timed > 0.0 ? time / timed : 0.0;
}

+ (NSString *)shortStringForDate:(NSDate *)date timeZone:(NSTimeZone *)timeZone year:(long *)outYear
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
    if (outYear) *outYear = yoe + era * 400 + (month <= 2 ? 1 : 0);
    return [NSString stringWithFormat:@"%@ %ld", names[month - 1], day];
}

+ (NSString *)shortStringForDate:(NSDate *)date timeZone:(NSTimeZone *)timeZone
{
    return [self shortStringForDate:date timeZone:timeZone year:NULL];
}

+ (NSString *)mediumStringForDate:(NSDate *)date timeZone:(NSTimeZone *)timeZone
{
    long year = 0;
    NSString *s = [self shortStringForDate:date timeZone:timeZone year:&year];
    return [s length] > 0 ? [NSString stringWithFormat:@"%@, %ld", s, year] : @"";
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
