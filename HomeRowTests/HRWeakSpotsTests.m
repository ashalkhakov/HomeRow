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
#import "HRWeakSpots.h"
#import "HRRandom.h"
#import "HRWord.h"

@interface HRWeakSpotsTests : XCTestCase
@end

@implementation HRWeakSpotsTests

- (NSDictionary *)counts
{
    /* 2% overall; q and # stand out, e is fine, z was hardly pressed, and
     * the space bar is nobody's weak key */
    return @{@"e": @{@"hits": @990, @"misses": @10},
             @"t": @{@"hits": @980, @"misses": @20},
             @"q": @{@"hits": @40, @"misses": @10},
             @"#": @{@"hits": @20, @"misses": @10},
             @"T": @{@"hits": @45, @"misses": @5},
             @"z": @{@"hits": @1, @"misses": @1},
             @" ": @{@"hits": @500, @"misses": @100}};
}

- (void)testWeakKeysStandOutFromTheTypistsOwnAverage
{
    HRWeakSpots *w = [HRWeakSpots weakSpotsFromCounts:[self counts] minimumKeyPresses:10 minimumTotalPresses:200 maximum:6];
    NSArray *expected = @[@"#", @"q", @"T"];
    XCTAssertEqualObjects(w.characters, expected, @"worst first; e, t, z and space left out");
    XCTAssertEqualWithAccuracy([w weaknessOfCharacter:@"#"], 1.0, 1e-9);
    XCTAssertEqualWithAccuracy([w weaknessOfCharacter:@"q"], 0.2 / (1.0 / 3.0), 1e-9);
    XCTAssertEqualWithAccuracy([w weaknessOfCharacter:@"e"], 0.0, 1e-9);

    HRWeakSpots *two = [HRWeakSpots weakSpotsFromCounts:[self counts] minimumKeyPresses:10 minimumTotalPresses:200 maximum:2];
    XCTAssertEqual([two.characters count], (NSUInteger)2);
}

- (void)testTooLittleOnRecordIsNoVerdict
{
    XCTAssertNil([HRWeakSpots weakSpotsFromCounts:@{} minimumKeyPresses:10 minimumTotalPresses:200 maximum:6]);
    XCTAssertNil([HRWeakSpots weakSpotsFromCounts:[self counts] minimumKeyPresses:10 minimumTotalPresses:100000 maximum:6]);
    NSDictionary *even = @{@"a": @{@"hits": @980, @"misses": @20}, @"b": @{@"hits": @980, @"misses": @20}};
    XCTAssertNil([HRWeakSpots weakSpotsFromCounts:even minimumKeyPresses:10 minimumTotalPresses:200 maximum:6],
                 @"nothing stands out");
}

- (void)testTheDrillLeansOnTheWeakKeysButStaysText
{
    HRWeakSpots *w = [HRWeakSpots weakSpotsFromCounts:[self counts] minimumKeyPresses:10 minimumTotalPresses:200 maximum:6];
    NSArray *words = @[@"the", @"and", @"quick", @"queen", @"home", @"row", @"tree", @"equal", @"stone", @"river",
                       @"light", @"water", @"paper", @"green", @"table", @"under", @"think", @"about", @"quiet", @"time"];
    HRWeakSpotSource *source = [[HRWeakSpotSource alloc] initWithWords:words weakSpots:w random:[[HRRandom alloc] initWithSeed:7]];
    source.limit = 400;
    NSArray *drill = [source nextWords:1000];
    XCTAssertEqual([drill count], (NSUInteger)400, @"the limit holds");
    XCTAssertTrue([source isFinite]);

    NSUInteger withQ = 0, withHash = 0, capitalT = 0, plain = 0, repeats = 0;
    NSString *previous = nil;
    for (HRWord *word in drill) {
        NSString *t = word.text;
        BOOL special = NO;
        if ([t rangeOfString:@"q"].location != NSNotFound) { withQ++; special = YES; }
        if ([t rangeOfString:@"#"].location != NSNotFound) { withHash++; special = YES; }
        if ([t hasPrefix:@"T"]) { capitalT++; special = YES; }
        if (!special) plain++;
        if ([t isEqualToString:previous]) repeats++;
        previous = t;
    }
    /* 4 of the 20 words have a q: a fifth by chance, far more by design */
    XCTAssertGreaterThan(withQ, (NSUInteger)140);
    XCTAssertGreaterThan(withHash, (NSUInteger)30, @"# is in no word, so it is attached to some");
    XCTAssertGreaterThan(capitalT, (NSUInteger)30, @"a weak capital gets capitalised words");
    XCTAssertGreaterThan(plain, (NSUInteger)60, @"and it still reads like text");
    XCTAssertLessThan(repeats, (NSUInteger)8);
    XCTAssertEqual(source.produced, (NSUInteger)400);
    XCTAssertEqual(source.producedWithWeakCharacter, (NSUInteger)400 - plain);
}

- (void)testPairsAreWrappedAndTheSameSeedGivesTheSameDrill
{
    NSDictionary *counts = @{@"e": @{@"hits": @2000, @"misses": @10}, @"(": @{@"hits": @20, @"misses": @10}};
    HRWeakSpots *w = [HRWeakSpots weakSpotsFromCounts:counts minimumKeyPresses:10 minimumTotalPresses:200 maximum:6];
    NSArray *expected = @[@"("];
    XCTAssertEqualObjects(w.characters, expected);
    NSMutableArray *runs = [NSMutableArray array];
    for (int run = 0; run < 2; run++) {
        HRWeakSpotSource *source = [[HRWeakSpotSource alloc] initWithWords:@[@"alpha", @"beta", @"gamma"] weakSpots:w
                                                                    random:[[HRRandom alloc] initWithSeed:3]];
        NSMutableArray *texts = [NSMutableArray array];
        for (HRWord *word in [source nextWords:60]) [texts addObject:word.text];
        [runs addObject:texts];
    }
    XCTAssertEqualObjects(runs[0], runs[1]);
    NSUInteger wrapped = 0;
    for (NSString *t in runs[0]) {
        if ([t hasPrefix:@"("]) { wrapped++; XCTAssertTrue([t hasSuffix:@")"], @"%@", t); }
    }
    XCTAssertGreaterThan(wrapped, (NSUInteger)3);
}

@end
