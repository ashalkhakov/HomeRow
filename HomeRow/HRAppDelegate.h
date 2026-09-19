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
#import "HRTestView.h"

@class HRChartView;
@class HRResultsView;
@class HRKeyboardView;

@interface HRAppDelegate : NSObject <NSApplicationDelegate, HRTestViewDelegate>

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

- (IBAction)modeChanged:(id)sender;
- (IBAction)selectMode:(id)sender;
- (IBAction)amountChanged:(id)sender;
- (IBAction)optionChanged:(id)sender;
- (IBAction)restartTest:(id)sender;
- (IBAction)openText:(id)sender;
- (IBAction)selectLanguage:(id)sender;
- (IBAction)selectWordList:(id)sender;
- (IBAction)selectLayout:(id)sender;
- (IBAction)showCourses:(id)sender;
- (IBAction)continueCourse:(id)sender;
- (IBAction)switchToCourse:(id)sender;
- (IBAction)restartLesson:(id)sender;
- (IBAction)toggleKeyboard:(id)sender;

@end
