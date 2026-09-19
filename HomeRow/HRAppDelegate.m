/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * This library is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2.1 of the License, or (at
 * your option) any later version.  See COPYING.LIB.
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
    [_punctuationCheck setState:(_configuration.punctuation ? NSControlStateValueOn : NSControlStateValueOff)];
    [_numbersCheck setState:(_configuration.numbers ? NSControlStateValueOn : NSControlStateValueOff)];
}

- (void)saveConfiguration
{
    [[NSUserDefaults standardUserDefaults] setObject:[_configuration dictionaryRepresentation]
                                              forKey:HRConfigurationDefaultsKey];
}

- (IBAction)modeChanged:(id)sender
{
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
    _customText = text;
    _configuration.mode = HRTestModeCustom;
    [self syncControls];
    [self startNewTest];
}

#pragma mark - Running a test

- (id<HRTextSource>)makeSource
{
    switch (_configuration.mode) {
        case HRTestModeZen:
            return nil;
        case HRTestModeCustom:
            return [[HRFixedTextSource alloc] initWithText:_customText ?: @""];
        case HRTestModeTime:
        case HRTestModeWords: {
            HRLanguage *language = [self currentLanguage];
            NSString *list = _configuration.wordListName;
            if (![language.wordListNames containsObject:list]) list = [language.wordListNames firstObject];
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
    _session = [[HRTestSession alloc] initWithConfiguration:_configuration source:[self makeSource]];
    _testView.session = _session;
    [_resultsView setHidden:YES];
    [_testView setHidden:NO];
    [_window makeFirstResponder:_testView];
    [self updateLiveField];
}

- (void)updateLiveField
{
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
        isBest = (_configuration.mode != HRTestModeCustom && _configuration.mode != HRTestModeZen)
                 && best != nil && s.wpm > [best.wpm doubleValue];
        NSError *error = nil;
        if (![_store recordSummary:s configuration:_configuration date:[NSDate date] error:&error]) {
            NSLog(@"HomeRow: the result was not saved: %@", error);
        }
    }

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
