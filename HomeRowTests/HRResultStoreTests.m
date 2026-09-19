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
#import "HRResultStore.h"
#import "HRTestSummary.h"
#import "HRTestConfiguration.h"

/* Runs against Apple's CoreData under Xcode and FreeCoreData under GNUstep:
 * the same assertions on both is the point. */
@interface HRResultStoreTests : XCTestCase
@end

@implementation HRResultStoreTests
{
    NSString *_dir;
}

- (void)setUp
{
    [super setUp];
    _dir = [NSTemporaryDirectory() stringByAppendingPathComponent:
            [NSString stringWithFormat:@"hr-store-%d-%u", (int)[[NSProcessInfo processInfo] processIdentifier], arc4random()]];
    [[NSFileManager defaultManager] createDirectoryAtPath:_dir withIntermediateDirectories:YES attributes:nil error:NULL];
}

- (void)tearDown
{
    [[NSFileManager defaultManager] removeItemAtPath:_dir error:NULL];
    [super tearDown];
}

- (HRTestSummary *)summaryWithWpm:(double)wpm
{
    HRTestSummary *s = [[HRTestSummary alloc] init];
    s.wpm = wpm;
    s.rawWpm = wpm + 5.0;
    s.accuracy = 97.5;
    s.consistency = 80.0;
    s.duration = 30.0;
    s.correctCharacters = 200;
    s.incorrectCharacters = 3;
    s.rawWpmPerSecond = @[@60.0, @72.0, @48.0];
    s.errorsPerSecond = @[@0, @1, @0];
    s.keyStats = @{@"a": @{@"hits": @10, @"misses": @1}, @"b": @{@"hits": @4, @"misses": @0}};
    return s;
}

- (HRResultStore *)storeAtURL:(NSURL *)url
{
    NSError *e = nil;
    HRResultStore *store = [[HRResultStore alloc] initWithStoreURL:url
                                                            bundle:[NSBundle bundleForClass:[self class]]
                                                             error:&e];
    XCTAssertNotNil(store, @"%@", e);
    return store;
}

- (void)testRecordAndFetchInMemory
{
    HRResultStore *store = [self storeAtURL:nil];
    HRTestConfiguration *c = [HRTestConfiguration defaultConfiguration];
    NSError *e = nil;
    XCTAssertNotNil([store recordSummary:[self summaryWithWpm:50] configuration:c
                                    date:[NSDate dateWithTimeIntervalSince1970:1000] error:&e], @"%@", e);
    XCTAssertNotNil([store recordSummary:[self summaryWithWpm:70] configuration:c
                                    date:[NSDate dateWithTimeIntervalSince1970:2000] error:&e], @"%@", e);
    XCTAssertNotNil([store recordSummary:[self summaryWithWpm:60] configuration:c
                                    date:[NSDate dateWithTimeIntervalSince1970:3000] error:&e], @"%@", e);

    NSArray *recent = [store recentResultsWithLimit:2 error:&e];
    XCTAssertEqual([recent count], (NSUInteger)2);
    XCTAssertEqualWithAccuracy([((HRTestResult *)recent[0]).wpm doubleValue], 60.0, 1e-9, @"newest first");

    HRTestResult *best = [store personalBestForSettingsKey:[c settingsKey] error:&e];
    XCTAssertEqualWithAccuracy([best.wpm doubleValue], 70.0, 1e-9);
    XCTAssertNil([store personalBestForSettingsKey:@"words:10:english/words-200" error:&e]);
}

- (void)testResultsSurviveReopeningTheSQLiteStore
{
    NSURL *url = [NSURL fileURLWithPath:[_dir stringByAppendingPathComponent:@"t.sqlite"]];
    HRTestConfiguration *c = [HRTestConfiguration defaultConfiguration];
    c.mode = HRTestModeWords;
    c.amount = 25;
    c.punctuation = YES;
    @autoreleasepool {
        HRResultStore *store = [self storeAtURL:url];
        NSError *e = nil;
        XCTAssertNotNil([store recordSummary:[self summaryWithWpm:55.5] configuration:c date:nil error:&e], @"%@", e);
    }

    HRResultStore *reopened = [self storeAtURL:url];
    NSError *e = nil;
    NSArray *all = [reopened recentResultsWithLimit:0 error:&e];
    XCTAssertEqual([all count], (NSUInteger)1, @"%@", e);
    HRTestResult *r = [all firstObject];
    XCTAssertEqualObjects(r.mode, @"words");
    XCTAssertEqualObjects(r.settingsKey, @"words:25:english/words-200:p");
    XCTAssertEqualWithAccuracy([r.wpm doubleValue], 55.5, 1e-9);
    XCTAssertEqual([r.correctCharacters integerValue], (NSInteger)200);
    XCTAssertEqualObjects([r seriesDictionary][@"raw"], (@[@60.0, @72.0, @48.0]));

    XCTAssertEqual([r.keyStats count], (NSUInteger)2);
    NSUInteger misses = 0;
    for (HRKeyStat *k in r.keyStats) misses += [k.misses unsignedIntegerValue];
    XCTAssertEqual(misses, (NSUInteger)1);
}

@end
