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
#import "HRResultExchange.h"
#import "HRStatistics.h"
#import "HRPlotView.h"
#import "HRChartView.h"
#import "HRStatTilesView.h"
#import "HRKeyboardView.h"
#import "HRKeyboardLayout.h"
#import "HRTheme.h"

#define HRLoc(key) NSLocalizedString(key, nil)

static NSString * const HRStatsKindDefaultsKey = @"HRStatsKind";
static NSString * const HRStatsDaysDefaultsKey = @"HRStatsDays";
static NSString * const HRStatsPaneDefaultsKey = @"HRStatsPane";
static NSString * const HRStatsHeatDefaultsKey = @"HRStatsHeatShowsSpeed";
static NSString * const HRStatsSubjectDefaultsKey = @"HRStatsSubject";
static const NSUInteger HRStatsTrendWindow = 10;
static const NSUInteger HRStatsMinimumPresses = 10;

@implementation HRStatsWindowController
{
    HRResultStore *_store;
    HRTheme *_theme;
    NSArray *_history;          /* HRTestResult, newest first, as filtered */
    NSSet *_bestIDs;            /* objectIDs of the personal bests */
    NSArray *_subjects;
    NSTimeZone *_zone;
}

- (instancetype)initWithStore:(HRResultStore *)store theme:(HRTheme *)theme
{
    if ((self = [super initWithWindowNibName:@"StatsWindow"])) {
        _store = store;
        _theme = theme;
        _history = @[];
        _subjects = @[];
    }
    return self;
}

- (void)fill:(NSPopUpButton *)popUp with:(NSArray *)pairs
{
    [popUp removeAllItems];
    for (NSArray *pair in pairs) {
        [popUp addItemWithTitle:pair[0]];
        [[popUp lastItem] setTag:[pair[1] integerValue]];
    }
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    [[self window] setBackgroundColor:_theme.background];
    [[self window] setDelegate:(id)self];

    [self fill:_kindPopUp with:@[@[HRLoc(@"Everything"), @(HRStatKindAll)], @[HRLoc(@"Tests"), @(HRStatKindTests)],
                                 @[HRLoc(@"Courses"), @(HRStatKindCourse)], @[HRLoc(@"Code"), @(HRStatKindCode)]]];
    [self fill:_periodPopUp with:@[@[HRLoc(@"Last 7 days"), @7], @[HRLoc(@"Last 30 days"), @30],
                                   @[HRLoc(@"Last 90 days"), @90], @[HRLoc(@"All time"), @0]]];
    [self fill:_heatPopUp with:@[@[HRLoc(@"Keys by mistakes"), @0], @[HRLoc(@"Keys by speed"), @1],
                                 @[HRLoc(@"Kinds of key"), @2]]];
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [_kindPopUp selectItemWithTag:[d integerForKey:HRStatsKindDefaultsKey]];
    [_periodPopUp selectItemWithTag:([d objectForKey:HRStatsDaysDefaultsKey] ? [d integerForKey:HRStatsDaysDefaultsKey] : 30)];
    [_heatPopUp selectItemWithTag:[d integerForKey:HRStatsHeatDefaultsKey]];
    if (![_heatPopUp selectedItem]) [_heatPopUp selectItemAtIndex:0];
    if (![_kindPopUp selectedItem]) [_kindPopUp selectItemAtIndex:0];
    if (![_periodPopUp selectedItem]) [_periodPopUp selectItemAtIndex:1];
    _pane = (HRStatsPane)MAX(0, MIN(2, [d integerForKey:HRStatsPaneDefaultsKey]));
    /* the panes are drawn in the theme's colours: let the window's background through */
    [_tabView setDrawsBackground:NO];
    if (_pane < [_tabView numberOfTabViewItems]) [_tabView selectTabViewItemAtIndex:_pane];

    _tilesView.theme = _theme;
    for (HRPlotView *plot in [self allPlots]) plot.theme = _theme;
    _resultChart.theme = _theme;
    _keyboardView.theme = _theme;
    _keyboardView.heatMinimumPresses = HRStatsMinimumPresses;
    [_keysField setTextColor:_theme.untyped];
    [_resultField setTextColor:_theme.untyped];
    [_progressField setTextColor:_theme.untyped];

    _speedPlot.title = HRLoc(@"Speed, test after test");
    _speedPlot.unit = HRLoc(@"wpm");
    _accuracyPlot.title = HRLoc(@"Accuracy, test after test");
    _accuracyPlot.unit = @"%";
    _accuracyPlot.ceiling = 100.0;
    _daysPlot.title = HRLoc(@"Practice, day by day");
    _daysPlot.unit = HRLoc(@"min");
    _daysPlot.style = HRPlotStyleBars;
    NSString *trendName = [NSString stringWithFormat:HRLoc(@"average of %lu"), (unsigned long)HRStatsTrendWindow];
    _speedPlot.trendName = trendName;
    _accuracyPlot.trendName = trendName;
    _lessonSpeedPlot.title = HRLoc(@"Best speed, lesson by lesson");
    _lessonSpeedPlot.unit = HRLoc(@"wpm");
    _lessonSpeedPlot.style = HRPlotStyleBars;
    /* mistakes, not accuracy: bars start at zero, and from zero 96% and 99%
     * look the same, while 4% and 1% do not */
    _lessonAccuracyPlot.title = HRLoc(@"Mistakes in the best run, lesson by lesson");
    _lessonAccuracyPlot.unit = @"%";
    _lessonAccuracyPlot.style = HRPlotStyleBars;

    [_historyTable setTarget:self];
    [self layoutViews];
    [self reload];
}

