/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * HomeRow is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version.  It comes with ABSOLUTELY NO WARRANTY.  See COPYING.
 */
#import <AppKit/AppKit.h>
#import "HRActivity.h"

@class HRCourseRun;
@class HRCourseWindowController;

/* Following a course: GNU Typist's lessons, exercise by exercise, with the
 * place kept in each course that has been started.  Owns the Courses window
 * and answers it. */
@interface HRCourseActivity : HRActivity

/* The course that "continue" means: the one chosen last, if it still exists. */
- (NSString *)currentCourseFile;
/* The course to start a beginner on: the first one for the layout in use,
 * in the language of the tests if there is one. */
- (NSString *)beginnersCourseFile;

/* -begin carries on the current course where it was left, or says why not. */
/* Makes `file` the current course and carries on from ITS place. */
- (void)switchToCourse:(NSString *)file;
- (void)startLesson:(NSUInteger)lessonIndex ofCourse:(NSString *)file atStep:(NSUInteger)step;
- (void)restartLesson;

/* A lesson is in progress (as against: a page about there being none). */
@property (nonatomic, readonly) BOOL isInLesson;
@property (nonatomic, readonly) HRCourseRun *run;
@property (nonatomic, readonly, copy) NSString *courseFile;   /* of the lesson in progress */
@property (nonatomic, readonly) NSUInteger lessonIndex;

- (HRCourseWindowController *)windowController;
- (void)showWindow;
/* A result was recorded somewhere: the window's numbers may be stale. */
- (void)reloadWindowIfLoaded;

@end

extern NSString * const HRCurrentCourseDefaultsKey;
