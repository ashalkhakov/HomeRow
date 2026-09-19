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
#import <objc/runtime.h>

static NSString * const HRConfigurationDefaultsKey = @"HRConfiguration";
static NSString * const HRCurrentCourseDefaultsKey = @"HRCurrentCourse";
/* the keyboard shows by default while following a course, and not otherwise */
static NSString * const HRKeyboardInCourseDefaultsKey = @"HRShowKeyboardInCourse";
static NSString * const HRKeyboardInTestsDefaultsKey = @"HRShowKeyboardInTests";

#define HRLoc(key) NSLocalizedString(key, nil)

@interface HRAppDelegate () <HRCourseWindowDelegate>
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

    NSMenu *_languageMenu;
    NSMenu *_wordListMenu;
    NSMutableDictionary *_scripts;   /* course file -> HRTypScript, parsed on demand */

    NSMenu *_layoutMenu;
    NSMenuItem *_keyboardMenuItem;
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

    _theme = [HRTheme currentTheme];
    _testView.theme = _theme;
    _testView.delegate = self;
    _chartView.theme = _theme;
    _keyboardView.theme = _theme;
    [_keyboardView setHidden:YES];
    _resultsView.backgroundColor = _theme.background;
    _resultsView.target = self;
    [_window setBackgroundColor:_theme.background];
    /* not array literals: an unconnected outlet is the smoke test's to
     * report, not a nil-insertion exception's */
    [_wpmField setTextColor:_theme.accent];
    [_accuracyField setTextColor:_theme.accent];
    [_detailField setTextColor:_theme.untyped];
    [_hintField setTextColor:_theme.untyped];
    [_liveField setTextColor:_theme.untyped];

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
    [texts removeObjectAtIndex:0];
    [_testView typeText:[texts componentsJoinedByString:@" "] atTime:now];
    if (_store && [[_store recentResultsWithLimit:0 error:NULL] count] != before + 1) {
        [failures addObject:@"the result was not saved"];
    }
    if (_session.state != HRSessionFinished) [failures addObject:@"typing the whole text did not finish the test"];
    if ([_resultsView isHidden]) [failures addObject:@"the results were not shown"];
    if ([[_wpmField stringValue] length] == 0) [failures addObject:@"the results are empty"];

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
    [self selectLanguage:[_languageMenu itemWithTitle:@"Russian"]];
    if (_keyboardShown) [failures addObject:@"the keyboard stayed up outside the course"];
    if ([_amountPopUp isHidden] || [_modePopUp isHidden] || NSMaxY([_modePopUp frame]) < NSMaxY([[_window contentView] bounds]) - 30.0
        || fabs(NSMinY([_testView frame])) > 0.5 || NSMaxY([_testView frame]) > NSMinY([_modePopUp frame])) {
        [failures addObject:@"after the course, the window did not go back to its test layout"];
    }
    if (![[self currentLanguage].identifier isEqualToString:@"russian"] || _session == nil
        || [_session.words count] == 0) {
        [failures addObject:@"switching to Russian did not start a Russian test"];
    }
    if ([_wordListMenu numberOfItems] < 2) [failures addObject:@"the word-list menu was not rebuilt"];

    /* draw everything once, so that a drawing method that raises, or that
     * the text system complains about, does so here and not on a user */
    [self toggleKeyboard:self];
    [[_window contentView] display];
    [self toggleKeyboard:self];
    [[_window contentView] display];

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
    [_punctuationCheck setEnabled:generated];
    [_numbersCheck setEnabled:generated];
    /* following a course, none of the three means anything: the lesson
     * decides the text.  Greyed-out is for "not now"; this is "not here". */
    BOOL inCourse = (_configuration.mode == HRTestModeLesson);
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
        if (!_run) [self continueCourse:sender];
        return;
    }
    [self leaveLesson];
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
    for (HRLanguage *l in byName) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:l.displayName
                                                      action:@selector(selectLanguage:)
                                               keyEquivalent:@""];
        [item setTarget:self];
        [item setRepresentedObject:l.identifier];
        [_languageMenu addItem:item];
    }
    NSMenuItem *languageItem = [[NSMenuItem alloc] initWithTitle:HRLoc(@"Language") action:NULL keyEquivalent:@""];
    [languageItem setSubmenu:_languageMenu];
    [main insertItem:languageItem atIndex:at];

    /* Language > Keyboard Layout: what the on-screen keyboard draws when no
     * course says otherwise.  It describes the system's layout; it never
     * changes it. */
    _layoutMenu = [[NSMenu alloc] initWithTitle:HRLoc(@"Keyboard Layout")];
    for (NSString *identifier in [HRKeyboardLayout identifiersInDirectory:[self layoutsDirectory]]) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:[identifier stringByReplacingOccurrencesOfString:@"_" withString:@" "]
                                                      action:@selector(selectLayout:) keyEquivalent:@""];
        [item setTarget:self];
        [item setRepresentedObject:identifier];
        [_layoutMenu addItem:item];
    }
    NSMenuItem *layouts = [[NSMenuItem alloc] initWithTitle:HRLoc(@"Keyboard Layout") action:NULL keyEquivalent:@""];
    [layouts setSubmenu:_layoutMenu];
    [_languageMenu insertItem:layouts atIndex:1];

    _courses = [NSDictionary dictionaryWithContentsOfFile:
                [[self lessonsDirectory] stringByAppendingPathComponent:@"index.plist"]][@"courses"] ?: @[];
    _scripts = [NSMutableDictionary dictionary];

    NSMenu *testMenu = [[main itemWithTitle:@"Test"] submenu];
    if (testMenu) {
        [testMenu addItem:(NSMenuItem *)[NSMenuItem separatorItem]];
        NSArray *modes = @[@[HRLoc(@"Time Test"), @(HRTestModeTime), @"1"],
                           @[HRLoc(@"Words Test"), @(HRTestModeWords), @"2"],
                           @[HRLoc(@"Zen"), @(HRTestModeZen), @"3"]];
        for (NSArray *mode in modes) {
            NSMenuItem *modeItem = (NSMenuItem *)[testMenu addItemWithTitle:mode[0] action:@selector(selectMode:)
                                                              keyEquivalent:mode[2]];
            [modeItem setTarget:self];
            [modeItem setTag:[mode[1] integerValue]];
        }
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
    }
    for (NSMenuItem *item in [_languageMenu itemArray]) {
        if (![item representedObject]) continue;
        BOOL on = [[item representedObject] isEqual:[self currentLanguage].identifier];
        [item setState:(on ? NSControlStateValueOn : NSControlStateValueOff)];
    }
    for (NSMenuItem *item in [_layoutMenu itemArray]) {
        BOOL on = [[item representedObject] isEqual:_configuration.layoutID];
        [item setState:(on ? NSControlStateValueOn : NSControlStateValueOff)];
    }
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
    [self syncControls];
    [self saveConfiguration];
    [self startNewTest];
}

