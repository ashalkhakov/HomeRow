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

@class HRKeyboardLayout;
@class HRTheme;

/* The on-screen keyboard: the layout's characters on an ANSI or ISO board,
 * finger zones tinted, the home keys marked, and the key to press next lit
 * -- with the Shift of the other hand when it needs one.
 *
 * It only shows; it takes no input and never becomes first responder. */
@interface HRKeyboardView : NSView

/* not "layout": NSView has a -layout of its own on macOS */
@property (nonatomic, strong) HRKeyboardLayout *keyboardLayout;
@property (nonatomic, strong) HRTheme *theme;
/* From -[HRTestSession expectedInput]: a character, @" ", @"\n", @"\b",
 * or nil for nothing. */
@property (nonatomic, copy) NSString *expectedInput;

/* What is lit for the current expectedInput, for tests: @"key:2:3",
 * @"space", @"return", @"backspace", plus @"+lshift" / @"+rshift"; nil when
 * nothing is. */
- (NSString *)litKeyDescription;

/* The height that keeps the keys square at a given width. */
+ (CGFloat)heightForWidth:(CGFloat)width;

@end
