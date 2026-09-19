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

@class HRTheme;

/* A row of headline numbers: each a figure with what it is underneath.
 * Some things are better said as a number than drawn as a chart. */
@interface HRStatTilesView : NSView
@property (nonatomic, strong) HRTheme *theme;
/* @[ @[value, caption], ... ], both NSString */
@property (nonatomic, copy) NSArray *tiles;
@end