- (NSArray *)allPlots
{
    NSMutableArray *plots = [NSMutableArray array];
    for (id plot in @[_speedPlot ?: (id)[NSNull null], _accuracyPlot ?: (id)[NSNull null], _daysPlot ?: (id)[NSNull null],
                      _lessonSpeedPlot ?: (id)[NSNull null], _lessonAccuracyPlot ?: (id)[NSNull null]]) {
        if (plot != [NSNull null]) [plots addObject:plot];
    }
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

- (void)setPane:(HRStatsPane)pane
{
    _pane = pane;
    if (![self isWindowLoaded]) return;
    if (pane < [_tabView numberOfTabViewItems] && [_tabView indexOfTabViewItem:[_tabView selectedTabViewItem]] != pane) {
        [_tabView selectTabViewItemAtIndex:pane];   /* comes back through the delegate method below */
        return;
    }
    [[NSUserDefaults standardUserDefaults] setInteger:pane forKey:HRStatsPaneDefaultsKey];
    [self layoutViews];
    [self reload];
}

#pragma mark - Layout

- (void)layoutViews
{
    /* above the tabs, to the right: the two filters, where they apply */
    NSRect window = [[[self window] contentView] bounds];
    BOOL filtered = (_pane != HRStatsPaneProgress);
    [_kindPopUp setHidden:!filtered];
    [_periodPopUp setHidden:!filtered];
    [_kindPopUp setFrame:NSMakeRect(NSMaxX(window) - 20.0 - 336.0, NSMaxY(window) - 40.0, 165.0, 26.0)];
    [_periodPopUp setFrame:NSMakeRect(NSMaxX(window) - 20.0 - 165.0, NSMaxY(window) - 40.0, 165.0, 26.0)];
    [_tabView setFrame:NSMakeRect(13.0, 10.0, MAX(200.0, NSWidth(window) - 26.0), MAX(200.0, NSHeight(window) - 58.0))];

    /* inside the selected pane */
    NSRect c = [[[_tabView selectedTabViewItem] view] bounds];
    if (NSIsEmptyRect(c)) return;
    CGFloat margin = 10.0, W = MAX(200.0, NSWidth(c) - 2 * margin);
    CGFloat top = NSMaxY(c) - 10.0;

    if (_pane == HRStatsPaneOverview) {
        [_tilesView setFrame:NSMakeRect(margin, top - 56.0, W, 56.0)];
        top -= 56.0 + 8.0;
        CGFloat bottom = 12.0;
        CGFloat buttonWidth = _practiceButton ? 190.0 : 0.0;
        [_keysField setFrame:NSMakeRect(margin, bottom, W - buttonWidth, 18.0)];
        [_practiceButton setFrame:NSMakeRect(margin + W - buttonWidth + 6.0, bottom - 7.0, buttonWidth - 6.0, 32.0)];
        bottom += 18.0 + 8.0;
        CGFloat boardWidth = MIN(W, 720.0);
        CGFloat boardHeight = [HRKeyboardView heightForWidth:boardWidth];
        [_keyboardView setFrame:NSMakeRect(margin + floor((W - boardWidth) / 2.0), bottom, boardWidth, boardHeight)];
        bottom += boardHeight + 4.0;
        [_heatPopUp setFrame:NSMakeRect(margin + floor((W - boardWidth) / 2.0) - 3.0, bottom, 220.0, 26.0)];
        bottom += 26.0 + 6.0;
        NSArray *plots = @[_speedPlot ?: (id)[NSNull null], _accuracyPlot ?: (id)[NSNull null], _daysPlot ?: (id)[NSNull null]];
        CGFloat each = floor(MAX(60.0, top - bottom) / 3.0);
        for (id plot in plots) {
            if (plot != [NSNull null]) [(NSView *)plot setFrame:NSMakeRect(margin, top - each, W, each - 6.0)];
            top -= each;
        }
    } else if (_pane == HRStatsPaneHistory) {
        CGFloat bottom = 5.0;
        [_deleteButton setFrame:NSMakeRect(margin - 6.0, bottom, 150.0, 32.0)];
        [_importButton setFrame:NSMakeRect(margin + W - 114.0, bottom, 120.0, 32.0)];
        [_exportButton setFrame:NSMakeRect(margin + W - 234.0, bottom, 120.0, 32.0)];
        bottom += 32.0 + 8.0;
        [_resultField setFrame:NSMakeRect(margin, bottom, W, 18.0)];
        bottom += 18.0 + 6.0;
        CGFloat chart = MAX(90.0, floor((top - bottom) * 0.30));
        [_resultChart setFrame:NSMakeRect(margin, bottom, W, chart)];
        bottom += chart + 10.0;
        [_historyScroll setFrame:NSMakeRect(margin, bottom, W, MAX(80.0, top - bottom))];
    } else {
        [_subjectPopUp setFrame:NSMakeRect(margin - 3.0, top - 26.0, MIN(420.0, W * 0.55), 26.0)];
        CGFloat fieldX = margin + MIN(420.0, W * 0.55) + 8.0;
        [_progressField setFrame:NSMakeRect(fieldX, top - 22.0, MAX(40.0, margin + W - fieldX), 18.0)];
        top -= 26.0 + 10.0;
        CGFloat each = floor(MAX(120.0, top - 14.0) / 2.0);
        [_lessonSpeedPlot setFrame:NSMakeRect(margin, top - each, W, each - 8.0)];
        [_lessonAccuracyPlot setFrame:NSMakeRect(margin, top - 2 * each, W, each - 8.0)];
    }
    [[[self window] contentView] setNeedsDisplay:YES];
}

- (void)windowDidResize:(NSNotification *)notification
{
    [self layoutViews];
}

#pragma mark - Actions

- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)item
{
    NSInteger index = [tabView indexOfTabViewItem:item];
    if (index >= 0 && index <= HRStatsPaneProgress) self.pane = (HRStatsPane)index;
}

