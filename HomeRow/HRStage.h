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

@class HRStage;
@class HRTestSession;
@class HRTestSummary;
@class HRResultsView;
@class HRChartView;
@class HRTheme;
@class HRReplay;

/* What the results panel shows.  Whoever ran the test knows what it came to
 * and what Return will do next; the stage only knows how to show it. */
@interface HRStageResult : NSObject
@property (nonatomic) double wpm;
@property (nonatomic) double accuracy;
@property (nonatomic, copy) NSString *detail;
@property (nonatomic, copy) NSString *hint;
@property (nonatomic, copy) NSArray *samples;   /* raw WPM per second; empty for no chart */
@property (nonatomic, copy) NSArray *errors;
@property (nonatomic) double average;
/* The session just finished can be played back ("r"). */
@property (nonatomic) BOOL replayable;
/* The usual result of one session: its numbers and its chart. */
+ (instancetype)resultWithSummary:(HRTestSummary *)summary;
@end

@protocol HRStageDelegate <NSObject>
/* Tab or Esc while typing; Tab, Esc or Return on a result. */
- (void)stageDidRequestNext:(HRStage *)stage;
/* Return or Space on a page of reading text. */
- (void)stageDidDismissPage:(HRStage *)stage;
/* The session on stage reached its end. */
- (void)stage:(HRStage *)stage didFinishSession:(HRTestSession *)session;
/* Something was typed or put on stage: what is expected next may have changed. */
- (void)stageDidChange:(HRStage *)stage;
/* A wrong key; nil a moment later. */
- (void)stage:(HRStage *)stage didTypeWrongInput:(NSString *)input;
/* What goes before "62 wpm  97%" in the line over the text: a lesson's
 * title and place, a file's name and part.  nil for a plain test, which
 * then also shows what is left of it. */
- (NSString *)statusPrefixForStage:(HRStage *)stage;
@end

/* The part of the main window where typing happens and results are shown:
 * the typing view, the results panel that takes its place, the line of live
 * numbers, the clock that drives them -- and what belongs to a test whatever
 * it is a test of: the pace caret, the replay, the sounds.
 *
 * It does not know what is being typed or why; see HRActivity. */
@interface HRStage : NSObject <HRTestViewDelegate>

/* The views, handed over by whoever loaded the XIB, before -start. */
@property (nonatomic, strong) NSWindow *window;
@property (nonatomic, strong) HRTestView *testView;
@property (nonatomic, strong) HRResultsView *resultsView;
@property (nonatomic, strong) HRChartView *chartView;
@property (nonatomic, strong) NSTextField *liveField;
@property (nonatomic, strong) NSTextField *wpmField;
@property (nonatomic, strong) NSTextField *accuracyField;
@property (nonatomic, strong) NSTextField *detailField;
@property (nonatomic, strong) NSTextField *hintField;

@property (nonatomic, weak) id<HRStageDelegate> delegate;

/* Takes the views over and starts the clock. */
- (void)start;
/* Theme, fonts and the beep, from the user defaults. */
- (void)applyTheme:(HRTheme *)theme;

/* --- putting something on --------------------------------------------- */

/* A session to type.  `paceWpm` > 0 runs a pace caret at that speed. */
- (void)presentSession:(HRTestSession *)session caption:(NSString *)caption
            codeLayout:(BOOL)codeLayout paceWpm:(double)paceWpm;
/* Text to read; Return or Space dismisses it. */
- (void)presentPage:(NSString *)text;
- (void)presentResult:(HRStageResult *)result;

/* --- what is on -------------------------------------------------------- */

@property (nonatomic, readonly) HRTestSession *session;   /* nil under a page */
@property (nonatomic, readonly) BOOL showsPage;
@property (nonatomic, readonly) BOOL showsResult;
/* The speed of the pace caret; can be changed while a test is on. */
@property (nonatomic) double paceWpm;
/* What the on-screen keyboard should light: nil under a page or a result. */
- (NSString *)expectedInput;

/* --- replay ------------------------------------------------------------ */

@property (nonatomic, readonly) BOOL canReplay;
@property (nonatomic, readonly) BOOL isReplaying;
- (IBAction)replayLastTest:(id)sender;
/* The replay's own session and clock, for tests. */
@property (nonatomic, readonly) HRTestSession *replaySession;
@property (nonatomic, readonly) HRReplay *replay;
- (void)advanceReplayToElapsed:(NSTimeInterval)elapsed;
/* Puts the pace caret where the clock says, now rather than at the next tick. */
- (void)movePaceCaret;

/* NSBeep() on every wrong key; kept in the user defaults. */
@property (nonatomic) BOOL beepsOnError;

/* --- sounds ------------------------------------------------------------ */

/* A folder under Resources/Sounds; nil or @"" for silence. */
@property (nonatomic, copy) NSString *soundScheme;
@property (nonatomic, readonly) NSUInteger loadedSounds;
/* One key's worth, so that a choice in Preferences is heard at once. */
- (void)playSampleSound;

@end
