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

@class HRTheme;

typedef NS_ENUM(NSInteger, HRPlotStyle) {
    HRPlotStyleTrend = 0,   /* a dot per value, and `trend` as a line through them */
    HRPlotStyleBars         /* a bar per value, from zero */
};

/* One measure against one axis -- the Statistics window stacks several of
 * these rather than putting two scales on one chart.  Values are evenly
 * spaced along x (test after test, day after day); `labels` says what each
 * position is, for the two ends of the axis and for the read-out that
 * follows the mouse. */
@interface HRPlotView : NSView

@property (nonatomic, strong) HRTheme *theme;
@property (nonatomic) HRPlotStyle style;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *unit;        /* after a value: @"wpm", @"%", @"min" */
@property (nonatomic, copy) NSArray *values;       /* NSNumber */
@property (nonatomic, copy) NSArray *trend;        /* NSNumber, same count as values, or nil */
@property (nonatomic, copy) NSString *trendName;   /* for the read-out: @"avg of 10" */
@property (nonatomic, copy) NSArray *labels;       /* NSString, same count as values */
@property (nonatomic) double ceiling;              /* the axis never goes above this; 0 = no limit */
@property (nonatomic, copy) NSString *emptyText;

/* For tests: the axis range chosen for the current values. */
- (void)getAxisMinimum:(double *)minimum maximum:(double *)maximum;
/* The position the read-out shows, or NSNotFound; settable for tests. */
@property (nonatomic) NSUInteger highlightedIndex;
- (NSString *)readout;

@end
