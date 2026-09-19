/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * HomeRow is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version.  It comes with ABSOLUTELY NO WARRANTY.  See COPYING.
 */
#import "HRStatsWindowController.h"
#import "HRResultStore.h"
#import "HRStatistics.h"
#import "HRPlotView.h"
#import "HRStatTilesView.h"
#import "HRKeyboardView.h"
#import "HRKeyboardLayout.h"
#import "HRTheme.h"

#define HRLoc(key) NSLocalizedString(key, nil)

static NSString * const HRStatsKindDefaultsKey = @"HRStatsKind";
static NSString * const HRStatsDaysDefaultsKey = @"HRStatsDays";
static const NSUInteger HRStatsTrendWindow = 10;
static const NSUInteger HRStatsMinimumPresses = 10;

@implementation HRStatsWindowController
{
    HRResultStore *_store;
    HRTheme *_theme;
}

- (instancetype)initWithStore:(HRResultStore *)store theme:(HRTheme *)theme
{
    if ((self = [super initWithWindowNibName:@"StatsWindow"])) {
        _store = store;
        _theme = theme;
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    [[self window] setBackgroundColor:_theme.background];
    [[self window] setDelegate:(id)self];

    [_kindPopUp removeAllItems];
    NSArray *kinds = @[@[HRLoc(@"Everything"), @(HRStatKindAll)], @[HRLoc(@"Tests"), @(HRStatKindTests)],
                       @[HRLoc(@"Courses"), @(HRStatKindCourse)], @[HRLoc(@"Code"), @(HRStatKindCode)]];
    for (NSArray *k in kinds) {
        [_kindPopUp addItemWithTitle:k[0]];
        [[_kindPopUp lastItem] setTag:[k[1] integerValue]];
    }
    [_periodPopUp removeAllItems];
    NSArray *periods = @[@[HRLoc(@"Last 7 days"), @7], @[HRLoc(@"Last 30 days"), @30],
                         @[HRLoc(@"Last 90 days"), @90], @[HRLoc(@"All time"), @0]];
    for (NSArray *p in periods) {
        [_periodPopUp addItemWithTitle:p[0]];
        [[_periodPopUp lastItem] setTag:[p[1] integerValue]];
    }
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [_kindPopUp selectItemWithTag:[d integerForKey:HRStatsKindDefaultsKey]];
    [_periodPopUp selectItemWithTag:([d objectForKey:HRStatsDaysDefaultsKey] ? [d integerForKey:HRStatsDaysDefaultsKey] : 30)];
    if (![_kindPopUp selectedItem]) [_kindPopUp selectItemAtIndex:0];
    if (![_periodPopUp selectedItem]) [_periodPopUp selectItemAtIndex:1];

    _tilesView.theme = _theme;
    for (HRPlotView *plot in [self plots]) plot.theme = _theme;
    _keyboardView.theme = _theme;
    _keyboardView.heatMinimumPresses = HRStatsMinimumPresses;
    [_keysField setTextColor:_theme.untyped];

    _speedPlot.title = HRLoc(@"Speed, test after test");
    _speedPlot.unit = HRLoc(@"wpm");
    _accuracyPlot.title = HRLoc(@"Accuracy, test after test");
    _accuracyPlot.unit = @"%";
    _accuracyPlot.ceiling = 100.0;
    _daysPlot.title = HRLoc(@"Practice, day by day");
    _daysPlot.unit = HRLoc(@"min");
    _daysPlot.style = HRPlotStyleBars;
    for (HRPlotView *plot in @[_speedPlot ?: (id)[NSNull null], _accuracyPlot ?: (id)[NSNull null]]) {
        if ((id)plot == [NSNull null]) continue;
        plot.trendName = [NSString stringWithFormat:HRLoc(@"average of %lu"), (unsigned long)HRStatsTrendWindow];
    }
    [self layoutViews];
    [self reload];
}

- (NSArray *)plots
{
    NSMutableArray *plots = [NSMutableArray array];
    if (_speedPlot) [plots addObject:_speedPlot];
    if (_accuracyPlot) [plots addObject:_accuracyPlot];
    if (_daysPlot) [plots addObject:_daysPlot];
    return plots;
}

- (void)setKeyboardLayout:(HRKeyboardLayout *)layout
{
    _keyboardLayout = layout;
    if ([self isWindowLoaded]) {
        _keyboardView.keyboardLayout = layout;
        [self reload];
    }
}

#pragma mark - Layout

/* Top to bottom: the two pop-ups, the tiles, three charts sharing what is
 * left, the keyboard at the height its width asks for, the list of keys. */
- (void)layoutViews
{
    NSRect c = [[[self window] contentView] bounds];
    CGFloat margin = 20.0, W = MAX(200.0, NSWidth(c) - 2 * margin);
    CGFloat top = NSMaxY(c) - 14.0;

    [_kindPopUp setFrame:NSMakeRect(margin - 3.0, top - 26.0, 170.0, 26.0)];
    [_periodPopUp setFrame:NSMakeRect(margin + 175.0, top - 26.0, 170.0, 26.0)];
    top -= 26.0 + 10.0;
    [_tilesView setFrame:NSMakeRect(margin, top - 56.0, W, 56.0)];
    top -= 56.0 + 8.0;

    CGFloat keysHeight = 18.0;
    CGFloat boardWidth = MIN(W, 720.0);
    CGFloat boardHeight = [HRKeyboardView heightForWidth:boardWidth];
    CGFloat bottom = 12.0;
    CGFloat buttonWidth = _practiceButton ? 190.0 : 0.0;
    [_keysField setFrame:NSMakeRect(margin, bottom, W - buttonWidth, keysHeight)];
    [_practiceButton setFrame:NSMakeRect(margin + W - buttonWidth + 6.0, bottom - 7.0, buttonWidth - 6.0, 32.0)];
    bottom += keysHeight + 6.0;
    [_keyboardView setFrame:NSMakeRect(margin + floor((W - boardWidth) / 2.0), bottom, boardWidth, boardHeight)];
    bottom += boardHeight + 8.0;

    NSArray *plots = [self plots];
    CGFloat each = [plots count] > 0 ? floor(MAX(60.0, top - bottom) / (CGFloat)[plots count]) : 0.0;
    for (HRPlotView *plot in plots) {
        [plot setFrame:NSMakeRect(margin, top - each, W, each - 6.0)];
        top -= each;
    }
    [[[self window] contentView] setNeedsDisplay:YES];
}

- (void)windowDidResize:(NSNotification *)notification
{
    [self layoutViews];
}

#pragma mark - Data

- (IBAction)filterChanged:(id)sender
{
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d setInteger:[[_kindPopUp selectedItem] tag] forKey:HRStatsKindDefaultsKey];
    [d setInteger:[[_periodPopUp selectedItem] tag] forKey:HRStatsDaysDefaultsKey];
    [self reload];
}

