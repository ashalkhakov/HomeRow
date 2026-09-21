/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * HomeRow is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version.  It comes with ABSOLUTELY NO WARRANTY.  See COPYING.
 */
#import "HRWelcomeWindowController.h"

#define HRLoc(key) NSLocalizedString(key, nil)

@implementation HRWelcomeWindowController
{
    __weak id<HRWelcomeDelegate> _delegate;
    BOOL _chosen;   /* the window is closing because of a choice, not instead of one */
}

- (instancetype)initWithDelegate:(id<HRWelcomeDelegate>)delegate
{
    if ((self = [super initWithWindowNibName:@"WelcomeWindow"])) {
        _delegate = delegate;
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    [[self window] center];
    [[self window] setDelegate:self];
    [self sync];
}

- (void)setResumeDescription:(NSString *)resumeDescription
{
    _resumeDescription = [resumeDescription copy];
    if ([self isWindowLoaded]) [self sync];
}

/* Return goes to what most people want: on with it, or -- the first time --
 * the course. */
- (void)sync
{
    BOOL canResume = [_resumeDescription length] > 0;
    [_resumeButton setEnabled:canResume];
    [_resumeField setStringValue:(canResume ? _resumeDescription : HRLoc(@"Nothing to carry on with yet."))];
    [[self window] setDefaultButtonCell:[(canResume ? _resumeButton : _teachButton) cell]];
}

- (void)showWindow:(id)sender
{
    _chosen = NO;
    [super showWindow:sender];
}

- (void)choose:(HRWelcomeChoice)choice
{
    _chosen = YES;
    [[self window] orderOut:self];
    [_delegate welcome:self didChoose:choice];
}

- (void)dismiss
{
    if (![self isWindowLoaded] || _chosen) return;
    _chosen = YES;
    [[self window] orderOut:self];
}

- (IBAction)resume:(id)sender { if ([_resumeDescription length] > 0) [self choose:HRWelcomeResume]; }
- (IBAction)teachMe:(id)sender { [self choose:HRWelcomeTeachMe]; }
- (IBAction)testMe:(id)sender { [self choose:HRWelcomeTestMe]; }

- (void)windowWillClose:(NSNotification *)notification
{
    if (_chosen) return;
    _chosen = YES;
    [_delegate welcome:self didChoose:([_resumeDescription length] > 0 ? HRWelcomeResume : HRWelcomeTestMe)];
}

@end
