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
@class HRStatTilesView;
@class HRKeyboardView;

/* The Statistics window: what the saved results add up to.  Headline
 * numbers, speed and accuracy test after test, practice day by day, and
 * the keyboard tinted by how often each key is missed.  StatsWindow.xib
 * holds the views; their frames are laid out here, because three charts
 * and a keyboard sharing a resizable window is more than autoresizing
 * masks can say. */
@interface HRStatsWindowController : NSWindowController

@property (nonatomic, strong) IBOutlet NSPopUpButton *kindPopUp;
@property (nonatomic, strong) IBOutlet NSPopUpButton *periodPopUp;
@property (nonatomic, strong) IBOutlet HRStatTilesView *tilesView;
@property (nonatomic, strong) IBOutlet HRPlotView *speedPlot;
@property (nonatomic, strong) IBOutlet HRPlotView *accuracyPlot;
@property (nonatomic, strong) IBOutlet HRPlotView *daysPlot;
@property (nonatomic, strong) IBOutlet HRKeyboardView *keyboardView;
@property (nonatomic, strong) IBOutlet NSTextField *keysField;
@property (nonatomic, strong) IBOutlet NSButton *practiceButton;

- (instancetype)initWithStore:(HRResultStore *)store theme:(HRTheme *)theme;

/* The layout the heatmap is drawn on. */
@property (nonatomic, strong) HRKeyboardLayout *keyboardLayout;

/* Reads the store again; cheap enough to call after every saved result. */
- (void)reload;

- (IBAction)filterChanged:(id)sender;

/* "Practise Weak Keys": sent to practiceTarget, which starts the round. */
@property (nonatomic, weak) id practiceTarget;
@property (nonatomic) SEL practiceAction;
- (IBAction)practise:(id)sender;

@end
