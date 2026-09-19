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
/* The key that was just pressed by mistake, drawn in the error colour:
 * same spelling as expectedInput.  nil for none. */
@property (nonatomic, copy) NSString *wrongInput;

/* Statistics: character -> @{@"hits", @"misses"} (as HRResultStore sums
 * them).  When set, the finger tints give way to a heatmap: the more often
 * a key was missed, per press, the deeper it is tinted in the error colour
 * -- one hue, light to dark.  A key's characters (both levels) are taken
 * together; keys pressed fewer than heatMinimumPresses times stay plain. */
@property (nonatomic, copy) NSDictionary *heatCounts;
@property (nonatomic) NSUInteger heatMinimumPresses;
/* The error rate (0...1) the deepest tint stands for, for a legend. */
- (double)heatMaximumRate;
/* For tests: the rate of the key at row/column, or -1 when it stays plain. */
- (double)heatRateForKeyAtRow:(NSUInteger)row column:(NSUInteger)column;

/* What is lit for the current expectedInput, for tests: @"key:2:3",
 * @"space", @"return", @"backspace", plus @"+lshift" / @"+rshift"; nil when
 * nothing is. */
- (NSString *)litKeyDescription;
- (NSString *)wrongKeyDescription;

/* The height that keeps the keys square at a given width. */
+ (CGFloat)heightForWidth:(CGFloat)width;

@end
