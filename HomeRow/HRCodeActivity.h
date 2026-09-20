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

@class HRCodeLibrary;
@class HRCodeFile;
@class HRCodeWindowController;

/* Code mode is a course whose lessons are the sections of a source file:
 * the same two tables keep its place (CourseProgress, under the file's
 * "code:..." identifier) and what each section came to (LessonRecord).
 * What differs is the text -- laid out as code, coloured by a TextMate
 * grammar, indentation and comments filled in rather than typed -- and
 * that a wrong key does not go in.
 *
 * Owns the library of code and the Code window, and answers the window. */
@interface HRCodeActivity : HRActivity

@property (nonatomic, readonly) HRCodeLibrary *library;

/* -begin carries on the current file where it was left, or says why not. */
- (void)startSection:(NSUInteger)section ofFile:(HRCodeFile *)file;

/* The section on stage, or just typed; nil file when there is none. */
@property (nonatomic, readonly) HRCodeFile *file;
@property (nonatomic, readonly) NSUInteger section;
@property (nonatomic, readonly) NSUInteger sectionCount;

- (HRCodeWindowController *)windowController;
- (void)showWindow;
- (void)reloadWindowIfLoaded;

@end
