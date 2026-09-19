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

/* Syntax colours for code that is not typed yet, by HRTextStyle (HRWord.h).
 * Muted on purpose: once typed, text takes the correct/incorrect colours,
 * and those have to stay the loudest thing on the surface. */
- (NSColor *)colorForTextStyle:(uint8_t)style;

/* A font whose glyphs really are all one width -- measured, not taken on
 * trust.  The typing surface puts every character in a cell of its own;
 * gnustep-gui's -userFixedPitchFontOfSize: asks for "Courier", and where
 * there is no Courier it quietly answers with the proportional default,
 * which leaves an "i" adrift in an "m"-wide cell.  So: the user's fixed
 * font if it is one, else the first monospaced family that is installed
 * (the AppImage brings DejaVu Sans Mono and Liberation Mono), else any
 * font with "Mono" in its name that measures up. */
+ (NSFont *)fixedPitchFontOfSize:(CGFloat)size;
/* The families Preferences offers: fixed-pitch by the ruler, sorted. */
+ (NSArray *)fixedPitchFontFamilies;
/* The sizes set in Preferences, or the defaults (24 and 15). */
+ (CGFloat)proseFontSize;
+ (CGFloat)codeFontSize;
/* For the smoke test: NO when even that search ended on a proportional font. */
+ (BOOL)fontIsFixedPitch:(NSFont *)font;

+ (instancetype)themeNamed:(NSString *)name;
/* The "HRTheme" default; "auto" (the default) follows the system's
 * light/dark setting where there is one. */
+ (instancetype)currentTheme;

+ (NSColor *)colorFromHex:(NSString *)hex;

@end

/* User defaults.  HRFontFamily empty: choose one (see above).  HRTheme:
 * "auto" (follow the system), "light", "dark". */
extern NSString * const HRFontFamilyDefaultsKey;
extern NSString * const HRProseFontSizeDefaultsKey;
extern NSString * const HRCodeFontSizeDefaultsKey;
extern NSString * const HRThemeDefaultsKey;
