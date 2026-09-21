/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * HomeRow is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version.  It comes with ABSOLUTELY NO WARRANTY.  See COPYING.
 */
#import "HRAppDelegate.h"
#import "HRAppModel.h"
#import "HRStage.h"
#import "HRActivity.h"
#import "HRFreeTestActivity.h"
#import "HRCourseActivity.h"
#import "HRCodeActivity.h"
#import "HRKeyboardDock.h"
#import "HRMenuController.h"
#import "HRControlBar.h"
#import "HRSmokeTest.h"
#import "HRTestView.h"
#import "HRResultsView.h"
#import "HRChartView.h"
#import "HRKeyboardView.h"
#import "HRTheme.h"
#import "HRPacks.h"
#import "HRLanguage.h"
#import "HRTypScript.h"
#import "HRResultStore.h"
#import "HRManagedObjects.h"
#import "HRCodeLibrary.h"
#import "HRCodeDocument.h"
#import "HRStatsWindowController.h"
#import "HRPreferencesWindowController.h"
#import "HRLayoutChooserController.h"
#import "HRWelcomeWindowController.h"
#import "HRSoundPlayer.h"
#import <objc/runtime.h>

#define HRLoc(key) NSLocalizedString(key, nil)

@interface HRAppDelegate () <HRActivityHost, HRStageDelegate, HRControlBarDelegate, HRMenuActions, HRPreferencesDelegate,
                             HRLayoutChooserDelegate, HRStatsSubjectSource, HRWelcomeDelegate>
@end

@implementation HRAppDelegate
{
    HRTheme *_theme;
    HRStatsWindowController *_statsWindow;
    HRPreferencesWindowController *_preferencesWindow;
    HRLayoutChooserController *_layoutChooser;
    HRWelcomeWindowController *_welcomeWindow;
}

#pragma mark - Launch

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    _model = [[HRAppModel alloc] init];

    _stage = [[HRStage alloc] init];
    _stage.window = _window;
    _stage.testView = _testView;
    _stage.resultsView = _resultsView;
    _stage.chartView = _chartView;
    _stage.liveField = _liveField;
    _stage.wpmField = _wpmField;
    _stage.accuracyField = _accuracyField;
    _stage.detailField = _detailField;
    _stage.hintField = _hintField;
    _stage.delegate = self;
    [_stage start];

    _keyboardDock = [[HRKeyboardDock alloc] init];
    _keyboardDock.window = _window;
    _keyboardDock.keyboardView = _keyboardView;
    _keyboardDock.typingView = _testView;
    _keyboardDock.resultsView = _resultsView;
    [_keyboardView setHidden:YES];

    _freeTests = [[HRFreeTestActivity alloc] initWithModel:_model stage:_stage host:self];
    _course = [[HRCourseActivity alloc] initWithModel:_model stage:_stage host:self];
    _code = [[HRCodeActivity alloc] initWithModel:_model stage:_stage host:self];

    _controlBar = [[HRControlBar alloc] initWithModel:_model delegate:self];
    _controlBar.modePopUp = _modePopUp;
    _controlBar.amountPopUp = _amountPopUp;
    _controlBar.punctuationCheck = _punctuationCheck;
    _controlBar.numbersCheck = _numbersCheck;

    [self applyAppearance];
    _menus = [[HRMenuController alloc] initWithModel:_model course:_course target:self];
    [_menus build];
    [self syncControls];
    [_liveField setStringValue:@""];
    [_window makeKeyAndOrderFront:self];

    if ([[[NSProcessInfo processInfo] environment] objectForKey:@"HR_SMOKE_TEST"]) {
        /* nobody to ask: on with whatever was on */
        [self carryOn];
        [[[HRSmokeTest alloc] initWithAppDelegate:self] performSelector:@selector(run) withObject:nil afterDelay:0.5];
    } else {
        /* every launch starts with the question; the stage waits for the answer */
        [self showWelcome];
    }
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
    return YES;
}

/* macOS 12+ warns at launch without it; GNUstep never asks. */
- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app
{
    return YES;
}

#pragma mark - Which activity is on

- (HRActivity *)activityForMode:(HRTestMode)mode
{
    if (mode == HRTestModeLesson) return _course;
    if (mode == HRTestModeCode) return _code;
    return _freeTests;
}

