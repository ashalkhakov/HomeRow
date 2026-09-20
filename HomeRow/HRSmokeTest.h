/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * HomeRow is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version.  It comes with ABSOLUTELY NO WARRANTY.  See COPYING.
 */
#import <Foundation/Foundation.h>

@class HRAppDelegate;

/* HR_SMOKE_TEST=1: prove that the packaged app starts, that every outlet of
 * every XIB is connected, that packs were found, and that a test, a lesson
 * and a section of code can be typed and scored -- then exit, 0 for good.
 * CI runs this against the AppImage under Xvfb and against the macOS app,
 * where a unit test cannot reach.
 *
 * It drives the app through its parts, as the menus and windows do, and
 * puts back whatever it changes. */
@interface HRSmokeTest : NSObject

- (instancetype)initWithAppDelegate:(HRAppDelegate *)appDelegate;
/* Does not return: exits with the verdict. */
- (void)run;

@end
