/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * HomeRow is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version.  It comes with ABSOLUTELY NO WARRANTY.  See COPYING.
 */
#import "HRUpdater.h"
#import <Sparkle/Sparkle.h>

@implementation HRUpdater
{
    SPUStandardUpdaterController *_controller;
}

- (instancetype)initStarting:(BOOL)start
{
    if ((self = [super init])) {
        _controller = [[SPUStandardUpdaterController alloc] initWithStartingUpdater:start
                                                                    updaterDelegate:nil
                                                                 userDriverDelegate:nil];
    }
    return self;
}

- (BOOL)available
{
    return YES;
}

- (BOOL)canCheckForUpdates
{
    return _controller.updater.canCheckForUpdates;
}

- (IBAction)checkForUpdates:(id)sender
{
    [_controller checkForUpdates:sender];
}

@end
