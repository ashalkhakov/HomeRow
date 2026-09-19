/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * This library is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2.1 of the License, or (at
 * your option) any later version.  See COPYING.LIB.
 */
#import "HRTestView.h"
#import "HRTestSession.h"
#import "HRTheme.h"
#import "HRClock.h"
#import <objc/runtime.h>

static const NSUInteger HRVisibleLines = 3;
static const CGFloat HRInset = 24.0;

@implementation HRTestView
{
    NSTimeInterval _eventTime;
}

- (void)setUpDefaults
{
    if (!_font) _font = [NSFont userFixedPitchFontOfSize:24.0] ?: [NSFont systemFontOfSize:24.0];
}

- (instancetype)initWithFrame:(NSRect)frame
{
    if ((self = [super initWithFrame:frame])) [self setUpDefaults];
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) [self setUpDefaults];
    return self;
}

- (BOOL)isFlipped { return YES; }
- (BOOL)isOpaque { return YES; }
- (BOOL)acceptsFirstResponder { return YES; }
- (BOOL)becomeFirstResponder { [self setNeedsDisplay:YES]; return YES; }
- (BOOL)resignFirstResponder { [self setNeedsDisplay:YES]; return YES; }

- (void)setSession:(HRTestSession *)session
{
    _session = session;
    [self setNeedsDisplay:YES];
}

- (void)setTheme:(HRTheme *)theme
{
    _theme = theme;
    [self setNeedsDisplay:YES];
}

#pragma mark - Layout

/* Breaks the loaded words into lines of at most `columns` characters.
 * Each line is an NSValue range of word indexes.  Recomputed per draw: a
 * test holds a few hundred words at most, and a cache would have to be
 * invalidated by every keystroke anyway, since extras widen a word. */
- (NSArray *)linesForColumns:(NSUInteger)columns
{
    NSMutableArray *lines = [NSMutableArray array];
    NSUInteger count = MAX([_session.words count], _session.currentWordIndex + 1);
    NSUInteger start = 0, used = 0;
    for (NSUInteger i = 0; i < count; i++) {
        NSUInteger len = [_session displayLengthOfWordAtIndex:i];
        NSUInteger need = (used == 0) ? len : used + 1 + len;
        if (used > 0 && need > columns) {
            [lines addObject:[NSValue valueWithRange:NSMakeRange(start, i - start)]];
            start = i;
            used = len;
        } else {
            used = need;
        }
        BOOL breaks = i < [_session.words count]
            && ((HRWord *)_session.words[i]).separator == HRSeparatorNewline;
        if (breaks) {
            [lines addObject:[NSValue valueWithRange:NSMakeRange(start, i + 1 - start)]];
            start = i + 1;
            used = 0;
        }
    }
    if (start < count) [lines addObject:[NSValue valueWithRange:NSMakeRange(start, count - start)]];
    return lines;
}

- (NSColor *)colorForState:(HRCharacterState)state
{
    switch (state) {
        case HRCharacterUntyped:   return _theme.untyped;
        case HRCharacterCorrect:   return _theme.correct;
        case HRCharacterIncorrect: return _theme.incorrect;
        case HRCharacterExtra:     return _theme.extra;
        case HRCharacterMissed:    return _theme.untyped;
    }
    return _theme.untyped;
}

- (void)drawRect:(NSRect)dirtyRect
{
    NSRect bounds = [self bounds];
    [(_theme.background ?: [NSColor whiteColor]) set];
    NSRectFill(bounds);
    if (!_session || !_theme) return;

    CGFloat advance = [@"m" sizeWithAttributes:@{NSFontAttributeName: _font}].width;
    CGFloat lineHeight = ceil(([_font ascender] - [_font descender]) * 1.5);
    if (advance <= 0.0) return;
    NSUInteger columns = (NSUInteger)MAX(10.0, floor((NSWidth(bounds) - 2 * HRInset) / advance));

    NSArray *lines = [self linesForColumns:columns];
    NSUInteger current = _session.currentWordIndex;
    NSUInteger currentLine = 0;
    for (NSUInteger l = 0; l < [lines count]; l++) {
        if (NSLocationInRange(current, [lines[l] rangeValue])) { currentLine = l; break; }
    }
    /* the line being typed is the middle one, as soon as there is a line
     * above it to show */
    NSUInteger firstLine = currentLine > 0 ? currentLine - 1 : 0;
    CGFloat top = floor((NSHeight(bounds) - HRVisibleLines * lineHeight) / 2.0);

    for (NSUInteger row = 0; row < HRVisibleLines && firstLine + row < [lines count]; row++) {
        NSRange range = [lines[firstLine + row] rangeValue];
        CGFloat y = top + row * lineHeight;
        NSUInteger col = 0;
        for (NSUInteger wi = range.location; wi < NSMaxRange(range); wi++) {
            NSUInteger len = [_session displayLengthOfWordAtIndex:wi];
            for (NSUInteger ci = 0; ci < len; ci++) {
                HRCharacterState st = [_session stateOfCharacterAtIndex:ci inWordAtIndex:wi];
                NSString *ch = [_session displayCharacterAtIndex:ci inWordAtIndex:wi];
                NSPoint p = NSMakePoint(HRInset + (col + ci) * advance, y);
                [ch drawAtPoint:p withAttributes:@{NSFontAttributeName: _font,
                                                   NSForegroundColorAttributeName: [self colorForState:st]}];
                /* never colour alone: wrong and skipped characters are
                 * underlined as well */
                if (st == HRCharacterIncorrect || st == HRCharacterExtra || st == HRCharacterMissed) {
                    [[self colorForState:(st == HRCharacterMissed ? HRCharacterIncorrect : st)] set];
                    NSRectFill(NSMakeRect(p.x, y + lineHeight - 8.0, advance - 1.0, 2.0));
                }
            }
            if (wi == current && _session.state != HRSessionFinished) {
                CGFloat x = HRInset + (col + [_session caretIndexInCurrentWord]) * advance;
                BOOL focused = [[self window] firstResponder] == self;
                [[_theme.caret colorWithAlphaComponent:(focused ? 1.0 : 0.35)] set];
                NSRectFill(NSMakeRect(x - 1.0, y + 2.0, 2.0, lineHeight - 10.0));
            }
            if (wi < [_session.words count]
                && ((HRWord *)_session.words[wi]).separator == HRSeparatorNewline
                && wi + 1 < [_session.words count]) {
                [@"↵" drawAtPoint:NSMakePoint(HRInset + (col + len) * advance + advance / 2.0, y)
                        withAttributes:@{NSFontAttributeName: _font,
                                         NSForegroundColorAttributeName: _theme.untyped}];
            }
            col += len + 1;
        }
    }
}

