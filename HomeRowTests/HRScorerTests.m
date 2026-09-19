/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * This library is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2.1 of the License, or (at
 * your option) any later version.  See COPYING.LIB.
 */
#import <XCTest/XCTest.h>
#import "HRTestSummary.h"
#include <math.h>

@interface HRScorerTests : XCTestCase
@end

@implementation HRScorerTests

- (void)testWpmIsCharactersOverFivePerMinute
{
    XCTAssertEqualWithAccuracy([HRScorer wpmForCharacters:250 duration:60.0], 50.0, 1e-9);
    XCTAssertEqualWithAccuracy([HRScorer wpmForCharacters:125 duration:30.0], 50.0, 1e-9);
    XCTAssertEqualWithAccuracy([HRScorer wpmForCharacters:10 duration:0.0], 0.0, 1e-9);
}

- (void)testConsistency
{
    NSArray *even = @[@60, @60, @60, @60];
    XCTAssertEqualWithAccuracy([HRScorer consistencyForSamples:even], 100.0, 1e-9);

    /* mean 60, population stddev 20 -> cv = 1/3 */
    NSArray *uneven = @[@40, @80, @40, @80];
    double cv = 1.0 / 3.0;
    double expected = 100.0 * (1.0 - tanh(cv + pow(cv, 3) / 3.0 + pow(cv, 5) / 5.0));
    XCTAssertEqualWithAccuracy([HRScorer consistencyForSamples:uneven], expected, 1e-9);

    XCTAssertEqualWithAccuracy([HRScorer consistencyForSamples:@[]], 0.0, 1e-9);
    XCTAssertEqualWithAccuracy([HRScorer consistencyForSamples:(@[@0, @0])], 0.0, 1e-9);
}

@end
