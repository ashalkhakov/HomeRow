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

NSString * const HRWelcomeDoneDefaultsKey = @"HRWelcomeDone";

@implementation HRWelcomeWindowController
{
    __weak id<HRWelcomeDelegate> _delegate;
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
    [[self window] setDefaultButtonCell:[_teachButton cell]];
}

- (void)choose:(HRWelcomeChoice)choice
{
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:HRWelcomeDoneDefaultsKey];
    [[self window] orderOut:self];
    [_delegate welcome:self didChoose:choice];
}

- (IBAction)teachMe:(id)sender { [self choose:HRWelcomeTeachMe]; }
- (IBAction)testMe:(id)sender { [self choose:HRWelcomeTestMe]; }

@end