- (IBAction)selectLayout:(id)sender
{
    _configuration.layoutID = [sender representedObject];
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
    [self leaveLesson];
    _configuration.mode = HRTestModeLesson;
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
    _run = [[HRCourseRun alloc] initWithLesson:lesson startingAtStep:step];
    if (_run.stepIndex == 0) {
        [_store noteLessonStarted:lessonIndex title:lesson.title inCourse:file error:NULL];
    }
    NSDictionary *course = [self courseEntryForFile:file];
    _configuration.mode = HRTestModeLesson;
    if (course[@"language"]) _configuration.languageID = course[@"language"];
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
        _session = [[HRTestSession alloc] initWithConfiguration:_configuration
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

#pragma mark - The on-screen keyboard

- (BOOL)isInCourse
{
    return _configuration.mode == HRTestModeLesson;
}

- (BOOL)wantsKeyboard
{
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    if ([self isInCourse]) {
        return [d objectForKey:HRKeyboardInCourseDefaultsKey] ? [d boolForKey:HRKeyboardInCourseDefaultsKey] : YES;
    }
    return [d boolForKey:HRKeyboardInTestsDefaultsKey];
}

- (IBAction)toggleKeyboard:(id)sender
{
    [[NSUserDefaults standardUserDefaults] setBool:![self wantsKeyboard]
                                            forKey:([self isInCourse] ? HRKeyboardInCourseDefaultsKey
                                                                      : HRKeyboardInTestsDefaultsKey)];
    [self syncKeyboard];
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
    return YES;
}

#pragma mark - Running a test

- (id<HRTextSource>)makeSource
{
    switch (_configuration.mode) {
        case HRTestModeZen:
            return nil;
        case HRTestModeLesson:   /* a lesson builds its own sources */
            return nil;
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
            source.punctuation = _configuration.punctuation;
            source.numbers = _configuration.numbers;
            if (_configuration.mode == HRTestModeWords) source.limit = (NSUInteger)_configuration.amount;
            return source;
        }
    }
    return nil;
}

- (void)startNewTest
{
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
    if (_configuration.mode == HRTestModeCustom && _customText == nil) {
        /* a custom mode with no text behind it */
        _configuration.mode = HRTestModeTime;
        [self syncControls];
    }
    _testView.caption = nil;
    _testView.pageText = nil;
    _session = [[HRTestSession alloc] initWithConfiguration:_configuration source:[self makeSource]];
    _testView.session = _session;
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
    if (_session.state == HRSessionIdle) {
        [_liveField setStringValue:(_configuration.mode == HRTestModeZen
                                    ? HRLoc(@"type anything — shift+return to finish")
                                    : HRLoc(@"start typing"))];
        return;
    }
    NSTimeInterval now = HRMonotonicNow();
    NSInteger remaining = [_session remainingAtTime:now];
    NSString *left = remaining >= 0 ? [NSString stringWithFormat:@"%ld   ", (long)remaining] : @"";
    [_liveField setStringValue:[NSString stringWithFormat:@"%@%.0f wpm   %.0f%%",
                                left, [_session liveWpmAtTime:now], [_session liveAccuracy]]];
}

- (void)timerFired:(NSTimer *)timer
{
    [_testView tick];
}

#pragma mark - HRTestViewDelegate

- (void)testViewDidRequestRestart:(HRTestView *)view
{
    [self startNewTest];
}

- (void)testViewDidDismissPage:(HRTestView *)view
{
    if (!_run) {
        /* the "choose a course" page */
        [self showCourses:self];
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

- (void)testViewDidFinish:(HRTestView *)view
{
    HRTestSummary *s = [_session summary];

    BOOL isBest = NO;
    /* a test with nothing in it is not a result */
    BOOL worthKeeping = s.duration >= 1.0 && (s.correctKeystrokes + s.incorrectKeystrokes) > 0;
    if (_store && worthKeeping) {
        NSString *key = [_configuration settingsKey];
        HRTestResult *best = [_store personalBestForSettingsKey:key error:NULL];
        isBest = (_configuration.mode == HRTestModeTime || _configuration.mode == HRTestModeWords)
                 && best != nil && s.wpm > [best.wpm doubleValue];
        NSError *error = nil;
        BOOL saved = _run
            ? [_store recordSummary:s configuration:_configuration courseFile:_courseFile lessonIndex:_lessonIndex
                          stepIndex:_run.stepIndex date:[NSDate date] error:&error] != nil
            : [_store recordSummary:s configuration:_configuration date:[NSDate date] error:&error] != nil;
        if (!saved) {
            NSLog(@"HomeRow: the result was not saved: %@", error);
        }
    }

    if (_run) {
        [self lessonExerciseDidFinish:s];
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
    [_hintField setStringValue:HRLoc(@"tab, esc or return — next test")];
    _chartView.errors = s.errorsPerSecond;
    _chartView.average = s.rawWpm;
    _chartView.samples = s.rawWpmPerSecond;

    [_testView setHidden:YES];
    [_resultsView setHidden:NO];
    [_window makeFirstResponder:_resultsView];
    [_liveField setStringValue:@""];
}

@end
