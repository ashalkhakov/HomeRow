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

@class HRTestView;
@class HRChartView;
@class HRResultsView;
@class HRKeyboardView;
@class HRAppModel;
@class HRStage;
@class HRActivity;
@class HRFreeTestActivity;
@class HRCourseActivity;
@class HRCodeActivity;
@class HRKeyboardDock;
@class HRMenuController;
@class HRControlBar;
@class HRStatsWindowController;
@class HRPreferencesWindowController;
@class HRLayoutChooserController;
@class HRWelcomeWindowController;

/* The app delegate loads MainMenu.xib's window, makes the parts and puts
 * them to work together:
 *
 *   HRAppModel           configuration, results store, packs
 *   HRStage              the typing view and the results panel; clock, pace
 *                        caret, replay, sounds
 *   HRActivity           what is typed and what becomes of it --
 *     HRFreeTestActivity   time, words, zen, custom text, weak keys
 *     HRCourseActivity     a course's lessons (and the Courses window)
 *     HRCodeActivity       a file's sections (and the Code window)
 *   HRKeyboardDock       the on-screen keyboard's place in the window
 *   HRControlBar         mode, amount, punctuation, numbers: the strip over the text
 *   HRMenuController     the menus that depend on packs and courses
 *
 * What is left here is what belongs to nobody else: which activity is on, the windows of the app as a whole
 * (Preferences, Statistics, the layout chooser, the welcome), and passing
 * on what one part has to tell another. */
@interface HRAppDelegate : NSObject <NSApplicationDelegate>

@property (nonatomic, strong) IBOutlet NSWindow *window;
@property (nonatomic, strong) IBOutlet HRTestView *testView;
@property (nonatomic, strong) IBOutlet HRResultsView *resultsView;
@property (nonatomic, strong) IBOutlet HRChartView *chartView;
@property (nonatomic, strong) IBOutlet HRKeyboardView *keyboardView;

@property (nonatomic, strong) IBOutlet NSPopUpButton *modePopUp;
@property (nonatomic, strong) IBOutlet NSPopUpButton *amountPopUp;
@property (nonatomic, strong) IBOutlet NSButton *punctuationCheck;
@property (nonatomic, strong) IBOutlet NSButton *numbersCheck;
@property (nonatomic, strong) IBOutlet NSTextField *liveField;

@property (nonatomic, strong) IBOutlet NSTextField *wpmField;
@property (nonatomic, strong) IBOutlet NSTextField *accuracyField;
@property (nonatomic, strong) IBOutlet NSTextField *detailField;
@property (nonatomic, strong) IBOutlet NSTextField *hintField;

/* The control bar */
- (IBAction)modeChanged:(id)sender;
- (IBAction)amountChanged:(id)sender;
- (IBAction)optionChanged:(id)sender;
/* MainMenu.xib's Test menu */
- (IBAction)restartTest:(id)sender;
- (IBAction)openText:(id)sender;
/* The menus HRMenuController builds: HRMenuActions, plus */
- (IBAction)continueCourse:(id)sender;
- (IBAction)practiseWeakKeys:(id)sender;

/* The parts, for one another's sake and the smoke test's. */
@property (nonatomic, readonly) HRAppModel *model;
@property (nonatomic, readonly) HRStage *stage;
@property (nonatomic, readonly) HRFreeTestActivity *freeTests;
@property (nonatomic, readonly) HRCourseActivity *course;
@property (nonatomic, readonly) HRCodeActivity *code;
@property (nonatomic, readonly) HRActivity *activity;   /* the one that is on */
@property (nonatomic, readonly) HRKeyboardDock *keyboardDock;
@property (nonatomic, readonly) HRMenuController *menus;
@property (nonatomic, readonly) HRControlBar *controlBar;

- (HRStatsWindowController *)statsWindow;
- (HRPreferencesWindowController *)preferencesWindow;
- (HRLayoutChooserController *)layoutChooser;
- (HRWelcomeWindowController *)welcomeWindow;
/* Nothing on record and never asked: the welcome is for them. */
- (BOOL)isNewHere;

@end