/* HRActivityHost */
- (void)activity:(HRActivity *)activity willPresentInMode:(HRTestMode)mode save:(BOOL)save
{
    for (HRActivity *other in @[_freeTests, _course, _code]) {
        if (other != activity) [other leave];
    }
    _activity = activity;
    [_welcomeWindow dismiss];   /* a menu got there first: the question is answered */
    _model.configuration.mode = mode;
    [self syncControls];
    if (save) [_model saveConfiguration];
}

- (void)activityDidRecordResult:(HRActivity *)activity
{
    [_statsWindow reload];
}

- (void)activity:(HRActivity *)activity wantsMode:(HRTestMode)mode
{
    [self enterMode:mode];
}

/* A free test in `mode`, from whatever was on. */
- (void)enterMode:(HRTestMode)mode
{
    _model.configuration.mode = mode;
    [_model saveConfiguration];
    [_freeTests begin];
}

#pragma mark - The control bar

- (void)syncControls
{
    [_controlBar sync];
    [self syncMenus];
}

- (void)syncMenus
{
    _menus.beepsOnError = _stage.beepsOnError;
    _menus.keyboardWanted = [self wantsKeyboard];
    [_menus sync];
}

/* Test > Time / Words / Zen: the modes by keyboard, and the way out of a
 * course now that the pop-up is hidden there. */
- (IBAction)selectMode:(id)sender
{
    [self controlBar:_controlBar didChooseMode:(HRTestMode)[sender tag]];
}

/* The XIB sends the bar's actions here, as it always has. */
- (IBAction)modeChanged:(id)sender { [_controlBar modeChanged:sender]; }
- (IBAction)amountChanged:(id)sender { [_controlBar amountChanged:sender]; }
- (IBAction)optionChanged:(id)sender { [_controlBar optionChanged:sender]; }

/* HRControlBarDelegate */
- (void)controlBar:(HRControlBar *)bar didChooseMode:(HRTestMode)mode
{
    if (mode == HRTestModeLesson) {
        if (!(_activity == _course && _course.isInLesson)) [_course begin];
    } else if (mode == HRTestModeCode) {
        if (!(_activity == _code && _code.file)) [_code begin];
    } else {
        [self enterMode:mode];
    }
}

- (void)controlBarDidChangeTest:(HRControlBar *)bar
{
    [_activity next];
}

- (IBAction)restartTest:(id)sender
{
    [_activity next];
}

- (IBAction)openText:(id)sender
{
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setAllowsMultipleSelection:NO];
    [panel setCanChooseDirectories:NO];
    if ([panel runModal] != NSModalResponseOK) return;
    NSURL *url = [[panel URLs] firstObject];
    NSError *error = nil;
    NSString *text = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:&error];
    if ([text length] == 0) {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:HRLoc(@"That file could not be read as UTF-8 text.")];
        if (error) [alert setInformativeText:[error localizedDescription]];
        [alert runModal];
        return;
    }
    _freeTests.customText = text;
    _model.configuration.mode = HRTestModeCustom;
    [_freeTests begin];
}

- (IBAction)toggleBeep:(id)sender
{
    _stage.beepsOnError = !_stage.beepsOnError;
    [self syncMenus];
    [_preferencesWindow sync];
}

- (IBAction)replayLastTest:(id)sender
{
    [_stage replayLastTest:sender];
}

- (BOOL)validateMenuItem:(NSMenuItem *)item
{
    /* Course > Restart Lesson only means something inside a lesson */
    if (sel_isEqual([item action], @selector(restartLesson:))) return _activity == _course && _course.isInLesson;
    if (sel_isEqual([item action], @selector(replayLastTest:))) return _stage.canReplay;
    return YES;
}

#pragma mark - The Language menu

/* A language or a word list means word tests. */
- (void)beginWordTest
{
    HRTestConfiguration *configuration = _model.configuration;
    if (configuration.mode != HRTestModeTime && configuration.mode != HRTestModeWords) {
        configuration.mode = HRTestModeTime;
    }
    [_model saveConfiguration];
    [_freeTests begin];
}

- (IBAction)selectLanguage:(id)sender
{
    _model.configuration.languageID = [sender representedObject];
    [self beginWordTest];
}

- (IBAction)selectWordList:(id)sender
{
    _model.configuration.wordListName = [sender representedObject];
    [self beginWordTest];
}

