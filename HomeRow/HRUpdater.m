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

/* GNUstep: the AppImage is updated from outside it (HRUpdater.h). */
@implementation HRUpdater

- (instancetype)initStarting:(BOOL)start
{
    return [super init];
}

- (BOOL)available
{
    return NO;
}

- (BOOL)canCheckForUpdates
{
    return NO;
}

- (IBAction)checkForUpdates:(id)sender
{
}

@end
