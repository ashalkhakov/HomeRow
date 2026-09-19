/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * HomeRow is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version.  It comes with ABSOLUTELY NO WARRANTY.  See COPYING.
 */
#import "HRKeyboardView.h"
#import "HRKeyboardLayout.h"
#import "HRTheme.h"

/* The board is 15 key-widths across and 5 rows tall. */
static const CGFloat HRBoardUnits = 15.0;
static const CGFloat HRBoardRows = 5.0;
static const CGFloat HRBoardInset = 12.0;

typedef NS_ENUM(NSInteger, HRSpecialKey) {
    HRSpecialNone = 0, HRSpecialBackspace, HRSpecialTab, HRSpecialCaps, HRSpecialReturn,
    HRSpecialLeftShift, HRSpecialRightShift, HRSpecialSpace
};

@implementation HRKeyboardView

+ (CGFloat)heightForWidth:(CGFloat)width
{
    CGFloat unit = MIN(46.0, (width - 2 * HRBoardInset) / HRBoardUnits);
    return ceil(unit * HRBoardRows + 2 * HRBoardInset);
}

- (BOOL)isFlipped { return YES; }
- (BOOL)isOpaque { return YES; }
- (BOOL)acceptsFirstResponder { return NO; }

- (void)setKeyboardLayout:(HRKeyboardLayout *)layout { _keyboardLayout = layout; [self setNeedsDisplay:YES]; }
- (void)setTheme:(HRTheme *)theme { _theme = theme; [self setNeedsDisplay:YES]; }

- (void)setExpectedInput:(NSString *)expectedInput
{
    if (_expectedInput == expectedInput || [_expectedInput isEqualToString:expectedInput]) return;
    _expectedInput = [expectedInput copy];
    [self setNeedsDisplay:YES];
}

#pragma mark - Geometry, in key units

/* x of the first character key of each row */
- (CGFloat)startOfRow:(NSUInteger)row
{
    switch (row) {
        case 0: return 0.0;
        case 1: return 1.5;                                             /* after Tab */
        case 2: return 1.75;                                            /* after Caps Lock */
        case 3: return _keyboardLayout.geometry == HRKeyboardISO ? 1.25 : 2.25; /* after the left Shift */
    }
    return 0.0;
}

- (NSRect)unitRectForKeyAtRow:(NSUInteger)row column:(NSUInteger)column
{
    CGFloat x = [self startOfRow:row] + (CGFloat)column;
    CGFloat w = 1.0;
    /* ANSI's backslash fills the row out to the right edge */
    if (row == 1 && _keyboardLayout.geometry == HRKeyboardANSI && column == 12) w = HRBoardUnits - x;
    return NSMakeRect(x, (CGFloat)row, w, 1.0);
}

- (NSRect)unitRectForSpecial:(HRSpecialKey)key
{
    BOOL iso = _keyboardLayout.geometry == HRKeyboardISO;
    switch (key) {
        case HRSpecialBackspace:  return NSMakeRect(13.0, 0.0, 2.0, 1.0);
        case HRSpecialTab:        return NSMakeRect(0.0, 1.0, 1.5, 1.0);
        case HRSpecialCaps:       return NSMakeRect(0.0, 2.0, 1.75, 1.0);
        case HRSpecialReturn:     return iso ? NSMakeRect(13.75, 1.0, 1.25, 2.0)   /* drawn tall */
                                             : NSMakeRect(12.75, 2.0, 2.25, 1.0);
        case HRSpecialLeftShift:  return NSMakeRect(0.0, 3.0, iso ? 1.25 : 2.25, 1.0);
        case HRSpecialRightShift: return NSMakeRect(12.25, 3.0, 2.75, 1.0);
        case HRSpecialSpace:      return NSMakeRect(4.0, 4.0, 6.25, 1.0);
        case HRSpecialNone:       break;
    }
    return NSZeroRect;
}

