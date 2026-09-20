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

int main(int argc, const char *argv[])
{
#if defined(__APPLE__)
    /* A held key repeats, as it does in a terminal or an editor set up for
     * code -- it does not open the accent pop-up, which has no text to work
     * on here.  Accents come from dead keys and Option.  (registerDefaults:
     * so a user's own setting for HomeRow still wins.) */
    @autoreleasepool {
        [[NSUserDefaults standardUserDefaults] registerDefaults:@{@"ApplePressAndHoldEnabled": @NO}];
    }
#endif
    return NSApplicationMain(argc, argv);
}
