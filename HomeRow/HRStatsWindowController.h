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

@class HRResultStore;
@class HRTheme;
@class HRKeyboardLayout;
@class HRPlotView;
@class HRChartView;
@class HRStatTilesView;
@class HRKeyboardView;
@class HRStatsWindowController;

typedef NS_ENUM(NSInteger, HRStatsPane) {
    HRStatsPaneOverview = 0,
    HRStatsPaneHistory,
    HRStatsPaneProgress
};

/* What the window cannot know from the results alone: what a course or a
 * code file is called, and how many lessons or parts it has. */
@protocol HRStatsSubjectSource <NSObject>
/* For every course and code file there is progress for:
 * @{@"identifier", @"title", @"count" (lessons or parts), @"unit" (@"lesson" / @"part")} */
- (NSArray *)subjectsForStatistics:(HRStatsWindowController *)controller;
/* A short name for a result's courseFile; nil when it is not known. */
- (NSString *)statistics:(HRStatsWindowController *)controller titleForCourseFile:(NSString *)courseFile;
@end

/* The Statistics window, in three panes that share it:
 *
 *   Overview  headline numbers; speed and accuracy test after test; practice
 *             day by day; the keyboard tinted by mistakes or by speed.
 *   History   every saved result, newest first, with the per-second chart of
 *             the selected one; delete, export, import.
 *   Progress  one course or code file: best speed and accuracy per lesson.
 *
 * StatsWindow.xib has them as the tabs of a tab view, one pane to look at at a
 * time in Interface Builder too.  Inside a pane the frames are laid out here:
 * charts and a keyboard sharing a resizable space is more than autoresizing
 * masks can say. */
@interface HRStatsWindowController : NSWindowController <NSTableViewDataSource, NSTableViewDelegate>

@property (nonatomic, strong) IBOutlet NSTabView *tabView;
@property (nonatomic, strong) IBOutlet NSPopUpButton *kindPopUp;
@property (nonatomic, strong) IBOutlet NSPopUpButton *periodPopUp;
/* Overview */
@property (nonatomic, strong) IBOutlet HRStatTilesView *tilesView;
@property (nonatomic, strong) IBOutlet HRPlotView *speedPlot;
@property (nonatomic, strong) IBOutlet HRPlotView *accuracyPlot;
@property (nonatomic, strong) IBOutlet HRPlotView *daysPlot;
@property (nonatomic, strong) IBOutlet NSPopUpButton *heatPopUp;
@property (nonatomic, strong) IBOutlet HRKeyboardView *keyboardView;
@property (nonatomic, strong) IBOutlet NSTextField *keysField;
@property (nonatomic, strong) IBOutlet NSButton *practiceButton;
/* History */
@property (nonatomic, strong) IBOutlet NSScrollView *historyScroll;
@property (nonatomic, strong) IBOutlet NSTableView *historyTable;
@property (nonatomic, strong) IBOutlet HRChartView *resultChart;
@property (nonatomic, strong) IBOutlet NSTextField *resultField;
@property (nonatomic, strong) IBOutlet NSButton *deleteButton;
@property (nonatomic, strong) IBOutlet NSButton *exportButton;
@property (nonatomic, strong) IBOutlet NSButton *importButton;
/* Progress */
@property (nonatomic, strong) IBOutlet NSPopUpButton *subjectPopUp;
@property (nonatomic, strong) IBOutlet NSTextField *progressField;
@property (nonatomic, strong) IBOutlet HRPlotView *lessonSpeedPlot;
@property (nonatomic, strong) IBOutlet HRPlotView *lessonAccuracyPlot;

- (instancetype)initWithStore:(HRResultStore *)store theme:(HRTheme *)theme;

@property (nonatomic, weak) id<HRStatsSubjectSource> subjectSource;
/* The layout the heatmap is drawn on. */
@property (nonatomic, strong) HRKeyboardLayout *keyboardLayout;
@property (nonatomic) HRStatsPane pane;

/* Reads the store again; cheap enough to call after every saved result. */
- (void)reload;

/* Export and import without the panels, for tests and for the actions. */
- (BOOL)exportToURL:(NSURL *)url error:(NSError **)error;   /* .csv: CSV; anything else: JSON */
- (NSString *)importFromURL:(NSURL *)url error:(NSError **)error;   /* what happened, in words; nil on failure */

- (IBAction)filterChanged:(id)sender;
- (IBAction)heatChanged:(id)sender;
- (IBAction)subjectChanged:(id)sender;
- (IBAction)deleteResult:(id)sender;
- (IBAction)exportResults:(id)sender;
- (IBAction)importResults:(id)sender;

/* "Practise Weak Keys": sent to practiceTarget, which starts the round. */
@property (nonatomic, weak) id practiceTarget;
@property (nonatomic) SEL practiceAction;
- (IBAction)practise:(id)sender;

@end