- (NSRect)viewRectForUnitRect:(NSRect)u
{
    NSRect b = [self bounds];
    CGFloat unit = MIN((NSWidth(b) - 2 * HRBoardInset) / HRBoardUnits,
                       (NSHeight(b) - 2 * HRBoardInset) / HRBoardRows);
    CGFloat left = floor((NSWidth(b) - unit * HRBoardUnits) / 2.0);
    CGFloat top = floor((NSHeight(b) - unit * HRBoardRows) / 2.0);
    return NSInsetRect(NSMakeRect(left + u.origin.x * unit, top + u.origin.y * unit,
                                  u.size.width * unit, u.size.height * unit), 2.0, 2.0);
}

#pragma mark - What is lit

- (void)resolveLitKey:(HRKeyPosition **)outPosition special:(HRSpecialKey *)outSpecial
{
    *outPosition = nil;
    *outSpecial = HRSpecialNone;
    if ([_expectedInput length] == 0) return;
    if ([_expectedInput isEqualToString:@" "])       *outSpecial = HRSpecialSpace;
    else if ([_expectedInput isEqualToString:@"\n"]) *outSpecial = HRSpecialReturn;
    else if ([_expectedInput isEqualToString:@"\b"]) *outSpecial = HRSpecialBackspace;
    else *outPosition = [_keyboardLayout positionOfCharacter:_expectedInput];
}

- (NSString *)litKeyDescription
{
    HRKeyPosition *p = nil;
    HRSpecialKey special = HRSpecialNone;
    [self resolveLitKey:&p special:&special];
    if (special == HRSpecialSpace) return @"space";
    if (special == HRSpecialReturn) return @"return";
    if (special == HRSpecialBackspace) return @"backspace";
    if (!p) return nil;
    NSString *d = [NSString stringWithFormat:@"key:%lu:%lu", (unsigned long)p.row, (unsigned long)p.column];
    if ([p needsShift]) d = [d stringByAppendingString:([p usesLeftShift] ? @"+lshift" : @"+rshift")];
    return d;
}

#pragma mark - Drawing

/* One muted colour per finger, the two index fingers told apart; mixed
 * into the key colour, so it works on a light and on a dark theme. */
- (NSColor *)tintForFinger:(HRFinger)finger
{
    static const CGFloat rgb[9][3] = {
        {0.80, 0.36, 0.36}, {0.85, 0.60, 0.25}, {0.72, 0.72, 0.25}, {0.35, 0.68, 0.40},
        {0.30, 0.66, 0.70}, {0.36, 0.50, 0.82}, {0.58, 0.42, 0.80}, {0.78, 0.40, 0.66},
        {0.50, 0.50, 0.50} };
    return [NSColor colorWithCalibratedRed:rgb[finger][0] green:rgb[finger][1] blue:rgb[finger][2] alpha:1.0];
}

- (NSColor *)blend:(NSColor *)a with:(NSColor *)b fraction:(CGFloat)f
{
    NSColor *ca = [a colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]];
    NSColor *cb = [b colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]];
    if (!ca || !cb) return a;
    return [NSColor colorWithCalibratedRed:[ca redComponent] * (1 - f) + [cb redComponent] * f
                                     green:[ca greenComponent] * (1 - f) + [cb greenComponent] * f
                                      blue:[ca blueComponent] * (1 - f) + [cb blueComponent] * f
                                     alpha:1.0];
}

- (void)fillKey:(NSRect)r color:(NSColor *)color
{
    [color set];
    [[NSBezierPath bezierPathWithRoundedRect:r xRadius:4.0 yRadius:4.0] fill];
}

- (void)drawLabel:(NSString *)label inRect:(NSRect)r size:(CGFloat)size color:(NSColor *)color corner:(BOOL)corner
{
    if ([label length] == 0) return;
    NSDictionary *attrs = @{NSFontAttributeName: [NSFont systemFontOfSize:size],
                            NSForegroundColorAttributeName: color};
    NSSize s = [label sizeWithAttributes:attrs];
    NSPoint p = corner ? NSMakePoint(NSMinX(r) + 4.0, NSMinY(r) + 2.0)
                       : NSMakePoint(NSMidX(r) - s.width / 2.0, NSMidY(r) - s.height / 2.0);
    [label drawAtPoint:p withAttributes:attrs];
}

