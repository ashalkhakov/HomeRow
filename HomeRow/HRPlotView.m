/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * HomeRow is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version.  It comes with ABSOLUTELY NO WARRANTY.  See COPYING.
 */
#import "HRPlotView.h"
#import "HRTheme.h"

static const CGFloat HRPlotLeft = 44.0;     /* room for the axis numbers */
static const CGFloat HRPlotRight = 12.0;
static const CGFloat HRPlotTop = 26.0;      /* title and read-out */
static const CGFloat HRPlotBottom = 20.0;   /* the two ends of the x axis */

@implementation HRPlotView
{
    NSTrackingRectTag _trackingTag;
    BOOL _tracking;
#if !defined(GNUSTEP)
    NSTrackingArea *_trackingArea;
#endif
}

- (void)setUp
{
    _highlightedIndex = NSNotFound;
}

- (instancetype)initWithFrame:(NSRect)frame
{
    if ((self = [super initWithFrame:frame])) [self setUp];
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) [self setUp];
    return self;
}

- (BOOL)isFlipped { return NO; }
- (BOOL)isOpaque { return YES; }

- (void)setValues:(NSArray *)values
{
    _values = [values copy];
    _highlightedIndex = NSNotFound;
    [self setNeedsDisplay:YES];
}

- (void)setTrend:(NSArray *)trend { _trend = [trend copy]; [self setNeedsDisplay:YES]; }
- (void)setTheme:(HRTheme *)theme { _theme = theme; [self setNeedsDisplay:YES]; }
- (void)setTitle:(NSString *)title { _title = [title copy]; [self setNeedsDisplay:YES]; }

- (void)setHighlightedIndex:(NSUInteger)index
{
    if (index != NSNotFound && index >= [_values count]) index = NSNotFound;
    if (index == _highlightedIndex) return;
    _highlightedIndex = index;
    [self setNeedsDisplay:YES];
}

#pragma mark - The axis

/* 1, 2 or 5 times a power of ten: the step that gives about `count` lines. */
static double HRNiceStep(double range, NSUInteger count)
{
    if (range <= 0.0 || count == 0) return 1.0;
    double raw = range / (double)count;
    double power = pow(10.0, floor(log10(raw)));
    double f = raw / power;
    return (f <= 1.0 ? 1.0 : f <= 2.0 ? 2.0 : f <= 5.0 ? 5.0 : 10.0) * power;
}

- (double)stepForMinimum:(double *)outMin maximum:(double *)outMax
{
    double lo = 0.0, hi = 0.0;
    BOOL any = NO;
    for (NSArray *series in @[_values ?: @[], _trend ?: @[]]) {
        for (NSNumber *n in series) {
            double v = [n doubleValue];
            if (!any) { lo = hi = v; any = YES; }
            lo = MIN(lo, v);
            hi = MAX(hi, v);
        }
    }
    /* bars are lengths, and a length starts at zero; a trend is a position,
     * and may be looked at closely */
    if (_style == HRPlotStyleBars || !any) lo = 0.0;
    if (!isfinite(lo) || !isfinite(hi)) { lo = 0.0; hi = 1.0; }
    /* One value, or several that differ only in the last bits (a value and
     * its own moving average): that is no range.  Left alone it gave a step
     * of 1e-14, which added to 99.67 is 99.67 again -- and a grid loop that
     * never ended. */
    if (hi - lo < 1e-6 * MAX(1.0, fabs(hi))) {
        lo = floor(lo);
        hi = lo + 1.0;
    }
    double step = HRNiceStep(hi - lo, 4);
    lo = floor(lo / step) * step;
    hi = ceil(hi / step) * step;
    if (_ceiling > 0.0 && hi > _ceiling) hi = _ceiling;
    if (hi <= lo) lo = hi - step;
    *outMin = lo;
    *outMax = hi;
    return step;
}

- (void)getAxisMinimum:(double *)minimum maximum:(double *)maximum
{
    double lo, hi;
    [self stepForMinimum:&lo maximum:&hi];
    if (minimum) *minimum = lo;
    if (maximum) *maximum = hi;
}

- (NSRect)plotRect
{
    NSRect b = [self bounds];
    return NSMakeRect(HRPlotLeft, HRPlotBottom, MAX(1.0, NSWidth(b) - HRPlotLeft - HRPlotRight),
                      MAX(1.0, NSHeight(b) - HRPlotTop - HRPlotBottom));
}

/* bars sit in slots; dots sit on the slot centres too, so that the two
 * kinds of chart line up when stacked */
- (CGFloat)xForIndex:(NSUInteger)i inRect:(NSRect)plot
{
    NSUInteger n = MAX((NSUInteger)1, [_values count]);
    return NSMinX(plot) + ((CGFloat)i + 0.5) * NSWidth(plot) / (CGFloat)n;
}

#pragma mark - The read-out

