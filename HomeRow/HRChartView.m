/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * This library is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2.1 of the License, or (at
 * your option) any later version.  See COPYING.LIB.
 */
#import "HRChartView.h"
#import "HRTheme.h"

@implementation HRChartView

- (void)setSamples:(NSArray *)samples
{
    _samples = [samples copy];
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect
{
    NSRect b = NSInsetRect([self bounds], 8.0, 8.0);
    [(_theme.background ?: [NSColor whiteColor]) set];
    NSRectFill([self bounds]);
    NSUInteger n = [_samples count];
    if (n < 2 || !_theme) return;

    double max = _average;
    for (NSNumber *s in _samples) max = MAX(max, [s doubleValue]);
    if (max <= 0.0) return;
    max *= 1.1;

    NSFont *small = [NSFont systemFontOfSize:10.0];
    NSDictionary *labelAttrs = @{NSFontAttributeName: small,
                                 NSForegroundColorAttributeName: _theme.untyped};
    CGFloat left = NSMinX(b) + 28.0, bottom = NSMinY(b) + 14.0;
    CGFloat width = NSMaxX(b) - left, height = NSMaxY(b) - bottom;

    /* axis */
    [[_theme.untyped colorWithAlphaComponent:0.4] set];
    NSRectFill(NSMakeRect(left, bottom, width, 1.0));
    [[NSString stringWithFormat:@"%.0f", max / 1.1] drawAtPoint:NSMakePoint(NSMinX(b), bottom + height / 1.1 - 6.0)
                                                  withAttributes:labelAttrs];
    [@"0" drawAtPoint:NSMakePoint(NSMinX(b), bottom - 6.0) withAttributes:labelAttrs];
    [[NSString stringWithFormat:@"%lus", (unsigned long)n] drawAtPoint:NSMakePoint(NSMaxX(b) - 24.0, NSMinY(b) - 2.0)
                                                         withAttributes:labelAttrs];

    if (_average > 0.0) {
        CGFloat y = bottom + height * (_average / max);
        NSBezierPath *rule = [NSBezierPath bezierPath];
        CGFloat dash[2] = {4.0, 4.0};
        [rule setLineDash:dash count:2 phase:0.0];
        [rule moveToPoint:NSMakePoint(left, y)];
        [rule lineToPoint:NSMakePoint(left + width, y)];
        [[_theme.untyped colorWithAlphaComponent:0.7] set];
        [rule stroke];
    }

    NSBezierPath *line = [NSBezierPath bezierPath];
    [line setLineWidth:2.0];
    [line setLineJoinStyle:NSLineJoinStyleRound];
    for (NSUInteger i = 0; i < n; i++) {
        NSPoint p = NSMakePoint(left + width * (double)i / (double)(n - 1),
                                bottom + height * ([_samples[i] doubleValue] / max));
        if (i == 0) [line moveToPoint:p]; else [line lineToPoint:p];
    }
    [_theme.accent set];
    [line stroke];

    [_theme.incorrect set];
    for (NSUInteger i = 0; i < MIN(n, [_errors count]); i++) {
        if ([_errors[i] integerValue] <= 0) continue;
        CGFloat x = left + width * (double)i / (double)(n - 1);
        NSRectFill(NSMakeRect(x - 1.5, bottom + 3.0, 3.0, 3.0 + 2.0 * MIN(5, [_errors[i] integerValue])));
    }
}

@end
