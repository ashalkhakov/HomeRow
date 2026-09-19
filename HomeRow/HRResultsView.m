/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * This library is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2.1 of the License, or (at
 * your option) any later version.  See COPYING.LIB.
 */
#import "HRResultsView.h"

@implementation HRResultsView

- (BOOL)acceptsFirstResponder { return YES; }

- (void)setBackgroundColor:(NSColor *)color
{
    _backgroundColor = color;
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect
{
    if (_backgroundColor) {
        [_backgroundColor set];
        NSRectFill([self bounds]);
    }
}

- (void)keyDown:(NSEvent *)event
{
    NSString *chars = [event charactersIgnoringModifiers];
    unichar c = [chars length] > 0 ? [chars characterAtIndex:0] : 0;
    if (([event modifierFlags] & NSEventModifierFlagCommand) == 0
        && (c == NSTabCharacter || c == 0x1B || c == NSCarriageReturnCharacter
            || c == NSNewlineCharacter || c == NSEnterCharacter)) {
        if ([_target respondsToSelector:@selector(restartTest:)]) {
            [_target performSelector:@selector(restartTest:) withObject:self];
        }
        return;
    }
    [super keyDown:event];
}

@end