- (void)useLayout:(NSString *)identifier
{
    _model.configuration.layoutID = identifier;
    _statsWindow.keyboardLayout = [_model.packs layoutNamed:identifier];
    [_preferencesWindow sync];
    [_model saveConfiguration];
    [self syncMenus];
    [self syncKeyboard];
}

#pragma mark - Courses and code

- (IBAction)showCourses:(id)sender { [_course showWindow]; }
- (IBAction)continueCourse:(id)sender { [_course begin]; }
- (IBAction)restartLesson:(id)sender { [_course restartLesson]; }
- (IBAction)showCode:(id)sender { [_code showWindow]; }

- (IBAction)switchToCourse:(id)sender
{
    NSString *file = [sender representedObject];
    /* the ticked course, while it is already running: nothing to do */
    if (_activity == _course && _course.isInLesson && [file isEqual:_course.courseFile]) {
        [_window makeKeyAndOrderFront:self];
        return;
    }
    [_course switchToCourse:file];
}

- (IBAction)practiseWeakKeys:(id)sender
{
    [self enterMode:HRTestModePractice];
    [_window makeKeyAndOrderFront:self];
}

#pragma mark - HRStageDelegate

- (void)stageDidRequestNext:(HRStage *)stage { [_activity next]; }
- (void)stageDidDismissPage:(HRStage *)stage { [_activity pageDismissed]; }
- (void)stage:(HRStage *)stage didFinishSession:(HRTestSession *)session { [_activity sessionDidFinish:session]; }
- (NSString *)statusPrefixForStage:(HRStage *)stage { return [_activity statusPrefix]; }

- (void)stageDidChange:(HRStage *)stage
{
    [self syncKeyboard];
}

/* the key pressed by mistake shows red on the keyboard for a moment */
- (void)stage:(HRStage *)stage didTypeWrongInput:(NSString *)input
{
    [_keyboardDock setWrongInput:input];
}

#pragma mark - The on-screen keyboard

/* Show Keyboard is remembered three times over: following a course and
 * typing code (on unless switched off), and the free tests (off unless
 * switched on).  The activity that is on says which. */
- (BOOL)wantsKeyboard
{
    HRActivity *activity = _activity ?: _freeTests;
    return [HRKeyboardDock isWantedForDefaultsKey:[activity keyboardDefaultsKey] unlessSet:[activity keyboardShowsByDefault]];
}

- (IBAction)toggleKeyboard:(id)sender
{
    [HRKeyboardDock setWanted:![self wantsKeyboard] forDefaultsKey:[(_activity ?: _freeTests) keyboardDefaultsKey]];
    [self syncMenus];
    [self syncKeyboard];
    [_preferencesWindow sync];
}

- (void)syncKeyboard
{
    BOOL wanted = [self wantsKeyboard];
    if (_menus.keyboardWanted != wanted) [self syncMenus];
    [_keyboardDock showLayout:[(_activity ?: _freeTests) keyboardLayout] wanted:wanted expectedInput:[_stage expectedInput]];
}

#pragma mark - Appearance and Preferences

/* Theme, fonts and the beep: at launch, and again whenever Preferences
 * changes one of them. */
- (void)applyAppearance
{
    _theme = [HRTheme currentTheme];
    [_stage applyTheme:_theme];
    _keyboardDock.theme = _theme;
    _layoutChooser.theme = _theme;
    [_window setBackgroundColor:_theme.background];
    /* the Statistics window takes its theme when it is built: build it anew */
    if (_statsWindow) {
        BOOL wasOpen = [[_statsWindow window] isVisible];
        [[_statsWindow window] orderOut:self];
        _statsWindow = nil;
        if (wasOpen) [self showStatistics:self];
    }
    [[_window contentView] setNeedsDisplay:YES];
    [self syncMenus];
}

- (HRPreferencesWindowController *)preferencesWindow
{
    if (!_preferencesWindow) _preferencesWindow = [[HRPreferencesWindowController alloc] initWithDelegate:self];
    return _preferencesWindow;
}

- (IBAction)showPreferences:(id)sender
{
    [[self preferencesWindow] showWindow:self];
    [[self preferencesWindow] sync];
}

