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
#import "HRRandom.h"

@interface HRSessionTests : XCTestCase
@end

@implementation HRSessionTests

- (HRTestSession *)sessionWithText:(NSString *)text
{
    HRTestConfiguration *c = [HRTestConfiguration defaultConfiguration];
    c.mode = HRTestModeCustom;
    return [[HRTestSession alloc] initWithConfiguration:c
                                                 source:[[HRFixedTextSource alloc] initWithText:text]];
}

/* Types `text` one character per `step` seconds starting at `t0`; returns
 * the time of the last keystroke. */
- (NSTimeInterval)type:(NSString *)text into:(HRTestSession *)s from:(NSTimeInterval)t0 step:(NSTimeInterval)step
{
    NSTimeInterval t = t0;
    for (NSString *ch in [HRWord charactersOfString:text]) {
        [s insertText:ch atTime:t];
        t += step;
    }
    return t - step;
}

- (void)testClockStartsWithTheFirstKey
{
    HRTestSession *s = [self sessionWithText:@"ab cd"];
    XCTAssertEqual(s.state, HRSessionIdle);
    XCTAssertEqualWithAccuracy([s elapsedAtTime:500.0], 0.0, 1e-9);
    [s insertText:@"a" atTime:100.0];
    XCTAssertEqual(s.state, HRSessionRunning);
    XCTAssertEqualWithAccuracy([s elapsedAtTime:103.0], 3.0, 1e-9);
}

- (void)testPerfectRunEndsOnTheLastCharacter
{
    HRTestSession *s = [self sessionWithText:@"hello world"];
    /* 11 characters, the last one lands at t = 6 s */
    [self type:@"hello world" into:s from:0.0 step:0.6];
    XCTAssertEqual(s.state, HRSessionFinished);
    HRTestSummary *r = [s summary];
    XCTAssertEqualWithAccuracy(r.duration, 6.0, 1e-9);
    XCTAssertEqual(r.correctCharacters, (NSUInteger)10);
    XCTAssertEqual(r.incorrectCharacters, (NSUInteger)0);
    XCTAssertEqualWithAccuracy(r.accuracy, 100.0, 1e-9);
    /* 10 letters + 1 space = 11 chars -> 11/5 words in 0.1 min = 22 wpm */
    XCTAssertEqualWithAccuracy(r.wpm, 22.0, 1e-9);
    XCTAssertEqualWithAccuracy(r.rawWpm, 22.0, 1e-9);
}

- (void)testAWrongWordCountsForRawButNotForWpm
{
    HRTestSession *s = [self sessionWithText:@"abc def"];
    [self type:@"abx def" into:s from:0.0 step:1.0]; /* ends at t = 6 */
    XCTAssertEqual(s.state, HRSessionFinished);
    HRTestSummary *r = [s summary];
    XCTAssertEqual(r.correctCharacters, (NSUInteger)5);
    XCTAssertEqual(r.incorrectCharacters, (NSUInteger)1);
    /* wpm: only "def" = 3 chars; raw: 3 + space + 3 = 7 chars; 6 s */
    XCTAssertEqualWithAccuracy(r.wpm, 3.0 / 5.0 * 10.0, 1e-9);
    XCTAssertEqualWithAccuracy(r.rawWpm, 7.0 / 5.0 * 10.0, 1e-9);
    /* wrong keys: the x, and the space that left a wrong word */
    XCTAssertEqual(r.incorrectKeystrokes, (NSUInteger)2);
    XCTAssertEqual(r.correctKeystrokes, (NSUInteger)5);
    XCTAssertEqual([r.keyStats[@"c"][@"misses"] unsignedIntegerValue], (NSUInteger)1);
}

- (void)testExtraAndMissedCharacters
{
    HRTestSession *s = [self sessionWithText:@"ab cd ef"];
    [s insertText:@"abxx " atTime:0.0];
    [s insertText:@"c " atTime:1.0];
    XCTAssertEqual([s stateOfCharacterAtIndex:2 inWordAtIndex:0], HRCharacterExtra);
    XCTAssertEqual([s stateOfCharacterAtIndex:1 inWordAtIndex:1], HRCharacterMissed);
    XCTAssertEqual([s displayLengthOfWordAtIndex:0], (NSUInteger)4);
    XCTAssertEqualObjects([s displayCharacterAtIndex:3 inWordAtIndex:0], @"x");
    [s insertText:@"ef" atTime:2.0];
    HRTestSummary *r = [s summary];
    XCTAssertEqual(r.extraCharacters, (NSUInteger)2);
    XCTAssertEqual(r.missedCharacters, (NSUInteger)1);
}