- (NSString *)stringForValue:(double)v
{
    NSString *number = (fabs(v) < 10.0 && v != floor(v)) ? [NSString stringWithFormat:@"%.1f", v]
                                                         : [NSString stringWithFormat:@"%.0f", v];
    return [_unit length] > 0 ? [NSString stringWithFormat:@"%@ %@", number, _unit] : number;
}

- (NSString *)readout
{
    if (_highlightedIndex == NSNotFound || _highlightedIndex >= [_values count]) return nil;
    NSMutableString *s = [NSMutableString string];
    if (_highlightedIndex < [_labels count]) [s appendFormat:@"%@   ", _labels[_highlightedIndex]];
    [s appendString:[self stringForValue:[_values[_highlightedIndex] doubleValue]]];
    if (_highlightedIndex < [_trend count] && [_trendName length] > 0) {
        [s appendFormat:@"   %@ %@", _trendName, [self stringForValue:[_trend[_highlightedIndex] doubleValue]]];
    }
    return s;
}

#pragma mark - Drawing

- (void)drawRect:(NSRect)dirtyRect
{
    NSColor *surface = _theme.background ?: [NSColor whiteColor];
    NSColor *ink = _theme.correct ?: [NSColor blackColor];
    NSColor *muted = _theme.untyped ?: [NSColor grayColor];
    NSColor *mark = _theme.accent ?: [NSColor blueColor];
    [surface set];
    NSRectFill([self bounds]);

    NSRect plot = [self plotRect];
    NSDictionary *small = @{NSFontAttributeName: [NSFont systemFontOfSize:10.0], NSForegroundColorAttributeName: muted};
    NSDictionary *titleAttrs = @{NSFontAttributeName: [NSFont boldSystemFontOfSize:12.0], NSForegroundColorAttributeName: ink};
    if (_title) [_title drawAtPoint:NSMakePoint(HRPlotLeft, NSMaxY(plot) + 6.0) withAttributes:titleAttrs];

    NSUInteger n = [_values count];
    if (n == 0) {
        NSString *text = _emptyText ?: @"";
        NSSize size = [text sizeWithAttributes:small];
        [text drawAtPoint:NSMakePoint(NSMidX(plot) - size.width / 2.0, NSMidY(plot) - size.height / 2.0) withAttributes:small];
        return;
    }

    double lo, hi;
    double step = [self stepForMinimum:&lo maximum:&hi];
    CGFloat scale = NSHeight(plot) / (CGFloat)(hi - lo);

    /* the grid: there, and nothing more */
    /* counted, not accumulated: whatever the step, this ends */
    NSUInteger lines = (step > 0.0 && isfinite(step)) ? (NSUInteger)MIN(20.0, floor((hi - lo) / step + 0.001)) : 0;
    for (NSUInteger k = 0; k <= lines; k++) {
        double v = lo + (double)k * step;
        CGFloat y = floor(NSMinY(plot) + (CGFloat)(v - lo) * scale) + 0.5;
        [[muted colorWithAlphaComponent:(v == lo ? 0.45 : 0.18)] set];
        [NSBezierPath fillRect:NSMakeRect(NSMinX(plot), y - 0.5, NSWidth(plot), 1.0)];
        NSString *label = [NSString stringWithFormat:@"%.0f", v];
        NSSize size = [label sizeWithAttributes:small];
        [label drawAtPoint:NSMakePoint(NSMinX(plot) - size.width - 6.0, y - size.height / 2.0) withAttributes:small];
    }
    if ([_labels count] == n) {
        NSString *first = _labels[0], *last = _labels[n - 1];
        [first drawAtPoint:NSMakePoint(NSMinX(plot), 3.0) withAttributes:small];
        if (n > 1 && ![last isEqualToString:first]) {
            NSSize size = [last sizeWithAttributes:small];
            [last drawAtPoint:NSMakePoint(NSMaxX(plot) - size.width, 3.0) withAttributes:small];
        }
    }

    if (_style == HRPlotStyleBars) {
        CGFloat slot = NSWidth(plot) / (CGFloat)n;
        /* a gap of surface between neighbours, until the bars get too thin for one */
        CGFloat gap = slot >= 6.0 ? 2.0 : (slot >= 3.0 ? 1.0 : 0.0);
        CGFloat width = MIN(28.0, MAX(1.0, slot - gap));
        for (NSUInteger i = 0; i < n; i++) {
            double v = [_values[i] doubleValue];
            if (v <= 0.0) continue;
            CGFloat h = MAX(1.0, (CGFloat)(MIN(v, hi) - lo) * scale);
            NSRect bar = NSMakeRect([self xForIndex:i inRect:plot] - width / 2.0, NSMinY(plot), width, h);
            [(i == _highlightedIndex ? ink : mark) set];
            CGFloat radius = MIN(3.0, MIN(width / 2.0, h));
            if (radius >= 1.5) {
                /* rounded at the data end only: square on the baseline */
                NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:bar xRadius:radius yRadius:radius];
                [path appendBezierPathWithRect:NSMakeRect(NSMinX(bar), NSMinY(bar), width, MIN(h, radius))];
                [path fill];
            } else {
                [NSBezierPath fillRect:bar];
            }
        }
    } else {
        /* dots recede as they multiply; the line carries the story */
        CGFloat radius = n > 200 ? 1.5 : (n > 60 ? 2.0 : 3.0);
        [[mark colorWithAlphaComponent:(n > 60 ? 0.35 : 0.5)] set];
        for (NSUInteger i = 0; i < n; i++) {
            CGFloat y = NSMinY(plot) + (CGFloat)([_values[i] doubleValue] - lo) * scale;
            y = MAX(NSMinY(plot), MIN(NSMaxY(plot), y));
            CGFloat x = [self xForIndex:i inRect:plot];
            [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(x - radius, y - radius, radius * 2.0, radius * 2.0)] fill];
        }
        if ([_trend count] == n && n > 1) {
            NSBezierPath *line = [NSBezierPath bezierPath];
            [line setLineWidth:2.0];
            [line setLineJoinStyle:NSLineJoinStyleRound];
            for (NSUInteger i = 0; i < n; i++) {
                CGFloat y = NSMinY(plot) + (CGFloat)([_trend[i] doubleValue] - lo) * scale;
                y = MAX(NSMinY(plot), MIN(NSMaxY(plot), y));
                NSPoint p = NSMakePoint([self xForIndex:i inRect:plot], y);
                if (i == 0) [line moveToPoint:p]; else [line lineToPoint:p];
            }
            [mark set];
            [line stroke];
        }
        if (_highlightedIndex != NSNotFound && _highlightedIndex < n) {
            CGFloat x = [self xForIndex:_highlightedIndex inRect:plot];
            [[muted colorWithAlphaComponent:0.5] set];
            [NSBezierPath fillRect:NSMakeRect(floor(x), NSMinY(plot), 1.0, NSHeight(plot))];
            CGFloat y = NSMinY(plot) + (CGFloat)([_values[_highlightedIndex] doubleValue] - lo) * scale;
            y = MAX(NSMinY(plot), MIN(NSMaxY(plot), y));
            /* a ring of surface keeps the dot apart from the line under it */
            [surface set];
            [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(x - 6.0, y - 6.0, 12.0, 12.0)] fill];
            [ink set];
            [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(x - 4.0, y - 4.0, 8.0, 8.0)] fill];
        }
    }

    NSString *readout = [self readout];
    if (readout) {
        NSDictionary *attrs = @{NSFontAttributeName: [NSFont systemFontOfSize:11.0], NSForegroundColorAttributeName: ink};
        NSSize size = [readout sizeWithAttributes:attrs];
        [readout drawAtPoint:NSMakePoint(NSMaxX(plot) - size.width, NSMaxY(plot) + 7.0) withAttributes:attrs];
    }
}

