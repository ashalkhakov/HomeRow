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
#import "HRResultExchange.h"

@interface HRResultExchangeTests : XCTestCase
@end

@implementation HRResultExchangeTests

- (NSArray *)records
{
    NSDictionary *test = @{@"uuid": @"11111111-2222-3333-4444-555555555555",
        @"date": [NSDate dateWithTimeIntervalSince1970:1789000000.5], @"mode": @"time", @"amount": @30,
        @"settingsKey": @"time:30:english/words-200:p", @"languageID": @"english", @"layoutID": @"qwerty",
        @"wpm": @71.25, @"rawWpm": @74.5, @"accuracy": @97.1, @"consistency": @81.0, @"duration": @30.0,
        @"correctCharacters": @178, @"incorrectCharacters": @3, @"extraCharacters": @1, @"missedCharacters": @0,
        @"punctuation": @YES, @"numbers": @NO, @"isBest": @YES,
        @"keys": @{@"a": @{@"hits": @12, @"misses": @1, @"timed": @10, @"time": @1.75}, @",": @{@"hits": @3, @"misses": @0, @"timed": @0, @"time": @0.0}},
        @"series": @{@"raw": @[@60, @75.5, @72], @"errors": @[@0, @1, @0]}};
    NSDictionary *lesson = @{@"uuid": @"aaaaaaaa-0000-0000-0000-000000000001",
        @"date": [NSDate dateWithTimeIntervalSince1970:1789000100.0], @"mode": @"lesson", @"settingsKey": @"lesson",
        @"languageID": @"german", @"wpm": @22.0, @"accuracy": @99.0, @"duration": @41.0,
        @"courseFile": @"ktde, neo.typ", @"lessonIndex": @4, @"stepIndex": @7};
    return @[test, lesson];
}

- (void)testJSONLosesNothing
{
    NSError *e = nil;
    NSData *json = [HRResultExchange JSONDataFromRecords:[self records] error:&e];
    XCTAssertNotNil(json, @"%@", e);
    NSUInteger skipped = 99;
    NSArray *back = [HRResultExchange recordsFromData:json skipped:&skipped error:&e];
    XCTAssertEqual([back count], (NSUInteger)2, @"%@", e);
    XCTAssertEqual(skipped, (NSUInteger)0);
    NSDictionary *t = back[0];
    XCTAssertEqualObjects(t[@"uuid"], @"11111111-2222-3333-4444-555555555555");
    XCTAssertEqualWithAccuracy([t[@"date"] timeIntervalSince1970], 1789000000.5, 0.001);
    XCTAssertEqualWithAccuracy([t[@"wpm"] doubleValue], 71.25, 1e-9);
    XCTAssertEqualObjects(t[@"settingsKey"], @"time:30:english/words-200:p");
    XCTAssertEqualObjects(t[@"keys"][@"a"][@"misses"], @1);
    XCTAssertEqualWithAccuracy([t[@"keys"][@"a"][@"time"] doubleValue], 1.75, 1e-9);
    XCTAssertEqualWithAccuracy([t[@"series"][@"raw"][1] doubleValue], 75.5, 1e-9);
    XCTAssertTrue([t[@"punctuation"] boolValue]);
    NSDictionary *l = back[1];
    XCTAssertEqualObjects(l[@"courseFile"], @"ktde, neo.typ");
    XCTAssertEqualObjects(l[@"lessonIndex"], @4);
    XCTAssertNil(l[@"keys"]);
}