- (IBAction)filterChanged:(id)sender
{
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d setInteger:[[_kindPopUp selectedItem] tag] forKey:HRStatsKindDefaultsKey];
    [d setInteger:[[_periodPopUp selectedItem] tag] forKey:HRStatsDaysDefaultsKey];
    [self reload];
}

- (IBAction)heatChanged:(id)sender
{
    [[NSUserDefaults standardUserDefaults] setInteger:[[_heatPopUp selectedItem] tag] forKey:HRStatsHeatDefaultsKey];
    [self reload];
}

- (IBAction)subjectChanged:(id)sender
{
    NSString *identifier = [[_subjectPopUp selectedItem] representedObject];
    if (identifier) [[NSUserDefaults standardUserDefaults] setObject:identifier forKey:HRStatsSubjectDefaultsKey];
    [self reloadProgress];
}

- (IBAction)practise:(id)sender
{
    if (_practiceTarget && _practiceAction) [NSApp sendAction:_practiceAction to:_practiceTarget from:self];
}

#pragma mark - Data

- (NSString *)nameOfCharacter:(NSString *)ch
{
    if ([ch isEqualToString:@" "]) return HRLoc(@"space");
    if ([ch isEqualToString:@"\n"]) return HRLoc(@"return");
    return ch;
}

