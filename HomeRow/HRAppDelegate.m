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

static NSString * const HRConfigurationDefaultsKey = @"HRConfiguration";

#define HRLoc(key) NSLocalizedString(key, nil)

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

    /* a lesson in progress: nil when testing freely */
    HRTypLesson *_lesson;
    NSUInteger _stepIndex;
    BOOL _repeating;
    HRTestSummary *_lastLessonSummary;
}

#pragma mark - Launch

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    NSDictionary *saved = [[NSUserDefaults standardUserDefaults] dictionaryForKey:HRConfigurationDefaultsKey];
    _configuration = saved ? [[HRTestConfiguration alloc] initWithDictionary:saved]
                           : [HRTestConfiguration defaultConfiguration];
    /* a custom text does not outlive the run that opened it */
    if (_configuration.mode == HRTestModeCustom || _configuration.mode == HRTestModeLesson) {
        _configuration.mode = HRTestModeTime;
    }

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

    /* A whole lesson, the way the Lessons menu starts one: read the pages,
     * type the drills, arrive at the results. */
    NSMenuItem *starter = [[NSMenuItem alloc] initWithTitle:@"" action:NULL keyEquivalent:@""];
    [starter setRepresentedObject:@[@"q.typ", @0]];
    [self startLesson:starter];
    if (!_lesson) {
        [failures addObject:@"the first lesson of q.typ did not start"];
    } else {
        NSUInteger pages = 0, exercises = 0;
        NSTimeInterval t = HRMonotonicNow();
        for (NSUInteger guard = 0; _lesson && guard < 1000; guard++) {
            HRTypStep *step = _lesson.steps[_stepIndex];
            if (_testView.pageText) { pages++; [self testViewDidDismissPage:_testView]; }
            else { exercises++; t += 10.0; [_testView typeText:step.text atTime:t]; }
        }
        if (_lesson) [failures addObject:@"the lesson did not come to an end"];
        if (pages == 0 || exercises == 0) [failures addObject:@"the lesson had no pages or no exercises"];
        if ([_resultsView isHidden]) [failures addObject:@"the lesson did not end on the results"];
        printf("HomeRow smoke test: lesson with %lu pages and %lu exercises\n", (unsigned long)pages, (unsigned long)exercises);
    }
    [self selectLanguage:[_languageMenu itemWithTitle:@"Russian"]];
    if (![[self currentLanguage].identifier isEqualToString:@"russian"] || _session == nil
        || [_session.words count] == 0) {
        [failures addObject:@"switching to Russian did not start a Russian test"];
    }
    if ([_wordListMenu numberOfItems] < 2) [failures addObject:@"the word-list menu was not rebuilt"];

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
    if (_configuration.mode == HRTestModeCustom || _configuration.mode == HRTestModeLesson) {
        [_modePopUp addItemWithTitle:HRLoc([_configuration modeName])];
        [[_modePopUp lastItem] setTag:_configuration.mode];
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
    [_punctuationCheck setState:(_configuration.punctuation ? NSControlStateValueOn : NSControlStateValueOff)];
    [_numbersCheck setState:(_configuration.numbers ? NSControlStateValueOn : NSControlStateValueOff)];
    [self syncMenus];
}

- (void)saveConfiguration
{
    [[NSUserDefaults standardUserDefaults] setObject:[_configuration dictionaryRepresentation]
                                              forKey:HRConfigurationDefaultsKey];
}

- (IBAction)modeChanged:(id)sender
{
    [self leaveLesson];
    _configuration.mode = (HRTestMode)[[_modePopUp selectedItem] tag];
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

    /* Lessons > language > course > lesson.  The lesson level is filled in
     * when a course's submenu first opens (-menuNeedsUpdate:): parsing all
     * the courses at launch would cost a second nobody asked for. */
    NSString *dir = [self lessonsDirectory];
    NSArray *courses = [NSDictionary dictionaryWithContentsOfFile:[dir stringByAppendingPathComponent:@"index.plist"]][@"courses"];
    if ([courses count] == 0) return;
    _scripts = [NSMutableDictionary dictionary];
    NSMenu *lessonsMenu = [[NSMenu alloc] initWithTitle:HRLoc(@"Lessons")];
    NSMutableDictionary *perLanguage = [NSMutableDictionary dictionary];
    for (NSDictionary *course in courses) {
        NSString *languageID = course[@"language"] ?: @"";
        NSMenu *languageCourses = perLanguage[languageID];
        if (!languageCourses) {
            NSString *name = languageID;
            for (HRLanguage *l in _languages) if ([l.identifier isEqualToString:languageID]) name = l.displayName;
            languageCourses = [[NSMenu alloc] initWithTitle:name];
            perLanguage[languageID] = languageCourses;
        }
        NSMenu *courseMenu = [[NSMenu alloc] initWithTitle:course[@"title"]];
        /* NSMenuDelegate is adopted informally: gnustep-gui's declaration of
         * the protocol has no @optional, and would demand all of it */
        [courseMenu setDelegate:(id)self];
        NSMenuItem *courseItem = [[NSMenuItem alloc] initWithTitle:course[@"title"] action:NULL keyEquivalent:@""];
        [courseItem setRepresentedObject:course[@"file"]];
        [courseItem setSubmenu:courseMenu];
        [languageCourses addItem:courseItem];
    }
    NSArray *names = [[perLanguage allValues] sortedArrayUsingDescriptors:
                      @[[NSSortDescriptor sortDescriptorWithKey:@"title" ascending:YES]]];
    for (NSMenu *m in names) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:[m title] action:NULL keyEquivalent:@""];
        [item setSubmenu:m];
        [lessonsMenu addItem:item];
    }
    NSMenuItem *lessonsItem = [[NSMenuItem alloc] initWithTitle:HRLoc(@"Lessons") action:NULL keyEquivalent:@""];
    [lessonsItem setSubmenu:lessonsMenu];
    [main insertItem:lessonsItem atIndex:at + 1];
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

