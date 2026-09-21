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

@class HRWelcomeWindowController;

typedef NS_ENUM(NSInteger, HRWelcomeChoice) {
    HRWelcomeResume = 0,    /* whatever was on when HomeRow was last quit */
    HRWelcomeTeachMe,       /* a course, from the beginning or from its place */
    HRWelcomeTestMe         /* a test, now */
};

@protocol HRWelcomeDelegate <NSObject>
- (void)welcome:(HRWelcomeWindowController *)controller didChoose:(HRWelcomeChoice)choice;
@end

/* What every launch starts with: carry on, be taught, or be tested.  A
 * tutor and a speed test are different programs to different people, and to
 * the same person on different days.  WelcomeWindow.xib.
 *
 * Closing the window is a choice too: to carry on if there is something to
 * carry on with, a test otherwise. */
@interface HRWelcomeWindowController : NSWindowController <NSWindowDelegate>

@property (nonatomic, strong) IBOutlet NSButton *resumeButton;
@property (nonatomic, strong) IBOutlet NSTextField *resumeField;
@property (nonatomic, strong) IBOutlet NSButton *teachButton;
@property (nonatomic, strong) IBOutlet NSButton *testButton;

- (instancetype)initWithDelegate:(id<HRWelcomeDelegate>)delegate;

/* What "carry on" would carry on with, in a line or two -- "Quick QWERTY
 * course, lesson 4 of 15"; nil when there is nothing on record, which
 * greys the button out. */
@property (nonatomic, copy) NSString *resumeDescription;

/* Something else answered the question (a menu, another window). */
- (void)dismiss;

- (IBAction)resume:(id)sender;
- (IBAction)teachMe:(id)sender;
- (IBAction)testMe:(id)sender;

@end