- (HRStatKind)kind { return (HRStatKind)[[_kindPopUp selectedItem] tag]; }
- (NSUInteger)days { return (NSUInteger)MAX(0, [[_periodPopUp selectedItem] tag]); }

- (void)reload
{
    if (![self isWindowLoaded]) return;
    _zone = [NSTimeZone localTimeZone];
    switch (_pane) {
        case HRStatsPaneOverview: [self reloadOverview]; break;
        case HRStatsPaneHistory:  [self reloadHistory]; break;
        case HRStatsPaneProgress: [self reloadProgress]; break;
    }
}

- (void)reloadOverview
{
    NSDate *now = [NSDate date];
    HRStatistics *st = [[HRStatistics alloc] initWithSamples:([_store statSamples] ?: @[])
                                                        kind:[self kind] days:[self days] now:now timeZone:_zone];
    NSString *dash = @"–";
    BOOL any = st.count > 0;
    _tilesView.tiles = @[
        @[[NSString stringWithFormat:@"%lu", (unsigned long)st.count], HRLoc(@"tests and exercises")],
        @[any ? [HRStatistics stringForDuration:st.totalDuration] : dash, HRLoc(@"time typing")],
        @[any ? [NSString stringWithFormat:@"%.0f", st.averageWpm] : dash, HRLoc(@"average wpm")],
        @[any ? [NSString stringWithFormat:@"%.0f", st.recentWpm] : dash, HRLoc(@"wpm, last ten")],
        @[any ? [NSString stringWithFormat:@"%.0f", st.bestWpm] : dash, HRLoc(@"best wpm")],
        @[any ? [NSString stringWithFormat:@"%.1f%%", st.averageAccuracy] : dash, HRLoc(@"accuracy")],
        /* what the mistakes cost: keystrokes that did not end up as text */
        @[st.averageOverhead >= 0.0 ? [NSString stringWithFormat:@"%.0f%%", st.averageOverhead * 100.0] : dash, HRLoc(@"keystroke overhead")]];

    NSMutableArray *wpm = [NSMutableArray array], *accuracy = [NSMutableArray array], *labels = [NSMutableArray array];
    for (HRStatSample *s in st.samples) {
        [wpm addObject:@(s.wpm)];
        [accuracy addObject:@(s.accuracy)];
        [labels addObject:[HRStatistics shortStringForDate:s.date timeZone:_zone]];
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
        [dayLabels addObject:[HRStatistics shortStringForDate:[day.day dateByAddingTimeInterval:43200.0] timeZone:_zone]];
    }
    _daysPlot.emptyText = nothing;
    _daysPlot.labels = dayLabels;
    _daysPlot.values = minutes;

    NSUInteger days = [self days];
    NSDate *since = days > 0 ? [now dateByAddingTimeInterval:-(NSTimeInterval)days * 86400.0] : nil;
    NSDictionary *counts = [_store keyCountsForKind:[self kind] since:since] ?: @{};
    BOOL speed = [[_heatPopUp selectedItem] tag] == 1;
    _keyboardView.keyboardLayout = _keyboardLayout;
    _keyboardView.heatShowsSpeed = speed;
    _keyboardView.heatCounts = counts;

    NSMutableArray *worst = [NSMutableArray array];
    if (speed) {
        for (HRStatKey *k in [HRStatistics slowKeysFromCounts:counts minimumTimed:HRStatsMinimumPresses]) {
            if ([worst count] >= 8) break;
            [worst addObject:[NSString stringWithFormat:@"%@ %.0f ms", [self nameOfCharacter:k.character], [k averageTime] * 1000.0]];
        }
    } else {
        for (HRStatKey *k in [HRStatistics keysFromCounts:counts minimumPresses:HRStatsMinimumPresses]) {
            if (k.misses == 0 || [worst count] >= 8) break;
            [worst addObject:[NSString stringWithFormat:@"%@ %.0f%%", [self nameOfCharacter:k.character], [k errorRate] * 100.0]];
        }
    }
    [_practiceButton setEnabled:[counts count] > 0 && _practiceTarget != nil];
    if ([[_heatPopUp selectedItem] tag] == 2) {
        /* letters, digits, brackets, operators...: what code is made of.  The board stays on mistakes. */
        NSDictionary *names = @{HRKeyClassLetters: HRLoc(@"letters"), HRKeyClassCapitals: HRLoc(@"capitals"), HRKeyClassDigits: HRLoc(@"digits"),
                                HRKeyClassBrackets: HRLoc(@"brackets"), HRKeyClassOperators: HRLoc(@"operators"),
                                HRKeyClassPunctuation: HRLoc(@"punctuation"), HRKeyClassWhitespace: HRLoc(@"space, return, tab")};
        [_keysField setStringValue:[HRStatistics lineForKeyClasses:[HRStatistics keyClassesFromCounts:counts] names:names]];
        return;
    }
    NSString *list = [worst componentsJoinedByString:@"    "];
    if ([worst count] == 0) {
        [_keysField setStringValue:([counts count] == 0 ? @""
            : speed ? HRLoc(@"No key has been timed often enough yet — results from before this version carry no times.")
                    : HRLoc(@"No key stands out yet."))];
    } else if (speed) {
        [_keysField setStringValue:[NSString stringWithFormat:HRLoc(@"Slowest:   %@      (average %.0f ms; plain is the fastest key, %.0f ms)"),
                                    list, [HRStatistics averageKeyTimeInCounts:counts] * 1000.0, [_keyboardView heatMinimumRate] * 1000.0]];
    } else {
        [_keysField setStringValue:[NSString stringWithFormat:HRLoc(@"Missed most often:   %@      (the deepest tint is %.0f%% of presses)"),
                                    list, [_keyboardView heatMaximumRate] * 100.0]];
    }
}