#pragma mark - Input

- (void)keyDown:(NSEvent *)event
{
#if defined(__APPLE__)
    _eventTime = [event timestamp];
#else
    _eventTime = HRMonotonicNow();
#endif
    NSString *chars = [event charactersIgnoringModifiers];
    unichar c = [chars length] > 0 ? [chars characterAtIndex:0] : 0;
    NSUInteger mods = [event modifierFlags];

    if ((mods & NSEventModifierFlagCommand) != 0) {
        [super keyDown:event];
        return;
    }
    BOOL isBackspace = (c == NSDeleteCharacter || c == NSBackspaceCharacter || c == NSDeleteFunctionKey);
    if (isBackspace && (mods & (NSEventModifierFlagOption | NSEventModifierFlagControl)) != 0) {
        [self deleteWordBackward:self];
        return;
    }
    BOOL isReturn = (c == NSCarriageReturnCharacter || c == NSNewlineCharacter || c == NSEnterCharacter);
    if (isReturn && (mods & NSEventModifierFlagShift) != 0) {
        [_session finishAtTime:_eventTime];
        [self afterInput];
        return;
    }
    [self interpretKeyEvents:@[event]];
}

- (void)afterInput
{
    [self setNeedsDisplay:YES];
    [_delegate testViewDidChange:self];
    if (_session.state == HRSessionFinished) [_delegate testViewDidFinish:self];
}

- (void)insertText:(id)string
{
    NSString *s = [string isKindOfClass:[NSAttributedString class]] ? [string string] : string;
    if (_session.state == HRSessionFinished) return;
    [_session insertText:s atTime:_eventTime];
    [self afterInput];
}

- (void)typeText:(NSString *)text atTime:(NSTimeInterval)time
{
    _eventTime = time;
    [self insertText:text];
}

/* NSTextInputClient spells it this way on macOS when it is asked. */
- (void)insertText:(id)string replacementRange:(NSRange)range
{
    [self insertText:string];
}

- (void)insertNewline:(id)sender
{
    [self insertText:@"\n"];
}

- (void)deleteBackward:(id)sender
{
    [_session deleteBackwardAtTime:_eventTime];
    [self afterInput];
}

- (void)deleteWordBackward:(id)sender
{
    [_session deleteWordBackwardAtTime:_eventTime];
    [self afterInput];
}

- (void)insertTab:(id)sender
{
    [_delegate testViewDidRequestRestart:self];
}

- (void)cancelOperation:(id)sender
{
    [_delegate testViewDidRequestRestart:self];
}

/* Everything else the key-binding system may come up with (arrows, page
 * keys, ...) has no meaning here; swallow it rather than beep. */
/* Only the commands that mean something here; everything else the
 * key-binding system may come up with (arrows, page keys, ...) is swallowed
 * rather than beeped at.
 *
 * sel_isEqual, not ==: with libobjc2 a selector can carry type information,
 * and two selectors for the same name are then not the same pointer.  The
 * smoke test caught exactly that -- Tab arrived and matched nothing. */
- (void)doCommandBySelector:(SEL)selector
{
    if (sel_isEqual(selector, @selector(insertNewline:)))           [self insertNewline:self];
    else if (sel_isEqual(selector, @selector(deleteBackward:)))     [self deleteBackward:self];
    else if (sel_isEqual(selector, @selector(deleteWordBackward:))) [self deleteWordBackward:self];
    else if (sel_isEqual(selector, @selector(insertTab:)))          [self insertTab:self];
    else if (sel_isEqual(selector, @selector(cancelOperation:)))    [self cancelOperation:self];
}

- (void)mouseDown:(NSEvent *)event
{
    [[self window] makeFirstResponder:self];
}

- (void)tick
{
    if (_session.state != HRSessionRunning) return;
    [_session tickAtTime:HRMonotonicNow()];
    [_delegate testViewDidChange:self];
    if (_session.state == HRSessionFinished) {
        [self setNeedsDisplay:YES];
        [_delegate testViewDidFinish:self];
    }
}

@end
