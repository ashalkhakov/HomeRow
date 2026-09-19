/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * HomeRow is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version.  It comes with ABSOLUTELY NO WARRANTY.  See COPYING.
 */
#import <Foundation/Foundation.h>
#import "HRTestConfiguration.h"
#import "HRTextSource.h"
#import "HRTestSummary.h"

typedef NS_ENUM(NSInteger, HRSessionState) {
    HRSessionIdle = 0,   /* nothing typed yet; the clock has not started */
    HRSessionRunning,
    HRSessionFinished
};

typedef NS_ENUM(NSInteger, HRCharacterState) {
    HRCharacterUntyped = 0,
    HRCharacterCorrect,
    HRCharacterIncorrect,
    HRCharacterExtra,    /* typed past the end of the word */
    HRCharacterMissed    /* word left before this character was typed */
};

/* One run of a test: target text, what has been typed against it, and the
 * clock.  Foundation only.
 *
 * Time never comes from inside: every input carries the timestamp of the
 * event that caused it (seconds on any monotonic clock).  That keeps the
 * numbers independent of redraw latency, and lets tests replay a session
 * exactly. */
@interface HRTestSession : NSObject

@property (nonatomic, readonly, copy) HRTestConfiguration *configuration;
@property (nonatomic, readonly) HRSessionState state;

/* Target words loaded so far (HRWord).  Grows while an endless source is
 * being consumed; in zen mode it mirrors what was typed. */
@property (nonatomic, readonly) NSArray *words;
@property (nonatomic, readonly) NSUInteger currentWordIndex;

- (instancetype)initWithConfiguration:(HRTestConfiguration *)configuration
                               source:(id<HRTextSource>)source;

/* --- input ------------------------------------------------------------ */

/* Any text the input system delivers; may hold several characters.
 * " " and "\n" are separators, everything else is typed into the word. */
- (void)insertText:(NSString *)text atTime:(NSTimeInterval)time;
- (void)deleteBackwardAtTime:(NSTimeInterval)time;
- (void)deleteWordBackwardAtTime:(NSTimeInterval)time;

/* Call regularly while running: ends a timed test when its time is up. */
- (void)tickAtTime:(NSTimeInterval)time;
/* Ends the test now (zen mode, or giving up). */
- (void)finishAtTime:(NSTimeInterval)time;

/* --- reading ---------------------------------------------------------- */

/* Characters typed so far for a word (NSString units); empty for words
 * not reached. */
- (NSArray *)typedCharactersForWordAtIndex:(NSUInteger)index;
/* Display length of a word: its own length or the typed length, whichever
 * is longer. */
- (NSUInteger)displayLengthOfWordAtIndex:(NSUInteger)index;
- (HRCharacterState)stateOfCharacterAtIndex:(NSUInteger)charIndex
                                inWordAtIndex:(NSUInteger)wordIndex;
/* What to draw at that position: the target character, or the extra one. */
- (NSString *)displayCharacterAtIndex:(NSUInteger)charIndex
                        inWordAtIndex:(NSUInteger)wordIndex;
/* What the learner has to press next, for the on-screen keyboard:
 * the next character of the word, @" " or @"\n" at its end, @"\b" when
 * what is typed so far is wrong and has to be taken back first, and nil
 * when there is nothing to press (zen, finished). */
- (NSString *)expectedInput;

/* For feedback on a wrong key.  The count goes up with every wrong input --
 * compare it before and after -insertText:atTime: -- and the other two
 * describe the latest one: what was pressed (@" " and @"\n" for the
 * separators), and whether it was refused (stop on error, or the wrong
 * separator) rather than entered and shown as a mistake. */
@property (nonatomic, readonly) NSUInteger wrongInputCount;
@property (nonatomic, readonly, copy) NSString *lastWrongInput;
@property (nonatomic, readonly) BOOL lastWrongInputWasRefused;

/* Caret position within the current word, in characters. */
- (NSUInteger)caretIndexInCurrentWord;

- (NSTimeInterval)elapsedAtTime:(NSTimeInterval)time;
/* Seconds (time mode) or words (finite modes) left; -1 when not meaningful. */
- (NSInteger)remainingAtTime:(NSTimeInterval)time;
- (double)liveWpmAtTime:(NSTimeInterval)time;
- (double)liveAccuracy;

/* Valid once finished. */
- (HRTestSummary *)summary;

@end
