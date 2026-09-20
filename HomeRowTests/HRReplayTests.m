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
#import "HRTestSession.h"
#import "HRReplay.h"
#import "HRPace.h"
#import "HRRandom.h"

@interface HRReplayTests : XCTestCase
@end

@implementation HRReplayTests

- (HRTestSession *)sessionInMode:(HRTestMode)mode amount:(NSInteger)amount text:(NSString *)text
{
    HRTestConfiguration *c = [[HRTestConfiguration alloc] init];
    c.mode = mode;
    c.amount = amount;
    return [[HRTestSession alloc] initWithConfiguration:c source:[[HRFixedTextSource alloc] initWithText:text]];
}

- (void)testAReplayEndsWithTheSameNumbers
{
    HRTestSession *s = [self sessionInMode:HRTestModeCustom amount:0 text:@"the quick brown fox"];
    NSTimeInterval t = 100.0;
    for (NSString *step in @[@"t", @"h", @"x", @"<", @"e", @" ", @"q", @"u", @"i", @"k", @" ", @"<<", @"<",
                             @"c", @"k", @" ", @"brown", @" ", @"fox"]) {
        t += 0.21;
        if ([step isEqualToString:@"<"]) [s deleteBackwardAtTime:t];
        else if ([step isEqualToString:@"<<"]) [s deleteWordBackwardAtTime:t];
        else [s insertText:step atTime:t];
    }
    XCTAssertEqual(s.state, HRSessionFinished);
    HRTestSummary *original = [s summary];

    HRReplay *replay = [[HRReplay alloc] initWithSession:s];
    XCTAssertEqual([replay.events count], (NSUInteger)19);
    HRTestSession *again = [replay begin];
    /* half-way, the replay is half-way */
    XCTAssertTrue([replay advanceToElapsed:replay.duration / 2.0]);
    XCTAssertEqual(again.state, HRSessionRunning);
    XCTAssertTrue(again.currentWordIndex > 0 && again.currentWordIndex < 3);
    XCTAssertFalse([replay advanceToElapsed:replay.duration + 0.5]);
    XCTAssertEqual(again.state, HRSessionFinished);
    HRTestSummary *copy = [again summary];
    XCTAssertEqualWithAccuracy(copy.wpm, original.wpm, 1e-9);
    XCTAssertEqualWithAccuracy(copy.rawWpm, original.rawWpm, 1e-9);
    XCTAssertEqualWithAccuracy(copy.accuracy, original.accuracy, 1e-9);
    XCTAssertEqualWithAccuracy(copy.duration, original.duration, 1e-9);
    XCTAssertEqual(copy.deletions, original.deletions);
    /* and it can be begun again */
    HRTestSession *third = [replay begin];
    XCTAssertEqual(third.state, HRSessionIdle);
    XCTAssertEqualObjects([third inputLog], @[]);
}

- (void)testATimedTestReplaysToItsEndWithoutAnyoneTyping
{
    HRTestSession *s = [self sessionInMode:HRTestModeTime amount:15 text:@"one two three four five six seven eight nine ten"];
    [s insertText:@"one " atTime:50.0];
    [s insertText:@"two " atTime:52.0];
    [s tickAtTime:65.3];
    XCTAssertEqual(s.state, HRSessionFinished);
    [s insertText:@"late" atTime:66.0];
    XCTAssertEqual([[s inputLog] count], (NSUInteger)2, @"what comes after the end is not part of the test");

    HRReplay *replay = [[HRReplay alloc] initWithSession:s];
    XCTAssertEqualWithAccuracy(replay.duration, 15.0, 1e-9);
    HRTestSession *again = [replay begin];
    XCTAssertTrue([replay advanceToElapsed:3.0], @"the log is done, the clock is not");
    XCTAssertEqual(again.state, HRSessionRunning);
    XCTAssertFalse([replay advanceToElapsed:15.0]);
    XCTAssertEqualWithAccuracy([again summary].wpm, [s summary].wpm, 1e-9);
}

- (void)testZenIsReplayedFromWhatWasTyped
{
    HRTestSession *s = [self sessionInMode:HRTestModeZen amount:0 text:@""];
    [s insertText:@"free " atTime:10.0];
    [s insertText:@"text" atTime:11.0];
    [s finishAtTime:12.0];
    HRReplay *replay = [[HRReplay alloc] initWithSession:s];
    HRTestSession *again = [replay begin];
    XCTAssertFalse([replay advanceToElapsed:5.0]);
    XCTAssertEqual(again.state, HRSessionFinished);
    XCTAssertEqual([again.words count], [s.words count]);
    XCTAssertEqualWithAccuracy([again summary].wpm, [s summary].wpm, 1e-9);
}

- (void)testThePaceCaretCountsTheSpaces
{
    XCTAssertEqualWithAccuracy([HRPace charactersAtWpm:60.0 elapsed:1.0], 5.0, 1e-9);
    XCTAssertEqualWithAccuracy([HRPace charactersAtWpm:0.0 elapsed:9.0], 0.0, 1e-9);
    NSArray *words = @[[HRWord wordWithText:@"ab"], [HRWord wordWithText:@"cde"]];
    NSUInteger w = 9, c = 9;
    XCTAssertTrue([HRPace getWordIndex:&w characterIndex:&c forCharacters:0.9 inWords:words]);
    XCTAssertTrue(w == 0 && c == 0);
    XCTAssertTrue([HRPace getWordIndex:&w characterIndex:&c forCharacters:2.0 inWords:words]);
    XCTAssertTrue(w == 0 && c == 2, @"on the space after the first word");
    XCTAssertTrue([HRPace getWordIndex:&w characterIndex:&c forCharacters:3.5 inWords:words]);
    XCTAssertTrue(w == 1 && c == 0);
    XCTAssertTrue([HRPace getWordIndex:&w characterIndex:&c forCharacters:6.0 inWords:words]);
    XCTAssertTrue(w == 1 && c == 3);
    XCTAssertFalse([HRPace getWordIndex:&w characterIndex:&c forCharacters:7.0 inWords:words]);
}

- (void)testTheAverageToRaceIsOfTheLastTen
{
    XCTAssertEqualWithAccuracy([HRPace averageOfRecentSpeeds:@[]], 0.0, 1e-9);
    NSMutableArray *speeds = [NSMutableArray arrayWithObject:@1000];
    for (int i = 0; i < 10; i++) [speeds addObject:@(40 + i)];
    XCTAssertEqualWithAccuracy([HRPace averageOfRecentSpeeds:speeds], 44.5, 1e-9);
}

@end
