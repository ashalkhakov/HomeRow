/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * HomeRow is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version.  It comes with ABSOLUTELY NO WARRANTY.  See COPYING.
 */
#import "HRTestView.h"
#import "HRTestSession.h"
#import "HRTheme.h"
#import "HRClock.h"
#import <objc/runtime.h>

static const NSUInteger HRVisibleLines = 3;
static const CGFloat HRInset = 24.0;
static const NSTimeInterval HRFlashDuration = 0.35;

/* `defaults write org.homerow.HomeRow HRLogInput -bool YES`, or -HRLogInput YES
 * on the command line: every step of the conversation with the input
 * system goes to the log.  For when an accent does not arrive. */
static BOOL HRInputLogging(void)
{
    static int on = -1;
    if (on < 0) on = [[NSUserDefaults standardUserDefaults] boolForKey:@"HRLogInput"] ? 1 : 0;
    return on == 1;
}
#define HRInputLog(...) do { if (HRInputLogging()) NSLog(@"HomeRow input: %@", [NSString stringWithFormat:__VA_ARGS__]); } while (0)

@implementation HRTestView
{
    NSTimeInterval _eventTime;
    NSTimeInterval _flashUntil;   /* monotonic; 0 = no wrong key being shown */
    BOOL _flashRefused;           /* ...and it was refused: flash the caret's place */
    NSRect _caretCell;            /* where the next character goes, as last drawn */
    NSFont *_caretFont;
}

