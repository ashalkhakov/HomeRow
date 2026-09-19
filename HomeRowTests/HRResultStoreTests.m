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
#import "HRResultExchange.h"
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

    /* the same three, as the Statistics window gets them */
    NSArray *samples = [store statSamples];
    XCTAssertEqual([samples count], (NSUInteger)3);
    HRStatSample *sample = samples[0];
    XCTAssertEqualObjects(sample.mode, [c modeName]);
    XCTAssertEqualWithAccuracy(sample.duration, 30.0, 1e-9);
    XCTAssertEqual([sample kind], HRStatKindTests);
    NSDictionary *all = [store keyCountsForKind:HRStatKindAll since:nil];
    XCTAssertEqualObjects(all[@"a"][@"hits"], @30);
    XCTAssertEqualObjects(all[@"a"][@"misses"], @3);
    NSDictionary *late = [store keyCountsForKind:HRStatKindTests since:[NSDate dateWithTimeIntervalSince1970:2500]];
    XCTAssertEqualObjects(late[@"b"][@"hits"], @4);
    XCTAssertEqualObjects(late[@"b"][@"misses"], @0);
    XCTAssertEqual([[store keyCountsForKind:HRStatKindCode since:nil] count], (NSUInteger)0);
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

/* Out through the exchange format and back into another store: everything
 * arrives once, however often it is sent. */
- (void)testExportImportRoundTripAndBests
{
    HRResultStore *a = [self storeAtURL:nil];
    HRTestConfiguration *c = [HRTestConfiguration defaultConfiguration];
    NSError *e = nil;
    [a recordSummary:[self summaryWithWpm:50] configuration:c date:[NSDate dateWithTimeIntervalSince1970:1700000000] error:&e];
    [a recordSummary:[self summaryWithWpm:70] configuration:c date:[NSDate dateWithTimeIntervalSince1970:1700000100] error:&e];
    HRTestConfiguration *words = [c copy];
    words.mode = HRTestModeWords;
    words.amount = 25;
    [a recordSummary:[self summaryWithWpm:64] configuration:words date:[NSDate dateWithTimeIntervalSince1970:1700000200] error:&e];
    HRTestConfiguration *zen = [c copy];
    zen.mode = HRTestModeZen;
    [a recordSummary:[self summaryWithWpm:99] configuration:zen date:[NSDate dateWithTimeIntervalSince1970:1700000300] error:&e];

    NSArray *bests = [a personalBests];
    XCTAssertEqual([bests count], (NSUInteger)2, @"one per setting of the time and words tests; zen has no best");
    XCTAssertEqualWithAccuracy([((HRTestResult *)bests[0]).wpm doubleValue], 70.0, 1e-9);
    XCTAssertEqualWithAccuracy([((HRTestResult *)bests[1]).wpm doubleValue], 64.0, 1e-9);

    NSArray *records = [a exportRecords];
    XCTAssertEqual([records count], (NSUInteger)4);
    XCTAssertEqualWithAccuracy([records[0][@"wpm"] doubleValue], 50.0, 1e-9, @"oldest first");
    XCTAssertEqualObjects(records[1][@"isBest"], @YES);
    XCTAssertEqualObjects(records[0][@"isBest"], @NO);
    XCTAssertEqualObjects(records[0][@"keys"][@"a"][@"hits"], @10);

    NSData *json = [HRResultExchange JSONDataFromRecords:records error:&e];
    XCTAssertNotNil(json, @"%@", e);
    NSArray *read = [HRResultExchange recordsFromData:json skipped:NULL error:&e];
    HRResultStore *b = [self storeAtURL:nil];
    NSUInteger duplicates = 0;
    XCTAssertEqual([b importRecords:read duplicates:&duplicates error:&e], (NSUInteger)4, @"%@", e);
    XCTAssertEqual(duplicates, (NSUInteger)0);
    XCTAssertEqual([b importRecords:read duplicates:&duplicates error:&e], (NSUInteger)0);
    XCTAssertEqual(duplicates, (NSUInteger)4, @"the same file again adds nothing");
    XCTAssertEqualObjects([b keyCountsForKind:HRStatKindAll since:nil][@"a"][@"hits"], @40);
    XCTAssertEqual([[b personalBests] count], (NSUInteger)2);
    HRTestResult *newest = [[b recentResultsWithLimit:1 error:&e] firstObject];
    XCTAssertEqualObjects(newest.mode, @"zen");
    XCTAssertEqual([[newest seriesDictionary][@"raw"] count], (NSUInteger)3, @"the per-second series came along");

    /* a CSV has no uuids of its own worth the name: the moment, mode and speed decide */
    NSArray *fromCSV = [HRResultExchange recordsFromData:[HRResultExchange CSVDataFromRecords:records] skipped:NULL error:&e];
    NSMutableArray *anonymous = [NSMutableArray array];
    for (NSDictionary *r in fromCSV) {
        NSMutableDictionary *m = [r mutableCopy];
        [m removeObjectForKey:@"uuid"];
        [anonymous addObject:m];
    }
    XCTAssertEqual([b importRecords:anonymous duplicates:&duplicates error:&e], (NSUInteger)0);
    XCTAssertEqual(duplicates, (NSUInteger)4);

    /* and one can go */
    XCTAssertTrue([b deleteResult:newest error:&e], @"%@", e);
    XCTAssertEqual([[b recentResultsWithLimit:0 error:&e] count], (NSUInteger)3);
    XCTAssertEqualObjects([b keyCountsForKind:HRStatKindAll since:nil][@"a"][@"hits"], @30, @"its key stats went with it");
}

@end
