/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * HomeRow is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version.  It comes with ABSOLUTELY NO WARRANTY.  See COPYING.
 */
#import "HRKeyboardDock.h"
#import "HRKeyboardView.h"
#import "HRKeyboardLayout.h"
#import "HRTheme.h"

@implementation HRKeyboardDock
{
    CGFloat _height;   /* what showing it added to the window */
}

+ (BOOL)isWantedForDefaultsKey:(NSString *)key unlessSet:(BOOL)fallback
{
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    return [d objectForKey:key] ? [d boolForKey:key] : fallback;
}

+ (void)setWanted:(BOOL)wanted forDefaultsKey:(NSString *)key
{
    [[NSUserDefaults standardUserDefaults] setBool:wanted forKey:key];
}

- (void)setTheme:(HRTheme *)theme
{
    _theme = theme;
    _keyboardView.theme = theme;
}

- (void)showLayout:(HRKeyboardLayout *)layout wanted:(BOOL)wanted expectedInput:(NSString *)expectedInput
{
    BOOL show = wanted && layout != nil;
    if (_keyboardView.keyboardLayout != layout) _keyboardView.keyboardLayout = layout;
    _keyboardView.expectedInput = show ? expectedInput : nil;
    if (show != _isShown) [self setShown:show];
}

- (void)setWrongInput:(NSString *)input
{
    _keyboardView.wrongInput = _isShown ? input : nil;
}

/* The window grows downwards by the keyboard's height and shrinks back, so
 * the typing surface keeps its size either way.
 *
 * Autoresizing stays ON while the window changes: that is what keeps the
 * control bar glued to the top edge.  (Switching it off for the resize left
 * the bar where it was, in the middle of the taller window.)  The order
 * still matters when hiding: a view squeezed to nothing by a shrinking
 * window never gets its subviews' margins back, so the typing and result
 * views are first given the keyboard's area as well, and then shrink with
 * the window to exactly what is left. */
- (void)setShown:(BOOL)show
{
    _isShown = show;
    NSView *contentView = [_window contentView];
    NSRect content = [contentView bounds];
    CGFloat bar = 48.0;   /* the control bar */
    /* hide exactly what was shown, whatever the width has become since */
    CGFloat h = show ? [HRKeyboardView heightForWidth:NSWidth(content)] : _height;
    _height = show ? h : 0.0;

    BOOL fixedFrame = NO;
#if defined(__APPLE__)
    fixedFrame = ([_window styleMask] & NSWindowStyleMaskFullScreen) != 0;
#endif
    if (!show) {
        CGFloat top = MAX(0.0, NSHeight(content) - bar);
        [_typingView setFrame:NSMakeRect(0, 0, NSWidth(content), top)];
        [_resultsView setFrame:NSMakeRect(0, 0, NSWidth(content), top)];
    }
    if (!fixedFrame) {
        NSRect frame = [_window frame];
        frame.size.height += show ? h : -h;
        frame.origin.y -= show ? h : -h;
        /* growing downwards must not push the keyboard under the screen's edge */
        NSRect visible = [[_window screen] ?: [NSScreen mainScreen] visibleFrame];
        if (show && !NSIsEmptyRect(visible) && NSMinY(frame) < NSMinY(visible)) {
            frame.origin.y = MIN(NSMinY(visible), NSMaxY(visible) - NSHeight(frame));
        }
        [_window setFrame:frame display:NO];
    }
    NSSize minimum = NSMakeSize(640.0, 360.0 + (show ? h : 0.0));
    [_window setContentMinSize:minimum];

    content = [contentView bounds];
    CGFloat bottom = show ? h : 0.0;
    CGFloat top = MAX(bottom, NSHeight(content) - bar);
    [_keyboardView setHidden:!show];
    [_keyboardView setFrame:NSMakeRect(0, 0, NSWidth(content), h)];
    [_typingView setFrame:NSMakeRect(0, bottom, NSWidth(content), top - bottom)];
    [_resultsView setFrame:NSMakeRect(0, bottom, NSWidth(content), top - bottom)];
    [contentView setNeedsDisplay:YES];
}

@end