- (void)testBackspaceReturnsOnlyToAWrongWord
{
    HRTestSession *s = [self sessionWithText:@"ab cd ef"];
    [s insertText:@"ab " atTime:0.0];
    [s deleteBackwardAtTime:0.1];
    XCTAssertEqual(s.currentWordIndex, (NSUInteger)1, @"a correct word is closed");

    [s insertText:@"cx " atTime:0.2];
    XCTAssertEqual(s.currentWordIndex, (NSUInteger)2);
    [s deleteBackwardAtTime:0.3];
    XCTAssertEqual(s.currentWordIndex, (NSUInteger)1, @"a wrong word can be reopened");
    XCTAssertEqual([s caretIndexInCurrentWord], (NSUInteger)2);
    [s deleteBackwardAtTime:0.4];
    [s insertText:@"d ef" atTime:0.5];
    XCTAssertEqual(s.state, HRSessionFinished);
    XCTAssertEqual([s summary].incorrectCharacters, (NSUInteger)0);
    XCTAssertLessThan([s summary].accuracy, 100.0, @"fixing a mistake does not erase it from accuracy");
}

- (void)testBackspacePolicies
{
    HRTestConfiguration *c = [HRTestConfiguration defaultConfiguration];
    c.mode = HRTestModeCustom;
    c.backspacePolicy = HRBackspaceNone;
    HRTestSession *s = [[HRTestSession alloc] initWithConfiguration:c
                                                             source:[[HRFixedTextSource alloc] initWithText:@"ab cd"]];
    [s insertText:@"ax" atTime:0.0];
    [s deleteBackwardAtTime:0.1];
    XCTAssertEqual([s caretIndexInCurrentWord], (NSUInteger)2);

    c.backspacePolicy = HRBackspaceCurrentWord;
    s = [[HRTestSession alloc] initWithConfiguration:c
                                              source:[[HRFixedTextSource alloc] initWithText:@"ab cd"]];
    [s insertText:@"ax " atTime:0.0];
    [s deleteBackwardAtTime:0.1];
    XCTAssertEqual(s.currentWordIndex, (NSUInteger)1);
}

- (void)testDeleteWordBackward
{
    HRTestSession *s = [self sessionWithText:@"hello world"];
    [s insertText:@"hexx" atTime:0.0];
    [s deleteWordBackwardAtTime:0.1];
    XCTAssertEqual([s caretIndexInCurrentWord], (NSUInteger)0);
}

- (void)testLeadingSeparatorIsIgnored
{
    HRTestSession *s = [self sessionWithText:@"ab cd"];
    [s insertText:@" " atTime:0.0];
    XCTAssertEqual(s.state, HRSessionIdle);
    XCTAssertEqual(s.currentWordIndex, (NSUInteger)0);
}

- (void)testNewlineIsItsOwnSeparator
{
    HRTestSession *s = [self sessionWithText:@"ab\ncd"];
    XCTAssertEqual(((HRWord *)s.words[0]).separator, HRSeparatorNewline);
    [s insertText:@"ab " atTime:0.0];
    XCTAssertEqual(s.currentWordIndex, (NSUInteger)0, @"space does not stand in for Return");
    [s insertText:@"\n" atTime:0.1];
    XCTAssertEqual(s.currentWordIndex, (NSUInteger)1);
    [s insertText:@"cd" atTime:0.2];
    XCTAssertEqual(s.state, HRSessionFinished);
    XCTAssertEqual([s summary].incorrectKeystrokes, (NSUInteger)1);
}

- (void)testComposedCharactersAreOneTargetEach
{
    /* e + combining acute, then a non-BMP character */
    NSString *text = @"éa \U0001F600";
    HRTestSession *s = [self sessionWithText:text];
    XCTAssertEqual([((HRWord *)s.words[0]).characters count], (NSUInteger)2);
    XCTAssertEqual([((HRWord *)s.words[1]).characters count], (NSUInteger)1);
    [s insertText:text atTime:0.0];
    XCTAssertEqual(s.state, HRSessionFinished);
    XCTAssertEqual([s summary].correctCharacters, (NSUInteger)3);
}

