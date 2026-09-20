/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * HomeRow is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version.  It comes with ABSOLUTELY NO WARRANTY.  See COPYING.
 */
#import <Foundation/Foundation.h>
#import "HRTestConfiguration.h"

@class HRActivity;
@class HRAppModel;
@class HRStage;
@class HRTestSession;
@class HRTestSummary;
@class HRKeyboardLayout;

/* What an activity asks of whoever holds them all (the app delegate). */
@protocol HRActivityHost <NSObject>
/* `activity` is about to put something on the stage in `mode`: the others
 * let go of what they had on, the controls follow, and -- when `save` --
 * the mode is remembered for the next launch.  (A page saying "nothing
 * chosen yet" is not a mode worth coming back to.) */
- (void)activity:(HRActivity *)activity willPresentInMode:(HRTestMode)mode save:(BOOL)save;
/* A result went into the store. */
- (void)activityDidRecordResult:(HRActivity *)activity;
/* The activity has nothing to offer and sends the typist elsewhere. */
- (void)activity:(HRActivity *)activity wantsMode:(HRTestMode)mode;
@end

/* Something there is to type, and what becomes of it: the free tests, a
 * course, a file of code.  An activity owns its own state -- which lesson,
 * which file, which text -- builds the sessions, puts them on the stage and
 * records what they come to.  The stage tells the host what the typist did;
 * the host passes it to the activity that is on.
 *
 * Abstract: see HRFreeTestActivity, HRCourseActivity, HRCodeActivity. */
@interface HRActivity : NSObject

- (instancetype)initWithModel:(HRAppModel *)model stage:(HRStage *)stage host:(id<HRActivityHost>)host;

@property (nonatomic, readonly) HRAppModel *model;
@property (nonatomic, readonly) HRStage *stage;
@property (nonatomic, readonly, weak) id<HRActivityHost> host;

/* --- for the host ------------------------------------------------------ */

/* Take the stage: start, or carry on from where this was left. */
- (void)begin;
/* Let go of whatever is in progress.  The saved place stays. */
- (void)leave;
/* Tab or Esc while typing: the same again.  After a result: go on. */
- (void)next;
- (void)pageDismissed;
- (void)sessionDidFinish:(HRTestSession *)session;
/* Goes before the live numbers; nil for none. */
- (NSString *)statusPrefix;
/* Where "Show Keyboard" is remembered for this activity, and whether it
 * shows when nothing is remembered. */
- (NSString *)keyboardDefaultsKey;
- (BOOL)keyboardShowsByDefault;
/* The layout the on-screen keyboard draws; nil for none at all. */
- (HRKeyboardLayout *)keyboardLayout;
/* A setting that shapes the sessions changed: what is being typed starts
 * over under it.  A result on screen stays. */
- (void)rulesDidChange;

/* --- for subclasses ---------------------------------------------------- */

/* Shows `text` as a page in `mode`, with nothing to type behind it. */
- (void)presentPlaceholder:(NSString *)text inMode:(HRTestMode)mode;
/* Whether a session was a test at all: long enough, and something typed. */
+ (BOOL)summaryIsWorthKeeping:(HRTestSummary *)summary;

@end