- (HRTestConfiguration *)configurationForPreferences:(HRPreferencesWindowController *)controller
{
    return _model.configuration;
}

- (void)preferencesWantsLayoutChooser:(HRPreferencesWindowController *)controller
{
    [self showLayoutChooser:controller];
}

- (NSURL *)storeURLForPreferences:(HRPreferencesWindowController *)controller
{
    return _model.store ? [HRResultStore defaultStoreURL] : nil;
}

- (void)preferences:(HRPreferencesWindowController *)controller didChange:(HRPreferencesChange)change
{
    [_model saveConfiguration];
    if (change & HRPreferencesChangedAppearance) [self applyAppearance];
    if (change & HRPreferencesChangedSound) {
        _stage.soundScheme = [[NSUserDefaults standardUserDefaults] stringForKey:HRSoundSchemeDefaultsKey];
        [_stage playSampleSound];   /* what was chosen, heard at once */
    }
    if (change & HRPreferencesChangedPace) {
        if (_activity == _freeTests) [_freeTests paceDidChange];
    }
    if (change & HRPreferencesChangedKeyboard) {
        _statsWindow.keyboardLayout = [_model.packs layoutNamed:_model.configuration.layoutID];
        [self syncMenus];
        [self syncKeyboard];
    }
    /* new rules: the test that is being typed starts over under them; a
     * result on screen stays where it is */
    if (change & HRPreferencesChangedTyping) [_activity rulesDidChange];
}

#pragma mark - Choosing a keyboard layout

- (HRLayoutChooserController *)layoutChooser
{
    if (!_layoutChooser) _layoutChooser = [[HRLayoutChooserController alloc] initWithDelegate:self theme:_theme];
    return _layoutChooser;
}

- (IBAction)showLayoutChooser:(id)sender
{
    [[self layoutChooser] chooseStartingFrom:(_model.configuration.layoutID ?: @"qwerty")];
}

- (NSArray *)layoutIdentifiersForChooser:(HRLayoutChooserController *)chooser
{
    return _model.packs.layoutIdentifiers;
}

- (HRKeyboardLayout *)layoutChooser:(HRLayoutChooserController *)chooser layoutNamed:(NSString *)identifier
{
    return [_model.packs layoutNamed:identifier];
}

- (void)layoutChooser:(HRLayoutChooserController *)chooser didChoose:(NSString *)identifier
{
    [self useLayout:identifier];
}

#pragma mark - Statistics

- (HRStatsWindowController *)statsWindow
{
    if (!_statsWindow) {
        _statsWindow = [[HRStatsWindowController alloc] initWithStore:_model.store theme:_theme];
        _statsWindow.keyboardLayout = [_model currentLayout];
        _statsWindow.subjectSource = self;
        _statsWindow.practiceTarget = self;
        _statsWindow.practiceAction = @selector(practiseWeakKeys:);
    }
    return _statsWindow;
}

- (IBAction)showStatistics:(id)sender
{
    [[self statsWindow] showWindow:self];
    [[self statsWindow] reload];
}

/* What a result's courseFile is called: a course by its language and title,
 * a code file by its own. */
- (NSString *)statistics:(HRStatsWindowController *)controller titleForCourseFile:(NSString *)courseFile
{
    if ([courseFile hasPrefix:@"code:"]) return [_code.library fileWithIdentifier:courseFile].title;
    NSDictionary *course = [_model.packs courseEntryForFile:courseFile];
    if (!course) return nil;
    NSString *language = course[@"language"] ? [_model displayNameOfLanguage:course[@"language"]] : nil;
    return language ? [NSString stringWithFormat:@"%@ \u2014 %@", language, course[@"title"]] : course[@"title"];
}

- (NSArray *)subjectsForStatistics:(HRStatsWindowController *)controller
{
    NSMutableArray *subjects = [NSMutableArray array];
    for (HRCourseProgress *progress in [_model.store startedCourses]) {
        NSString *identifier = progress.courseFile;
        NSString *title = [self statistics:controller titleForCourseFile:identifier];
        if (!title) continue;   /* a course or file that is no longer there */
        NSUInteger count = 0;
        BOOL code = [identifier hasPrefix:@"code:"];
        if (code) {
            HRCodeFile *file = [_code.library fileWithIdentifier:identifier];
            count = [_code.library documentForFile:file error:NULL].numberOfSections;
        } else {
            count = [[_model.packs scriptForCourseFile:identifier].lessons count];
        }
        if (count == 0) continue;
        [subjects addObject:@{@"identifier": identifier, @"title": title, @"count": @(count), @"unit": code ? @"part" : @"lesson"}];
    }
    return subjects;
}