#pragma mark - Following the mouse

- (void)highlightAtPoint:(NSPoint)p
{
    NSRect plot = [self plotRect];
    NSUInteger n = [_values count];
    if (n == 0 || !NSPointInRect(p, NSInsetRect([self bounds], 0.0, 0.0)) || p.x < NSMinX(plot) || p.x > NSMaxX(plot)) {
        self.highlightedIndex = NSNotFound;
        return;
    }
    NSInteger i = (NSInteger)floor((p.x - NSMinX(plot)) / (NSWidth(plot) / (CGFloat)n));
    self.highlightedIndex = (NSUInteger)MAX(0, MIN((NSInteger)n - 1, i));
}

#if defined(GNUSTEP)
/* gnustep-gui has no -addTrackingArea:; a tracking rect for entered/exited,
 * and mouse-moved events switched on for the window while inside */
- (void)resetTracking
{
    if (_tracking) [self removeTrackingRect:_trackingTag];
    _tracking = NO;
    if ([self window]) {
        _trackingTag = [self addTrackingRect:[self bounds] owner:self userData:NULL assumeInside:NO];
        _tracking = YES;
    }
}

- (void)viewDidMoveToWindow { [super viewDidMoveToWindow]; [self resetTracking]; }
- (void)setFrame:(NSRect)frame { [super setFrame:frame]; [self resetTracking]; }
- (void)mouseEntered:(NSEvent *)event { [[self window] setAcceptsMouseMovedEvents:YES]; }
#else
- (void)updateTrackingAreas
{
    [super updateTrackingAreas];
    if (_trackingArea) [self removeTrackingArea:_trackingArea];
    _trackingArea = [[NSTrackingArea alloc] initWithRect:NSZeroRect
                                                 options:(NSTrackingMouseEnteredAndExited | NSTrackingMouseMoved
                                                          | NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect)
                                                   owner:self userInfo:nil];
    [self addTrackingArea:_trackingArea];
}

- (void)mouseEntered:(NSEvent *)event { }
#endif

- (void)mouseMoved:(NSEvent *)event
{
    [self highlightAtPoint:[self convertPoint:[event locationInWindow] fromView:nil]];
}

- (void)mouseExited:(NSEvent *)event
{
    self.highlightedIndex = NSNotFound;
}

@end
