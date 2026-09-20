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

@class HRTestSession;
@class HRTestConfiguration;

typedef NS_ENUM(NSInteger, HRInputKind) {
    HRInputText = 0,        /* -insertText:atTime: */
    HRInputDeleteBackward,
    HRInputDeleteWord,
    HRInputFinish           /* -finishAtTime: (zen, or giving up) */
};

/* One thing the typist did, with the timestamp it came with.  A session
 * keeps these in order (-inputLog); since a session takes its time from its
 * input and nowhere else, feeding the log to a fresh session over the same
 * words gives the same test again, to the last number. */
@interface HRInputEvent : NSObject
@property (nonatomic, readonly) HRInputKind kind;
@property (nonatomic, readonly, copy) NSString *text;   /* HRInputText only */
@property (nonatomic, readonly) NSTimeInterval time;
+ (instancetype)eventWithKind:(HRInputKind)kind text:(NSString *)text time:(NSTimeInterval)time;
@end

/* A finished test, to be watched again.  Kept in memory for the test just
 * done; nothing of it is saved. */
@interface HRReplay : NSObject

- (instancetype)initWithSession:(HRTestSession *)session;

@property (nonatomic, readonly, copy) HRTestConfiguration *configuration;
@property (nonatomic, readonly, copy) NSArray *words;    /* HRWord */
@property (nonatomic, readonly, copy) NSArray *events;   /* HRInputEvent */
/* The clock of the original test: its first input, and its end. */
@property (nonatomic, readonly) NSTimeInterval startTime;
@property (nonatomic, readonly) NSTimeInterval duration;

/* A session over the same words with nothing typed yet, and the place in
 * the log back at its start. */
- (HRTestSession *)begin;
/* Feeds the session begun last everything up to `seconds` into the test,
 * and lets its clock run to there.  YES while there is more to come. */
- (BOOL)advanceToElapsed:(NSTimeInterval)seconds;
/* The original clock, for anything that asks the session about "now". */
- (NSTimeInterval)timeAtElapsed:(NSTimeInterval)seconds;

@end