- (void)drawRect:(NSRect)dirtyRect
{
    [(_theme.background ?: [NSColor whiteColor]) set];
    NSRectFill([self bounds]);
    if (!_keyboardLayout || !_theme) return;

    HRKeyPosition *lit = nil;
    HRSpecialKey litSpecial = HRSpecialNone;
    [self resolveLitKey:&lit special:&litSpecial];
    HRSpecialKey litShift = HRSpecialNone;
    if (lit && [lit needsShift]) litShift = [lit usesLeftShift] ? HRSpecialLeftShift : HRSpecialRightShift;

    NSColor *plain = [self blend:_theme.background with:_theme.untyped fraction:0.22];
    CGFloat unit = NSWidth([self viewRectForUnitRect:NSMakeRect(0, 0, 1, 1)]);
    CGFloat labelSize = MAX(9.0, floor(unit * 0.36));

    for (NSUInteger row = 0; row < [_keyboardLayout numberOfRows]; row++) {
        for (NSUInteger col = 0; col < [_keyboardLayout numberOfKeysInRow:row]; col++) {
            NSRect r = [self viewRectForUnitRect:[self unitRectForKeyAtRow:row column:col]];
            BOOL isLit = lit && lit.row == row && lit.column == col;
            HRFinger finger = [_keyboardLayout fingerForKeyAtRow:row column:col];
            NSColor *fill = isLit ? _theme.accent : [self blend:plain with:[self tintForFinger:finger] fraction:0.30];
            [self fillKey:r color:fill];

            NSArray *chars = [_keyboardLayout charactersForKeyAtRow:row column:col];
            NSString *base = [chars count] > 0 ? chars[0] : @"";
            NSString *shifted = [chars count] > 1 ? chars[1] : @"";
            NSColor *ink = isLit ? _theme.background : _theme.correct;
            if ([shifted length] > 0 && [shifted isEqualToString:[base uppercaseString]]
                && ![shifted isEqualToString:base]) {
                /* a letter: one capital, as on the key cap */
                [self drawLabel:shifted inRect:r size:labelSize color:ink corner:NO];
            } else {
                [self drawLabel:base inRect:r size:labelSize color:ink corner:NO];
                [self drawLabel:shifted inRect:r size:MAX(8.0, labelSize * 0.7)
                          color:(isLit ? _theme.background : _theme.untyped) corner:YES];
            }
            /* the bumps under the index fingers */
            if (row == 2 && (col == 3 || col == 6)) {
                [ink set];
                NSRectFill(NSMakeRect(NSMidX(r) - 5.0, NSMaxY(r) - 6.0, 10.0, 2.0));
            }
        }
    }

    struct { HRSpecialKey key; __unsafe_unretained NSString *label; } specials[] = {
        /* words, not symbols: gnustep-gui has no font fallback, and a font
         * without U+21E7 would leave the key blank */
        {HRSpecialBackspace, @"bksp"}, {HRSpecialTab, @"tab"}, {HRSpecialCaps, @"caps"},
        {HRSpecialReturn, @"enter"}, {HRSpecialLeftShift, @"shift"}, {HRSpecialRightShift, @"shift"},
        {HRSpecialSpace, @""} };
    for (NSUInteger i = 0; i < sizeof(specials) / sizeof(specials[0]); i++) {
        HRSpecialKey key = specials[i].key;
        NSRect r = [self viewRectForUnitRect:[self unitRectForSpecial:key]];
        BOOL isLit = (key == litSpecial);
        BOOL isShift = (key == litShift);
        NSColor *fill = plain;
        if (isLit) fill = (key == HRSpecialBackspace) ? _theme.incorrect : _theme.accent;
        else if (isShift) fill = [self blend:plain with:_theme.accent fraction:0.6];
        else if (key == HRSpecialSpace) fill = [self blend:plain with:[self tintForFinger:HRFingerThumb] fraction:0.30];
        [self fillKey:r color:fill];
        [self drawLabel:specials[i].label inRect:r size:MAX(8.0, labelSize * 0.75)
                  color:((isLit || isShift) ? _theme.background : _theme.untyped) corner:NO];
    }
}

@end