- (void)testTimedTestEndsWhenItsTimeIsUpNotWhenNoticed
{
    HRTestConfiguration *c = [HRTestConfiguration defaultConfiguration];
    c.mode = HRTestModeTime;
    c.amount = 15;
    HRWordListSource *src = [[HRWordListSource alloc] initWithWords:@[@"aa", @"bb", @"cc"]
                                                             random:[[HRRandom alloc] initWithSeed:7]];
    HRTestSession *s = [[HRTestSession alloc] initWithConfiguration:c source:src];
    XCTAssertGreaterThanOrEqual([s.words count], (NSUInteger)60);

    [s insertText:((HRWord *)s.words[0]).text atTime:10.0];
    XCTAssertEqual([s remainingAtTime:12.0], (NSInteger)13);
    [s tickAtTime:24.9];
    XCTAssertEqual(s.state, HRSessionRunning);
    /* a key that arrives late is dropped, and the test is 15 s long */
    [s insertText:@" " atTime:31.0];
    XCTAssertEqual(s.state, HRSessionFinished);
    XCTAssertEqual(s.currentWordIndex, (NSUInteger)0);
    HRTestSummary *r = [s summary];
    XCTAssertEqualWithAccuracy(r.duration, 15.0, 1e-9);
    /* the unfinished-but-right word counts: 2 chars in 15 s */
    XCTAssertEqualWithAccuracy(r.wpm, 2.0 / 5.0 * 4.0, 1e-9);
    XCTAssertEqual([r.rawWpmPerSecond count], (NSUInteger)15);
}

- (void)testEndlessSourceKeepsAhead
{
    HRTestConfiguration *c = [HRTestConfiguration defaultConfiguration];
    c.mode = HRTestModeTime;
    c.amount = 600;
    HRWordListSource *src = [[HRWordListSource alloc] initWithWords:@[@"a", @"b"]
                                                             random:[[HRRandom alloc] initWithSeed:3]];
    HRTestSession *s = [[HRTestSession alloc] initWithConfiguration:c source:src];
    for (NSUInteger i = 0; i < 200; i++) {
        [s insertText:((HRWord *)s.words[i]).text atTime:(double)i];
        [s insertText:@" " atTime:(double)i + 0.5];
    }
    XCTAssertEqual(s.currentWordIndex, (NSUInteger)200);
    XCTAssertGreaterThan([s.words count], (NSUInteger)230);
}

- (void)testZenHasNoTargetAndEndsOnRequest
{
    HRTestConfiguration *c = [HRTestConfiguration defaultConfiguration];
    c.mode = HRTestModeZen;
    HRTestSession *s = [[HRTestSession alloc] initWithConfiguration:c source:nil];
    [s insertText:@"free text" atTime:0.0];
    XCTAssertEqual([s stateOfCharacterAtIndex:0 inWordAtIndex:1], HRCharacterCorrect);
    [s finishAtTime:6.0];
    XCTAssertEqual(s.state, HRSessionFinished);
    HRTestSummary *r = [s summary];
    XCTAssertEqualWithAccuracy(r.accuracy, 100.0, 1e-9);
    XCTAssertEqualWithAccuracy(r.wpm, 9.0 / 5.0 * 10.0, 1e-9);
}

/* The time a key takes: from the keystroke before it, when both were right
 * and there was no pause in between. */
- (void)testKeysAreTimedWhenTheRunIsClean
{
    HRTestConfiguration *c = [HRTestConfiguration defaultConfiguration];
    c.mode = HRTestModeCustom;
    HRTestSession *s = [[HRTestSession alloc] initWithConfiguration:c
                                                             source:[[HRFixedTextSource alloc] initWithText:@"abcab x"]];
    [s insertText:@"a" atTime:10.0];    /* the first key has nothing before it */
    [s insertText:@"b" atTime:10.2];    /* b: 0.2 */
    [s insertText:@"x" atTime:10.3];    /* wrong */
    [s deleteBackwardAtTime:10.4];
    [s insertText:@"c" atTime:10.5];    /* after a mistake and Backspace: not timed */
    [s insertText:@"a" atTime:10.8];    /* a: 0.3 */
    [s insertText:@"b" atTime:15.0];    /* a pause: not timed */
    [s insertText:@" " atTime:15.1];    /* space: 0.1 */
    [s insertText:@"x" atTime:15.25];   /* x: 0.15 */
    XCTAssertEqual(s.state, HRSessionFinished);
    NSDictionary *k = [s summary].keyStats;
    XCTAssertEqual([k[@"a"][@"timed"] unsignedIntegerValue], (NSUInteger)1);
    XCTAssertEqualWithAccuracy([k[@"a"][@"time"] doubleValue], 0.3, 1e-9);
    XCTAssertEqual([k[@"b"][@"timed"] unsignedIntegerValue], (NSUInteger)1);
    XCTAssertEqualWithAccuracy([k[@"b"][@"time"] doubleValue], 0.2, 1e-9);
    XCTAssertEqual([k[@"c"][@"timed"] unsignedIntegerValue], (NSUInteger)0);
    XCTAssertEqualWithAccuracy([k[@" "][@"time"] doubleValue], 0.1, 1e-9);
    XCTAssertEqualWithAccuracy([k[@"x"][@"time"] doubleValue], 0.15, 1e-9);
    XCTAssertEqual([k[@"b"][@"hits"] unsignedIntegerValue], (NSUInteger)2, @"counted as before");
}

@end