#pragma mark - History

- (HRStatKind)kindOfMode:(NSString *)mode
{
    if ([mode isEqualToString:@"lesson"]) return HRStatKindCourse;
    if ([mode isEqualToString:@"code"]) return HRStatKindCode;
    return HRStatKindTests;
}

- (void)reloadHistory
{
    HRTestResult *selected = [self selectedResult];
    NSUInteger days = [self days];
    NSDate *since = days > 0 ? [NSDate dateWithTimeIntervalSinceNow:-(NSTimeInterval)days * 86400.0] : nil;
    HRStatKind kind = [self kind];
    NSMutableArray *rows = [NSMutableArray array];
    for (HRTestResult *r in [_store recentResultsWithLimit:0 error:NULL] ?: @[]) {
        if (since && r.date && [r.date compare:since] == NSOrderedAscending) continue;
        if (kind != HRStatKindAll && [self kindOfMode:r.mode] != kind) continue;
        [rows addObject:r];
    }
    _history = rows;
    NSMutableSet *best = [NSMutableSet set];
    for (HRTestResult *b in [_store personalBests]) [best addObject:[b objectID]];
    _bestIDs = best;
    [_historyTable reloadData];
    NSUInteger row = selected ? [_history indexOfObject:selected] : NSNotFound;
    if (row == NSNotFound && [_history count] > 0) row = 0;
    if (row != NSNotFound) {
        [_historyTable selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
    } else {
        [_historyTable deselectAll:self];
    }
    [_exportButton setEnabled:_store != nil];
    [_importButton setEnabled:_store != nil];
    [self showSelectedResult];
}

- (HRTestResult *)selectedResult
{
    NSInteger row = [_historyTable selectedRow];
    return (row >= 0 && row < (NSInteger)[_history count]) ? _history[(NSUInteger)row] : nil;
}

- (NSArray *)selectedResults
{
    NSMutableArray *results = [NSMutableArray array];
    NSIndexSet *rows = [_historyTable selectedRowIndexes];
    for (NSUInteger row = [rows firstIndex]; row != NSNotFound; row = [rows indexGreaterThanIndex:row]) {
        if (row < [_history count]) [results addObject:_history[row]];
    }
    return results;
}

- (NSString *)kindNameOfResult:(HRTestResult *)r
{
    NSDictionary *names = @{@"time": HRLoc(@"time"), @"words": HRLoc(@"words"), @"zen": HRLoc(@"zen"), @"custom": HRLoc(@"custom"),
                            @"lesson": HRLoc(@"course"), @"code": HRLoc(@"code"), @"practice": HRLoc(@"weak keys")};
    return names[r.mode ?: @""] ?: (r.mode ?: @"");
}

- (NSString *)subjectOfResult:(HRTestResult *)r
{
    if ([r.courseFile length] > 0) {
        NSString *title = [_subjectSource statistics:self titleForCourseFile:r.courseFile] ?: r.courseFile;
        NSString *unit = [r.mode isEqualToString:@"code"] ? HRLoc(@"part") : HRLoc(@"lesson");
        return [NSString stringWithFormat:@"%@ — %@ %ld", title, unit, (long)[r.lessonIndex integerValue] + 1];
    }
    NSMutableArray *parts = [NSMutableArray array];
    if ([r.mode isEqualToString:@"time"]) [parts addObject:[NSString stringWithFormat:HRLoc(@"%ld s"), (long)[r.amount integerValue]]];
    if ([r.mode isEqualToString:@"words"]) [parts addObject:[NSString stringWithFormat:HRLoc(@"%ld words"), (long)[r.amount integerValue]]];
    if ([r.languageID length] > 0) [parts addObject:[r.languageID stringByReplacingOccurrencesOfString:@"_" withString:@" "]];
    NSArray *flags = [r.settingsKey componentsSeparatedByString:@":"];
    if ([flags containsObject:@"p"]) [parts addObject:HRLoc(@"punctuation")];
    if ([flags containsObject:@"n"]) [parts addObject:HRLoc(@"numbers")];
    return [parts componentsJoinedByString:@", "];
}

- (NSString *)dateStringOfResult:(HRTestResult *)r
{
    if (!r.date) return @"";
    NSTimeZone *zone = _zone ?: [NSTimeZone localTimeZone];
    long seconds = (long)floor([r.date timeIntervalSince1970]) + (long)[zone secondsFromGMTForDate:r.date];
    long ofDay = ((seconds % 86400) + 86400) % 86400;
    return [NSString stringWithFormat:@"%@  %02ld:%02ld", [HRStatistics mediumStringForDate:r.date timeZone:zone],
            ofDay / 3600, (ofDay % 3600) / 60];
}

- (void)showSelectedResult
{
    HRTestResult *r = [self selectedResult];
    NSUInteger selected = [[_historyTable selectedRowIndexes] count];
    [_deleteButton setEnabled:selected > 0];
    if (selected > 1) {
        /* several: say what they add up to, which is what one wants to know before deleting them */
        NSTimeInterval time = 0.0;
        for (HRTestResult *each in [self selectedResults]) time += [each.duration doubleValue];
        _resultChart.samples = @[];
        _resultChart.errors = @[];
        [_resultField setStringValue:[NSString stringWithFormat:HRLoc(@"%lu results selected   \u2014   %@ of typing"),
                                      (unsigned long)selected, [HRStatistics stringForDuration:time]]];
        return;
    }
    if (!r) {
        _resultChart.samples = @[];
        _resultChart.errors = @[];
        [_resultField setStringValue:([_history count] == 0 ? HRLoc(@"Nothing typed in this period yet.") : @"")];
        return;
    }
    NSDictionary *series = [r seriesDictionary];
    _resultChart.errors = series[@"errors"] ?: @[];
    _resultChart.average = [r.rawWpm doubleValue];
    _resultChart.samples = series[@"raw"] ?: @[];
    [_resultField setStringValue:[NSString stringWithFormat:
        HRLoc(@"%@   —   %@   —   characters %ld/%ld/%ld/%ld%@"),
        [self dateStringOfResult:r], [self subjectOfResult:r],
        (long)[r.correctCharacters integerValue], (long)[r.incorrectCharacters integerValue],
        (long)[r.extraCharacters integerValue], (long)[r.missedCharacters integerValue],
        ([_bestIDs containsObject:[r objectID]] ? HRLoc(@"   —   personal best for this setting") : @"")]];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return (NSInteger)[_history count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)column row:(NSInteger)row
{
    HRTestResult *r = _history[(NSUInteger)row];
    NSString *key = [column identifier];
    if ([key isEqualToString:@"best"])        return [_bestIDs containsObject:[r objectID]] ? @"★" : @"";
    if ([key isEqualToString:@"date"])        return [self dateStringOfResult:r];
    if ([key isEqualToString:@"kind"])        return [self kindNameOfResult:r];
    if ([key isEqualToString:@"what"])        return [self subjectOfResult:r];
    if ([key isEqualToString:@"wpm"])         return [NSString stringWithFormat:@"%.0f", [r.wpm doubleValue]];
    if ([key isEqualToString:@"raw"])         return [NSString stringWithFormat:@"%.0f", [r.rawWpm doubleValue]];
    if ([key isEqualToString:@"accuracy"])    return [NSString stringWithFormat:@"%.1f%%", [r.accuracy doubleValue]];
    if ([key isEqualToString:@"consistency"]) return [NSString stringWithFormat:@"%.0f%%", [r.consistency doubleValue]];
    if ([key isEqualToString:@"duration"])    return [HRStatistics stringForDuration:[r.duration doubleValue]];
    return @"";
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
    [self showSelectedResult];
}

- (IBAction)deleteResult:(id)sender
{
    NSUInteger count = [[self selectedResults] count];
    if (count == 0) return;
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:(count == 1 ? HRLoc(@"Delete this result?")
                                      : [NSString stringWithFormat:HRLoc(@"Delete these %lu results?"), (unsigned long)count])];
    [alert setInformativeText:HRLoc(@"They are removed from the history and from the statistics, the keys that weak-spot practice goes by included. The place in a course and its lesson records stay as they are.")];
    [alert addButtonWithTitle:HRLoc(@"Delete")];
    [alert addButtonWithTitle:HRLoc(@"Cancel")];
    if ([alert runModal] != NSAlertFirstButtonReturn) return;
    [self deleteSelectedResultWithoutAsking];
}

- (void)deleteSelectedResultWithoutAsking
{
    for (HRTestResult *r in [self selectedResults]) {
        NSError *error = nil;
        if (![_store deleteResult:r error:&error]) NSLog(@"HomeRow: a result was not deleted: %@", error);
    }
    [_historyTable deselectAll:self];
    [self reload];
}

#pragma mark - Export and import

- (BOOL)exportToURL:(NSURL *)url error:(NSError **)error
{
    NSArray *records = [_store exportRecords] ?: @[];
    BOOL csv = [[[url pathExtension] lowercaseString] isEqualToString:@"csv"];
    NSData *data = csv ? [HRResultExchange CSVDataFromRecords:records]
                       : [HRResultExchange JSONDataFromRecords:records error:error];
    if (!data) return NO;
    if ([data writeToURL:url atomically:YES]) return YES;
    if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteUnknownError
                                        userInfo:@{NSLocalizedDescriptionKey: HRLoc(@"The file could not be written.")}];
    return NO;
}