/* Fills a course's submenu with its lessons the first time it opens. */
- (void)menuNeedsUpdate:(NSMenu *)menu
{
    if ([menu numberOfItems] > 0) return;
    NSString *file = nil;
    NSMenu *parent = [menu supermenu];
    for (NSMenuItem *item in [parent itemArray]) {
        if ([item submenu] == menu) file = [item representedObject];
    }
    if (!file) return;
    NSArray *lessons = [self scriptForCourseFile:file].lessons;
    for (NSUInteger i = 0; i < [lessons count]; i++) {
        HRTypLesson *lesson = lessons[i];
        NSString *title = [lesson.title length] > 0 ? lesson.title
                          : [NSString stringWithFormat:@"%lu", (unsigned long)(i + 1)];
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:@selector(startLesson:) keyEquivalent:@""];
        [item setTarget:self];
        [item setRepresentedObject:@[file, @(i)]];
        [menu addItem:item];
    }
}

- (void)syncMenus
{
    for (NSMenuItem *item in [_languageMenu itemArray]) {
        if (![item representedObject]) continue;
        BOOL on = [[item representedObject] isEqual:[self currentLanguage].identifier];
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

- (IBAction)selectWordList:(id)sender
{
    _configuration.wordListName = [sender representedObject];
    [self leaveLesson];
    [self syncControls];
    [self saveConfiguration];
    [self startNewTest];
}

#pragma mark - Lessons

- (IBAction)startLesson:(id)sender
{
    NSArray *ref = [sender representedObject];
    NSArray *lessons = [self scriptForCourseFile:ref[0]].lessons;
    NSUInteger i = [ref[1] unsignedIntegerValue];
    if (i >= [lessons count]) return;
    _lesson = lessons[i];
    _stepIndex = 0;
    _repeating = NO;
    _lastLessonSummary = nil;
    _configuration.mode = HRTestModeLesson;
    [self syncControls];
    [self startLessonStep];
}

- (void)leaveLesson
{
    _lesson = nil;
    _testView.pageText = nil;
    _testView.caption = nil;
}

- (void)startLessonStep
{
    if (_stepIndex >= [_lesson.steps count]) {
        [self finishLesson];
        return;
    }
    HRTypStep *step = _lesson.steps[_stepIndex];
    [_resultsView setHidden:YES];
    [_testView setHidden:NO];
    [_window makeFirstResponder:_testView];
    if (!step.isExercise) {
        _session = nil;
        _testView.session = nil;
        _testView.caption = nil;
        _testView.pageText = step.text;
        [self updateLiveField];
        return;
    }
    NSString *caption = step.instruction;
    if (_repeating) {
        NSString *again = HRLoc(@"Too many errors — once more.");
        caption = [caption length] > 0 ? [NSString stringWithFormat:@"%@\n%@", again, caption] : again;
    }
    _testView.pageText = nil;
    _testView.caption = caption;
    _session = [[HRTestSession alloc] initWithConfiguration:_configuration
                                                     source:[[HRFixedTextSource alloc] initWithText:step.text]];
    _testView.session = _session;
    [self updateLiveField];
}

/* GNU Typist's rule: an exercise with more than its allowed share of wrong
 * keystrokes (3% unless the script says otherwise) is done again, unless
 * it is marked practice-only. */
- (void)lessonExerciseDidFinish:(HRTestSummary *)summary
{
    HRTypStep *step = _lesson.steps[_stepIndex];
    double allowed = step.maxErrorPercent >= 0.0 ? step.maxErrorPercent : 3.0;
    _lastLessonSummary = summary;
    if (!step.practiceOnly && (100.0 - summary.accuracy) > allowed) {
        _repeating = YES;
    } else {
        _repeating = NO;
        _stepIndex++;
    }
    [self startLessonStep];
}

- (void)finishLesson
{
    NSString *title = _lesson.title;
    HRTestSummary *last = _lastLessonSummary;
    [self leaveLesson];
    if (last) [self showSummary:last isBest:NO];
    [_hintField setStringValue:[NSString stringWithFormat:HRLoc(@"%@ — lesson complete.  tab, esc or return — free practice"), title]];
}

#pragma mark - Running a test

- (id<HRTextSource>)makeSource
{
    switch (_configuration.mode) {
        case HRTestModeZen:
            return nil;
        case HRTestModeLesson:   /* a lesson builds its own sources */
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
    if (_lesson) {
        /* Tab in a lesson: this exercise again, not a way out of it */
        [self startLessonStep];
        return;
    }
    if (_configuration.mode == HRTestModeLesson
        || (_configuration.mode == HRTestModeCustom && _customText == nil)) {
        /* a finished lesson, or a custom mode with no text behind it */
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
}

- (void)updateLiveField
{
    if (_lesson) {
        NSString *progress = [NSString stringWithFormat:@"%@   %lu/%lu", _lesson.title,
                              (unsigned long)MIN(_stepIndex + 1, [_lesson.steps count]), (unsigned long)[_lesson.steps count]];
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
    if (!_lesson) return;
    _stepIndex++;
    [self startLessonStep];
}

- (void)testViewDidChange:(HRTestView *)view
{
    [self updateLiveField];
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
        if (![_store recordSummary:s configuration:_configuration date:[NSDate date] error:&error]) {
            NSLog(@"HomeRow: the result was not saved: %@", error);
        }
    }

    if (_lesson) {
        [self lessonExerciseDidFinish:s];
        return;
    }
    [self showSummary:s isBest:isBest];
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