- (IBAction)practise:(id)sender
{
    if (_practiceTarget && _practiceAction) [NSApp sendAction:_practiceAction to:_practiceTarget from:self];
}

- (NSString *)nameOfCharacter:(NSString *)ch
{
    if ([ch isEqualToString:@" "]) return HRLoc(@"space");
    if ([ch isEqualToString:@"\n"]) return HRLoc(@"return");
    return ch;
}

- (void)reload
{
    if (![self isWindowLoaded]) return;
    HRStatKind kind = (HRStatKind)[[_kindPopUp selectedItem] tag];
    NSUInteger days = (NSUInteger)MAX(0, [[_periodPopUp selectedItem] tag]);
    NSDate *now = [NSDate date];
    NSTimeZone *zone = [NSTimeZone localTimeZone];
    HRStatistics *st = [[HRStatistics alloc] initWithSamples:([_store statSamples] ?: @[])
                                                        kind:kind days:days now:now timeZone:zone];

    NSString *dash = @"–";
    BOOL any = st.count > 0;
    _tilesView.tiles = @[
        @[[NSString stringWithFormat:@"%lu", (unsigned long)st.count], HRLoc(@"tests and exercises")],
        @[any ? [HRStatistics stringForDuration:st.totalDuration] : dash, HRLoc(@"time typing")],
        @[any ? [NSString stringWithFormat:@"%.0f", st.averageWpm] : dash, HRLoc(@"average wpm")],
        @[any ? [NSString stringWithFormat:@"%.0f", st.recentWpm] : dash, HRLoc(@"wpm, last ten")],
        @[any ? [NSString stringWithFormat:@"%.0f", st.bestWpm] : dash, HRLoc(@"best wpm")],
        @[any ? [NSString stringWithFormat:@"%.1f%%", st.averageAccuracy] : dash, HRLoc(@"accuracy")]];

    NSMutableArray *wpm = [NSMutableArray array], *accuracy = [NSMutableArray array], *labels = [NSMutableArray array];
    for (HRStatSample *s in st.samples) {
        [wpm addObject:@(s.wpm)];
        [accuracy addObject:@(s.accuracy)];
        [labels addObject:[HRStatistics shortStringForDate:s.date timeZone:zone]];
    }
    NSString *nothing = _store ? HRLoc(@"Nothing typed in this period yet.") : HRLoc(@"Results are not being saved, so there is nothing to show.");
    _speedPlot.emptyText = nothing;
    _speedPlot.labels = labels;
    _speedPlot.trend = [st movingAverageOfKey:@"wpm" window:HRStatsTrendWindow];
    _speedPlot.values = wpm;
    _accuracyPlot.emptyText = nothing;
    _accuracyPlot.labels = labels;
    _accuracyPlot.trend = [st movingAverageOfKey:@"accuracy" window:HRStatsTrendWindow];
    _accuracyPlot.values = accuracy;

    NSMutableArray *minutes = [NSMutableArray array], *dayLabels = [NSMutableArray array];
    for (HRStatDay *day in [st days]) {
        [minutes addObject:@(day.duration / 60.0)];
        [dayLabels addObject:[HRStatistics shortStringForDate:[day.day dateByAddingTimeInterval:43200.0] timeZone:zone]];
    }
    _daysPlot.emptyText = nothing;
    _daysPlot.labels = dayLabels;
    _daysPlot.values = minutes;

    NSDate *since = days > 0 ? [now dateByAddingTimeInterval:-(NSTimeInterval)days * 86400.0] : nil;
    NSDictionary *counts = [_store keyCountsForKind:kind since:since] ?: @{};
    _keyboardView.keyboardLayout = _keyboardLayout;
    _keyboardView.heatCounts = counts;

    NSMutableArray *worst = [NSMutableArray array];
    for (HRStatKey *k in [HRStatistics keysFromCounts:counts minimumPresses:HRStatsMinimumPresses]) {
        if (k.misses == 0 || [worst count] >= 8) break;
        [worst addObject:[NSString stringWithFormat:@"%@ %.0f%%", [self nameOfCharacter:k.character], [k errorRate] * 100.0]];
    }
    [_practiceButton setEnabled:[worst count] > 0 && _practiceTarget != nil];
    if ([worst count] > 0) {
        [_keysField setStringValue:[NSString stringWithFormat:HRLoc(@"Missed most often:   %@      (the deepest tint is %.0f%% of presses)"),
                                    [worst componentsJoinedByString:@"    "], [_keyboardView heatMaximumRate] * 100.0]];
    } else {
        [_keysField setStringValue:([counts count] > 0 ? HRLoc(@"No key stands out yet.") : @"")];
    }
}

@end