- (void)testCSVHasMonkeyTypesColumnsFirstAndComesBack
{
    NSString *csv = [[NSString alloc] initWithData:[HRResultExchange CSVDataFromRecords:[self records]] encoding:NSUTF8StringEncoding];
    NSArray *lines = [csv componentsSeparatedByString:@"\n"];
    XCTAssertTrue([lines[0] hasPrefix:@"_id,isPb,wpm,acc,rawWpm,consistency,charStats,mode,mode2,quoteLength,restartCount,testDuration,"
                   @"afkDuration,incompleteTestSeconds,punctuation,numbers,language,funbox,difficulty,lazyMode,blindMode,bailedOut,tags,timestamp"],
                  @"%@", lines[0]);
    NSArray *first = [HRResultExchange fieldsOfCSVLine:lines[1]];
    XCTAssertEqualObjects(first[1], @"true");
    XCTAssertEqualObjects(first[2], @"71.25");
    XCTAssertEqualObjects(first[6], @"178;3;1;0");
    XCTAssertEqualObjects(first[7], @"time");
    XCTAssertEqualObjects(first[8], @"30");
    XCTAssertEqualObjects(first[23], @"1789000000500");
    NSArray *second = [HRResultExchange fieldsOfCSVLine:lines[2]];
    XCTAssertEqualObjects(second[7], @"custom", @"a lesson is, to MonkeyType's tools, a custom text");
    XCTAssertEqualObjects(second[24], @"lesson");
    XCTAssertEqualObjects(second[26], @"ktde, neo.typ", @"a comma in a field survives the quoting");

    NSUInteger skipped = 0;
    NSError *e = nil;
    NSArray *back = [HRResultExchange recordsFromData:[csv dataUsingEncoding:NSUTF8StringEncoding] skipped:&skipped error:&e];
    XCTAssertEqual([back count], (NSUInteger)2, @"%@", e);
    XCTAssertEqualObjects(back[1][@"mode"], @"lesson", @"HomeRow's own column wins over MonkeyType's");
    XCTAssertEqualObjects(back[1][@"courseFile"], @"ktde, neo.typ");
    XCTAssertEqualObjects(back[0][@"uuid"], @"11111111-2222-3333-4444-555555555555");
    XCTAssertEqualObjects(back[0][@"correctCharacters"], @178);
}

- (void)testAMonkeyTypeExportIsRead
{
    NSString *csv = @"_id,isPb,wpm,acc,rawWpm,consistency,charStats,mode,mode2,quoteLength,restartCount,testDuration,afkDuration,"
                    @"incompleteTestSeconds,punctuation,numbers,language,funbox,difficulty,lazyMode,blindMode,bailedOut,tags,timestamp\n"
                    @"64a1f0,true,88.79,96.5,92.39,78.12,222;2;0;1,time,30,-1,0,30,0,0,false,false,english,none,normal,false,false,false,,1688300000000\n"
                    @"64a1f1,false,95.2,98,97,80.5,310;1;0;0,quote,1234,2,1,39.07,0,0,false,false,english,none,normal,false,false,false,,1688300100000\n"
                    @"broken,false,fast,98,97,80.5,1;1;0;0,time,15,-1,0,15,0,0,false,false,english,none,normal,false,false,false,,1688300200000\n";
    NSUInteger skipped = 0;
    NSError *e = nil;
    NSArray *records = [HRResultExchange recordsFromData:[csv dataUsingEncoding:NSUTF8StringEncoding] skipped:&skipped error:&e];
    XCTAssertEqual([records count], (NSUInteger)2, @"%@", e);
    XCTAssertEqual(skipped, (NSUInteger)1, @"a speed that is not a number");
    XCTAssertEqualObjects(records[0][@"uuid"], @"monkeytype:64a1f0");
    XCTAssertEqualObjects(records[0][@"amount"], @30);
    XCTAssertEqualWithAccuracy([records[0][@"accuracy"] doubleValue], 96.5, 1e-9);
    XCTAssertEqualObjects(records[0][@"missedCharacters"], @1);
    XCTAssertEqualObjects(records[1][@"mode"], @"custom", @"a quote is a given text");
    XCTAssertEqualWithAccuracy([records[0][@"date"] timeIntervalSince1970], 1688300000.0, 0.001);
}

- (void)testWhatIsNotAResultsFileIsRefusedWithAReason
{
    NSError *e = nil;
    XCTAssertNil([HRResultExchange recordsFromData:[@"{\"hello\": 1}" dataUsingEncoding:NSUTF8StringEncoding] skipped:NULL error:&e]);
    XCTAssertNotNil(e);
    e = nil;
    XCTAssertNil([HRResultExchange recordsFromData:[@"name,age\nx,3\n" dataUsingEncoding:NSUTF8StringEncoding] skipped:NULL error:&e]);
    XCTAssertNotNil(e);
    e = nil;
    XCTAssertNil([HRResultExchange recordsFromData:[NSData data] skipped:NULL error:&e]);
    XCTAssertNotNil(e);
    e = nil;
    NSString *newer = @"{\"format\": \"homerow-results\", \"version\": 99, \"results\": []}";
    XCTAssertNil([HRResultExchange recordsFromData:[newer dataUsingEncoding:NSUTF8StringEncoding] skipped:NULL error:&e]);
    XCTAssertNotNil(e);
    NSArray *quoted = [HRResultExchange fieldsOfCSVLine:@"a,\"b,\"\"c\"\"\",,d"];
    NSArray *expected = @[@"a", @"b,\"c\"", @"", @"d"];
    XCTAssertEqualObjects(quoted, expected);
}

@end
