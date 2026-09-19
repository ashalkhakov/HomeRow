/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * This library is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2.1 of the License, or (at
 * your option) any later version.  See COPYING.LIB.
 */
#import <AppKit/AppKit.h>

@class HRTheme;

/* Raw WPM per second as a line, wrong keystrokes as marks along the
 * bottom.  NSBezierPath only: no chart library on either platform. */
@interface HRChartView : NSView

@property (nonatomic, strong) HRTheme *theme;
@property (nonatomic, copy) NSArray *samples;  /* NSNumber, one per second */
@property (nonatomic, copy) NSArray *errors;   /* NSNumber, one per second */
@property (nonatomic) double average;          /* drawn as a rule; 0 = none */

@end
