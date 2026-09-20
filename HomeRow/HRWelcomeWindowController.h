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
    HRWelcomeTeachMe = 0,   /* a course, from the beginning */
    HRWelcomeTestMe         /* a test, now */
};

@protocol HRWelcomeDelegate <NSObject>
- (void)welcome:(HRWelcomeWindowController *)controller didChoose:(HRWelcomeChoice)choice;
@end

/* The first launch: a tutor and a speed test are different programs to
 * different people, and the main window cannot guess which one this is.
 * WelcomeWindow.xib.  Shown once; closing it is a choice too (a test). */
@interface HRWelcomeWindowController : NSWindowController

@property (nonatomic, strong) IBOutlet NSButton *teachButton;
@property (nonatomic, strong) IBOutlet NSButton *testButton;

- (instancetype)initWithDelegate:(id<HRWelcomeDelegate>)delegate;

- (IBAction)teachMe:(id)sender;
- (IBAction)testMe:(id)sender;

@end

/* User default: the question has been answered (or waved away). */
extern NSString * const HRWelcomeDoneDefaultsKey;
