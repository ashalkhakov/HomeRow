/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * HomeRow is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version.  It comes with ABSOLUTELY NO WARRANTY.  See COPYING.
 */
#import <XCTest/XCTest.h>
#import "HRStatistics.h"

@interface HRStatisticsTests : XCTestCase
@end

@implementation HRStatisticsTests
{
    NSTimeZone *_utc;
    NSDate *_now;
}

- (void)setUp
{
    _utc = [NSTimeZone timeZoneForSecondsFromGMT:0];
    /* noon UTC of some day: the reference date is a midnight UTC.  (Not
     * built with NSCalendar, which needs ICU on GNUstep.) */
    _now = [NSDate dateWithTimeIntervalSinceReferenceDate:9140.0 * 86400.0 + 43200.0];
}

- (HRStatSample *)sampleDaysAgo:(double)days mode:(NSString *)mode wpm:(double)wpm accuracy:(double)accuracy
                       duration:(NSTimeInterval)duration
{
    HRStatSample *s = [[HRStatSample alloc] init];
    s.date = [_now dateByAddingTimeInterval:-days * 86400.0];
    s.mode = mode;
    s.wpm = wpm;
    s.rawWpm = wpm + 2.0;
    s.accuracy = accuracy;
    s.duration = duration;
    return s;
}

- (void)testHeadlineNumbersAreTimeWeighted
{
    NSArray *samples = @[[self sampleDaysAgo:0 mode:@"time" wpm:60 accuracy:90 duration:30],
                         [self sampleDaysAgo:2 mode:@"words" wpm:30 accuracy:100 duration:10]];
    HRStatistics *st = [[HRStatistics alloc] initWithSamples:samples kind:HRStatKindAll days:0 now:_now timeZone:_utc];
    XCTAssertEqual(st.count, (NSUInteger)2);
    XCTAssertEqualWithAccuracy(st.totalDuration, 40.0, 0.001);
    XCTAssertEqualWithAccuracy(st.averageWpm, (60.0 * 30 + 30.0 * 10) / 40.0, 0.001);
    XCTAssertEqualWithAccuracy(st.averageAccuracy, (90.0 * 30 + 100.0 * 10) / 40.0, 0.001);
    XCTAssertEqualWithAccuracy(st.bestWpm, 60.0, 0.001);
    XCTAssertEqualWithAccuracy(st.recentWpm, 45.0, 0.001);
    HRStatSample *first = st.samples[0];
    XCTAssertEqualWithAccuracy(first.wpm, 30.0, 0.001, @"oldest first, whatever order they came in");
}

- (void)testKindAndPeriodFilter
{
    NSArray *samples = @[[self sampleDaysAgo:1 mode:@"time" wpm:50 accuracy:95 duration:30],
                         [self sampleDaysAgo:1 mode:@"lesson" wpm:20 accuracy:97 duration:60],
                         [self sampleDaysAgo:1 mode:@"code" wpm:35 accuracy:92 duration:120],
                         [self sampleDaysAgo:40 mode:@"zen" wpm:70 accuracy:100 duration:30]];
    HRStatistics *tests = [[HRStatistics alloc] initWithSamples:samples kind:HRStatKindTests days:0 now:_now timeZone:_utc];
    XCTAssertEqual(tests.count, (NSUInteger)2, @"time and zen");
    HRStatistics *month = [[HRStatistics alloc] initWithSamples:samples kind:HRStatKindTests days:30 now:_now timeZone:_utc];
    XCTAssertEqual(month.count, (NSUInteger)1);
    HRStatistics *code = [[HRStatistics alloc] initWithSamples:samples kind:HRStatKindCode days:7 now:_now timeZone:_utc];
    XCTAssertEqual(code.count, (NSUInteger)1);
    XCTAssertEqualWithAccuracy(code.bestWpm, 35.0, 0.001);
    HRStatistics *none = [[HRStatistics alloc] initWithSamples:@[] kind:HRStatKindAll days:0 now:_now timeZone:_utc];
    XCTAssertEqual(none.count, (NSUInteger)0);
    XCTAssertEqualWithAccuracy(none.averageWpm, 0.0, 0.001);
    XCTAssertEqualObjects([none days], @[]);
    XCTAssertEqualObjects([none movingAverageOfKey:@"wpm" window:10], @[]);
}

