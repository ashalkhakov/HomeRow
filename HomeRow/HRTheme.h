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

/* Colours of the typing surface.  A theme is a plist of "#RRGGBB" strings
 * in Resources/Themes (and, later, in Application Support/HomeRow/Themes);
 * see light.plist for the keys. */
@interface HRTheme : NSObject

@property (nonatomic, readonly, copy) NSString *name;
@property (nonatomic, readonly) NSColor *background;
@property (nonatomic, readonly) NSColor *untyped;
@property (nonatomic, readonly) NSColor *correct;
@property (nonatomic, readonly) NSColor *incorrect;
@property (nonatomic, readonly) NSColor *extra;
@property (nonatomic, readonly) NSColor *caret;
@property (nonatomic, readonly) NSColor *accent;

+ (instancetype)themeNamed:(NSString *)name;
/* The "HRTheme" default; "auto" (the default) follows the system's
 * light/dark setting where there is one. */
+ (instancetype)currentTheme;

+ (NSColor *)colorFromHex:(NSString *)hex;

@end
