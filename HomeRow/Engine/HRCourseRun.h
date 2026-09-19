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
#import "HRTypScript.h"
#import "HRTestSummary.h"

/* What a lesson came to, over all of its exercises (repeats included). */
@interface HRLessonSummary : NSObject
@property (nonatomic) double wpm;            /* time-weighted over the exercises */
@property (nonatomic) double accuracy;       /* correct keystrokes / all keystrokes */
@property (nonatomic) NSTimeInterval duration;
@property (nonatomic) NSUInteger exercises;  /* distinct exercises typed */
@property (nonatomic) NSUInteger repeats;    /* times an exercise had to be done again */
@end

/* One pass through one lesson: which step is up, whether the last exercise
 * was good enough, and the running totals.  Foundation only, so the rules
 * of a course are tested without a window.
 *
 * GNU Typist's rule is kept: an exercise with more than its allowed share
 * of wrong keystrokes -- 3% unless the script's E: says otherwise -- is done
 * again, unless it is marked practice-only (d:, s:). */
@interface HRCourseRun : NSObject

@property (nonatomic, readonly) HRTypLesson *lesson;
@property (nonatomic, readonly) NSUInteger stepIndex;
@property (nonatomic, readonly) BOOL isRepeating;   /* the current exercise is a retry */
@property (nonatomic, readonly) BOOL isFinished;
/* NO when the run resumed in the middle: its totals then cover only part
 * of the lesson and are no basis for a personal best. */
@property (nonatomic, readonly) BOOL coversWholeLesson;

+ (double)defaultMaxErrorPercent;

/* stepIndex beyond the lesson starts it from the top. */
- (instancetype)initWithLesson:(HRTypLesson *)lesson startingAtStep:(NSUInteger)stepIndex;

/* nil when finished. */
- (HRTypStep *)currentStep;
/* The current step is a tutorial page and has been read. */
- (void)advancePastPage;
/* The current step is an exercise and was typed.  YES: passed, moved on.
 * NO: too many errors, the same exercise is up again. */
- (BOOL)recordExercise:(HRTestSummary *)summary;

- (HRLessonSummary *)summary;

@end
