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
#import "HRChartView.h"
#import "HRResultsView.h"
#import "HRTheme.h"
#import "HRResultStore.h"
#import "HRTestSession.h"
#import "HRLanguage.h"
#import "HRRandom.h"
#import "HRClock.h"
#import "HRTypScript.h"
#import "HRCourseRun.h"
#import "HRKeyboardLayout.h"
#import "HRKeyboardView.h"
#import "HRCourseWindowController.h"
#import "HRCodeLibrary.h"
#import "HRCodeDocument.h"
#import "HRCodeWindowController.h"
#import "HRStatsWindowController.h"
#import "HRPreferencesWindowController.h"
#import "HRLayoutChooserController.h"
#import "HRWeakSpots.h"
#import "HRPlotView.h"
#import "HRStatTilesView.h"
#import <objc/runtime.h>
#import "HRPace.h"
#import "HRReplay.h"
#import "HRSoundPlayer.h"
#import "HRWelcomeWindowController.h"

static NSString * const HRConfigurationDefaultsKey = @"HRConfiguration";
static NSString * const HRCurrentCourseDefaultsKey = @"HRCurrentCourse";
/* the file being typed in code mode, and the files opened from disk */
static NSString * const HRCurrentCodeFileDefaultsKey = @"HRCurrentCodeFile";
/* (when the keyboard shows and the beep: HRPreferencesWindowController.h) */

#define HRLoc(key) NSLocalizedString(key, nil)

@interface HRAppDelegate () <HRCourseWindowDelegate, HRCodeWindowDelegate, HRPreferencesDelegate, HRLayoutChooserDelegate, HRStatsSubjectSource, HRWelcomeDelegate>
@end

@implementation HRAppDelegate
{
    HRTestConfiguration *_configuration;
    HRTestSession *_session;
    HRResultStore *_store;
    HRTheme *_theme;
    NSArray *_languages;
    NSString *_customText;
    NSTimer *_timer;
    HRSoundPlayer *_sounds;
    double _paceWpm;                 /* 0: no pace caret in this test */
    HRReplay *_lastReplay;           /* the test whose result is on screen */
    HRReplay *_replay;               /* ...while it is being played back */
    HRTestSession *_replaySession;
    NSTimeInterval _replayBegan;
    HRWelcomeWindowController *_welcomeWindow;

    NSMenu *_languageMenu;
    NSMenu *_programmingMenu;
    NSMenuItem *_programmingItem;
    NSMenu *_wordListMenu;
    NSMutableDictionary *_scripts;   /* course file -> HRTypScript, parsed on demand */

    NSMenuItem *_layoutMenuItem;
    HRLayoutChooserController *_layoutChooser;
    HRWeakSpots *_weakSpots;         /* what the practice round under way is for */
    HRWeakSpots *_weakSpotsForTesting;   /* the smoke test's: its store is too young to have weak keys */
    NSMenuItem *_keyboardMenuItem;
    NSMenuItem *_testKeyboardMenuItem;   /* the same command in the Test menu, where code and tests look for it */
    NSMenu *_courseMenu;
    NSMutableArray *_startedCourseItems;   /* the part of the Course menu that is rebuilt */
    NSArray *_courses;               /* Lessons/gtypist/index.plist */
    HRCourseWindowController *_courseWindow;
    NSMutableDictionary *_layouts;   /* identifier -> HRKeyboardLayout, loaded on demand */
    BOOL _keyboardShown;
    CGFloat _keyboardHeight;         /* what showing it added to the window */

    /* a lesson of the current course in progress: nil when testing freely */
    NSString *_courseFile;
    NSString *_unsavedCourseFile;    /* the place in the course when there is no store */
    NSUInteger _unsavedNextLesson;
    NSUInteger _lessonIndex;
    HRCourseRun *_run;

    /* code mode: a section of a source file; nil when not typing one */
    HRCodeLibrary *_codeLibrary;
    HRCodeWindowController *_codeWindow;
    HRStatsWindowController *_statsWindow;
    HRPreferencesWindowController *_preferencesWindow;
    HRCodeFile *_codeFile;
    NSUInteger _codeSection;
    NSUInteger _codeSectionCount;
    BOOL _codeSectionDone;           /* typed to the end: Return moves on */
    NSString *_unsavedCodeFile;      /* the place in the file when there is no store */
    NSUInteger _unsavedNextSection;
}

#pragma mark - Launch

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    NSDictionary *saved = [[NSUserDefaults standardUserDefaults] dictionaryForKey:HRConfigurationDefaultsKey];
    _configuration = saved ? [[HRTestConfiguration alloc] initWithDictionary:saved]
                           : [HRTestConfiguration defaultConfiguration];
    /* a custom text does not outlive the run that opened it */
    if (_configuration.mode == HRTestModeCustom) _configuration.mode = HRTestModeTime;

    [self loadLanguages];

    NSError *error = nil;
    _store = [[HRResultStore alloc] initWithStoreURL:[HRResultStore defaultStoreURL]
                                              bundle:[NSBundle mainBundle]
                                               error:&error];
    /* typing still works without history; say why there is none */
    if (!_store) NSLog(@"HomeRow: results will not be saved: %@", error);

    _testView.delegate = self;
    [_keyboardView setHidden:YES];
    _resultsView.target = self;
    [self applyAppearance];
    _sounds = [[HRSoundPlayer alloc] init];
    _sounds.scheme = [[NSUserDefaults standardUserDefaults] stringForKey:HRSoundSchemeDefaultsKey];

    [self buildMenus];
    [self syncControls];
    /* someone following a course comes back to it, where they left it */
    [self startNewTest];

    _timer = [NSTimer scheduledTimerWithTimeInterval:0.1
                                              target:self
                                            selector:@selector(timerFired:)
                                            userInfo:nil
                                             repeats:YES];
    [_window makeKeyAndOrderFront:self];

    if ([[[NSProcessInfo processInfo] environment] objectForKey:@"HR_SMOKE_TEST"]) {
        [self performSelector:@selector(runSmokeTest) withObject:nil afterDelay:0.5];
    } else {
        [self welcomeIfNew];
    }
}

#pragma mark - The first launch

/* Asked once, and only of someone with nothing on record: whoever has
 * results or a course under way has answered it already. */
- (BOOL)isNewHere
{
    if ([[NSUserDefaults standardUserDefaults] boolForKey:HRWelcomeDoneDefaultsKey]) return NO;
    if ([[_store recentResultsWithLimit:1 error:NULL] count] > 0 || [[_store startedCourses] count] > 0) return NO;
    return YES;
}

- (void)welcomeIfNew
{
    if (![self isNewHere]) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:HRWelcomeDoneDefaultsKey];
        return;
    }
    [[self welcomeWindow] showWindow:self];
}

- (HRWelcomeWindowController *)welcomeWindow
{
    if (!_welcomeWindow) _welcomeWindow = [[HRWelcomeWindowController alloc] initWithDelegate:self];
    return _welcomeWindow;
}

/* The course to start a beginner on: the first one for the layout the
 * keyboard is set to, in the language of the tests. */
- (NSString *)beginnersCourseFile
{
    NSString *layout = _configuration.layoutID ?: @"qwerty";
    NSString *fallback = nil;
    for (NSDictionary *course in _courses) {
        if (![course[@"layout"] isEqual:layout]) continue;
        if ([course[@"language"] isEqual:_configuration.languageID]) return course[@"file"];
        if (!fallback) fallback = course[@"file"];
    }
    return fallback;
}

- (void)welcome:(HRWelcomeWindowController *)controller didChoose:(HRWelcomeChoice)choice
{
    [_window makeKeyAndOrderFront:self];
    if (choice == HRWelcomeTestMe) {
        [_window makeFirstResponder:_testView];
        return;   /* the test is there already */
    }
    NSString *file = [self beginnersCourseFile];
    if (file) {
        NSMenuItem *carrier = [[NSMenuItem alloc] initWithTitle:@"" action:NULL keyEquivalent:@""];
        [carrier setRepresentedObject:file];
        [self switchToCourse:carrier];
    } else {
        /* no course for this layout: let them pick */
        [self showCourses:self];
    }
}

/* HR_SMOKE_TEST=1: prove that the packaged app starts, that every outlet
 * in MainMenu.xib is connected, that a language pack was found and that a
 * test can be typed and scored -- then quit.  CI runs this against the
 * AppImage under Xvfb, where a unit test cannot reach. */
- (NSEvent *)keyEventWithCharacters:(NSString *)characters keyCode:(unsigned short)keyCode
{
    return [NSEvent keyEventWithType:NSEventTypeKeyDown
                            location:NSZeroPoint
                       modifierFlags:0
                           timestamp:HRMonotonicNow()
                        windowNumber:[_window windowNumber]
                             context:nil
                          characters:characters
         charactersIgnoringModifiers:characters
                           isARepeat:NO
                             keyCode:keyCode];
}

/* AppKit on macOS catches an exception thrown from a run-loop callback,
 * logs it and carries on -- which here would mean a CI job sitting until
 * its timeout.  So: catch, report, exit. */
- (void)runSmokeTest
{
    @try {
        [self runSmokeTestChecks];
    } @catch (id exception) {
        fprintf(stderr, "HomeRow smoke test: exception: %s\n", [[exception description] UTF8String]);
        exit(1);
    }
}