- (void)testMovingAverage
{
    NSMutableArray *samples = [NSMutableArray array];
    double wpm[] = {10, 20, 30, 40};
    for (int i = 0; i < 4; i++) {
        [samples addObject:[self sampleDaysAgo:(4 - i) mode:@"time" wpm:wpm[i] accuracy:100 duration:30]];
    }
    HRStatistics *st = [[HRStatistics alloc] initWithSamples:samples kind:HRStatKindAll days:0 now:_now timeZone:_utc];
    NSArray *expected = @[@10.0, @15.0, @25.0, @35.0];
    XCTAssertEqualObjects([st movingAverageOfKey:@"wpm" window:2], expected);
}

- (void)testDaysIncludeTheEmptyOnes
{
    /* noon today, two on the day before yesterday */
    NSArray *samples = @[[self sampleDaysAgo:0 mode:@"time" wpm:60 accuracy:90 duration:30],
                         [self sampleDaysAgo:2 mode:@"time" wpm:40 accuracy:100 duration:30],
                         [self sampleDaysAgo:2.2 mode:@"time" wpm:20 accuracy:80 duration:90]];
    HRStatistics *st = [[HRStatistics alloc] initWithSamples:samples kind:HRStatKindAll days:0 now:_now timeZone:_utc];
    NSArray *days = [st days];
    XCTAssertEqual([days count], (NSUInteger)3);
    HRStatDay *first = days[0], *gap = days[1], *last = days[2];
    XCTAssertEqual(first.count, (NSUInteger)2);
    XCTAssertEqualWithAccuracy(first.duration, 120.0, 0.001);
    XCTAssertEqualWithAccuracy(first.wpm, (40.0 * 30 + 20.0 * 90) / 120.0, 0.001);
    XCTAssertEqual(gap.count, (NSUInteger)0);
    XCTAssertEqual(last.count, (NSUInteger)1);
    XCTAssertEqualWithAccuracy([last.day timeIntervalSinceDate:first.day], 2 * 86400.0, 1.0);
}

- (void)testKeysWorstFirstAndRarelyPressedLeftOut
{
    NSDictionary *counts = @{@"a": @{@"hits": @90, @"misses": @10},
                             @"q": @{@"hits": @15, @"misses": @5},
                             @"z": @{@"hits": @1, @"misses": @1},
                             @"e": @{@"hits": @200, @"misses": @0}};
    NSArray *keys = [HRStatistics keysFromCounts:counts minimumPresses:10];
    XCTAssertEqual([keys count], (NSUInteger)3, @"z was pressed twice: not a statistic");
    XCTAssertEqualObjects(((HRStatKey *)keys[0]).character, @"q");
    XCTAssertEqualWithAccuracy([(HRStatKey *)keys[0] errorRate], 0.25, 0.0001);
    XCTAssertEqualObjects(((HRStatKey *)keys[1]).character, @"a");
    XCTAssertEqualObjects(((HRStatKey *)keys[2]).character, @"e");
}

- (void)testDurationStrings
{
    /* 2024-02-29 23:30 UTC is already March 1st an hour to the east */
    NSDate *leap = [NSDate dateWithTimeIntervalSince1970:1709249400.0];
    XCTAssertEqualObjects([HRStatistics shortStringForDate:leap timeZone:_utc], @"Feb 29");
    XCTAssertEqualObjects([HRStatistics shortStringForDate:leap timeZone:[NSTimeZone timeZoneForSecondsFromGMT:3600]], @"Mar 1");
    XCTAssertEqualObjects([HRStatistics shortStringForDate:[NSDate dateWithTimeIntervalSince1970:0] timeZone:_utc], @"Jan 1");
    XCTAssertEqualObjects([HRStatistics stringForDuration:40], @"40 s");
    XCTAssertEqualObjects([HRStatistics stringForDuration:12 * 60 + 10], @"12 min");
    XCTAssertEqualObjects([HRStatistics stringForDuration:3900], @"1 h 05 min");
}

@end
