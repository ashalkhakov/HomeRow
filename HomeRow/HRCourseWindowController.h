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

@class HRResultStore;
@class HRCourseWindowController;

@protocol HRCourseWindowDelegate <NSObject>
/* Lessons of a course, as HRTypLesson objects; parsed on demand. */
- (NSArray *)courseWindow:(HRCourseWindowController *)controller lessonsOfCourse:(NSString *)courseFile;
/* The learner picked a course to follow. */
- (void)courseWindow:(HRCourseWindowController *)controller didSelectCourse:(NSString *)courseFile;
/* Go on where that course was left. */
- (void)courseWindowDidRequestContinue:(HRCourseWindowController *)controller;
/* The progress of a course was just forgotten. */
- (void)courseWindow:(HRCourseWindowController *)controller didResetCourse:(NSString *)courseFile;
/* Start this lesson from its beginning. */
- (void)courseWindow:(HRCourseWindowController *)controller didRequestLesson:(NSUInteger)lessonIndex;
@end

/* The Courses window: which course is being followed, how far along it is,
 * and what each lesson came to.  CourseWindow.xib. */
@interface HRCourseWindowController : NSWindowController <NSTableViewDataSource, NSTableViewDelegate>

@property (nonatomic, strong) IBOutlet NSPopUpButton *coursePopUp;
@property (nonatomic, strong) IBOutlet NSTextField *summaryField;
@property (nonatomic, strong) IBOutlet NSTableView *lessonTable;
@property (nonatomic, strong) IBOutlet NSButton *continueButton;
@property (nonatomic, strong) IBOutlet NSButton *startButton;
@property (nonatomic, strong) IBOutlet NSButton *resetButton;

/* `courses`: the entries of Lessons/gtypist/index.plist.  `languageNames`:
 * language pack identifier -> display name. */
- (instancetype)initWithCourses:(NSArray *)courses
                  languageNames:(NSDictionary *)languageNames
                          store:(HRResultStore *)store
                       delegate:(id<HRCourseWindowDelegate>)delegate;

@property (nonatomic, copy) NSString *selectedCourseFile;
/* Re-read progress from the store; call when a lesson ends. */
- (void)reloadProgress;

- (IBAction)courseChanged:(id)sender;
- (IBAction)continueCourse:(id)sender;
- (IBAction)startSelectedLesson:(id)sender;
- (IBAction)resetProgress:(id)sender;

@end