- (void)runSmokeTestChecks
{
    NSMutableArray *failures = [NSMutableArray array];
    NSDictionary *outlets = @{@"window": _window ?: [NSNull null], @"testView": _testView ?: [NSNull null],
        @"resultsView": _resultsView ?: [NSNull null], @"chartView": _chartView ?: [NSNull null],
        @"keyboardView": _keyboardView ?: [NSNull null],
        @"modePopUp": _modePopUp ?: [NSNull null], @"amountPopUp": _amountPopUp ?: [NSNull null],
        @"punctuationCheck": _punctuationCheck ?: [NSNull null], @"numbersCheck": _numbersCheck ?: [NSNull null],
        @"liveField": _liveField ?: [NSNull null], @"wpmField": _wpmField ?: [NSNull null],
        @"accuracyField": _accuracyField ?: [NSNull null], @"detailField": _detailField ?: [NSNull null],
        @"hintField": _hintField ?: [NSNull null]};
    for (NSString *name in outlets) {
        if (outlets[name] == [NSNull null]) [failures addObject:[NSString stringWithFormat:@"outlet %@ is not connected", name]];
    }
    if ([_languages count] == 0) [failures addObject:@"no language pack was loaded"];
    if (!_store) [failures addObject:@"the result store did not open"];

    _configuration.mode = HRTestModeWords;
    _configuration.amount = 10;
    [self syncControls];
    /* a pace caret at a speed of one's choosing, for the test below */
    NSUserDefaults *smokeDefaults = [NSUserDefaults standardUserDefaults];
    id paceKindBefore = [smokeDefaults objectForKey:HRPaceKindDefaultsKey], paceWpmBefore = [smokeDefaults objectForKey:HRPaceCustomWpmDefaultsKey];
    id soundBefore = [smokeDefaults objectForKey:HRSoundSchemeDefaultsKey];
    [smokeDefaults setInteger:HRPaceCustom forKey:HRPaceKindDefaultsKey];
    [smokeDefaults setInteger:30 forKey:HRPaceCustomWpmDefaultsKey];
    /* sounds on: where they cannot be made, typing must go on as if they were */
    if ([[HRSoundPlayer schemeNames] count] < 2) [failures addObject:@"the sound schemes were not found"];
    _sounds.scheme = [[HRSoundPlayer schemeNames] firstObject];
    printf("HomeRow smoke test: %lu sounds loaded from \"%s\"\n", (unsigned long)_sounds.loadedSounds, [_sounds.scheme UTF8String]);
    [self startNewTest];
    /* Real key events first, through -sendEvent:, because that is the path
     * a keyboard takes: keyDown: -> interpretKeyEvents: -> insertText: /
     * doCommandBySelector:.  One character, Backspace, then Tab. */
    if ([_session.words count] == 0) {
        fprintf(stderr, "HomeRow smoke test: the test has no words\n");
        exit(1);
    }
    NSString *firstCharacter = [((HRWord *)_session.words[0]).characters firstObject];
    [_window sendEvent:[self keyEventWithCharacters:firstCharacter keyCode:0]];
    if (_session.state != HRSessionRunning || [_session caretIndexInCurrentWord] != 1) {
        [failures addObject:@"a key event did not reach the session as a typed character"];
    }
    [_window sendEvent:[self keyEventWithCharacters:[NSString stringWithFormat:@"%C", (unichar)NSDeleteCharacter] keyCode:51]];
    if ([_session caretIndexInCurrentWord] != 0) {
        [failures addObject:@"Backspace did not delete the typed character"];
    }
    /* A dead key: the accent waits as marked text, is drawn, and the letter
     * that completes it arrives through -insertText:replacementRange: (the
     * path macOS takes; here it is walked by hand on both platforms). */
    [_testView setMarkedTextForTesting:@"\u00B4"];
    [[_window contentView] display];
    if (![_testView.markedText isEqualToString:@"\u00B4"]) [failures addObject:@"the typing view does not hold marked text"];
    if ([_session caretIndexInCurrentWord] != 0) [failures addObject:@"a pending accent counted as a typed character"];
    [(id)_testView insertText:firstCharacter replacementRange:NSMakeRange(NSNotFound, 0)];
    if (_testView.markedText != nil || [_session caretIndexInCurrentWord] != 1) {
        [failures addObject:@"completing a dead key did not type the character"];
    }
    [_testView setMarkedTextForTesting:@"\u00A8"];
    [_window sendEvent:[self keyEventWithCharacters:[NSString stringWithFormat:@"%C", (unichar)NSDeleteCharacter] keyCode:51]];
    /* whoever took that Backspace, the view must not be left waiting */
    [_testView setMarkedTextForTesting:nil];
    HRTestSession *beforeTab = _session;
    [_window sendEvent:[self keyEventWithCharacters:@"\t" keyCode:48]];
    if (_session == beforeTab) [failures addObject:@"Tab did not start a new test"];

    NSMutableArray *texts = [NSMutableArray array];
    for (HRWord *w in _session.words) [texts addObject:w.text];
    /* five seconds "ago" for the first word, so that the test has a
     * duration and is worth saving */
    NSTimeInterval now = HRMonotonicNow();
    NSUInteger before = [[_store recentResultsWithLimit:0 error:NULL] count];
    [_testView typeText:[texts[0] stringByAppendingString:@" "] atTime:now - 5.0];
    if (_paceWpm != 30.0) [failures addObject:@"the pace caret did not take the chosen speed"];
    [self movePaceCaret];
    [[_window contentView] display];
    /* 30 wpm for five seconds: twelve characters and a half into the text */
    NSUInteger paceWord = 0, paceCharacter = 0;
    [HRPace getWordIndex:&paceWord characterIndex:&paceCharacter forCharacters:12.5 inWords:_session.words];
    NSString *paceExpected = [NSString stringWithFormat:@"%lu:%lu", (unsigned long)paceWord, (unsigned long)paceCharacter];
    if (![_testView.paceCaretDescription isEqualToString:paceExpected]) {
        [failures addObject:[NSString stringWithFormat:@"the pace caret is at %@, not at %@", _testView.paceCaretDescription, paceExpected]];
    }
    [texts removeObjectAtIndex:0];
    [_testView typeText:[texts componentsJoinedByString:@" "] atTime:now];
    if (_store && [[_store recentResultsWithLimit:0 error:NULL] count] != before + 1) {
        [failures addObject:@"the result was not saved"];
    }
    if (_session.state != HRSessionFinished) [failures addObject:@"typing the whole text did not finish the test"];
    if ([_resultsView isHidden]) [failures addObject:@"the results were not shown"];
    if ([[_wpmField stringValue] length] == 0) [failures addObject:@"the results are empty"];
    if (_testView.paceCharacters >= 0.0) [failures addObject:@"the pace caret outlived the test"];

    /* Replay: the same test again, typed by nobody, and nothing saved */
    {
        NSUInteger saved = [[_store recentResultsWithLimit:0 error:NULL] count];
        double wpm = [_session summary].wpm;
        if ([[_hintField stringValue] rangeOfString:@"replay"].location == NSNotFound) [failures addObject:@"the result does not offer its replay"];
        [_window sendEvent:[self keyEventWithCharacters:@"r" keyCode:15]];
        if (!_replay || !_testView.replaying || [_testView isHidden] || ![_resultsView isHidden]) {
            [failures addObject:@"r on a result did not start its replay"];
        } else {
            [self advanceReplayToElapsed:2.5];
            /* the first word went in at once, the rest five seconds later */
            if (_replaySession.state != HRSessionRunning || _replaySession.currentWordIndex != 1) {
                [failures addObject:@"between the first word and the rest, the replay is somewhere else"];
            }
            [[_window contentView] display];
            NSUInteger caretBefore = [_replaySession caretIndexInCurrentWord];
            [_window sendEvent:[self keyEventWithCharacters:@"x" keyCode:7]];
            if ([_replaySession caretIndexInCurrentWord] != caretBefore) [failures addObject:@"a key got into a replay"];
            [self advanceReplayToElapsed:_replay.duration + 1.0];
            if (_replay || _testView.replaying || [_resultsView isHidden]) [failures addObject:@"the replay did not end on the result it came from"];
            /* once more, left with Esc */
            [self replayLastTest:self];
            [_window sendEvent:[self keyEventWithCharacters:@"\033" keyCode:53]];
            if (_replay || [_resultsView isHidden]) [failures addObject:@"Esc did not leave the replay for the result"];
        }
        if (fabs([_session summary].wpm - wpm) > 1e-9) [failures addObject:@"the replay changed the result"];
        if ([[_store recentResultsWithLimit:0 error:NULL] count] != saved) [failures addObject:@"a replay was saved as a result"];
    }
    for (NSArray *pair in @[@[HRPaceKindDefaultsKey, paceKindBefore ?: [NSNull null]], @[HRPaceCustomWpmDefaultsKey, paceWpmBefore ?: [NSNull null]]]) {
        if (pair[1] == [NSNull null]) [smokeDefaults removeObjectForKey:pair[0]];
        else [smokeDefaults setObject:pair[1] forKey:pair[0]];
    }

    /* Follow a course the way the Courses window makes one do it: choose
     * it, continue, read the pages, type the drills -- and find the place
     * kept and the lesson recorded afterwards. */
    [_store resetCourse:@"q.typ" error:NULL];
    [_store resetCourse:@"p.typ" error:NULL];
    [self courseWindow:nil didSelectCourse:@"q.typ"];
    [self continueCourse:self];
    if (!_run) {
        [failures addObject:@"the first lesson of q.typ did not start"];
    } else {
        if (!_keyboardShown || [_keyboardView isHidden]) [failures addObject:@"the keyboard is not shown in a course"];
        /* a German course is followed for a moment: its results are German, the tests stay as they were */
        {
            NSString *languageBefore = [_configuration.languageID copy];
            NSString *german = nil;
            for (NSDictionary *course in _courses) if ([course[@"language"] isEqual:@"german"]) { german = course[@"file"]; break; }
            if (german) {
                /* leave no trace of it: unless the course was already being followed, forget it again */
                BOOL followed = [_store progressForCourse:german] != nil;
                [self startLesson:0 ofCourse:german atStep:0];
                for (NSUInteger guard = 0; _run && _testView.pageText && guard < 50; guard++) [self testViewDidDismissPage:_testView];
                if (_session && ![_session.configuration.languageID isEqualToString:@"german"]) {
                    [failures addObject:@"a German lesson does not record its language"];
                }
                if (![_configuration.languageID isEqual:languageBefore]) [failures addObject:@"following a German course changed the language of the tests"];
                if (!followed) [_store resetCourse:german error:NULL];
                [self startLesson:0 ofCourse:@"q.typ" atStep:0];
            }
        }
        NSRect contentBounds = [[_window contentView] bounds];
        if (NSMaxY([_modePopUp frame]) < NSMaxY(contentBounds) - 30.0
            || NSMaxY([_testView frame]) > NSMinY([_modePopUp frame])
            || NSMinY([_testView frame]) < NSMaxY([_keyboardView frame]) - 0.5) {
            [failures addObject:@"with the keyboard up, the control bar, typing view and keyboard overlap"];
        }
        if (![_amountPopUp isHidden] || ![_modePopUp isHidden]) [failures addObject:@"the test controls are still showing in a course"];
        if (![[[[NSApp mainMenu] itemWithTitle:@"Test"] submenu] itemWithTitle:HRLoc(@"Time Test")]) {
            [failures addObject:@"there is no way out of the course: Test > Time Test is missing"];
        }
        NSUInteger pages = 0, exercises = 0;
        NSString *lit = nil;
        NSTimeInterval t = HRMonotonicNow();
        for (NSUInteger guard = 0; _run && guard < 1000; guard++) {
            HRTypStep *step = [_run currentStep];
            if (_testView.pageText) { pages++; [self testViewDidDismissPage:_testView]; }
            else {
                if (!lit) lit = [_keyboardView litKeyDescription];
                exercises++; t += 10.0; [_testView typeText:step.text atTime:t];
            }
        }
        if (_run) [failures addObject:@"the lesson did not come to an end"];
        if (pages == 0 || exercises == 0) [failures addObject:@"the lesson had no pages or no exercises"];
        if (![lit hasPrefix:@"key:"]) [failures addObject:@"the keyboard did not light the first key of the first drill"];
        if ([_resultsView isHidden]) [failures addObject:@"the lesson did not end on the results"];
        if (_store) {
            HRCourseProgress *progress = [_store progressForCourse:@"q.typ"];
            if ([progress.lessonIndex integerValue] != 1 || [progress.stepIndex integerValue] != 0) {
                [failures addObject:@"the course did not move on to its second lesson"];
            }
            HRLessonRecord *record = [_store lessonRecordsForCourse:@"q.typ"][@0];
            if ([record.completions integerValue] != 1) [failures addObject:@"the finished lesson was not recorded"];
        }
        /* Return on the results: the next lesson, not a free test */
        [self restartTest:self];
        if (!_run || _lessonIndex != 1) [failures addObject:@"Return after a lesson did not start the next one"];
        /* taking the first lesson again is practice: recorded, but the
         * place in the course stays at lesson two */
        [self courseWindow:nil didRequestLesson:0];
        for (NSUInteger guard = 0; _run && guard < 1000; guard++) {
            if (_testView.pageText) [self testViewDidDismissPage:_testView];
            else { t += 10.0; [_testView typeText:[_run currentStep].text atTime:t]; }
        }
        if (_store) {
            if ([[_store progressForCourse:@"q.typ"].lessonIndex integerValue] != 1) {
                [failures addObject:@"taking a lesson again moved the place in the course"];
            }
            HRLessonRecord *again = [_store lessonRecordsForCourse:@"q.typ"][@0];
            if ([again.completions integerValue] != 2) [failures addObject:@"the lesson taken again was not recorded"];
        }
        /* a second course alongside: start it, switch back, and find the
         * first one where it was */
        [self courseWindow:nil didSelectCourse:@"p.typ"];
        [self continueCourse:self];
        if (![_courseFile isEqual:@"p.typ"] || _lessonIndex != 0) [failures addObject:@"a second course did not start"];
        [self rebuildStartedCourseItems];
        NSMenuItem *back = nil;
        for (NSMenuItem *item in _startedCourseItems) if ([[item representedObject] isEqual:@"q.typ"]) back = item;
        if (!back) {
            [failures addObject:@"the Course menu does not list the courses in progress"];
        } else {
            [self switchToCourse:back];
            if (![_courseFile isEqual:@"q.typ"] || _lessonIndex != 1) [failures addObject:@"switching back did not return to the first course's place"];
            if (_store && [[_store progressForCourse:@"p.typ"].lessonIndex integerValue] != 0) [failures addObject:@"the other course lost its place"];
        }
        [[self courseWindow] showWindow:self];
        if ([[self courseWindow].lessonTable numberOfRows] < 2) [failures addObject:@"the Courses window lists no lessons"];
        [[[self courseWindow] window] orderOut:self];
        printf("HomeRow smoke test: lesson with %lu pages and %lu exercises, first key %s\n",
               (unsigned long)pages, (unsigned long)exercises, [lit UTF8String] ?: "-");
    }
    /* Code: every bundled file must load and cut into sections (a grammar
     * that fails to compile shows up here), and one section must type
     * through, be recorded, and hand over to the next. */
    {
        HRCodeLibrary *library = [self codeLibrary];
        NSUInteger files = 0;
        HRCodeFile *first = nil;
        if ([library.languages count] == 0) [failures addObject:@"no code languages were found"];
        for (HRCodeLanguage *language in library.languages) {
            if (![library grammarForLanguage:language]) {
                [failures addObject:[NSString stringWithFormat:@"the %@ grammar did not load", language.identifier]];
            }
            for (HRCodeFile *file in [library filesForLanguage:language]) {
                if (!file.isBundled) continue;
                HRCodeDocument *document = [library documentForFile:file error:NULL];
                if (document.numberOfSections == 0) {
                    [failures addObject:[NSString stringWithFormat:@"%@ has no sections", file.identifier]];
                }
                files++;
                if (!first && [language.identifier isEqualToString:@"c"]) first = file;
            }
        }
        if (first) {
            [_store resetCourse:first.identifier error:NULL];
            [self codeWindow:nil didRequestFile:first section:0];
            if (!_codeFile || !_testView.codeLayout || _configuration.mode != HRTestModeCode) {
                [failures addObject:@"a section of code did not start"];
            }
            if (![_modePopUp isHidden]) [failures addObject:@"the test controls are still showing in code mode"];
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:HRKeyboardInCodeDefaultsKey];
            [self syncKeyboard];
            if (!_keyboardShown || [_keyboardView isHidden]) [failures addObject:@"the keyboard is not shown in code mode"];
            if (![[_keyboardView litKeyDescription] hasPrefix:@"key:"]) [failures addObject:@"the keyboard did not light the first key of the code"];
            if (NSMinY([_testView frame]) < NSMaxY([_keyboardView frame]) - 0.5) [failures addObject:@"the keyboard covers the code"];
            NSMutableString *text = [NSMutableString string];
            BOOL styled = NO;
            NSUInteger count = [_session.words count];
            for (NSUInteger i = 0; i < count; i++) {
                HRWord *w = _session.words[i];
                [text appendString:w.text];
                if (i + 1 < count) [text appendString:(w.separator == HRSeparatorNewline ? @"\n" : @" ")];
                for (NSUInteger c = 0; c < [w.characters count]; c++) {
                    if ([w styleOfCharacterAtIndex:c] != HRTextStylePlain) styled = YES;
                }
            }
            if (!styled) [failures addObject:@"the code has no syntax colouring"];
            [[_window contentView] display];
            /* a wrong key must not go in */
            [_testView typeText:@"§" atTime:HRMonotonicNow() - 20.0];
            if ([_session caretIndexInCurrentWord] != 0) [failures addObject:@"code mode let a wrong key in"];
            if (_session.wrongInputCount != 1 || !_session.lastWrongInputWasRefused) {
                [failures addObject:@"the refused key was not reported for feedback"];
            }
            [[_window contentView] display];   /* with the flash on */
            [_testView typeText:text atTime:HRMonotonicNow()];
            if (_session.state != HRSessionFinished || [_resultsView isHidden]) {
                [failures addObject:@"typing a section of code did not finish it"];
            }
            if (_store) {
                HRLessonRecord *record = [_store lessonRecordsForCourse:first.identifier][@0];
                if ([record.completions integerValue] != 1) [failures addObject:@"the section of code was not recorded"];
                if ([[_store progressForCourse:first.identifier].lessonIndex integerValue] != 1) {
                    [failures addObject:@"the file did not move on to its second part"];
                }
            }
            [self restartTest:self];
            if (!_codeFile || _codeSection != 1) [failures addObject:@"Return after a section did not start the next one"];
            [[_window contentView] display];
            [[self codeWindow] showWindow:self];
            if ([[self codeWindow].sectionTable numberOfRows] < 2) [failures addObject:@"the Code window lists no sections"];
            if (![self codeWindow].folderButton || ![self codeWindow].removeButton) {
                [failures addObject:@"CodeWindow.xib: the folder or the remove button is not connected"];
            }
            [_store resetCourse:first.identifier error:NULL];

            /* a folder of one's own, with Tab typed where the code goes deeper */
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            id tabsBefore = [defaults objectForKey:HRCodeTypeTabsDefaultsKey];
            id foldersBefore = [defaults objectForKey:HRCodeUserFoldersDefaultsKey];
            id filesBefore = [defaults objectForKey:HRCodeUserFilesDefaultsKey];
            NSString *folder = [NSTemporaryDirectory() stringByAppendingPathComponent:
                                [NSString stringWithFormat:@"homerow-smoke-%d", (int)[[NSProcessInfo processInfo] processIdentifier]]];
            [[NSFileManager defaultManager] createDirectoryAtPath:[folder stringByAppendingPathComponent:@"node_modules"]
                                      withIntermediateDirectories:YES attributes:nil error:NULL];
            NSString *source = @"int f(int x)\n{\n    if (x) {\n        return 1;\n    }\n    return 0;\n}\n";
            [source writeToFile:[folder stringByAppendingPathComponent:@"smoke.c"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
            [source writeToFile:[folder stringByAppendingPathComponent:@"node_modules/skipped.c"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
            if (![[self codeWindow] addPaths:@[folder]]) [failures addObject:@"a folder of code was not taken in"];
            HRCodeFile *mine = nil;
            NSUInteger fromFolder = 0;
            for (HRCodeFile *file in [library filesForLanguage:[library languageWithIdentifier:@"c"]]) {
                if ([[library folderOfFile:file] isEqualToString:folder]) { fromFolder++; mine = file; }
            }
            if (fromFolder != 1) [failures addObject:[NSString stringWithFormat:@"the folder brought %lu files, not the one outside node_modules", (unsigned long)fromFolder]];
            if (mine) {
                [defaults setBool:YES forKey:HRCodeTypeTabsDefaultsKey];
                [self codeWindow:nil didRequestFile:mine section:0];
                NSMutableString *typed = [NSMutableString string];
                NSUInteger tabs = 0, n = [_session.words count];
                for (NSUInteger i = 0; i < n; i++) {
                    HRWord *w = _session.words[i];
                    if ([w.text hasPrefix:@"\t"]) tabs++;
                    [typed appendString:w.text];
                    if (i + 1 < n) [typed appendString:(w.separator == HRSeparatorNewline ? @"\n" : @" ")];
                }
                if (tabs != 2) [failures addObject:[NSString stringWithFormat:@"%lu Tabs to type where the code goes deeper twice", (unsigned long)tabs]];
                if (![[_keyboardView litKeyDescription] hasPrefix:@"key:"]) [failures addObject:@"no key is lit at the start of one's own file"];
                [[_window contentView] display];   /* the arrows of the Tabs */
                [_testView typeText:typed atTime:HRMonotonicNow()];
                if (_session.state != HRSessionFinished) [failures addObject:@"a section with Tabs in it did not type through"];
                if ([[_detailField stringValue] rangeOfString:@"overhead"].location == NSNotFound) {
                    [failures addObject:@"the result of a section of code does not give the keystroke overhead"];
                }
                [defaults setBool:NO forKey:HRCodeTypeTabsDefaultsKey];
                [self codeWindow:nil didRequestFile:mine section:0];
                for (HRWord *w in _session.words) {
                    if ([w.text rangeOfString:@"\t"].location != NSNotFound) { [failures addObject:@"Tab is asked for with the preference off"]; break; }
                }
                [[self codeWindow] revealFile:mine section:0];
                [[self codeWindow] removeSelected:self];
                if ([library fileWithIdentifier:mine.identifier]) [failures addObject:@"removing a folder left its files"];
                [_store resetCourse:mine.identifier error:NULL];
            }
            [[NSFileManager defaultManager] removeItemAtPath:folder error:NULL];
            for (NSArray *pair in @[@[HRCodeTypeTabsDefaultsKey, tabsBefore ?: [NSNull null]],
                                    @[HRCodeUserFoldersDefaultsKey, foldersBefore ?: [NSNull null]],
                                    @[HRCodeUserFilesDefaultsKey, filesBefore ?: [NSNull null]]]) {
                if (pair[1] == [NSNull null]) [defaults removeObjectForKey:pair[0]];
                else [defaults setObject:pair[1] forKey:pair[0]];
            }
            [[[self codeWindow] window] orderOut:self];
        } else {
            [failures addObject:@"there is no C file to type"];
        }
        printf("HomeRow smoke test: %lu code files in %lu languages\n",
               (unsigned long)files, (unsigned long)[library.languages count]);
    }
    /* a keyword list is a language like any other, under its own submenu,
     * typed as it stands */
    {
        NSMenuItem *python = (NSMenuItem *)[_programmingMenu itemWithTitle:@"Python"];
        if (!python || [_languageMenu itemWithTitle:@"Python"]) [failures addObject:@"Python's keywords are not under Language > Programming"];
        if (python) {
            BOOL punctuationBefore = _configuration.punctuation;
            _configuration.punctuation = YES;
            [self selectLanguage:python];
            if (![self currentLanguage].isCode || [_session.words count] == 0) [failures addObject:@"choosing Python did not start a test of its keywords"];
            if ([_punctuationCheck isEnabled]) [failures addObject:@"punctuation is on offer for a keyword list"];
            if ([_programmingItem state] != NSControlStateValueMixed) [failures addObject:@"the Programming submenu does not show that the language is inside it"];
            _configuration.punctuation = punctuationBefore;
        }
    }
    [self selectLanguage:[_languageMenu itemWithTitle:@"Russian"]];
    if (_keyboardShown) [failures addObject:@"the keyboard stayed up outside the course"];
    if (_codeFile || _testView.codeLayout) [failures addObject:@"the code layout stayed on outside code mode"];
    if ([_amountPopUp isHidden] || [_modePopUp isHidden] || NSMaxY([_modePopUp frame]) < NSMaxY([[_window contentView] bounds]) - 30.0
        || fabs(NSMinY([_testView frame])) > 0.5 || NSMaxY([_testView frame]) > NSMinY([_modePopUp frame])) {
        [failures addObject:@"after the course, the window did not go back to its test layout"];
    }
    if (![[self currentLanguage].identifier isEqualToString:@"russian"] || _session == nil
        || [_session.words count] == 0) {
        [failures addObject:@"switching to Russian did not start a Russian test"];
    }
    if ([_wordListMenu numberOfItems] < 2) [failures addObject:@"the word-list menu was not rebuilt"];

    /* Statistics: by now there are results of all three kinds in the store */
    {
        HRStatsWindowController *stats = [self statsWindow];
        [stats showWindow:self];
        stats.pane = HRStatsPaneOverview;
        [[stats kindPopUp] selectItemWithTag:HRStatKindAll];
        [[stats periodPopUp] selectItemWithTag:0];
        [stats filterChanged:self];
        NSDictionary *statsOutlets = @{@"kindPopUp": stats.kindPopUp ?: [NSNull null], @"periodPopUp": stats.periodPopUp ?: [NSNull null],
            @"tilesView": (id)stats.tilesView ?: [NSNull null], @"speedPlot": (id)stats.speedPlot ?: [NSNull null],
            @"accuracyPlot": (id)stats.accuracyPlot ?: [NSNull null], @"daysPlot": (id)stats.daysPlot ?: [NSNull null],
            @"keyboardView": (id)stats.keyboardView ?: [NSNull null], @"keysField": stats.keysField ?: [NSNull null],
            @"practiceButton": (id)stats.practiceButton ?: [NSNull null],
            @"tabView": (id)stats.tabView ?: [NSNull null], @"heatPopUp": (id)stats.heatPopUp ?: [NSNull null],
            @"historyScroll": (id)stats.historyScroll ?: [NSNull null], @"historyTable": (id)stats.historyTable ?: [NSNull null],
            @"resultChart": (id)stats.resultChart ?: [NSNull null], @"resultField": (id)stats.resultField ?: [NSNull null],
            @"deleteButton": (id)stats.deleteButton ?: [NSNull null], @"exportButton": (id)stats.exportButton ?: [NSNull null],
            @"importButton": (id)stats.importButton ?: [NSNull null], @"subjectPopUp": (id)stats.subjectPopUp ?: [NSNull null],
            @"progressField": (id)stats.progressField ?: [NSNull null], @"lessonSpeedPlot": (id)stats.lessonSpeedPlot ?: [NSNull null],
            @"lessonAccuracyPlot": (id)stats.lessonAccuracyPlot ?: [NSNull null]};
        for (NSString *name in statsOutlets) {
            if (statsOutlets[name] == [NSNull null]) [failures addObject:[NSString stringWithFormat:@"StatsWindow.xib: outlet %@ is not connected", name]];
        }
        if (_store) {
            /* on a machine that never ran HomeRow that is two: the words
             * test and the section of code (the lesson's drills are typed
             * in no time at all, and a result without a duration is not
             * kept).  Whatever else the store holds is shown too. */
            NSUInteger saved = [[_store recentResultsWithLimit:0 error:NULL] count];
            if (saved < 2 || [stats.speedPlot.values count] != saved) {
                [failures addObject:[NSString stringWithFormat:@"the statistics show %lu results, the store holds %lu (at least 2 expected)",
                                     (unsigned long)[stats.speedPlot.values count], (unsigned long)saved]];
            }
            if ([stats.daysPlot.values count] < 1) [failures addObject:@"the statistics show no day of practice"];
            if ([stats.speedPlot.trend count] != [stats.speedPlot.values count]) [failures addObject:@"the speed chart has no trend line"];
            if ([stats.keyboardView.heatCounts count] == 0) [failures addObject:@"the statistics have no key counts for the heatmap"];
            double lo = 0.0, hi = 0.0;
            [stats.accuracyPlot getAxisMinimum:&lo maximum:&hi];
            if (!(lo < hi) || hi > 100.0 || lo < 0.0) [failures addObject:@"the accuracy chart's axis is not within 0...100"];
            [stats.daysPlot getAxisMinimum:&lo maximum:&hi];
            if (lo != 0.0 || !(hi > 0.0)) [failures addObject:@"the bars of the practice chart do not start at zero"];
            /* values that differ in the last bits only once hung the grid loop */
            HRPlotView *probe = [[HRPlotView alloc] initWithFrame:NSMakeRect(0, 0, 300, 120)];
            probe.trend = @[@99.675324675324674];
            probe.values = @[@99.675324675324703];
            [probe getAxisMinimum:&lo maximum:&hi];
            if (!(hi - lo >= 0.5)) [failures addObject:@"a chart of near-equal values has no axis range"];
            [[[stats window] contentView] addSubview:probe];
            [probe display];
            [probe removeFromSuperview];
            /* a key shows the worst of its characters, as the list under it does */
            HRKeyboardView *board = [[HRKeyboardView alloc] initWithFrame:NSMakeRect(0, 0, 600, 200)];
            board.keyboardLayout = [self layoutNamed:@"qwerty"];
            board.heatMinimumPresses = 10;
            board.heatCounts = @{@"3": @{@"hits": @200, @"misses": @0}, @"#": @{@"hits": @20, @"misses": @10},
                                 @"q": @{@"hits": @2, @"misses": @2}};
            HRKeyPosition *hash = [board.keyboardLayout positionOfCharacter:@"#"];
            HRKeyPosition *q = [board.keyboardLayout positionOfCharacter:@"q"];
            if (fabs([board heatRateForKeyAtRow:hash.row column:hash.column] - 1.0 / 3.0) > 1e-9) {
                [failures addObject:@"the heatmap hides a badly missed # behind a well-typed 3"];
            }
            if ([board heatRateForKeyAtRow:q.row column:q.column] >= 0.0) [failures addObject:@"the heatmap judges a key on four presses"];
            stats.speedPlot.highlightedIndex = 0;
            if ([[stats.speedPlot readout] length] == 0) [failures addObject:@"the speed chart has no read-out"];
            [[stats kindPopUp] selectItemWithTag:HRStatKindCode];
            [stats filterChanged:self];
            if ([stats.speedPlot.values count] < 1) [failures addObject:@"the statistics do not show the section of code that was typed"];
        }
        if (!NSContainsRect([[[stats window] contentView] bounds], [stats.tabView frame])) [failures addObject:@"the Statistics tabs leave the window"];
        NSRect previous = NSZeroRect;
        for (NSView *v in @[stats.keysField ?: (id)_window.contentView, stats.keyboardView ?: (id)_window.contentView,
                            stats.heatPopUp ?: (id)_window.contentView, stats.daysPlot ?: (id)_window.contentView,
                            stats.accuracyPlot ?: (id)_window.contentView, stats.speedPlot ?: (id)_window.contentView, stats.tilesView ?: (id)_window.contentView]) {
            if (!NSContainsRect([[v superview] bounds], [v frame]) || NSMinY([v frame]) < NSMaxY(previous) - 0.5) {
                [failures addObject:@"the Statistics window's views overlap or leave their pane"];
                break;
            }
            previous = [v frame];
        }
        [[[stats window] contentView] display];
        printf("HomeRow smoke test: statistics over %lu results, %lu days\n",
               (unsigned long)[stats.speedPlot.values count], (unsigned long)[stats.daysPlot.values count]);

        /* the keyboard by speed: the words test above was typed in two goes
         * with no time between the keys, so there is nothing timed yet --
         * and the pane must say so rather than show an empty board as news */
        [[stats kindPopUp] selectItemWithTag:HRStatKindAll];
        [[stats heatPopUp] selectItemWithTag:1];
        [stats heatChanged:self];
        if (!stats.keyboardView.heatShowsSpeed) [failures addObject:@"Keys by speed did not switch the heatmap"];
        [[[stats window] contentView] display];
        [[stats heatPopUp] selectItemWithTag:0];
        [stats heatChanged:self];

        if (_store) {
            /* History: every result listed, the chart follows the selection,
             * out to a file and back without doubling, and one can be deleted */
            stats.pane = HRStatsPaneHistory;
            NSUInteger saved = [[_store recentResultsWithLimit:0 error:NULL] count];
            if ([stats.historyTable numberOfRows] != (NSInteger)saved) [failures addObject:@"the History pane does not list every result"];
            if ([stats.historyTable selectedRow] != 0 || [[stats.resultField stringValue] length] == 0) {
                [failures addObject:@"the History pane does not show the newest result"];
            }
            if ([stats.tilesView window] != nil || [stats.historyScroll window] == nil) [failures addObject:@"switching panes did not switch the views"];
            if (!NSContainsRect([[stats.historyScroll superview] bounds], [stats.historyScroll frame])
                || NSMinY([stats.historyScroll frame]) < NSMaxY([stats.resultChart frame])) {
                [failures addObject:@"the History pane's views overlap or leave the window"];
            }
            [[[stats window] contentView] display];
            NSString *directory = [NSTemporaryDirectory() stringByAppendingPathComponent:
                                   [NSString stringWithFormat:@"homerow-smoke-%d", (int)[[NSProcessInfo processInfo] processIdentifier]]];
            [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:NULL];
            NSError *error = nil;
            for (NSString *name in @[@"results.json", @"results.csv"]) {
                NSURL *url = [NSURL fileURLWithPath:[directory stringByAppendingPathComponent:name]];
                if (![stats exportToURL:url error:&error]) {
                    [failures addObject:[NSString stringWithFormat:@"%@ was not exported: %@", name, error]];
                    continue;
                }
                NSString *said = [stats importFromURL:url error:&error];
                if (!said) [failures addObject:[NSString stringWithFormat:@"%@ was not read back: %@", name, error]];
                if ([[_store recentResultsWithLimit:0 error:NULL] count] != saved) {
                    [failures addObject:[NSString stringWithFormat:@"importing our own %@ doubled the history", name]];
                }
            }
            [[NSFileManager defaultManager] removeItemAtPath:directory error:NULL];
            if ([stats respondsToSelector:@selector(deleteSelectedResultWithoutAsking)]) {
                [stats performSelector:@selector(deleteSelectedResultWithoutAsking)];
                if ([[_store recentResultsWithLimit:0 error:NULL] count] != saved - 1 || [stats.historyTable numberOfRows] != (NSInteger)saved - 1) {
                    [failures addObject:@"deleting a result did not remove it"];
                }
            }

            /* Progress: the course and the code file typed above are both there */
            stats.pane = HRStatsPaneProgress;
            if ([stats.subjectPopUp numberOfItems] < 1) [failures addObject:@"the Progress pane lists no course"];
            if ([stats.lessonSpeedPlot.values count] < 2) [failures addObject:@"the Progress pane shows no lessons"];
            /* (no speeds to check: the drills above were typed in no time at all) */
            if ([[stats.progressField stringValue] length] == 0) [failures addObject:@"the Progress pane says nothing about the course"];
            if ([stats.lessonSpeedPlot window] == nil || [stats.historyScroll window] != nil) [failures addObject:@"the Progress pane did not take the window over"];
            [[[stats window] contentView] display];
            stats.pane = HRStatsPaneOverview;
        }
        [[stats window] orderOut:self];
    }

    /* Weak-spot practice: with next to nothing on record it says so; with
     * weak keys to go by, the round is made of them. */
    {
        [self practiseWeakKeys:self];
        if (_configuration.mode != HRTestModePractice) [failures addObject:@"Practise Weak Keys did not switch to practice"];
        if (![self currentWeakSpots] && _testView.pageText == nil) {
            [failures addObject:@"with nothing to go by, practice did not say so"];
        }
        _weakSpotsForTesting = [HRWeakSpots weakSpotsFromCounts:@{@"e": @{@"hits": @2000, @"misses": @10},
                                                                   @"q": @{@"hits": @30, @"misses": @10},
                                                                   @"#": @{@"hits": @20, @"misses": @10}}
                                              minimumKeyPresses:10 minimumTotalPresses:300 maximum:6];
        [self startNewTest];
        NSUInteger withWeak = 0;
        for (HRWord *w in _session.words) {
            if ([w.text rangeOfString:@"q"].location != NSNotFound || [w.text rangeOfString:@"#"].location != NSNotFound) withWeak++;
        }
        if (_testView.pageText != nil || [_session.words count] == 0) [failures addObject:@"a practice round did not start"];
        /* the draw is random and q is rare in any word list: a handful, not a share
         * (the unit tests pin the shares down with a seed) */
        else if (withWeak < 2) [failures addObject:@"the practice round hardly contains the weak keys"];
        if ([_testView.caption rangeOfString:@"#"].location == NSNotFound) [failures addObject:@"the practice round does not say which keys it is for"];
        if ([_modePopUp isHidden]) [failures addObject:@"the mode pop-up is hidden in practice"];
        [[_window contentView] display];
        NSMutableArray *practiceTexts = [NSMutableArray array];
        for (HRWord *w in _session.words) [practiceTexts addObject:w.text];
        NSUInteger savedBefore = [[_store recentResultsWithLimit:0 error:NULL] count];
        if ([practiceTexts count] > 0) {
            [_testView typeText:[practiceTexts[0] stringByAppendingString:@" "] atTime:HRMonotonicNow() - 8.0];
            [practiceTexts removeObjectAtIndex:0];
            /* the source hands words out as they are needed: type what there is until it is done */
            for (NSUInteger guard = 0; _session.state != HRSessionFinished && guard < 200; guard++) {
                HRWord *w = _session.currentWordIndex < [_session.words count] ? _session.words[_session.currentWordIndex] : nil;
                if (!w) break;
                BOOL last = (_session.currentWordIndex + 1 == [_session.words count]);
                [_testView typeText:(last ? w.text : [w.text stringByAppendingString:@" "]) atTime:HRMonotonicNow()];
                if (last && _session.state != HRSessionFinished) [_testView typeText:@" " atTime:HRMonotonicNow()];
            }
        }
        if (_session.state != HRSessionFinished) [failures addObject:@"the practice round did not come to an end"];
        if (_store && [[_store recentResultsWithLimit:0 error:NULL] count] != savedBefore + 1) [failures addObject:@"the practice round was not saved"];
        if (_store && ![[(HRTestResult *)[[_store recentResultsWithLimit:1 error:NULL] firstObject] mode] isEqualToString:@"practice"]) {
            [failures addObject:@"the practice round was not saved as practice"];
        }
        _weakSpotsForTesting = nil;
        [_modePopUp selectItemWithTag:HRTestModeTime];
        [self modeChanged:self];
    }

    /* Preferences: every control connected, and a change made there takes
     * effect here -- then everything is put back as it was found. */
    {
        NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
        NSArray *keys = @[HRThemeDefaultsKey, HRProseFontSizeDefaultsKey, HRCodeFontSizeDefaultsKey, HRFontFamilyDefaultsKey,
                          HRBeepOnErrorDefaultsKey, HRKeyboardInTestsDefaultsKey];
        NSMutableDictionary *before = [NSMutableDictionary dictionary];
        for (NSString *key in keys) if ([d objectForKey:key]) before[key] = [d objectForKey:key];
        HRStopPolicy stopBefore = _configuration.stopPolicy;
        HRBackspacePolicy backspaceBefore = _configuration.backspacePolicy;

        HRPreferencesWindowController *prefs = [self preferencesWindow];
        [prefs showWindow:self];
        [prefs sync];
        NSDictionary *prefsOutlets = @{@"themePopUp": prefs.themePopUp ?: (id)[NSNull null], @"fontPopUp": prefs.fontPopUp ?: (id)[NSNull null],
            @"proseSizePopUp": prefs.proseSizePopUp ?: (id)[NSNull null], @"codeSizePopUp": prefs.codeSizePopUp ?: (id)[NSNull null],
            @"stopPopUp": prefs.stopPopUp ?: (id)[NSNull null], @"backspacePopUp": prefs.backspacePopUp ?: (id)[NSNull null],
            @"beepCheck": prefs.beepCheck ?: (id)[NSNull null], @"layoutField": prefs.layoutField ?: (id)[NSNull null],
            @"layoutButton": prefs.layoutButton ?: (id)[NSNull null],
            @"keyboardCourseCheck": prefs.keyboardCourseCheck ?: (id)[NSNull null], @"keyboardCodeCheck": prefs.keyboardCodeCheck ?: (id)[NSNull null],
            @"keyboardTestsCheck": prefs.keyboardTestsCheck ?: (id)[NSNull null], @"commentsCheck": prefs.commentsCheck ?: (id)[NSNull null],
            @"codeFontPopUp": prefs.codeFontPopUp ?: (id)[NSNull null], @"tabsCheck": prefs.tabsCheck ?: (id)[NSNull null],
            @"pacePopUp": prefs.pacePopUp ?: (id)[NSNull null], @"paceField": prefs.paceField ?: (id)[NSNull null],
            @"soundPopUp": prefs.soundPopUp ?: (id)[NSNull null],
            @"dataField": prefs.dataField ?: (id)[NSNull null], @"revealButton": prefs.revealButton ?: (id)[NSNull null]};
        for (NSString *name in prefsOutlets) {
            if (prefsOutlets[name] == [NSNull null]) [failures addObject:[NSString stringWithFormat:@"PreferencesWindow.xib: outlet %@ is not connected", name]];
        }
        if (![[prefs.layoutField stringValue] isEqualToString:[HRLayoutChooserController titleForIdentifier:_configuration.layoutID]]) {
            [failures addObject:@"Preferences does not show the current layout"];
        }
        /* the layout chooser: searched, previewed, chosen -- and put back */
        {
            NSString *layoutBefore = [_configuration.layoutID copy];
            HRLayoutChooserController *chooser = [self layoutChooser];
            [prefs chooseLayout:self];
            NSDictionary *chooserOutlets = @{@"searchField": chooser.searchField ?: (id)[NSNull null], @"layoutTable": chooser.layoutTable ?: (id)[NSNull null],
                @"keyboardView": chooser.keyboardView ?: (id)[NSNull null], @"chooseButton": chooser.chooseButton ?: (id)[NSNull null],
                @"countField": chooser.countField ?: (id)[NSNull null]};
            for (NSString *name in chooserOutlets) {
                if (chooserOutlets[name] == [NSNull null]) [failures addObject:[NSString stringWithFormat:@"LayoutChooser.xib: outlet %@ is not connected", name]];
            }
            NSArray *everything = [chooser identifiersMatching:@""];
            if ([everything count] < 100 || ![[everything firstObject] isEqualToString:@"qwerty"]) {
                [failures addObject:@"the layout chooser does not lead with the well-known layouts"];
            }
            NSArray *colemaks = [chooser identifiersMatching:@"col dh"];
            if ([colemaks count] == 0 || [colemaks count] > 20 || ![colemaks containsObject:@"colemak_dh"]) {
                [failures addObject:@"searching the layouts for \"col dh\" does not find colemak dh"];
            }
            if ([[chooser identifiersMatching:@"zzzz"] count] != 0) [failures addObject:@"a search that matches nothing still lists layouts"];
            [chooser.searchField setStringValue:@"dvorak"];
            [chooser searchChanged:self];
            if ([chooser.layoutTable numberOfRows] < 1 || [chooser.layoutTable numberOfRows] >= (NSInteger)[everything count]) {
                [failures addObject:@"the layout list does not follow the search field"];
            }
            if (![chooser.keyboardView.keyboardLayout.identifier isEqualToString:@"dvorak"]) {
                [failures addObject:@"the layout chooser does not preview the selected layout"];
            }
            [[[chooser window] contentView] display];
            [chooser choose:self];
            if (![_configuration.layoutID isEqualToString:@"dvorak"] || ![[prefs.layoutField stringValue] isEqualToString:@"dvorak"]) {
                [failures addObject:@"choosing a layout did not take effect"];
            }
            if ([[_layoutMenuItem title] rangeOfString:@"dvorak"].location == NSNotFound) [failures addObject:@"the Language menu does not name the layout"];
            [self layoutChooser:chooser didChoose:layoutBefore];
        }

        HRTestSession *sessionBefore = _session;
        [prefs.stopPopUp selectItemAtIndex:2];       /* on every word */
        [prefs.backspacePopUp selectItemAtIndex:1];  /* current word only */
        [prefs.themePopUp selectItemAtIndex:([_theme.name isEqualToString:@"dark"] ? 1 : 2)];
        [prefs.proseSizePopUp selectItemAtIndex:0];  /* 16 */
        [prefs.keyboardTestsCheck setState:NSControlStateValueOn];
        NSString *themeBefore = [_theme.name copy];
        [prefs changed:self];
        if (_configuration.stopPolicy != HRStopOnWord || _configuration.backspacePolicy != HRBackspaceCurrentWord) {
            [failures addObject:@"Preferences did not change the typing rules"];
        }
        if (_session == sessionBefore || _session.configuration.stopPolicy != HRStopOnWord) {
            [failures addObject:@"the test under way did not start over under the new rules"];
        }
        if ([_theme.name isEqualToString:themeBefore] || _testView.theme != _theme) [failures addObject:@"Preferences did not switch the theme"];
        if (fabs([_testView.font pointSize] - 16.0) > 0.01) [failures addObject:@"Preferences did not change the text size"];
        if (!_keyboardShown) [failures addObject:@"Preferences did not bring up the keyboard"];
        NSDictionary *saved = [d dictionaryForKey:HRConfigurationDefaultsKey];
        if ([saved[@"stopPolicy"] integerValue] != HRStopOnWord) [failures addObject:@"Preferences did not save the configuration"];
        [[_window contentView] display];
        [[[prefs window] contentView] display];

        for (NSString *key in keys) {
            if (before[key]) [d setObject:before[key] forKey:key]; else [d removeObjectForKey:key];
        }
        _configuration.stopPolicy = stopBefore;
        _configuration.backspacePolicy = backspaceBefore;
        [self saveConfiguration];
        [self applyAppearance];
        [self syncKeyboard];
        [prefs sync];
        [[prefs window] orderOut:self];
        [self startNewTest];
    }

    /* every character gets a cell of its own, so the font had better be
     * fixed-pitch: measured here, because gnustep-gui hands out a proportional
     * font without a word when it cannot find "Courier".  (A backend that
     * measures nothing at all -- headless -- has no say.) */
    {
        NSFont *fixed = [HRTheme fixedPitchFontOfSize:15.0];
        CGFloat m = [@"m" sizeWithAttributes:@{NSFontAttributeName: fixed}].width;
        printf("HomeRow smoke test: typing font %s, m is %.2f wide\n", [[fixed fontName] UTF8String] ?: "-", (double)m);
        if (m > 0.0 && ![HRTheme fontIsFixedPitch:fixed]) {
            [failures addObject:[NSString stringWithFormat:@"the typing font %@ is not fixed-pitch", [fixed fontName]]];
        }
    }

    /* draw everything once, so that a drawing method that raises, or that
     * the text system complains about, does so here and not on a user */
    [self toggleKeyboard:self];
    [[_window contentView] display];
    [self toggleKeyboard:self];
    [[_window contentView] display];

    /* The first launch: the question is asked of someone new only, and
     * "teach me" starts a course for the layout in use */
    {
        HRWelcomeWindowController *welcome = [self welcomeWindow];
        [welcome showWindow:self];
        if (!welcome.teachButton || !welcome.testButton) [failures addObject:@"WelcomeWindow.xib: a button is not connected"];
        if ([self isNewHere]) [failures addObject:@"someone with results on record was taken for new"];
        NSString *beginners = [self beginnersCourseFile];
        if (!beginners) {
            [failures addObject:@"there is no course to start a beginner on"];
        } else {
            id welcomeBefore = [smokeDefaults objectForKey:HRWelcomeDoneDefaultsKey];
            id courseBefore = [smokeDefaults objectForKey:HRCurrentCourseDefaultsKey];
            BOOL started = [_store progressForCourse:beginners] != nil;
            [welcome teachMe:self];
            if (!_run || ![_courseFile isEqual:beginners]) [failures addObject:@"\"Teach me\" did not start the beginners' course"];
            if ([[welcome window] isVisible]) [failures addObject:@"the welcome stayed up after its answer"];
            if (![smokeDefaults boolForKey:HRWelcomeDoneDefaultsKey]) [failures addObject:@"the welcome would be shown again"];
            [self leaveLesson];
            if (!started) [_store resetCourse:beginners error:NULL];
            if (welcomeBefore) [smokeDefaults setObject:welcomeBefore forKey:HRWelcomeDoneDefaultsKey];
            else [smokeDefaults removeObjectForKey:HRWelcomeDoneDefaultsKey];
            if (courseBefore) [smokeDefaults setObject:courseBefore forKey:HRCurrentCourseDefaultsKey];
            else [smokeDefaults removeObjectForKey:HRCurrentCourseDefaultsKey];
        }
    }
    if (soundBefore) [smokeDefaults setObject:soundBefore forKey:HRSoundSchemeDefaultsKey];
    else [smokeDefaults removeObjectForKey:HRSoundSchemeDefaultsKey];

    if ([failures count] == 0) {
        printf("HomeRow smoke test: OK\n");
        exit(0);
    }
    for (NSString *f in failures) fprintf(stderr, "HomeRow smoke test: %s\n", [f UTF8String]);
    exit(1);
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

/* Bundled packs first, then the user's own; a user pack with the same
 * identifier replaces the bundled one. */
- (void)loadLanguages
{
    NSMutableDictionary *byID = [NSMutableDictionary dictionary];
    NSMutableArray *dirs = [NSMutableArray array];
    [dirs addObject:[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Languages"]];
    [dirs addObject:[[[[HRResultStore defaultStoreURL] path] stringByDeletingLastPathComponent]
                     stringByAppendingPathComponent:@"Languages"]];
    for (NSString *dir in dirs) {
        NSArray *problems = nil;
        for (HRLanguage *l in [HRLanguage languagesInDirectory:dir problems:&problems]) {
            byID[l.identifier] = l;
        }
        for (NSError *e in problems) NSLog(@"HomeRow: language pack skipped: %@", [e localizedDescription]);
    }
    _languages = [[byID allValues] sortedArrayUsingDescriptors:
                  @[[NSSortDescriptor sortDescriptorWithKey:@"identifier" ascending:YES]]];
}

- (HRLanguage *)currentLanguage
{
    for (HRLanguage *l in _languages) {
        if ([l.identifier isEqualToString:_configuration.languageID]) return l;
    }
    return [_languages firstObject];
}

#pragma mark - Controls

- (NSArray *)amountsForMode:(HRTestMode)mode
{
    if (mode == HRTestModeTime)  return @[@15, @30, @60, @120];
    if (mode == HRTestModeWords) return @[@10, @25, @50, @100];
    return @[];
}

- (void)syncControls
{
    [_modePopUp removeAllItems];
    [_modePopUp addItemsWithTitles:@[HRLoc(@"time"), HRLoc(@"words"), HRLoc(@"zen")]];
    [[_modePopUp itemAtIndex:0] setTag:HRTestModeTime];
    [[_modePopUp itemAtIndex:1] setTag:HRTestModeWords];
    [[_modePopUp itemAtIndex:2] setTag:HRTestModeZen];
    [_modePopUp addItemWithTitle:HRLoc(@"course")];
    [[_modePopUp lastItem] setTag:HRTestModeLesson];
    [_modePopUp addItemWithTitle:HRLoc(@"code")];
    [[_modePopUp lastItem] setTag:HRTestModeCode];
    [_modePopUp addItemWithTitle:HRLoc(@"weak keys")];
    [[_modePopUp lastItem] setTag:HRTestModePractice];
    if (_configuration.mode == HRTestModeCustom) {
        [_modePopUp addItemWithTitle:HRLoc(@"custom")];
        [[_modePopUp lastItem] setTag:HRTestModeCustom];
    }
    [_modePopUp selectItemWithTag:_configuration.mode];

    NSArray *amounts = [self amountsForMode:_configuration.mode];
    [_amountPopUp removeAllItems];
    for (NSNumber *a in amounts) {
        [_amountPopUp addItemWithTitle:[a stringValue]];
        [[_amountPopUp lastItem] setTag:[a integerValue]];
    }
    if ([amounts count] > 0 && ![amounts containsObject:@(_configuration.amount)]) {
        _configuration.amount = [amounts[1] integerValue];
    }
    [_amountPopUp selectItemWithTag:_configuration.amount];
    [_amountPopUp setEnabled:[amounts count] > 0];

    BOOL generated = (_configuration.mode == HRTestModeTime || _configuration.mode == HRTestModeWords);
    /* keywords are typed as they stand: "printf," teaches nothing */
    BOOL prose = ![self currentLanguage].isCode;
    [_punctuationCheck setEnabled:generated && prose];
    [_numbersCheck setEnabled:generated && prose];
    /* following a course, none of the three means anything: the lesson
     * decides the text.  Greyed-out is for "not now"; this is "not here". */
    /* the same goes for code: the file decides */
    BOOL inCourse = (_configuration.mode == HRTestModeLesson || _configuration.mode == HRTestModeCode);
    /* ...and so is the mode pop-up: a course is left through the Test menu
     * (Cmd-1/2/3), not by a control sitting over the lesson */
    [_modePopUp setHidden:inCourse];
    [_amountPopUp setHidden:inCourse];
    [_punctuationCheck setHidden:inCourse];
    [_numbersCheck setHidden:inCourse];
    [_punctuationCheck setState:(_configuration.punctuation ? NSControlStateValueOn : NSControlStateValueOff)];
    [_numbersCheck setState:(_configuration.numbers ? NSControlStateValueOn : NSControlStateValueOff)];
    [self syncMenus];
}

- (void)saveConfiguration
{
    [[NSUserDefaults standardUserDefaults] setObject:[_configuration dictionaryRepresentation]
                                              forKey:HRConfigurationDefaultsKey];
}

/* Test > Time / Words / Zen: the modes by keyboard, and the way out of a
 * course now that the pop-up is hidden there. */
- (IBAction)selectMode:(id)sender
{
    [_modePopUp selectItemWithTag:[sender tag]];
    [self modeChanged:sender];
}

- (IBAction)modeChanged:(id)sender
{
    HRTestMode chosen = (HRTestMode)[[_modePopUp selectedItem] tag];
    if (chosen == HRTestModeLesson) {
        [self leaveCode];
        if (!_run) [self continueCourse:sender];
        return;
    }
    if (chosen == HRTestModeCode) {
        [self leaveLesson];
        if (!_codeFile) [self continueCode:sender];
        return;
    }
    [self leaveLesson];
    [self leaveCode];
    _configuration.mode = chosen;
    [self syncControls];
    [self saveConfiguration];
    [self startNewTest];
}

- (IBAction)amountChanged:(id)sender
{
    _configuration.amount = [[_amountPopUp selectedItem] tag];
    [self saveConfiguration];
    [self startNewTest];
}

- (IBAction)optionChanged:(id)sender
{
    _configuration.punctuation = ([_punctuationCheck state] == NSControlStateValueOn);
    _configuration.numbers = ([_numbersCheck state] == NSControlStateValueOn);
    [self saveConfiguration];
    [self startNewTest];
}

- (IBAction)toggleBeep:(id)sender
{
    _testView.beepsOnError = !_testView.beepsOnError;
    [[NSUserDefaults standardUserDefaults] setBool:_testView.beepsOnError forKey:HRBeepOnErrorDefaultsKey];
    [self syncMenus];
    [_preferencesWindow sync];
}

- (IBAction)restartTest:(id)sender
{
    [self startNewTest];
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
    [self leaveLesson];
    [self leaveCode];
    _customText = text;
    _configuration.mode = HRTestModeCustom;
    [self syncControls];
    [self startNewTest];
}

#pragma mark - Language and lesson menus

/* Built in code rather than in the XIB: both are lists of whatever packs
 * and courses are present, which the XIB cannot know. */
- (void)buildMenus
{
    NSMenu *main = [NSApp mainMenu];
    NSInteger at = MAX(0, [main numberOfItems] - 1);   /* before Window */

    _languageMenu = [[NSMenu alloc] initWithTitle:HRLoc(@"Language")];
    _wordListMenu = [[NSMenu alloc] initWithTitle:HRLoc(@"Word List")];
    NSMenuItem *lists = [[NSMenuItem alloc] initWithTitle:HRLoc(@"Word List") action:NULL keyEquivalent:@""];
    [lists setSubmenu:_wordListMenu];
    [_languageMenu addItem:lists];
    [_languageMenu addItem:[NSMenuItem separatorItem]];
    NSArray *byName = [_languages sortedArrayUsingDescriptors:
                       @[[NSSortDescriptor sortDescriptorWithKey:@"displayName" ascending:YES]]];
    /* keyword lists of programming languages: words to type like any
     * other, but sixty more names do not belong among Afrikaans and Zulu */
    _programmingMenu = [[NSMenu alloc] initWithTitle:HRLoc(@"Programming")];
    for (HRLanguage *l in byName) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:l.displayName
                                                      action:@selector(selectLanguage:)
                                               keyEquivalent:@""];
        [item setTarget:self];
        [item setRepresentedObject:l.identifier];
        [(l.isCode ? _programmingMenu : _languageMenu) addItem:item];
    }
    if ([_programmingMenu numberOfItems] > 0) {
        _programmingItem = [[NSMenuItem alloc] initWithTitle:HRLoc(@"Programming") action:NULL keyEquivalent:@""];
        [_programmingItem setSubmenu:_programmingMenu];
        [_languageMenu insertItem:_programmingItem atIndex:2];
    }
    NSMenuItem *languageItem = [[NSMenuItem alloc] initWithTitle:HRLoc(@"Language") action:NULL keyEquivalent:@""];
    [languageItem setSubmenu:_languageMenu];
    [main insertItem:languageItem atIndex:at];

    /* Language > Keyboard Layout: what the on-screen keyboard draws when no
     * course says otherwise.  It describes the system's layout; it never
     * changes it. */
    /* one item that names the layout and opens the chooser: a submenu of 239
     * layouts could be scrolled but hardly used */
    _layoutMenuItem = [[NSMenuItem alloc] initWithTitle:HRLoc(@"Keyboard Layout\u2026") action:@selector(showLayoutChooser:)
                                          keyEquivalent:@""];
    [_layoutMenuItem setTarget:self];
    [_languageMenu insertItem:_layoutMenuItem atIndex:1];

    _courses = [NSDictionary dictionaryWithContentsOfFile:
                [[self lessonsDirectory] stringByAppendingPathComponent:@"index.plist"]][@"courses"] ?: @[];
    _scripts = [NSMutableDictionary dictionary];

    /* Preferences… under About, in the application menu (the first one) */
    NSMenu *appMenu = [main numberOfItems] > 0 ? [[main itemAtIndex:0] submenu] : nil;
    if (appMenu) {
        NSMenuItem *prefsItem = [[NSMenuItem alloc] initWithTitle:HRLoc(@"Preferences\u2026") action:@selector(showPreferences:)
                                                    keyEquivalent:@","];
        [prefsItem setTarget:self];
        /* About / ---- / Preferences… / ---- / Services … */
        NSInteger where = MIN((NSInteger)1, [appMenu numberOfItems]);
        if (where < [appMenu numberOfItems] && [[appMenu itemAtIndex:where] isSeparatorItem]) where++;
        [appMenu insertItem:prefsItem atIndex:where];
        if (where + 1 < [appMenu numberOfItems] && ![[appMenu itemAtIndex:where + 1] isSeparatorItem]) {
            [appMenu insertItem:(NSMenuItem *)[NSMenuItem separatorItem] atIndex:where + 1];
        }
    }

    NSMenu *testMenu = [[main itemWithTitle:@"Test"] submenu];
    if (testMenu) {
        [testMenu addItem:(NSMenuItem *)[NSMenuItem separatorItem]];
        NSArray *modes = @[@[HRLoc(@"Time Test"), @(HRTestModeTime), @"1"],
                           @[HRLoc(@"Words Test"), @(HRTestModeWords), @"2"],
                           @[HRLoc(@"Zen"), @(HRTestModeZen), @"3"]];
        /* Code is not among them: choosing it opens a window, see below */
        for (NSArray *mode in modes) {
            NSMenuItem *modeItem = (NSMenuItem *)[testMenu addItemWithTitle:mode[0] action:@selector(selectMode:)
                                                              keyEquivalent:mode[2]];
            [modeItem setTarget:self];
            [modeItem setTag:[mode[1] integerValue]];
        }
        NSMenuItem *practiceItem = (NSMenuItem *)[testMenu addItemWithTitle:HRLoc(@"Practise Weak Keys") action:@selector(selectMode:)
                                                              keyEquivalent:@"5"];
        [practiceItem setTarget:self];
        [practiceItem setTag:HRTestModePractice];
        NSMenuItem *codeItem = (NSMenuItem *)[testMenu addItemWithTitle:HRLoc(@"Code\u2026") action:@selector(showCode:)
                                                          keyEquivalent:@"4"];
        [codeItem setTarget:self];
        [testMenu addItem:(NSMenuItem *)[NSMenuItem separatorItem]];
        _testKeyboardMenuItem = (NSMenuItem *)[testMenu addItemWithTitle:HRLoc(@"Show Keyboard") action:@selector(toggleKeyboard:)
                                                          keyEquivalent:@""];
        [_testKeyboardMenuItem setTarget:self];
        NSMenuItem *statsItem = (NSMenuItem *)[testMenu addItemWithTitle:HRLoc(@"Statistics\u2026") action:@selector(showStatistics:)
                                                           keyEquivalent:@"S"];
        [statsItem setTarget:self];
        NSMenuItem *replayItem = (NSMenuItem *)[testMenu addItemWithTitle:HRLoc(@"Replay the Last Test") action:@selector(replayLastTest:)
                                                            keyEquivalent:@"R"];   /* Cmd-R is New Test */
        [replayItem setTarget:self];
        NSMenuItem *beepItem = (NSMenuItem *)[testMenu addItemWithTitle:HRLoc(@"Beep on a Wrong Key") action:@selector(toggleBeep:)
                                                          keyEquivalent:@""];
        [beepItem setTarget:self];
    }

    NSMenu *courseMenu = [[NSMenu alloc] initWithTitle:HRLoc(@"Course")];
    _courseMenu = courseMenu;
    /* informal NSMenuDelegate, see -menuNeedsUpdate: */
    [courseMenu setDelegate:(id)self];
    NSMenuItem *item = (NSMenuItem *)[courseMenu addItemWithTitle:HRLoc(@"Courses\u2026") action:@selector(showCourses:) keyEquivalent:@"l"];
    [item setTarget:self];
    item = (NSMenuItem *)[courseMenu addItemWithTitle:HRLoc(@"Restart Lesson") action:@selector(restartLesson:) keyEquivalent:@""];
    [item setTarget:self];
    [courseMenu addItem:[NSMenuItem separatorItem]];
    _keyboardMenuItem = (NSMenuItem *)[courseMenu addItemWithTitle:HRLoc(@"Show Keyboard") action:@selector(toggleKeyboard:) keyEquivalent:@"K"];
    [_keyboardMenuItem setTarget:self];
    NSMenuItem *courseItem = [[NSMenuItem alloc] initWithTitle:HRLoc(@"Course") action:NULL keyEquivalent:@""];
    [courseItem setSubmenu:courseMenu];
    [main insertItem:courseItem atIndex:at + 1];
}

/* Several courses can be on the go at once -- a QWERTY course and the
 * programmers' symbols, say, or two languages.  Each keeps its own place;
 * the Course menu lists the ones that have been started, the current one
 * ticked, and choosing another switches to it and carries on from ITS
 * place.  Rebuilt whenever the menu is about to open. */
- (void)menuNeedsUpdate:(NSMenu *)menu
{
    if (menu == _courseMenu) [self rebuildStartedCourseItems];
}

- (void)rebuildStartedCourseItems
{
    for (NSMenuItem *item in _startedCourseItems) [_courseMenu removeItem:item];
    _startedCourseItems = [NSMutableArray array];
    NSString *current = [self currentCourseFile];
    NSInteger at = [_courseMenu indexOfItemWithTarget:self andAction:@selector(restartLesson:)] + 1;
    if (at <= 0) return;
    for (HRCourseProgress *progress in [_store startedCourses]) {
        NSDictionary *course = [self courseEntryForFile:progress.courseFile];
        if (!course) continue;
        NSUInteger total = [[self scriptForCourseFile:progress.courseFile].lessons count];
        NSUInteger next = (NSUInteger)MAX(0, [progress.lessonIndex integerValue]);
        NSString *where = next >= total ? HRLoc(@"finished")
            : [NSString stringWithFormat:HRLoc(@"lesson %lu of %lu"), (unsigned long)(next + 1), (unsigned long)total];
        NSString *language = course[@"language"];
        for (HRLanguage *l in _languages) if ([l.identifier isEqual:course[@"language"]]) language = l.displayName;
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"%@ \u2014 %@   (%@)", language, course[@"title"], where]
                                                      action:@selector(switchToCourse:) keyEquivalent:@""];
        [item setTarget:self];
        [item setRepresentedObject:progress.courseFile];
        [item setState:([progress.courseFile isEqual:current] ? NSControlStateValueOn : NSControlStateValueOff)];
        if ([_startedCourseItems count] == 0) {
            NSMenuItem *separator = (NSMenuItem *)[NSMenuItem separatorItem];
            [_courseMenu insertItem:separator atIndex:at++];
            [_startedCourseItems addObject:separator];
        }
        [_courseMenu insertItem:item atIndex:at++];
        [_startedCourseItems addObject:item];
    }
}

- (IBAction)switchToCourse:(id)sender
{
    NSString *file = [sender representedObject];
    if (![self courseEntryForFile:file]) return;
    /* the ticked course, while it is already running: nothing to do */
    if (_run && [file isEqual:_courseFile]) {
        [_window makeKeyAndOrderFront:self];
        return;
    }
    /* the lesson that was running keeps its place: it is saved at every step */
    [self leaveLesson];
    [self leaveCode];
    [[NSUserDefaults standardUserDefaults] setObject:file forKey:HRCurrentCourseDefaultsKey];
    _courseWindow.selectedCourseFile = file;
    [self continueCourse:sender];
}

- (NSString *)layoutsDirectory
{
    return [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Layouts"];
}

- (HRKeyboardLayout *)layoutNamed:(NSString *)identifier
{
    if ([identifier length] == 0) return nil;
    if (!_layouts) _layouts = [NSMutableDictionary dictionary];
    id cached = _layouts[identifier];
    if (cached) return cached == [NSNull null] ? nil : cached;
    NSString *path = [[[self layoutsDirectory] stringByAppendingPathComponent:identifier] stringByAppendingPathExtension:@"plist"];
    HRKeyboardLayout *layout = [[NSFileManager defaultManager] fileExistsAtPath:path]
        ? [HRKeyboardLayout layoutWithContentsOfFile:path error:NULL] : nil;
    _layouts[identifier] = layout ?: (id)[NSNull null];
    return layout;
}

- (NSString *)lessonsDirectory
{
    return [[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Lessons"]
            stringByAppendingPathComponent:@"gtypist"];
}

- (HRTypScript *)scriptForCourseFile:(NSString *)file
{
    HRTypScript *script = _scripts[file];
    if (!script) {
        NSError *error = nil;
        script = [HRTypScript scriptWithContentsOfFile:[[self lessonsDirectory] stringByAppendingPathComponent:file]
                                                 error:&error];
        if (!script) {
            NSLog(@"HomeRow: %@ could not be read: %@", file, [error localizedDescription]);
            return nil;
        }
        _scripts[file] = script;
    }
    return script;
}

- (void)syncMenus
{
    for (NSMenuItem *item in [[[[NSApp mainMenu] itemWithTitle:@"Test"] submenu] itemArray]) {
        if (sel_isEqual([item action], @selector(selectMode:))) {
            [item setState:([item tag] == _configuration.mode ? NSControlStateValueOn : NSControlStateValueOff)];
        }
        if (sel_isEqual([item action], @selector(toggleBeep:))) {
            [item setState:(_testView.beepsOnError ? NSControlStateValueOn : NSControlStateValueOff)];
        }
        if (sel_isEqual([item action], @selector(showCode:))) {
            [item setState:(_configuration.mode == HRTestModeCode ? NSControlStateValueOn : NSControlStateValueOff)];
        }
    }
    NSMutableArray *languageMenus = [NSMutableArray array];   /* neither is there before buildMenus */
    if (_languageMenu) [languageMenus addObject:_languageMenu];
    if (_programmingMenu) [languageMenus addObject:_programmingMenu];
    for (NSMenu *menu in languageMenus) {
        for (NSMenuItem *item in [menu itemArray]) {
            if (![item representedObject]) continue;
            BOOL on = [[item representedObject] isEqual:[self currentLanguage].identifier];
            [item setState:(on ? NSControlStateValueOn : NSControlStateValueOff)];
        }
    }
    /* a dash on the submenu says the tick is inside it */
    [_programmingItem setState:([self currentLanguage].isCode ? NSControlStateValueMixed : NSControlStateValueOff)];
    [_layoutMenuItem setTitle:[NSString stringWithFormat:HRLoc(@"Keyboard Layout: %@\u2026"),
                               [HRLayoutChooserController titleForIdentifier:(_configuration.layoutID ?: @"qwerty")]]];
    [_wordListMenu removeAllItems];
    HRLanguage *language = [self currentLanguage];
    NSString *current = [self currentWordListName];
    for (NSString *name in language.wordListNames) {
        NSString *title = [name hasPrefix:@"words-"] ? [name substringFromIndex:6] : name;
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:@selector(selectWordList:) keyEquivalent:@""];
        [item setTarget:self];
        [item setRepresentedObject:name];
        [item setState:([name isEqualToString:current] ? NSControlStateValueOn : NSControlStateValueOff)];
        [_wordListMenu addItem:item];
    }
}

/* The configured list if this language has it, else its smallest. */
- (NSString *)currentWordListName
{
    HRLanguage *language = [self currentLanguage];
    if ([language.wordListNames containsObject:_configuration.wordListName]) return _configuration.wordListName;
    return [language.wordListNames firstObject];
}

- (IBAction)selectLanguage:(id)sender
{
    _configuration.languageID = [sender representedObject];
    if (_configuration.mode != HRTestModeTime && _configuration.mode != HRTestModeWords) {
        _configuration.mode = HRTestModeTime;
    }
    [self leaveLesson];
    [self leaveCode];
    [self syncControls];
    [self saveConfiguration];
    [self startNewTest];
}

- (IBAction)selectLayout:(id)sender
{
    _configuration.layoutID = [sender representedObject];
    _statsWindow.keyboardLayout = [self layoutNamed:_configuration.layoutID];
    [_preferencesWindow sync];
    [self saveConfiguration];
    [self syncMenus];
    [self syncKeyboard];
}

- (IBAction)selectWordList:(id)sender
{
    _configuration.wordListName = [sender representedObject];
    if (_configuration.mode != HRTestModeTime && _configuration.mode != HRTestModeWords) {
        _configuration.mode = HRTestModeTime;   /* a word list means word tests */
    }
    [self leaveLesson];
    [self leaveCode];
    [self syncControls];
    [self saveConfiguration];
    [self startNewTest];
}

#pragma mark - Following a course

- (NSDictionary *)courseEntryForFile:(NSString *)file
{
    for (NSDictionary *course in _courses) if ([course[@"file"] isEqual:file]) return course;
    return nil;
}

- (NSString *)currentCourseFile
{
    NSString *file = [[NSUserDefaults standardUserDefaults] stringForKey:HRCurrentCourseDefaultsKey];
    return [self courseEntryForFile:file] ? file : nil;
}

- (HRCourseWindowController *)courseWindow
{
    if (!_courseWindow) {
        NSMutableDictionary *names = [NSMutableDictionary dictionary];
        for (HRLanguage *l in _languages) names[l.identifier] = l.displayName;
        _courseWindow = [[HRCourseWindowController alloc] initWithCourses:_courses languageNames:names
                                                                    store:_store delegate:self];
        _courseWindow.selectedCourseFile = [self currentCourseFile];
    }
    return _courseWindow;
}

- (IBAction)showCourses:(id)sender
{
    [[self courseWindow] showWindow:self];
    [[self courseWindow] reloadProgress];
}

/* Where the current course was left; the Courses window when there is no
 * current course to go on with. */
- (IBAction)continueCourse:(id)sender
{
    NSString *file = [self currentCourseFile];
    if (!file) {
        [self showCoursePlaceholder:HRLoc(@"No course chosen yet.\n\nPick one in the Courses window \u2014 it keeps your place\nfrom then on.")];
        [self showCourses:sender];
        return;
    }
    NSArray *lessons = [self scriptForCourseFile:file].lessons;
    if ([lessons count] == 0) {
        [self showCoursePlaceholder:HRLoc(@"This course could not be read.")];
        return;
    }
    HRCourseProgress *progress = [_store progressForCourse:file];
    NSUInteger lesson = progress ? (NSUInteger)MAX(0, [progress.lessonIndex integerValue]) : 0;
    NSUInteger step = progress ? (NSUInteger)MAX(0, [progress.stepIndex integerValue]) : 0;
    if (!_store && [_unsavedCourseFile isEqual:file]) {
        /* no store to ask: at least do not go round in circles */
        lesson = _unsavedNextLesson;
        step = 0;
    }
    if (lesson >= [lessons count]) {
        /* the course is done; the window is where one picks what to repeat */
        [self showCoursePlaceholder:HRLoc(@"You have finished this course.\n\nPick another one, or a lesson to take again,\nin the Courses window.")];
        [self showCourses:sender];
        return;
    }
    [self startLesson:lesson ofCourse:file atStep:step];
}

/* Course mode with nothing to type: say why, and what to do about it. */
- (void)showCoursePlaceholder:(NSString *)text
{
    [self showPlaceholder:text inMode:HRTestModeLesson];
}

- (void)showPlaceholder:(NSString *)text inMode:(HRTestMode)mode
{
    [self leaveLesson];
    [self leaveCode];
    _configuration.mode = mode;
    [self syncControls];
    _session = nil;
    _testView.session = nil;
    _testView.pageText = text;
    [_resultsView setHidden:YES];
    [_testView setHidden:NO];
    [_liveField setStringValue:@""];
    [self syncKeyboard];
}

- (IBAction)restartLesson:(id)sender
{
    if (_run) [self startLesson:_lessonIndex ofCourse:_courseFile atStep:0];
}

- (void)startLesson:(NSUInteger)lessonIndex ofCourse:(NSString *)file atStep:(NSUInteger)step
{
    NSArray *lessons = [self scriptForCourseFile:file].lessons;
    if (lessonIndex >= [lessons count]) return;
    HRTypLesson *lesson = lessons[lessonIndex];
    _courseFile = [file copy];
    _lessonIndex = lessonIndex;
    [self leaveCode];
    _run = [[HRCourseRun alloc] initWithLesson:lesson startingAtStep:step];
    /* picked up in the middle (a relaunch): what was typed before counts too */
    if (_run.stepIndex > 0) {
        [_run addEarlierExercises:[_store earlierExercisesOfLesson:lessonIndex inCourse:file beforeStep:_run.stepIndex] ?: @[]];
    }
    if (_run.stepIndex == 0) {
        [_store noteLessonStarted:lessonIndex title:lesson.title inCourse:file error:NULL];
    }
    _configuration.mode = HRTestModeLesson;
    /* (the course's language goes on its results -- see -startLessonStep --
     * and no further: following a German course must not turn the tests and
     * the weak-key rounds German) */
    [self syncControls];
    [self saveConfiguration];
    [_window makeKeyAndOrderFront:self];
    [self startLessonStep];
}

- (void)leaveLesson
{
    _run = nil;
    _courseFile = nil;
    _testView.pageText = nil;
    _testView.caption = nil;
}

/* The course's bookmark only moves forwards.  Taking an earlier lesson
 * again is practice: it gets recorded, but it must not drag the place in
 * the course back to lesson 2 for someone who was at lesson 9. */
- (BOOL)lessonIsAtOrPastBookmark
{
    HRCourseProgress *progress = [_store progressForCourse:_courseFile];
    return !progress || (NSInteger)_lessonIndex >= [progress.lessonIndex integerValue];
}

- (void)saveCoursePosition
{
    if (!_run || !_courseFile || ![self lessonIsAtOrPastBookmark]) return;
    NSError *error = nil;
    if (![_store setLessonIndex:_lessonIndex stepIndex:_run.stepIndex forCourse:_courseFile error:&error] && _store) {
        NSLog(@"HomeRow: the position in the course was not saved: %@", error);
    }
}

- (void)startLessonStep
{
    [self cancelReplay];
    if (_run.isFinished) {
        [self finishLesson];
        return;
    }
    [self saveCoursePosition];
    HRTypStep *step = [_run currentStep];
    [_resultsView setHidden:YES];
    [_testView setHidden:NO];
    [_window makeFirstResponder:_testView];
    if (!step.isExercise) {
        _session = nil;
        _testView.session = nil;
        _testView.caption = nil;
        _testView.pageText = step.text;
    } else {
        NSString *caption = step.instruction;
        if (_run.isRepeating) {
            NSString *again = HRLoc(@"Too many errors — once more.");
            caption = [caption length] > 0 ? [NSString stringWithFormat:@"%@\n%@", again, caption] : again;
        }
        _testView.pageText = nil;
        _testView.caption = caption;
        HRTestConfiguration *configuration = [_configuration copy];
        NSString *language = [self courseEntryForFile:_courseFile][@"language"];
        if (language) configuration.languageID = language;
        _session = [[HRTestSession alloc] initWithConfiguration:configuration
                                                         source:[[HRFixedTextSource alloc] initWithText:step.text]];
        _testView.session = _session;
    }
    [self updateLiveField];
    [self syncKeyboard];
}

- (void)lessonExerciseDidFinish:(HRTestSummary *)summary
{
    [_run recordExercise:summary];
    [self startLessonStep];
}

/* The lesson is done: record what it came to, move the course on to the
 * next lesson, and show the lesson -- not its last exercise -- as the
 * result. */
- (void)finishLesson
{
    HRLessonSummary *l = [_run summary];
    NSArray *lessons = [self scriptForCourseFile:_courseFile].lessons;
    NSUInteger next = _lessonIndex + 1;
    NSError *error = nil;
    if (_store) {
        BOOL advances = [self lessonIsAtOrPastBookmark];
        if (![_store noteLessonCompleted:_lessonIndex summary:l countsForBest:_run.coversWholeLesson
                                inCourse:_courseFile error:&error]
            || (advances && ![_store setLessonIndex:next stepIndex:0 forCourse:_courseFile error:&error])) {
            NSLog(@"HomeRow: the lesson was not recorded: %@", error);
        }
    }
    _unsavedCourseFile = [_courseFile copy];
    _unsavedNextLesson = _lessonIndex + 1;
    NSString *title = _run.lesson.title;
    /* what Return does next is "continue the course", so say which lesson
     * that is -- after a retake it is the bookmark, not the one after this */
    HRCourseProgress *bookmark = [_store progressForCourse:_courseFile];
    if (bookmark) next = (NSUInteger)MAX(0, [bookmark.lessonIndex integerValue]);
    NSString *nextTitle = next < [lessons count] ? ((HRTypLesson *)lessons[next]).title : nil;
    _run = nil;
    _session = nil;
    _testView.pageText = nil;
    _testView.caption = nil;

    [_wpmField setStringValue:[NSString stringWithFormat:@"%.0f %@", l.wpm, HRLoc(@"wpm")]];
    [_accuracyField setStringValue:[NSString stringWithFormat:@"%.0f%% %@", l.accuracy, HRLoc(@"acc")]];
    [_detailField setStringValue:[NSString stringWithFormat:HRLoc(@"%@ — done.   %lu exercises   %lu repeated   %.0fs of typing"),
                                  title, (unsigned long)l.exercises, (unsigned long)l.repeats, l.duration]];
    [_hintField setStringValue:(nextTitle
        ? [NSString stringWithFormat:HRLoc(@"return — next lesson: %@"), nextTitle]
        : HRLoc(@"That was the last lesson of this course.  return — courses"))];
    _chartView.samples = @[];
    [_testView setHidden:YES];
    [_resultsView setHidden:NO];
    [_window makeFirstResponder:_resultsView];
    [_liveField setStringValue:@""];
    [self syncKeyboard];
    [_courseWindow reloadProgress];
}

#pragma mark - HRCourseWindowDelegate

- (NSArray *)courseWindow:(HRCourseWindowController *)controller lessonsOfCourse:(NSString *)courseFile
{
    return [self scriptForCourseFile:courseFile].lessons ?: @[];
}

- (void)courseWindow:(HRCourseWindowController *)controller didSelectCourse:(NSString *)courseFile
{
    [[NSUserDefaults standardUserDefaults] setObject:courseFile forKey:HRCurrentCourseDefaultsKey];
}

- (void)courseWindow:(HRCourseWindowController *)controller didResetCourse:(NSString *)courseFile
{
    if (![courseFile isEqual:_courseFile]) return;
    /* the lesson in progress belongs to a course that was just forgotten:
     * carrying on would write its place straight back */
    [self leaveLesson];
    if ([courseFile isEqual:[self currentCourseFile]]) [self continueCourse:controller];
}

- (void)courseWindowDidRequestContinue:(HRCourseWindowController *)controller
{
    [self continueCourse:controller];
}

- (void)courseWindow:(HRCourseWindowController *)controller didRequestLesson:(NSUInteger)lessonIndex
{
    [self startLesson:lessonIndex ofCourse:[self currentCourseFile] atStep:0];
}

#pragma mark - Code

/* Code mode is a course whose lessons are the sections of a source file:
 * the same two tables keep its place (CourseProgress, under the file's
 * "code:..." identifier) and what each section came to (LessonRecord).
 * What differs is the text -- laid out as code, coloured by a TextMate
 * grammar, indentation and comments filled in rather than typed -- and
 * that a wrong key does not go in. */

- (HRCodeLibrary *)codeLibrary
{
    if (!_codeLibrary) {
        NSString *directory = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Code"];
        _codeLibrary = [[HRCodeLibrary alloc] initWithDirectory:directory];
        NSArray *paths = [[NSUserDefaults standardUserDefaults] arrayForKey:HRCodeUserFilesDefaultsKey];
        if (paths) _codeLibrary.userFilePaths = paths;
        NSArray *folders = [[NSUserDefaults standardUserDefaults] arrayForKey:HRCodeUserFoldersDefaultsKey];
        if (folders) _codeLibrary.userFolderPaths = folders;
    }
    return _codeLibrary;
}

- (HRCodeWindowController *)codeWindow
{
    if (!_codeWindow) {
        _codeWindow = [[HRCodeWindowController alloc] initWithLibrary:[self codeLibrary] store:_store delegate:self];
        HRCodeFile *file = [[self codeLibrary] fileWithIdentifier:
                            [[NSUserDefaults standardUserDefaults] stringForKey:HRCurrentCodeFileDefaultsKey]];
        if ([file.languageID length] > 0) _codeWindow.selectedLanguageID = file.languageID;
    }
    return _codeWindow;
}

- (IBAction)showCode:(id)sender
{
    [[self codeWindow] showWindow:self];
    [[self codeWindow] reloadProgress];
}

- (void)leaveCode
{
    _codeFile = nil;
    _codeSectionDone = NO;
    _testView.codeLayout = NO;
}

/* Where the current file was left; the Code window when there is nothing
 * to go on with. */
- (IBAction)continueCode:(id)sender
{
    HRCodeFile *file = [[self codeLibrary] fileWithIdentifier:
                        [[NSUserDefaults standardUserDefaults] stringForKey:HRCurrentCodeFileDefaultsKey]];
    HRCodeDocument *document = file ? [[self codeLibrary] documentForFile:file error:NULL] : nil;
    if (!document) {
        [self showPlaceholder:HRLoc(@"No code chosen yet.\n\nPick a language and a file in the Code window —\nor open one of your own.")
                       inMode:HRTestModeCode];
        [self showCode:sender];
        return;
    }
    HRCourseProgress *progress = [_store progressForCourse:file.identifier];
    NSUInteger section = progress ? (NSUInteger)MAX(0, [progress.lessonIndex integerValue]) : 0;
    if (!_store && [_unsavedCodeFile isEqual:file.identifier]) section = _unsavedNextSection;
    if (section >= document.numberOfSections) {
        [self showPlaceholder:HRLoc(@"You have typed this file to the end.\n\nPick another one, or a part to type again,\nin the Code window.")
                       inMode:HRTestModeCode];
        [self showCode:sender];
        return;
    }
    [self startSection:section ofCodeFile:file];
}

- (void)startSection:(NSUInteger)section ofCodeFile:(HRCodeFile *)file
{
    HRCodeDocument *document = [[self codeLibrary] documentForFile:file error:NULL];
    if (!document || section >= document.numberOfSections) return;
    [self leaveLesson];
    _codeFile = file;
    _codeSection = section;
    _codeSectionCount = document.numberOfSections;
    [[NSUserDefaults standardUserDefaults] setObject:file.identifier forKey:HRCurrentCodeFileDefaultsKey];
    _configuration.mode = HRTestModeCode;
    [self syncControls];
    [self saveConfiguration];
    [_window makeKeyAndOrderFront:self];
    [self startCodeSection];
}

- (void)startCodeSection
{
    [self cancelReplay];
    HRCodeDocument *document = [[self codeLibrary] documentForFile:_codeFile error:NULL];
    if (!document) {
        /* one of the user's own files, gone or changed since it was opened */
        [self showPlaceholder:HRLoc(@"This file could not be read.") inMode:HRTestModeCode];
        return;
    }
    _codeSectionDone = NO;
    NSRange lines = [document lineRangeOfSection:_codeSection];
    [_store noteLessonStarted:_codeSection
                        title:[NSString stringWithFormat:@"%@:%lu-%lu", _codeFile.title,
                               (unsigned long)(lines.location + 1), (unsigned long)NSMaxRange(lines)]
                     inCourse:_codeFile.identifier error:NULL];
    BOOL comments = [[NSUserDefaults standardUserDefaults] boolForKey:HRCodeTypeCommentsDefaultsKey];
    /* a compiler takes no near misses, and neither does this: the wrong
     * key does not go in.  Only for the session -- the saved configuration
     * keeps whatever the other modes use. */
    HRTestConfiguration *configuration = [_configuration copy];
    configuration.stopOnError = YES;
    _testView.caption = nil;
    _testView.pageText = nil;
    _testView.codeLayout = YES;
    _session = [[HRTestSession alloc] initWithConfiguration:configuration
                                                     source:[document sourceForSection:_codeSection typeComments:comments
                                                                              typeTabs:[[NSUserDefaults standardUserDefaults] boolForKey:HRCodeTypeTabsDefaultsKey]]];
    _testView.session = _session;
    [_resultsView setHidden:YES];
    [_testView setHidden:NO];
    [_window makeFirstResponder:_testView];
    [self updateLiveField];
    [self syncKeyboard];
}

- (void)finishCodeSection:(HRTestSummary *)s worthKeeping:(BOOL)worthKeeping
{
    NSString *identifier = _codeFile.identifier;
    NSUInteger next = _codeSection + 1;
    if (_store && worthKeeping) {
        HRLessonSummary *l = [[HRLessonSummary alloc] init];
        l.wpm = s.wpm;
        l.accuracy = s.accuracy;
        l.duration = s.duration;
        l.exercises = 1;
        NSError *error = nil;
        /* like a course's, the bookmark only moves forwards */
        HRCourseProgress *progress = [_store progressForCourse:identifier];
        BOOL advances = !progress || (NSInteger)_codeSection >= [progress.lessonIndex integerValue];
        if (![_store noteLessonCompleted:_codeSection summary:l countsForBest:YES inCourse:identifier error:&error]
            || (advances && ![_store setLessonIndex:next stepIndex:0 forCourse:identifier error:&error])) {
            NSLog(@"HomeRow: the section was not recorded: %@", error);
        }
    }
    _unsavedCodeFile = [identifier copy];
    _unsavedNextSection = next;
    HRCourseProgress *bookmark = [_store progressForCourse:identifier];
    if (bookmark) next = (NSUInteger)MAX(0, [bookmark.lessonIndex integerValue]);
    _codeSectionDone = YES;

    [self showSummary:s isBest:NO];
    /* for code, what the mistakes cost and where they were made says more than consistency does */
    NSDictionary *classNames = @{HRKeyClassLetters: HRLoc(@"letters"), HRKeyClassCapitals: HRLoc(@"capitals"), HRKeyClassDigits: HRLoc(@"digits"),
                                 HRKeyClassBrackets: HRLoc(@"brackets"), HRKeyClassOperators: HRLoc(@"operators"),
                                 HRKeyClassPunctuation: HRLoc(@"punctuation"), HRKeyClassWhitespace: HRLoc(@"space, return, tab")};
    [_detailField setStringValue:[NSString stringWithFormat:HRLoc(@"overhead %.0f%%   \u2014   %@   \u2014   %.0fs"),
                                  [s keystrokeOverhead] * 100.0,
                                  [HRStatistics lineForKeyClasses:[HRStatistics keyClassesFromCounts:s.keyStats ?: @{}] names:classNames],
                                  s.duration]];
    [_hintField setStringValue:[self hintWithReplay:(next < _codeSectionCount
        ? [NSString stringWithFormat:HRLoc(@"return — part %lu of %lu"), (unsigned long)(next + 1), (unsigned long)_codeSectionCount]
        : HRLoc(@"That was the last part of this file.  return — code"))]];
    [self syncKeyboard];
    [_codeWindow reloadProgress];
}

#pragma mark - HRCodeWindowDelegate

- (void)codeWindow:(HRCodeWindowController *)controller didRequestFile:(HRCodeFile *)file section:(NSUInteger)section
{
    [self startSection:section ofCodeFile:file];
}

#pragma mark - Weak-spot practice

static const NSUInteger HRPracticeWords = 40;

/* From the last thirty days if that is enough to go by, otherwise from
 * everything there is: what was a weak key a year ago need not be one now. */
/* What can be practised here: the characters on the keyboard layout in use
 * and those in the word list the round is drawn from (with their capitals).
 * Everything else on record -- the umlauts of a German course, while the
 * round is English on a US keyboard -- is somebody else's weak spot. */
- (NSSet *)practisableCharacters
{
    NSMutableSet *characters = [NSMutableSet set];
    HRKeyboardLayout *layout = [self layoutNamed:_configuration.layoutID] ?: [self layoutNamed:@"qwerty"];
    for (NSUInteger row = 0; row < [layout numberOfRows]; row++) {
        for (NSUInteger col = 0; col < [layout numberOfKeysInRow:row]; col++) {
            for (NSString *ch in [layout charactersForKeyAtRow:row column:col]) if ([ch length] > 0) [characters addObject:ch];
        }
    }
    NSString *list = [self currentWordListName];
    for (NSString *word in (list ? [[self currentLanguage] wordsNamed:list error:NULL] : nil)) {
        for (NSString *ch in [HRWord charactersOfString:word]) {
            [characters addObject:ch];
            [characters addObject:[ch uppercaseString]];
        }
    }
    return characters;
}

- (HRWeakSpots *)currentWeakSpots
{
    if (!_store) return nil;
    NSSet *practisable = [self practisableCharacters];
    NSDate *month = [NSDate dateWithTimeIntervalSinceNow:-30.0 * 86400.0];
    for (NSDate *since in @[month, [NSDate distantPast]]) {
        NSDictionary *counts = [HRWeakSpots counts:[_store keyCountsForKind:HRStatKindAll since:since]
                                 keepingCharacters:practisable];
        HRWeakSpots *spots = [HRWeakSpots weakSpotsFromCounts:counts
                                            minimumKeyPresses:10 minimumTotalPresses:300 maximum:6];
        if (spots) return spots;
    }
    return nil;
}

- (IBAction)practiseWeakKeys:(id)sender
{
    [_modePopUp selectItemWithTag:HRTestModePractice];
    [self modeChanged:sender];
    [_window makeKeyAndOrderFront:self];
}

#pragma mark - Preferences

/* Theme, fonts and the beep: at launch, and again whenever Preferences
 * changes one of them. */
- (void)applyAppearance
{
    _theme = [HRTheme currentTheme];
    _testView.theme = _theme;
    _testView.font = [HRTheme fixedPitchFontOfSize:[HRTheme proseFontSize]];
    _testView.beepsOnError = [[NSUserDefaults standardUserDefaults] boolForKey:HRBeepOnErrorDefaultsKey];
    _chartView.theme = _theme;
    _keyboardView.theme = _theme;
    _layoutChooser.theme = _theme;
    _resultsView.backgroundColor = _theme.background;
    [_resultsView setNeedsDisplay:YES];
    [_window setBackgroundColor:_theme.background];
    /* not array literals: an unconnected outlet is the smoke test's to
     * report, not a nil-insertion exception's */
    [_wpmField setTextColor:_theme.accent];
    [_accuracyField setTextColor:_theme.accent];
    [_detailField setTextColor:_theme.untyped];
    [_hintField setTextColor:_theme.untyped];
    [_liveField setTextColor:_theme.untyped];
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
    return _configuration;
}

- (void)preferencesWantsLayoutChooser:(HRPreferencesWindowController *)controller
{
    [self showLayoutChooser:controller];
}

#pragma mark - Choosing a keyboard layout

- (HRLayoutChooserController *)layoutChooser
{
    if (!_layoutChooser) _layoutChooser = [[HRLayoutChooserController alloc] initWithDelegate:self theme:_theme];
    return _layoutChooser;
}

- (IBAction)showLayoutChooser:(id)sender
{
    [[self layoutChooser] chooseStartingFrom:(_configuration.layoutID ?: @"qwerty")];
}

- (NSArray *)layoutIdentifiersForChooser:(HRLayoutChooserController *)chooser
{
    return [HRKeyboardLayout identifiersInDirectory:[self layoutsDirectory]];
}

- (HRKeyboardLayout *)layoutChooser:(HRLayoutChooserController *)chooser layoutNamed:(NSString *)identifier
{
    return [self layoutNamed:identifier];
}

- (void)layoutChooser:(HRLayoutChooserController *)chooser didChoose:(NSString *)identifier
{
    NSMenuItem *carrier = [[NSMenuItem alloc] init];
    [carrier setRepresentedObject:identifier];
    [self selectLayout:carrier];
}

- (NSURL *)storeURLForPreferences:(HRPreferencesWindowController *)controller
{
    return _store ? [HRResultStore defaultStoreURL] : nil;
}

- (void)preferences:(HRPreferencesWindowController *)controller didChange:(HRPreferencesChange)change
{
    [self saveConfiguration];
    if (change & HRPreferencesChangedAppearance) [self applyAppearance];
    if (change & HRPreferencesChangedSound) {
        _sounds.scheme = [[NSUserDefaults standardUserDefaults] stringForKey:HRSoundSchemeDefaultsKey];
        [_sounds playKey:@"a"];   /* what was chosen, heard at once */
    }
    if (change & HRPreferencesChangedPace) {
        [self choosePace];
        [self updateLiveField];
    }
    if (change & HRPreferencesChangedKeyboard) {
        _statsWindow.keyboardLayout = [self layoutNamed:_configuration.layoutID];
        [self syncMenus];
        [self syncKeyboard];
    }
    /* new rules: the test that is being typed starts over under them; a
     * result on screen stays where it is */
    if ((change & HRPreferencesChangedTyping) && [_resultsView isHidden] && _testView.pageText == nil) {
        [self startNewTest];
    }
}

#pragma mark - Statistics

- (HRStatsWindowController *)statsWindow
{
    if (!_statsWindow) {
        _statsWindow = [[HRStatsWindowController alloc] initWithStore:_store theme:_theme];
        _statsWindow.keyboardLayout = [self layoutNamed:_configuration.layoutID] ?: [self layoutNamed:@"qwerty"];
        _statsWindow.subjectSource = self;
        _statsWindow.practiceTarget = self;
        _statsWindow.practiceAction = @selector(practiseWeakKeys:);
    }
    return _statsWindow;
}

/* What a result's courseFile is called: a course by its language and title,
 * a code file by its own. */
- (NSString *)statistics:(HRStatsWindowController *)controller titleForCourseFile:(NSString *)courseFile
{
    if ([courseFile hasPrefix:@"code:"]) return [[self codeLibrary] fileWithIdentifier:courseFile].title;
    NSDictionary *course = [self courseEntryForFile:courseFile];
    if (!course) return nil;
    NSString *language = course[@"language"];
    for (HRLanguage *l in _languages) if ([l.identifier isEqual:course[@"language"]]) language = l.displayName;
    return language ? [NSString stringWithFormat:@"%@ \u2014 %@", language, course[@"title"]] : course[@"title"];
}

- (NSArray *)subjectsForStatistics:(HRStatsWindowController *)controller
{
    NSMutableArray *subjects = [NSMutableArray array];
    for (HRCourseProgress *progress in [_store startedCourses]) {
        NSString *identifier = progress.courseFile;
        NSString *title = [self statistics:controller titleForCourseFile:identifier];
        if (!title) continue;   /* a course or file that is no longer there */
        NSUInteger count = 0;
        BOOL code = [identifier hasPrefix:@"code:"];
        if (code) {
            HRCodeFile *file = [[self codeLibrary] fileWithIdentifier:identifier];
            count = [[self codeLibrary] documentForFile:file error:NULL].numberOfSections;
        } else {
            count = [[self scriptForCourseFile:identifier].lessons count];
        }
        if (count == 0) continue;
        [subjects addObject:@{@"identifier": identifier, @"title": title, @"count": @(count), @"unit": code ? @"part" : @"lesson"}];
    }
    return subjects;
}

- (IBAction)showStatistics:(id)sender
{
    [[self statsWindow] showWindow:self];
    [[self statsWindow] reload];
}

#pragma mark - The on-screen keyboard

- (BOOL)isInCourse
{
    return _configuration.mode == HRTestModeLesson;
}

/* Show Keyboard is remembered three times over: following a course and
 * typing code (on unless switched off), and the free tests (off unless
 * switched on). */
- (NSString *)keyboardDefaultsKey
{
    if ([self isInCourse]) return HRKeyboardInCourseDefaultsKey;
    if (_configuration.mode == HRTestModeCode) return HRKeyboardInCodeDefaultsKey;
    return HRKeyboardInTestsDefaultsKey;
}

- (BOOL)wantsKeyboard
{
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    NSString *key = [self keyboardDefaultsKey];
    if ([d objectForKey:key]) return [d boolForKey:key];
    return ![key isEqualToString:HRKeyboardInTestsDefaultsKey];
}

- (IBAction)toggleKeyboard:(id)sender
{
    [[NSUserDefaults standardUserDefaults] setBool:![self wantsKeyboard] forKey:[self keyboardDefaultsKey]];
    [self syncKeyboard];
    [_preferencesWindow sync];
}

/* Which layout, whether it shows, what is lit.  A course names its layout
 * in index.plist; a course without one (the numeric keypad, or a national
 * layout there is no pack for) gets no keyboard rather than a wrong one. */
- (void)syncKeyboard
{
    HRKeyboardLayout *layout = nil;
    if ([self isInCourse]) {
        NSString *file = _courseFile ?: [self currentCourseFile];
        layout = [self layoutNamed:[self courseEntryForFile:file][@"layout"]];
    } else {
        layout = [self layoutNamed:_configuration.layoutID] ?: [self layoutNamed:@"qwerty"];
    }
    BOOL show = [self wantsKeyboard] && layout != nil;
    [_keyboardMenuItem setState:([self wantsKeyboard] ? NSControlStateValueOn : NSControlStateValueOff)];
    [_testKeyboardMenuItem setState:[_keyboardMenuItem state]];
    _keyboardView.keyboardLayout = layout;
    _keyboardView.expectedInput = (show && _session && _testView.pageText == nil) ? [_session expectedInput] : nil;
    if (show != _keyboardShown) [self setKeyboardShown:show];
}

/* The window grows downwards by the keyboard's height and shrinks back, so
 * the typing surface keeps its size either way.
 *
 * Autoresizing stays ON while the window changes: that is what keeps the
 * control bar glued to the top edge.  (Switching it off for the resize left
 * the bar where it was, in the middle of the taller window.)  The order
 * still matters when hiding: a view squeezed to nothing by a shrinking
 * window never gets its subviews' margins back, so the typing and result
 * views are first given the keyboard's area as well, and then shrink with
 * the window to exactly what is left. */
- (void)setKeyboardShown:(BOOL)show
{
    _keyboardShown = show;
    NSView *contentView = [_window contentView];
    NSRect content = [contentView bounds];
    CGFloat bar = 48.0;   /* the control bar */
    /* hide exactly what was shown, whatever the width has become since */
    CGFloat h = show ? [HRKeyboardView heightForWidth:NSWidth(content)] : _keyboardHeight;
    _keyboardHeight = show ? h : 0.0;

    BOOL fixedFrame = NO;
#if defined(__APPLE__)
    fixedFrame = ([_window styleMask] & NSWindowStyleMaskFullScreen) != 0;
#endif
    if (!show) {
        CGFloat top = MAX(0.0, NSHeight(content) - bar);
        [_testView setFrame:NSMakeRect(0, 0, NSWidth(content), top)];
        [_resultsView setFrame:NSMakeRect(0, 0, NSWidth(content), top)];
    }
    if (!fixedFrame) {
        NSRect frame = [_window frame];
        frame.size.height += show ? h : -h;
        frame.origin.y -= show ? h : -h;
        /* growing downwards must not push the keyboard under the screen's edge */
        NSRect visible = [[_window screen] ?: [NSScreen mainScreen] visibleFrame];
        if (show && !NSIsEmptyRect(visible) && NSMinY(frame) < NSMinY(visible)) {
            frame.origin.y = MIN(NSMinY(visible), NSMaxY(visible) - NSHeight(frame));
        }
        [_window setFrame:frame display:NO];
    }
    NSSize minimum = NSMakeSize(640.0, 360.0 + (show ? h : 0.0));
    [_window setContentMinSize:minimum];

    content = [contentView bounds];
    CGFloat bottom = show ? h : 0.0;
    CGFloat top = MAX(bottom, NSHeight(content) - bar);
    [_keyboardView setHidden:!show];
    [_keyboardView setFrame:NSMakeRect(0, 0, NSWidth(content), h)];
    [_testView setFrame:NSMakeRect(0, bottom, NSWidth(content), top - bottom)];
    [_resultsView setFrame:NSMakeRect(0, bottom, NSWidth(content), top - bottom)];
    [contentView setNeedsDisplay:YES];
}

/* Course > Restart Lesson only means something inside a lesson. */
- (BOOL)validateMenuItem:(NSMenuItem *)item
{
    if (sel_isEqual([item action], @selector(restartLesson:))) return _run != nil;
    if (sel_isEqual([item action], @selector(replayLastTest:))) return _lastReplay != nil && !_replay && ![_resultsView isHidden];
    return YES;
}

#pragma mark - Running a test

- (id<HRTextSource>)makeSource
{
    switch (_configuration.mode) {
        case HRTestModeZen:
            return nil;
        case HRTestModeLesson:   /* a lesson builds its own sources */
        case HRTestModeCode:     /* and so does a section of code */
            return nil;
        case HRTestModePractice: {
            HRLanguage *language = [self currentLanguage];
            NSString *list = [self currentWordListName];
            NSArray *words = list ? [language wordsNamed:list error:NULL] : nil;
            HRWeakSpotSource *source = [[HRWeakSpotSource alloc] initWithWords:words weakSpots:_weakSpots
                                                                        random:[HRRandom randomWithSystemSeed]];
            source.limit = HRPracticeWords;
            return source;
        }
        case HRTestModeCustom:
            return [[HRFixedTextSource alloc] initWithText:_customText ?: @""];
        case HRTestModeTime:
        case HRTestModeWords: {
            HRLanguage *language = [self currentLanguage];
            NSString *list = [self currentWordListName];
            NSArray *words = list ? [language wordsNamed:list error:NULL] : nil;
            /* no pack at all should not mean no app */
            if ([words count] == 0) words = @[@"home", @"row"];
            HRWordListSource *source = [[HRWordListSource alloc] initWithWords:words
                                                                        random:[HRRandom randomWithSystemSeed]];
            source.punctuation = _configuration.punctuation && !language.isCode;
            source.numbers = _configuration.numbers && !language.isCode;
            if (_configuration.mode == HRTestModeWords) source.limit = (NSUInteger)_configuration.amount;
            return source;
        }
    }
    return nil;
}

- (void)startNewTest
{
    [self cancelReplay];   /* whatever asked for a new test means it */
    _lastReplay = nil;
    if (_run) {
        /* Tab in a lesson: this exercise again, not a way out of it */
        [self startLessonStep];
        return;
    }
    if (_configuration.mode == HRTestModeLesson) {
        /* between lessons: on to the next one */
        [self continueCourse:self];
        return;
    }
    if (_configuration.mode == HRTestModeCode) {
        /* Tab while typing: this section again.  After it, or with no file
         * yet: on to wherever the file was left. */
        if (_codeFile && !_codeSectionDone) [self startCodeSection];
        else [self continueCode:self];
        return;
    }
    if (_configuration.mode == HRTestModePractice) {
        /* looked up afresh every round: the round before has just changed it */
        _weakSpots = _weakSpotsForTesting ?: [self currentWeakSpots];
        if (!_weakSpots) {
            [self showPlaceholder:HRLoc(@"There is not enough on record yet to say which keys are weak \u2014\nor none stands out.\n\nType a few tests, lessons or sections of code first.\nreturn \u2014 a time test")
                           inMode:HRTestModePractice];
            return;
        }
    }
    if (_configuration.mode == HRTestModeCustom && _customText == nil) {
        /* a custom mode with no text behind it */
        _configuration.mode = HRTestModeTime;
        [self syncControls];
    }
    _testView.caption = nil;
    _testView.pageText = nil;
    if (_configuration.mode == HRTestModePractice) {
        NSMutableArray *parts = [NSMutableArray array];
        if ([_weakSpots.missedCharacters count] > 0) {
            [parts addObject:[NSString stringWithFormat:HRLoc(@"missed most:   %@"), [_weakSpots.missedCharacters componentsJoinedByString:@"   "]]];
        }
        if ([_weakSpots.slowCharacters count] > 0) {
            [parts addObject:[NSString stringWithFormat:HRLoc(@"slowest:   %@"), [_weakSpots.slowCharacters componentsJoinedByString:@"   "]]];
        }
        /* the words come from the language chosen in the Language menu: say which */
        _testView.caption = [NSString stringWithFormat:HRLoc(@"Practising the keys, in %@ \u2014 %@"),
                             [self currentLanguage].displayName ?: @"?", [parts componentsJoinedByString:@"      "]];
    }
    _session = [[HRTestSession alloc] initWithConfiguration:_configuration source:[self makeSource]];
    _testView.session = _session;
    [self choosePace];
    [_resultsView setHidden:YES];
    [_testView setHidden:NO];
    [_window makeFirstResponder:_testView];
    [self updateLiveField];
    [self syncKeyboard];
}

- (void)updateLiveField
{
    if (_run) {
        NSString *progress = [NSString stringWithFormat:@"%@   %lu/%lu", _run.lesson.title,
                              (unsigned long)MIN(_run.stepIndex + 1, [_run.lesson.steps count]),
                              (unsigned long)[_run.lesson.steps count]];
        if (_session && _session.state != HRSessionIdle) {
            progress = [progress stringByAppendingFormat:@"   %.0f wpm   %.0f%%",
                        [_session liveWpmAtTime:HRMonotonicNow()], [_session liveAccuracy]];
        }
        [_liveField setStringValue:progress];
        return;
    }
    if (_codeFile) {
        NSString *progress = [NSString stringWithFormat:HRLoc(@"%@   part %lu/%lu"), _codeFile.title,
                              (unsigned long)(_codeSection + 1), (unsigned long)_codeSectionCount];
        if (_session && _session.state != HRSessionIdle) {
            progress = [progress stringByAppendingFormat:@"   %.0f wpm   %.0f%%",
                        [_session liveWpmAtTime:HRMonotonicNow()], [_session liveAccuracy]];
        }
        [_liveField setStringValue:progress];
        return;
    }
    if (_session.state == HRSessionIdle) {
        NSString *idle = (_configuration.mode == HRTestModeZen
                          ? HRLoc(@"type anything — shift+return to finish")
                          : HRLoc(@"start typing"));
        if (_paceWpm > 0.0) idle = [idle stringByAppendingFormat:HRLoc(@"   \u2014   pace caret at %.0f wpm"), _paceWpm];
        [_liveField setStringValue:idle];
        return;
    }
    NSTimeInterval now = [self sessionNow];
    NSInteger remaining = [_session remainingAtTime:now];
    NSString *left = remaining >= 0 ? [NSString stringWithFormat:@"%ld   ", (long)remaining] : @"";
    [_liveField setStringValue:[NSString stringWithFormat:@"%@%.0f wpm   %.0f%%",
                                left, [_session liveWpmAtTime:now], [_session liveAccuracy]]];
}

- (void)timerFired:(NSTimer *)timer
{
    if (_replay) {
        [self replayTick];
        return;
    }
    [_testView tick];
    [self movePaceCaret];
}

- (NSTimeInterval)sessionNow
{
    return HRMonotonicNow();
}

#pragma mark - The pace caret

/* Settled when a test starts: a caret that changed its mind half-way would
 * be no pace at all. */
- (void)choosePace
{
    _paceWpm = 0.0;
    HRTestMode mode = _configuration.mode;
    BOOL paced = (mode == HRTestModeTime || mode == HRTestModeWords || mode == HRTestModeCustom || mode == HRTestModePractice)
                 && !_run && !_codeFile;
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    HRPaceKind kind = paced ? (HRPaceKind)[d integerForKey:HRPaceKindDefaultsKey] : HRPaceOff;
    NSString *key = [_configuration settingsKey];
    switch (kind) {
        case HRPaceOff:
            break;
        case HRPaceAverage:
            _paceWpm = [HRPace averageOfRecentSpeeds:[_store recentSpeedsForSettingsKey:key limit:10]];
            break;
        case HRPaceBest:
            _paceWpm = [[_store personalBestForSettingsKey:key error:NULL].wpm doubleValue];
            break;
        case HRPaceCustom:
            _paceWpm = (double)[d integerForKey:HRPaceCustomWpmDefaultsKey];
            if (_paceWpm <= 0.0) _paceWpm = 60.0;
            break;
    }
    /* nothing on record with these settings yet: nothing to race */
    [self movePaceCaret];
}

- (void)movePaceCaret
{
    HRTestSession *session = _replay ? _replaySession : _session;
    if (_paceWpm <= 0.0 || !session || session.state == HRSessionFinished) {
        _testView.paceCharacters = -1.0;
        return;
    }
    NSTimeInterval now = _replay ? [_replay timeAtElapsed:(HRMonotonicNow() - _replayBegan)] : HRMonotonicNow();
    NSTimeInterval elapsed = session.state == HRSessionRunning ? [session elapsedAtTime:now] : 0.0;
    _testView.paceCharacters = [HRPace charactersAtWpm:_paceWpm elapsed:elapsed];
}

#pragma mark - Replay

/* The test whose result is on screen, typed again by nobody, at the speed
 * it was typed at.  Nothing is recorded; Tab, Esc or Return go back to the
 * result. */
- (IBAction)replayLastTest:(id)sender
{
    if (!_lastReplay || _replay || [_resultsView isHidden]) return;
    _replay = _lastReplay;
    _replaySession = [_replay begin];
    _replayBegan = HRMonotonicNow();
    _testView.session = _replaySession;
    _testView.replaying = YES;
    [_resultsView setHidden:YES];
    [_testView setHidden:NO];
    [_window makeFirstResponder:_testView];
    [self movePaceCaret];
    [self replayTick];
}

- (void)replayTick
{
    NSTimeInterval elapsed = HRMonotonicNow() - _replayBegan;
    [self advanceReplayToElapsed:elapsed];
}

- (void)advanceReplayToElapsed:(NSTimeInterval)elapsed
{
    if (!_replay) return;
    NSUInteger wrongBefore = _replaySession.wrongInputCount;
    NSUInteger wordBefore = _replaySession.currentWordIndex, caretBefore = [_replaySession caretIndexInCurrentWord];
    BOOL more = [_replay advanceToElapsed:elapsed];
    /* the sounds of it too, a tick's worth at a time */
    if (_replaySession.wrongInputCount != wrongBefore) [_sounds playError];
    else if (_replaySession.currentWordIndex != wordBefore || [_replaySession caretIndexInCurrentWord] != caretBefore) [_sounds playKey:@"a"];
    [_testView setNeedsDisplay:YES];
    [self movePaceCaret];
    NSTimeInterval now = [_replay timeAtElapsed:elapsed];
    [_liveField setStringValue:[NSString stringWithFormat:HRLoc(@"replay   %.0f wpm   %.0f%%   %.0fs   \u2014   esc \u2014 back to the result"),
                                [_replaySession liveWpmAtTime:now], [_replaySession liveAccuracy],
                                MIN(elapsed, _replay.duration)]];
    if (!more) [self endReplay];
}

/* Stops the show and leaves the stage as it is: for whoever is about to
 * put something else on it. */
- (void)cancelReplay
{
    if (!_replay) return;
    _replay = nil;
    _replaySession = nil;
    _testView.replaying = NO;
    _testView.session = _session;
    _testView.paceCharacters = -1.0;
}

/* ...and back to the result it came from. */
- (void)endReplay
{
    if (!_replay) return;
    [self cancelReplay];
    [_testView setHidden:YES];
    [_resultsView setHidden:NO];
    [_window makeFirstResponder:_resultsView];
    [_liveField setStringValue:@""];
}

/* "r" where a result is shown; the hint under the result says so. */
- (NSString *)hintWithReplay:(NSString *)hint
{
    return _lastReplay ? [hint stringByAppendingString:HRLoc(@"      r \u2014 replay")] : hint;
}

#pragma mark - Sounds

- (void)testView:(HRTestView *)view didTypeInput:(NSString *)input correctly:(BOOL)correct
{
    if (correct) [_sounds playKey:input];
    else [_sounds playError];
}

#pragma mark - HRTestViewDelegate

- (void)testViewDidRequestRestart:(HRTestView *)view
{
    if (_replay) {
        /* Tab, Esc or Return while a replay runs: back to its result */
        [self endReplay];
        return;
    }
    [self startNewTest];
}

- (void)testViewDidDismissPage:(HRTestView *)view
{
    if (!_run) {
        /* the "choose a course" page, or code mode's "choose a file" */
        if (_configuration.mode == HRTestModeCode) [self showCode:self];
        else if (_configuration.mode == HRTestModePractice) {
            /* the "nothing to practise yet" page: on to something that makes a record */
            [_modePopUp selectItemWithTag:HRTestModeTime];
            [self modeChanged:self];
        }
        else [self showCourses:self];
        return;
    }
    [_run advancePastPage];
    [self startLessonStep];
}

- (void)testViewDidChange:(HRTestView *)view
{
    [self updateLiveField];
    if (_keyboardShown) _keyboardView.expectedInput = [_session expectedInput];
}

/* the key pressed by mistake shows red on the keyboard for a moment */
- (void)testView:(HRTestView *)view didTypeWrongInput:(NSString *)input
{
    _keyboardView.wrongInput = _keyboardShown ? input : nil;
}

- (void)testViewDidFinish:(HRTestView *)view
{
    HRTestSummary *s = [_session summary];
    _testView.paceCharacters = -1.0;
    /* a lesson goes straight on to its next exercise: there is no result to replay from */
    _lastReplay = _run ? nil : [[HRReplay alloc] initWithSession:_session];

    BOOL isBest = NO;
    /* a test with nothing in it is not a result */
    BOOL worthKeeping = s.duration >= 1.0 && (s.correctKeystrokes + s.incorrectKeystrokes) > 0;
    if (_store && worthKeeping) {
        NSString *key = [_configuration settingsKey];
        HRTestResult *best = [_store personalBestForSettingsKey:key error:NULL];
        isBest = (_configuration.mode == HRTestModeTime || _configuration.mode == HRTestModeWords)
                 && best != nil && s.wpm > [best.wpm doubleValue];
        NSError *error = nil;
        BOOL saved = _codeFile
            ? [_store recordSummary:s configuration:(_session.configuration ?: _configuration) courseFile:_codeFile.identifier
                        lessonIndex:_codeSection stepIndex:0 date:[NSDate date] error:&error] != nil
            : _run
            ? [_store recordSummary:s configuration:(_session.configuration ?: _configuration) courseFile:_courseFile lessonIndex:_lessonIndex
                          stepIndex:_run.stepIndex date:[NSDate date] error:&error] != nil
            : [_store recordSummary:s configuration:(_session.configuration ?: _configuration) date:[NSDate date] error:&error] != nil;
        if (!saved) {
            NSLog(@"HomeRow: the result was not saved: %@", error);
        }
    }

    [_statsWindow reload];
    if (_run) {
        [self lessonExerciseDidFinish:s];
        return;
    }
    if (_codeFile) {
        [self finishCodeSection:s worthKeeping:worthKeeping];
        return;
    }
    [self showSummary:s isBest:isBest];
    [self syncKeyboard];
}

- (void)showSummary:(HRTestSummary *)s isBest:(BOOL)isBest
{
    [_wpmField setStringValue:[NSString stringWithFormat:@"%.0f %@", s.wpm, HRLoc(@"wpm")]];
    [_accuracyField setStringValue:[NSString stringWithFormat:@"%.0f%% %@", s.accuracy, HRLoc(@"acc")]];
    [_detailField setStringValue:[NSString stringWithFormat:
        HRLoc(@"raw %.0f   consistency %.0f%%   characters %lu/%lu/%lu/%lu   %.0fs%@"),
        s.rawWpm, s.consistency,
        (unsigned long)s.correctCharacters, (unsigned long)s.incorrectCharacters,
        (unsigned long)s.extraCharacters, (unsigned long)s.missedCharacters,
        s.duration, isBest ? HRLoc(@"   — new personal best") : @""]];
    [_hintField setStringValue:[self hintWithReplay:HRLoc(@"tab, esc or return — next test")]];
    _chartView.errors = s.errorsPerSecond;
    _chartView.average = s.rawWpm;
    _chartView.samples = s.rawWpmPerSecond;

    [_testView setHidden:YES];
    [_resultsView setHidden:NO];
    [_window makeFirstResponder:_resultsView];
    [_liveField setStringValue:@""];
}

@end