- (NSString *)importFromURL:(NSURL *)url error:(NSError **)error
{
    NSData *data = [NSData dataWithContentsOfURL:url];
    if (!data) {
        if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadUnknownError
                                            userInfo:@{NSLocalizedDescriptionKey: HRLoc(@"The file could not be read.")}];
        return nil;
    }
    NSUInteger skipped = 0, duplicates = 0;
    NSArray *records = [HRResultExchange recordsFromData:data skipped:&skipped error:error];
    if (!records) return nil;
    NSError *saveError = nil;
    NSUInteger added = [_store importRecords:records duplicates:&duplicates error:&saveError];
    if (saveError) {
        if (error) *error = saveError;
        return nil;
    }
    [self reload];
    NSMutableString *said = [NSMutableString stringWithFormat:HRLoc(@"%lu results were added."), (unsigned long)added];
    if (duplicates > 0) [said appendFormat:HRLoc(@"  %lu were here already."), (unsigned long)duplicates];
    if (skipped > 0) [said appendFormat:HRLoc(@"  %lu could not be read and were left out."), (unsigned long)skipped];
    return said;
}

- (void)say:(NSString *)message detail:(NSString *)detail
{
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:message ?: @""];
    if (detail) [alert setInformativeText:detail];
    [alert runModal];
}

