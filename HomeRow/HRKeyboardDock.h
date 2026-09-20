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

@class HRKeyboardView;
@class HRKeyboardLayout;
@class HRTheme;

/* The on-screen keyboard's place in the main window: whether it shows, and
 * the room the window makes for it.  It is told which layout to draw and
 * what to light; when it shows is remembered per kind of typing, under
 * whichever defaults key it is handed. */
@interface HRKeyboardDock : NSObject

/* The views it arranges, handed over by whoever loaded the XIB. */
@property (nonatomic, strong) NSWindow *window;
@property (nonatomic, strong) HRKeyboardView *keyboardView;
@property (nonatomic, strong) NSView *typingView;
@property (nonatomic, strong) NSView *resultsView;

@property (nonatomic, strong) HRTheme *theme;

/* Whether the keyboard is wanted where `key` remembers it; `fallback` when
 * nothing is remembered. */
+ (BOOL)isWantedForDefaultsKey:(NSString *)key unlessSet:(BOOL)fallback;
+ (void)setWanted:(BOOL)wanted forDefaultsKey:(NSString *)key;

/* Shows the keyboard when it is wanted and there is a layout to draw --
 * a course for a layout there is no pack for gets no keyboard rather than a
 * wrong one -- and lights `expectedInput` on it. */
- (void)showLayout:(HRKeyboardLayout *)layout wanted:(BOOL)wanted expectedInput:(NSString *)expectedInput;
/* The key hit by mistake, red for a moment; nil to stop. */
- (void)setWrongInput:(NSString *)input;

@property (nonatomic, readonly) BOOL isShown;

@end
