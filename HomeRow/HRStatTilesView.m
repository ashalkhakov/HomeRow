/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * HomeRow is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version.  It comes with ABSOLUTELY NO WARRANTY.  See COPYING.
 */
#import "HRStatTilesView.h"
#import "HRTheme.h"

@implementation HRStatTilesView

- (BOOL)isOpaque { return YES; }

- (void)setTiles:(NSArray *)tiles { _tiles = [tiles copy]; [self setNeedsDisplay:YES]; }
- (void)setTheme:(HRTheme *)theme { _theme = theme; [self setNeedsDisplay:YES]; }

- (void)drawRect:(NSRect)dirtyRect
{
    [(_theme.background ?: [NSColor whiteColor]) set];
    NSRectFill([self bounds]);
    NSUInteger n = [_tiles count];
    if (n == 0) return;
    NSRect b = [self bounds];
    CGFloat width = NSWidth(b) / (CGFloat)n;
    /* the figure shrinks before it collides with its neighbour */
    CGFloat size = width < 110.0 ? 17.0 : 22.0;
    NSDictionary *valueAttrs = @{NSFontAttributeName: [NSFont boldSystemFontOfSize:size],
                                 NSForegroundColorAttributeName: _theme.correct ?: [NSColor blackColor]};
    NSDictionary *captionAttrs = @{NSFontAttributeName: [NSFont systemFontOfSize:10.0],
                                   NSForegroundColorAttributeName: _theme.untyped ?: [NSColor grayColor]};
    for (NSUInteger i = 0; i < n; i++) {
        NSArray *tile = _tiles[i];
        if ([tile count] < 2) continue;
        NSString *value = tile[0], *caption = tile[1];
        NSSize vs = [value sizeWithAttributes:valueAttrs], cs = [caption sizeWithAttributes:captionAttrs];
        CGFloat x = NSMinX(b) + (CGFloat)i * width;
        CGFloat total = vs.height + cs.height;
        CGFloat y = NSMidY(b) - total / 2.0;
        BOOL flipped = [self isFlipped];
        [value drawAtPoint:NSMakePoint(x + (width - vs.width) / 2.0, flipped ? y : y + cs.height) withAttributes:valueAttrs];
        [caption drawAtPoint:NSMakePoint(x + (width - cs.width) / 2.0, flipped ? y + vs.height : y) withAttributes:captionAttrs];
    }
}

@end