- (IBAction)exportResults:(id)sender
{
    NSSavePanel *panel = [NSSavePanel savePanel];
    [panel setNameFieldStringValue:@"homerow-results.json"];
    [panel setMessage:HRLoc(@"Name the file .json to keep everything (and to import it again), or .csv for a spreadsheet — the CSV has MonkeyType's columns.")];
    if ([panel runModal] != NSModalResponseOK || ![panel URL]) return;
    NSError *error = nil;
    if (![self exportToURL:[panel URL] error:&error]) {
        [self say:HRLoc(@"The results were not exported.") detail:[error localizedDescription]];
    }
}

- (IBAction)importResults:(id)sender
{
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setAllowsMultipleSelection:NO];
    [panel setCanChooseDirectories:NO];
    [panel setMessage:HRLoc(@"A results file exported by HomeRow (.json or .csv), or a results.csv exported by MonkeyType.")];
    if ([panel runModal] != NSModalResponseOK) return;
    NSURL *url = [[panel URLs] firstObject];
    if (!url) return;
    NSError *error = nil;
    NSString *said = [self importFromURL:url error:&error];
    if (said) [self say:said detail:nil];
    else [self say:HRLoc(@"Nothing was imported.") detail:[error localizedDescription]];
}

#pragma mark - Progress