#pragma mark - The welcome

/* Nothing on record: there is nothing to carry on with. */
- (BOOL)isNewHere
{
    HRResultStore *store = _model.store;
    return [[store recentResultsWithLimit:1 error:NULL] count] == 0 && [[store startedCourses] count] == 0;
}

/* Someone following a course, or typing a file, comes back to it where they
 * left it; anyone else to the kind of test they had. */
- (void)carryOn
{
    [[self activityForMode:_model.configuration.mode] begin];
}

/* What -carryOn would put on, for the welcome to say; nil for someone new. */
- (NSString *)resumeDescription
{
    if ([self isNewHere]) return nil;
    HRTestConfiguration *configuration = _model.configuration;
    HRResultStore *store = _model.store;
    switch (configuration.mode) {
        case HRTestModeLesson: {
            NSString *file = [_course currentCourseFile];
            NSString *title = [self statistics:nil titleForCourseFile:file];
            if (!title) return HRLoc(@"Your courses.");
            NSUInteger total = [[_model.packs scriptForCourseFile:file].lessons count];
            NSUInteger next = (NSUInteger)MAX(0, [[store progressForCourse:file].lessonIndex integerValue]);
            if (next >= total) return [NSString stringWithFormat:HRLoc(@"%@ \u2014 finished; pick what to take again."), title];
            return [NSString stringWithFormat:HRLoc(@"%@, lesson %lu of %lu."), title, (unsigned long)(next + 1), (unsigned long)total];
        }
        case HRTestModeCode: {
            HRCodeFile *file = [_code currentFile];
            if (!file) return HRLoc(@"Your code.");
            NSUInteger total = [_code.library documentForFile:file error:NULL].numberOfSections;
            NSUInteger next = (NSUInteger)MAX(0, [[store progressForCourse:file.identifier].lessonIndex integerValue]);
            if (total == 0 || next >= total) return [NSString stringWithFormat:HRLoc(@"%@ \u2014 typed to the end; pick what to type again."), file.title];
            return [NSString stringWithFormat:HRLoc(@"%@, part %lu of %lu."), file.title, (unsigned long)(next + 1), (unsigned long)total];
        }
        case HRTestModeTime:
            return [NSString stringWithFormat:HRLoc(@"%ld-second tests in %@."), (long)configuration.amount, [_model currentLanguage].displayName ?: @"?"];
        case HRTestModeWords:
            return [NSString stringWithFormat:HRLoc(@"%ld-word tests in %@."), (long)configuration.amount, [_model currentLanguage].displayName ?: @"?"];
        case HRTestModeZen:
            return HRLoc(@"Zen: type anything.");
        case HRTestModePractice:
            return HRLoc(@"Practice on your weak keys.");
        case HRTestModeCustom:
            break;   /* the text is gone with the last launch */
    }
    return HRLoc(@"Tests, as you left them.");
}

- (HRWelcomeWindowController *)welcomeWindow
{
    if (!_welcomeWindow) _welcomeWindow = [[HRWelcomeWindowController alloc] initWithDelegate:self];
    return _welcomeWindow;
}

- (void)showWelcome
{
    [self welcomeWindow].resumeDescription = [self resumeDescription];
    [[self welcomeWindow] showWindow:self];
}

- (void)welcome:(HRWelcomeWindowController *)controller didChoose:(HRWelcomeChoice)choice
{
    [_window makeKeyAndOrderFront:self];
    switch (choice) {
        case HRWelcomeResume:
            [self carryOn];
            break;
        case HRWelcomeTestMe:
            /* a test whatever was on: the last kind of word test, or 30 seconds */
            [self beginWordTest];
            break;
        case HRWelcomeTeachMe: {
            /* the course they are in, if any; else the one to start a beginner on */
            NSString *file = [_course currentCourseFile] ?: [_course beginnersCourseFile];
            if (file) [_course switchToCourse:file];
            else [_course showWindow];   /* no course for this layout: let them pick */
            break;
        }
    }
}

@end