- (void)setUpDefaults
{
    if (!_font) _font = [HRTheme fixedPitchFontOfSize:24.0];
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
- (BOOL)resignFirstResponder { [self discardMarkedText]; [self setNeedsDisplay:YES]; return YES; }

- (void)setSession:(HRTestSession *)session
{
    _session = session;
    [self discardMarkedText];
    _flashUntil = 0.0;
    [self setNeedsDisplay:YES];
}

- (void)setCaption:(NSString *)caption
{
    _caption = [caption copy];
    [self setNeedsDisplay:YES];
}

- (void)setPageText:(NSString *)pageText
{
    _pageText = [pageText copy];
    [self setNeedsDisplay:YES];
}

- (void)setCodeLayout:(BOOL)codeLayout
{
    _codeLayout = codeLayout;
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
    _caretCell = NSZeroRect;
    [self drawSurface];
    /* a dead key has been pressed and waits for its letter: show the accent
     * where the letter will go, underlined as marked text is everywhere */
    if ([_markedText length] > 0 && !NSIsEmptyRect(_caretCell) && _caretFont) {
        NSDictionary *attrs = @{NSFontAttributeName: _caretFont, NSForegroundColorAttributeName: _theme.accent};
        NSSize size = [_markedText sizeWithAttributes:attrs];
        NSRect cell = _caretCell;
        cell.size.width = MAX(NSWidth(cell), size.width);
        [(_theme.background ?: [NSColor whiteColor]) set];
        NSRectFill(cell);
        [_markedText drawAtPoint:NSMakePoint(NSMinX(cell) + (NSWidth(cell) - size.width) / 2.0, NSMinY(cell) - 1.0) withAttributes:attrs];
        [_theme.accent set];
        NSRectFill(NSMakeRect(NSMinX(cell), NSMaxY(cell) - 2.0, NSWidth(cell), 2.0));
    }
}

- (void)drawSurface
{
    NSRect bounds = [self bounds];
    [(_theme.background ?: [NSColor whiteColor]) set];
    NSRectFill(bounds);
    if (!_theme) return;
    if (_pageText) {
        [self drawPageInRect:bounds];
        return;
    }
    if (!_session) return;
    if (_codeLayout) {
        [self drawCodeInRect:bounds];
        return;
    }

    CGFloat advance = [@"m" sizeWithAttributes:@{NSFontAttributeName: _font}].width;
    BOOL evenFont = [HRTheme fontIsFixedPitch:_font];
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

    if ([_caption length] > 0) {
        NSFont *small = [HRTheme fixedPitchFontOfSize:13.0];
        NSDictionary *attrs = @{NSFontAttributeName: small, NSForegroundColorAttributeName: _theme.untyped};
        NSArray *captionLines = [_caption componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
        CGFloat h = ceil([small ascender] - [small descender]) + 3.0;
        CGFloat y = MAX(8.0, top - 14.0 - h * [captionLines count]);
        for (NSString *l in captionLines) {
            [l drawAtPoint:NSMakePoint(HRInset, y) withAttributes:attrs];
            y += h;
        }
    }

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
                /* no fixed-pitch font on this machine: at least sit each glyph
                 * in the middle of its cell, not against its left edge */
                if (!evenFont) p.x += MAX(0.0, (advance - [ch sizeWithAttributes:@{NSFontAttributeName: _font}].width) / 2.0);
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
                _caretCell = NSMakeRect(x, y + 2.0, advance, lineHeight - 10.0);
                _caretFont = _font;
                BOOL focused = [[self window] firstResponder] == self;
                if ([self isFlashing]) {
                    /* the key was refused: nothing went in, so say so where the eyes are */
                    [[_theme.incorrect colorWithAlphaComponent:0.35] set];
                    [NSBezierPath fillRect:NSMakeRect(x, y + 2.0, advance, lineHeight - 10.0)];   /* composites, where NSRectFill copies */
                    [_theme.incorrect set];
                } else {
                    [[_theme.caret colorWithAlphaComponent:(focused ? 1.0 : 0.35)] set];
                }
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

#pragma mark - Code layout

/* One walk serves two purposes: with `draw` NO it only finds where the
 * caret is; with `draw` YES it paints the rows from `firstRow` on. */
- (void)walkCodeWithFont:(NSFont *)font advance:(CGFloat)advance lineHeight:(CGFloat)lineHeight
                  origin:(NSPoint)origin firstRow:(NSUInteger)firstRow rows:(NSUInteger)visibleRows
                    draw:(BOOL)draw caretRow:(NSUInteger *)outCaretRow caretColumn:(NSUInteger *)outCaretColumn
{
    NSArray *words = _session.words;
    NSUInteger current = _session.currentWordIndex;
    NSUInteger row = 0, col = 0;
    NSColor *dim = [[_theme colorForTextStyle:HRTextStyleComment] colorWithAlphaComponent:0.85];
    NSDictionary *dimAttrs = @{NSFontAttributeName: font, NSForegroundColorAttributeName: dim};

    for (NSUInteger wi = 0; wi < [words count]; wi++) {
        HRWord *word = words[wi];
        /* untyped text before and after the word: drawn line by line */
        for (int part = 0; part < 2; part++) {
            if (part == 1) {
                NSUInteger len = [_session displayLengthOfWordAtIndex:wi];
                BOOL visible = row >= firstRow && row < firstRow + visibleRows;
                if (wi == current) {
                    if (outCaretRow) *outCaretRow = row;
                    if (outCaretColumn) *outCaretColumn = col + [_session caretIndexInCurrentWord];
                }
                if (draw && visible) {
                    CGFloat y = origin.y + (row - firstRow) * lineHeight;
                    for (NSUInteger ci = 0; ci < len; ci++) {
                        HRCharacterState st = [_session stateOfCharacterAtIndex:ci inWordAtIndex:wi];
                        NSColor *color = (st == HRCharacterUntyped)
                            ? [_theme colorForTextStyle:[word styleOfCharacterAtIndex:ci]] : [self colorForState:st];
                        NSPoint p = NSMakePoint(origin.x + (col + ci) * advance, y);
                        [[_session displayCharacterAtIndex:ci inWordAtIndex:wi] drawAtPoint:p
                            withAttributes:@{NSFontAttributeName: font, NSForegroundColorAttributeName: color}];
                        if (st == HRCharacterIncorrect || st == HRCharacterExtra || st == HRCharacterMissed) {
                            [_theme.incorrect set];
                            NSRectFill(NSMakeRect(p.x, y + lineHeight - 4.0, advance - 1.0, 1.5));
                        }
                    }
                    if (wi == current && _session.state != HRSessionFinished) {
                        NSUInteger caret = [_session caretIndexInCurrentWord];
                        CGFloat x = origin.x + (col + caret) * advance;
                        _caretCell = NSMakeRect(x, y + 1.0, advance, lineHeight - 4.0);
                        _caretFont = font;
                        BOOL focused = [[self window] firstResponder] == self;
                        if ([self isFlashing]) {
                            [[_theme.incorrect colorWithAlphaComponent:0.35] set];
                            [NSBezierPath fillRect:NSMakeRect(x, y + 1.0, advance, lineHeight - 4.0)];   /* composites, where NSRectFill copies */
                            [_theme.incorrect set];
                        } else {
                            [[_theme.caret colorWithAlphaComponent:(focused ? 1.0 : 0.35)] set];
                        }
                        NSRectFill(NSMakeRect(x - 1.0, y + 1.0, 2.0, lineHeight - 4.0));
                        /* the word is done and the line is over: say so, since a
                         * comment may follow and hide the fact */
                        if (word.separator == HRSeparatorNewline && caret >= [word.characters count]
                            && wi + 1 < [words count]) {
                            [@"\u21B5" drawAtPoint:NSMakePoint(x + 3.0, y)
                                    withAttributes:@{NSFontAttributeName: font, NSForegroundColorAttributeName: _theme.accent}];
                        }
                    }
                }
                col += len;
            }
            NSString *untyped = part == 0 ? word.prefix : word.suffix;
            if ([untyped length] == 0) continue;
            NSArray *pieces = [untyped componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
            for (NSUInteger k = 0; k < [pieces count]; k++) {
                if (k > 0) { row++; col = 0; }
                NSString *piece = pieces[k];
                if ([piece length] == 0) continue;
                if (draw && row >= firstRow && row < firstRow + visibleRows) {
                    /* the return marker sits where a suffix would start */
                    CGFloat shift = (part == 1 && wi == current) ? advance * 1.2 : 0.0;
                    [piece drawAtPoint:NSMakePoint(origin.x + col * advance + shift, origin.y + (row - firstRow) * lineHeight)
                        withAttributes:dimAttrs];
                }
                col += [piece length];
            }
        }
        if (word.separator == HRSeparatorNewline) { row++; col = 0; }
        else col++;
    }
}

- (void)drawCodeInRect:(NSRect)bounds
{
    NSFont *font = [HRTheme fixedPitchFontOfSize:15.0];
    CGFloat advance = [@"m" sizeWithAttributes:@{NSFontAttributeName: font}].width;
    CGFloat lineHeight = ceil(([font ascender] - [font descender]) * 1.35);
    if (advance <= 0.0 || lineHeight <= 0.0) return;

    CGFloat top = 14.0;
    if ([_caption length] > 0) {
        NSFont *small = [NSFont systemFontOfSize:12.0];
        [_caption drawAtPoint:NSMakePoint(HRInset, 8.0)
               withAttributes:@{NSFontAttributeName: small, NSForegroundColorAttributeName: _theme.untyped}];
        top = 32.0;
    }
    NSUInteger visibleRows = (NSUInteger)MAX(3.0, floor((NSHeight(bounds) - top - 10.0) / lineHeight));

    NSUInteger caretRow = 0, caretColumn = 0;
    [self walkCodeWithFont:font advance:advance lineHeight:lineHeight origin:NSZeroPoint firstRow:0 rows:0
                      draw:NO caretRow:&caretRow caretColumn:&caretColumn];
    /* the caret's line a third of the way down: what was typed above it,
     * more of what is coming below */
    NSUInteger lead = visibleRows / 3;
    NSUInteger firstRow = caretRow > lead ? caretRow - lead : 0;
    /* a line longer than the view: slide left far enough to keep the caret in */
    CGFloat room = NSWidth(bounds) - 2 * HRInset;
    CGFloat caretX = caretColumn * advance;
    CGFloat slide = caretX > room * 0.85 ? caretX - room * 0.85 : 0.0;

    [self walkCodeWithFont:font advance:advance lineHeight:lineHeight
                    origin:NSMakePoint(HRInset - slide, top) firstRow:firstRow rows:visibleRows
                      draw:YES caretRow:NULL caretColumn:NULL];
}

/* Tabs to the next multiple of eight, as a terminal would. */
static NSString *HRExpandTabs(NSString *line)
{
    if ([line rangeOfString:@"\t" options:NSLiteralSearch].location == NSNotFound) return line;
    NSMutableString *out = [NSMutableString string];
    for (NSUInteger i = 0; i < [line length]; i++) {
        unichar c = [line characterAtIndex:i];
        if (c != '\t') { [out appendFormat:@"%C", c]; continue; }
        do { [out appendString:@" "]; } while ([out length] % 8 != 0);
    }
    return out;
}

- (void)drawPageInRect:(NSRect)bounds
{
    NSMutableArray *lines = [NSMutableArray array];
    NSUInteger columns = 40;
    for (NSString *l in [_pageText componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
        NSString *expanded = HRExpandTabs(l);
        columns = MAX(columns, [expanded length]);
        [lines addObject:expanded];
    }
    /* the largest size at which the widest line and all the lines fit */
    CGFloat size = 16.0;
    NSFont *font = nil;
    CGFloat advance = 0.0, lineHeight = 0.0;
    for (; size >= 8.0; size -= 1.0) {
        font = [HRTheme fixedPitchFontOfSize:size];
        advance = [@"m" sizeWithAttributes:@{NSFontAttributeName: font}].width;
        lineHeight = ceil(([font ascender] - [font descender]) * 1.25);
        if (advance * columns <= NSWidth(bounds) - 2 * HRInset
            && lineHeight * ([lines count] + 2) <= NSHeight(bounds) - 2 * 12.0) break;
    }
    NSDictionary *attrs = @{NSFontAttributeName: font, NSForegroundColorAttributeName: _theme.correct};
    CGFloat x = floor((NSWidth(bounds) - advance * columns) / 2.0);
    CGFloat y = MAX(12.0, floor((NSHeight(bounds) - lineHeight * ([lines count] + 2)) / 2.0));
    for (NSString *l in lines) {
        [l drawAtPoint:NSMakePoint(MAX(HRInset, x), y) withAttributes:attrs];
        y += lineHeight;
    }
    NSString *hint = NSLocalizedString(@"return or space \u2014 continue", nil);
    [hint drawAtPoint:NSMakePoint(MAX(HRInset, x), y + lineHeight)
       withAttributes:@{NSFontAttributeName: font, NSForegroundColorAttributeName: _theme.untyped}];
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
#if !defined(GNUSTEP)
    HRInputLog(@"keyDown keyCode %d characters '%@' ignoringModifiers '%@' flags %#lx; client %d, inputContext %@, marked %@",
               (int)[event keyCode], [event characters], chars, (unsigned long)mods,
               (int)[self conformsToProtocol:@protocol(NSTextInputClient)], [self inputContext], _markedText);
#endif

    if ((mods & NSEventModifierFlagCommand) != 0) {
        [super keyDown:event];
        return;
    }
    if ([self hasMarkedText]) {
        /* an accent is waiting: the next key completes or cancels it, and
         * that is the input context's call, Backspace and Escape included */
        [self interpretKeyEvents:@[event]];
        return;
    }
    if (_pageText) {
        BOOL advance = (c == ' ' || c == NSCarriageReturnCharacter || c == NSNewlineCharacter || c == NSEnterCharacter);
        if (advance) [_delegate testViewDidDismissPage:self];
        else if (c == NSTabCharacter || c == 0x1B) [_delegate testViewDidRequestRestart:self];
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

#pragma mark - Feedback on a wrong key

/* A wrong character that goes in is its own feedback: it is there, red and
 * underlined.  One that is REFUSED -- code mode's stop on error, Return
 * where a space belongs -- changes nothing on screen, which feels like a
 * dead keyboard.  So the place where it should have gone flashes red for a
 * moment.  Either kind can beep, and either is passed on so that the
 * on-screen keyboard can show which key it was. */
- (BOOL)isFlashing
{
    return _flashRefused && _flashUntil > 0.0 && HRMonotonicNow() < _flashUntil;
}

- (void)wrongInput
{
    _flashUntil = HRMonotonicNow() + HRFlashDuration;
    _flashRefused = _session.lastWrongInputWasRefused;
    if (_beepsOnError) NSBeep();
    if ([_delegate respondsToSelector:@selector(testView:didTypeWrongInput:)]) {
        [_delegate testView:self didTypeWrongInput:_session.lastWrongInput];
    }
}

- (void)endFlash
{
    if (_flashUntil == 0.0) return;
    _flashUntil = 0.0;
    [self setNeedsDisplay:YES];
    if ([_delegate respondsToSelector:@selector(testView:didTypeWrongInput:)]) {
        [_delegate testView:self didTypeWrongInput:nil];
    }
}

- (void)afterInput
{
    [self setNeedsDisplay:YES];
    [_delegate testViewDidChange:self];
    if (_session.state == HRSessionFinished) [_delegate testViewDidFinish:self];
}

- (void)insertText:(id)string
{
    HRInputLog(@"insertText:%@ (the plain NSResponder one)", string);
    NSString *s = [string isKindOfClass:[NSAttributedString class]] ? [string string] : string;
    if (_session.state == HRSessionFinished) return;
    NSUInteger wrongBefore = _session.wrongInputCount;
    [_session insertText:s atTime:_eventTime];
    if (_session.wrongInputCount != wrongBefore) [self wrongInput];
    else [self endFlash];   /* the right key: the red goes at once */
    [self afterInput];
}

- (void)typeText:(NSString *)text atTime:(NSTimeInterval)time
{
    _eventTime = time;
    [self insertText:text];
}

#pragma mark - Marked text (dead keys, Option accents)

/* What the view tells the input context about its text is deliberately next
 * to nothing: there is no document here to select in or to read back, only
 * a caret.  That is enough for dead keys and for input methods that compose
 * in place; it is not enough for ones that reconvert existing text, which a
 * typing test has no use for. */

- (void)setMarkedTextForTesting:(NSString *)text
{
    _markedText = [text length] > 0 ? [text copy] : nil;
    [self setNeedsDisplay:YES];
}

- (void)discardMarkedText
{
    if (!_markedText) return;
    _markedText = nil;
#if !defined(GNUSTEP)
    [[self inputContext] discardMarkedText];
#endif
    [self setNeedsDisplay:YES];
}

- (void)insertText:(id)string replacementRange:(NSRange)range
{
    HRInputLog(@"insertText:%@ replacementRange:%@ (marked was %@)", string, NSStringFromRange(range), _markedText);
    /* the composed character replaces the accent that was waiting */
    _markedText = nil;
    /* press-and-hold is switched off (see main.m), but should an input
     * method ask to replace what was just typed, take that back first */
    if (range.location != NSNotFound && range.length > 0 && range.length <= 4) {
        for (NSUInteger i = 0; i < range.length; i++) [_session deleteBackwardAtTime:_eventTime];
    }
    [self insertText:string];
}

- (void)setMarkedText:(id)string selectedRange:(NSRange)selectedRange replacementRange:(NSRange)replacementRange
{
    NSString *s = [string isKindOfClass:[NSAttributedString class]] ? [string string] : string;
    HRInputLog(@"setMarkedText:%@ selectedRange:%@ replacementRange:%@", s, NSStringFromRange(selectedRange), NSStringFromRange(replacementRange));
    _markedText = [s length] > 0 ? [s copy] : nil;
    [self setNeedsDisplay:YES];
}

- (void)unmarkText
{
    /* Only forget it.  AppKit sends this at moments of its own choosing, and
     * whatever is to be typed always arrives through -insertText:...; typing
     * the pending accent here as well would put a bare ` in the text. */
    HRInputLog(@"unmarkText (was %@)", _markedText);
    _markedText = nil;
    [self setNeedsDisplay:YES];
}

- (BOOL)hasMarkedText
{
    return [_markedText length] > 0;
}

- (NSRange)markedRange
{
    return [_markedText length] > 0 ? NSMakeRange(0, [_markedText length]) : NSMakeRange(NSNotFound, 0);
}

- (NSRange)selectedRange
{
    /* no document, no selection */
    return NSMakeRange(NSNotFound, 0);
}

- (NSArray *)validAttributesForMarkedText
{
    return @[];
}

- (NSAttributedString *)attributedSubstringForProposedRange:(NSRange)range actualRange:(NSRangePointer)actualRange
{
    return nil;
}

- (NSUInteger)characterIndexForPoint:(NSPoint)point
{
    return 0;
}

/* Where an input method may put its candidate window: by the caret. */
- (NSRect)firstRectForCharacterRange:(NSRange)range actualRange:(NSRangePointer)actualRange
{
    NSRect cell = NSIsEmptyRect(_caretCell) ? NSMakeRect(HRInset, HRInset, 1.0, 20.0) : _caretCell;
    NSRect inWindow = [self convertRect:cell toView:nil];
#if defined(GNUSTEP)
    NSPoint origin = [[self window] convertBaseToScreen:inWindow.origin];
    return NSMakeRect(origin.x, origin.y, NSWidth(inWindow), NSHeight(inWindow));
#else
    return [[self window] convertRectToScreen:inWindow];
#endif
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
    if (_flashUntil > 0.0 && HRMonotonicNow() >= _flashUntil) [self endFlash];
    if (_session.state != HRSessionRunning) return;
    [_session tickAtTime:HRMonotonicNow()];
    [_delegate testViewDidChange:self];
    if (_session.state == HRSessionFinished) {
        [self setNeedsDisplay:YES];
        [_delegate testViewDidFinish:self];
    }
}

@end