- (void)reloadProgress
{
    _subjects = [_subjectSource subjectsForStatistics:self] ?: @[];
    NSString *wanted = [[_subjectPopUp selectedItem] representedObject]
        ?: [[NSUserDefaults standardUserDefaults] stringForKey:HRStatsSubjectDefaultsKey];
    [_subjectPopUp removeAllItems];
    NSDictionary *subject = nil;
    for (NSDictionary *s in _subjects) {
        [_subjectPopUp addItemWithTitle:s[@"title"] ?: s[@"identifier"]];
        [[_subjectPopUp lastItem] setRepresentedObject:s[@"identifier"]];
        if ([s[@"identifier"] isEqual:wanted]) { subject = s; [_subjectPopUp selectItem:[_subjectPopUp lastItem]]; }
    }
    if (!subject) subject = [_subjects firstObject];
    [_subjectPopUp setEnabled:[_subjects count] > 0];

    NSString *nothing = HRLoc(@"Start a course or a code file, and its progress shows here.");
    _lessonSpeedPlot.emptyText = nothing;
    _lessonAccuracyPlot.emptyText = nothing;
    if (!subject) {
        _lessonSpeedPlot.values = @[];
        _lessonAccuracyPlot.values = @[];
        [_progressField setStringValue:@""];
        return;
    }
    BOOL code = [subject[@"unit"] isEqualToString:@"part"];
    _lessonSpeedPlot.title = code ? HRLoc(@"Best speed, part by part") : HRLoc(@"Best speed, lesson by lesson");
    _lessonAccuracyPlot.title = code ? HRLoc(@"Mistakes in the best run, part by part") : HRLoc(@"Mistakes in the best run, lesson by lesson");
    NSUInteger count = [subject[@"count"] unsignedIntegerValue];
    NSDictionary *records = [_store lessonRecordsForCourse:subject[@"identifier"]] ?: @{};
    NSMutableArray *speeds = [NSMutableArray array], *accuracies = [NSMutableArray array], *labels = [NSMutableArray array];
    NSUInteger done = 0;
    NSTimeInterval spent = 0.0;
    for (NSUInteger i = 0; i < count; i++) {
        HRLessonRecord *record = records[@(i)];
        BOOL finished = [record.completions integerValue] > 0;
        if (finished) done++;
        spent += [record.totalDuration doubleValue];
        /* a lesson not done yet is a gap in the row of bars, not a bar of zero height: same thing to the eye, and honest */
        [speeds addObject:@(finished ? [record.bestWpm doubleValue] : 0.0)];
        [accuracies addObject:@(finished ? MAX(0.0, 100.0 - [record.bestAccuracy doubleValue]) : 0.0)];
        NSString *name = [record.title length] > 0 ? record.title
            : [NSString stringWithFormat:@"%@ %lu", code ? HRLoc(@"part") : HRLoc(@"lesson"), (unsigned long)(i + 1)];
        [labels addObject:name];
    }
    _lessonSpeedPlot.labels = labels;
    _lessonSpeedPlot.values = speeds;
    _lessonAccuracyPlot.labels = labels;
    _lessonAccuracyPlot.values = accuracies;
    [_progressField setStringValue:[NSString stringWithFormat:HRLoc(@"%lu of %lu done   —   %@ of typing"),
                                    (unsigned long)done, (unsigned long)count, [HRStatistics stringForDuration:spent]]];
}

@end
