/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * HomeRow is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version.  It comes with ABSOLUTELY NO WARRANTY.  See COPYING.
 */
#import "HRSmokeTest.h"
#import "HRAppDelegate.h"
#import "HRAppModel.h"
#import "HRStage.h"
#import "HRActivity.h"
#import "HRFreeTestActivity.h"
#import "HRCourseActivity.h"
#import "HRCodeActivity.h"
#import "HRKeyboardDock.h"
#import "HRMenuController.h"
#import "HRManagedObjects.h"
#import "HRChartView.h"
#import "HRResultsView.h"
#import "HRTheme.h"
#import "HRResultStore.h"
#import "HRTestSession.h"
#import "HRLanguage.h"
#import "HRPacks.h"
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
/* +[NSTask launchPathForTool:], for the AppImage's xdg-open check.  Guarded by
 * what is there rather than by GNUSTEP: CI's import check wants exactly this
 * form on the line above anything outside Foundation/AppKit/CoreData. */
#if __has_include(<GNUstepBase/NSTask+GNUstepBase.h>)
#import <GNUstepBase/NSTask+GNUstepBase.h>
#endif
#import "HRPace.h"
#import "HRReplay.h"
#import "HRSoundPlayer.h"
#import "HRWelcomeWindowController.h"

/* What the test pokes that nobody else needs to: said here, not in the
 * app delegate's header. */
@interface HRAppDelegate (HRSmokeTest) <HRMenuActions>
- (void)syncControls;
- (void)syncKeyboard;
- (void)applyAppearance;
@end

@interface HRMenuController (HRSmokeTest)
- (void)rebuildStartedCourseItems;
- (NSArray *)startedCourseItems;
@end

#define HRLoc(key) NSLocalizedString(key, nil)

@implementation HRSmokeTest
{
    HRAppDelegate *_app;
}

- (instancetype)initWithAppDelegate:(HRAppDelegate *)appDelegate
{
    if ((self = [super init])) _app = appDelegate;
    return self;
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
                        windowNumber:[_app.window windowNumber]
                             context:nil
                          characters:characters
         charactersIgnoringModifiers:characters
                           isARepeat:NO
                             keyCode:keyCode];
}

/* AppKit on macOS catches an exception thrown from a run-loop callback,
 * logs it and carries on -- which here would mean a CI job sitting until
 * its timeout.  So: catch, report, exit. */
- (void)run
{
    @try {
        [self runChecks];
    } @catch (id exception) {
        fprintf(stderr, "HomeRow smoke test: exception: %s\n", [[exception description] UTF8String]);
        exit(1);
    }
}

- (void)runChecks
{
    NSMutableArray *failures = [NSMutableArray array];
    NSDictionary *outlets = @{@"window": _app.window ?: [NSNull null], @"testView": _app.testView ?: [NSNull null],
        @"resultsView": _app.resultsView ?: [NSNull null], @"chartView": _app.chartView ?: [NSNull null],
        @"keyboardView": _app.keyboardView ?: [NSNull null],
        @"modePopUp": _app.modePopUp ?: [NSNull null], @"amountPopUp": _app.amountPopUp ?: [NSNull null],
        @"punctuationCheck": _app.punctuationCheck ?: [NSNull null], @"numbersCheck": _app.numbersCheck ?: [NSNull null],
        @"liveField": _app.liveField ?: [NSNull null], @"wpmField": _app.wpmField ?: [NSNull null],
        @"accuracyField": _app.accuracyField ?: [NSNull null], @"detailField": _app.detailField ?: [NSNull null],
        @"hintField": _app.hintField ?: [NSNull null]};
    for (NSString *name in outlets) {
        if (outlets[name] == [NSNull null]) [failures addObject:[NSString stringWithFormat:@"outlet %@ is not connected", name]];
    }
    if ([_app.model.packs.languages count] == 0) [failures addObject:@"no language pack was loaded"];
    if (!_app.model.store) [failures addObject:@"the result store did not open"];

    _app.model.configuration.mode = HRTestModeWords;
    _app.model.configuration.amount = 10;
    [_app syncControls];
    /* a pace caret at a speed of one's choosing, for the test below */
    NSUserDefaults *smokeDefaults = [NSUserDefaults standardUserDefaults];
    id paceKindBefore = [smokeDefaults objectForKey:HRPaceKindDefaultsKey], paceWpmBefore = [smokeDefaults objectForKey:HRPaceCustomWpmDefaultsKey];
    id soundBefore = [smokeDefaults objectForKey:HRSoundSchemeDefaultsKey];
    [smokeDefaults setInteger:HRPaceCustom forKey:HRPaceKindDefaultsKey];
    [smokeDefaults setInteger:30 forKey:HRPaceCustomWpmDefaultsKey];
    /* sounds on: where they cannot be made, typing must go on as if they were */
    if ([[HRSoundPlayer schemeNames] count] < 2) [failures addObject:@"the sound schemes were not found"];
    _app.stage.soundScheme = [[HRSoundPlayer schemeNames] firstObject];
    printf("HomeRow smoke test: %lu sounds loaded from \"%s\"\n", (unsigned long)_app.stage.loadedSounds, [_app.stage.soundScheme UTF8String]);
    /* whatever was on when the app came up -- a course, a file -- a words test now */
    [_app.freeTests begin];
    if (_app.activity != _app.freeTests) [failures addObject:@"the free tests did not take the stage"];
    /* Real key events first, through -sendEvent:, because that is the path
     * a keyboard takes: keyDown: -> interpretKeyEvents: -> insertText: /
     * doCommandBySelector:.  One character, Backspace, then Tab. */
    if ([_app.stage.session.words count] == 0) {
        fprintf(stderr, "HomeRow smoke test: the test has no words\n");
        exit(1);
    }
    NSString *firstCharacter = [((HRWord *)_app.stage.session.words[0]).characters firstObject];
    [_app.window sendEvent:[self keyEventWithCharacters:firstCharacter keyCode:0]];
    if (_app.stage.session.state != HRSessionRunning || [_app.stage.session caretIndexInCurrentWord] != 1) {
        [failures addObject:@"a key event did not reach the session as a typed character"];
    }
    [_app.window sendEvent:[self keyEventWithCharacters:[NSString stringWithFormat:@"%C", (unichar)NSDeleteCharacter] keyCode:51]];
    if ([_app.stage.session caretIndexInCurrentWord] != 0) {
        [failures addObject:@"Backspace did not delete the typed character"];
    }
    /* A dead key: the accent waits as marked text, is drawn, and the letter
     * that completes it arrives through -insertText:replacementRange: (the
     * path macOS takes; here it is walked by hand on both platforms). */
    [_app.testView setMarkedTextForTesting:@"\u00B4"];
    [[_app.window contentView] display];
    if (![_app.testView.markedText isEqualToString:@"\u00B4"]) [failures addObject:@"the typing view does not hold marked text"];
    if ([_app.stage.session caretIndexInCurrentWord] != 0) [failures addObject:@"a pending accent counted as a typed character"];
    [(id)_app.testView insertText:firstCharacter replacementRange:NSMakeRange(NSNotFound, 0)];
    if (_app.testView.markedText != nil || [_app.stage.session caretIndexInCurrentWord] != 1) {
        [failures addObject:@"completing a dead key did not type the character"];
    }
    [_app.testView setMarkedTextForTesting:@"\u00A8"];
    [_app.window sendEvent:[self keyEventWithCharacters:[NSString stringWithFormat:@"%C", (unichar)NSDeleteCharacter] keyCode:51]];
    /* whoever took that Backspace, the view must not be left waiting */
    [_app.testView setMarkedTextForTesting:nil];
    HRTestSession *beforeTab = _app.stage.session;
    [_app.window sendEvent:[self keyEventWithCharacters:@"\t" keyCode:48]];
    if (_app.stage.session == beforeTab) [failures addObject:@"Tab did not start a new test"];

    NSMutableArray *texts = [NSMutableArray array];
    for (HRWord *w in _app.stage.session.words) [texts addObject:w.text];
    /* five seconds "ago" for the first word, so that the test has a
     * duration and is worth saving */
    NSTimeInterval now = HRMonotonicNow();
    NSUInteger before = [[_app.model.store recentResultsWithLimit:0 error:NULL] count];
    [_app.testView typeText:[texts[0] stringByAppendingString:@" "] atTime:now - 5.0];
    if (_app.stage.paceWpm != 30.0) [failures addObject:@"the pace caret did not take the chosen speed"];
    [_app.stage movePaceCaret];
    [[_app.window contentView] display];
    /* 30 wpm for five seconds: twelve characters and a half into the text */
    NSUInteger paceWord = 0, paceCharacter = 0;
    [HRPace getWordIndex:&paceWord characterIndex:&paceCharacter forCharacters:12.5 inWords:_app.stage.session.words];
    NSString *paceExpected = [NSString stringWithFormat:@"%lu:%lu", (unsigned long)paceWord, (unsigned long)paceCharacter];
    if (![_app.testView.paceCaretDescription isEqualToString:paceExpected]) {
        [failures addObject:[NSString stringWithFormat:@"the pace caret is at %@, not at %@", _app.testView.paceCaretDescription, paceExpected]];
    }
    [texts removeObjectAtIndex:0];
    [_app.testView typeText:[texts componentsJoinedByString:@" "] atTime:now];
    if (_app.model.store && [[_app.model.store recentResultsWithLimit:0 error:NULL] count] != before + 1) {
        [failures addObject:@"the result was not saved"];
    }
    if (_app.stage.session.state != HRSessionFinished) [failures addObject:@"typing the whole text did not finish the test"];
    if ([_app.resultsView isHidden]) [failures addObject:@"the results were not shown"];
    if ([[_app.wpmField stringValue] length] == 0) [failures addObject:@"the results are empty"];
    if (_app.testView.paceCharacters >= 0.0) [failures addObject:@"the pace caret outlived the test"];

    /* Replay: the same test again, typed by nobody, and nothing saved */
    {
        NSUInteger saved = [[_app.model.store recentResultsWithLimit:0 error:NULL] count];
        double wpm = [_app.stage.session summary].wpm;
        if ([[_app.hintField stringValue] rangeOfString:@"replay"].location == NSNotFound) [failures addObject:@"the result does not offer its replay"];
        [_app.window sendEvent:[self keyEventWithCharacters:@"r" keyCode:15]];
        if (!_app.stage.replay || !_app.testView.replaying || [_app.testView isHidden] || ![_app.resultsView isHidden]) {
            [failures addObject:@"r on a result did not start its replay"];
        } else {
            [_app.stage advanceReplayToElapsed:2.5];
            /* the first word went in at once, the rest five seconds later */
            if (_app.stage.replaySession.state != HRSessionRunning || _app.stage.replaySession.currentWordIndex != 1) {
                [failures addObject:@"between the first word and the rest, the replay is somewhere else"];
            }
            [[_app.window contentView] display];
            NSUInteger caretBefore = [_app.stage.replaySession caretIndexInCurrentWord];
            [_app.window sendEvent:[self keyEventWithCharacters:@"x" keyCode:7]];
            if ([_app.stage.replaySession caretIndexInCurrentWord] != caretBefore) [failures addObject:@"a key got into a replay"];
            [_app.stage advanceReplayToElapsed:_app.stage.replay.duration + 1.0];
            if (_app.stage.replay || _app.testView.replaying || [_app.resultsView isHidden]) [failures addObject:@"the replay did not end on the result it came from"];
            /* once more, left with Esc */
            [_app replayLastTest:self];
            [_app.window sendEvent:[self keyEventWithCharacters:@"\033" keyCode:53]];
            if (_app.stage.replay || [_app.resultsView isHidden]) [failures addObject:@"Esc did not leave the replay for the result"];
        }
        if (fabs([_app.stage.session summary].wpm - wpm) > 1e-9) [failures addObject:@"the replay changed the result"];
        if ([[_app.model.store recentResultsWithLimit:0 error:NULL] count] != saved) [failures addObject:@"a replay was saved as a result"];
    }
    for (NSArray *pair in @[@[HRPaceKindDefaultsKey, paceKindBefore ?: [NSNull null]], @[HRPaceCustomWpmDefaultsKey, paceWpmBefore ?: [NSNull null]]]) {
        if (pair[1] == [NSNull null]) [smokeDefaults removeObjectForKey:pair[0]];
        else [smokeDefaults setObject:pair[1] forKey:pair[0]];
    }

    /* Follow a course the way the Courses window makes one do it: choose
     * it, continue, read the pages, type the drills -- and find the place
     * kept and the lesson recorded afterwards. */
    [_app.model.store resetCourse:@"q.typ" error:NULL];
    [_app.model.store resetCourse:@"p.typ" error:NULL];
    [(id<HRCourseWindowDelegate>)_app.course courseWindow:nil didSelectCourse:@"q.typ"];
    [_app continueCourse:self];
    if (!_app.course.run) {
        [failures addObject:@"the first lesson of q.typ did not start"];
    } else {
        if (!_app.keyboardDock.isShown || [_app.keyboardView isHidden]) [failures addObject:@"the keyboard is not shown in a course"];
        /* a German course is followed for a moment: its results are German, the tests stay as they were */
        {
            NSString *languageBefore = [_app.model.configuration.languageID copy];
            NSString *german = nil;
            for (NSDictionary *course in _app.model.packs.courses) if ([course[@"language"] isEqual:@"german"]) { german = course[@"file"]; break; }
            if (german) {
                /* leave no trace of it: unless the course was already being followed, forget it again */
                BOOL followed = [_app.model.store progressForCourse:german] != nil;
                [_app.course startLesson:0 ofCourse:german atStep:0];
                for (NSUInteger guard = 0; _app.course.run && _app.testView.pageText && guard < 50; guard++) [_app.stage testViewDidDismissPage:_app.testView];
                if (_app.stage.session && ![_app.stage.session.configuration.languageID isEqualToString:@"german"]) {
                    [failures addObject:@"a German lesson does not record its language"];
                }
                if (![_app.model.configuration.languageID isEqual:languageBefore]) [failures addObject:@"following a German course changed the language of the tests"];
                if (!followed) [_app.model.store resetCourse:german error:NULL];
                [_app.course startLesson:0 ofCourse:@"q.typ" atStep:0];
            }
        }
        NSRect contentBounds = [[_app.window contentView] bounds];
        if (NSMaxY([_app.modePopUp frame]) < NSMaxY(contentBounds) - 30.0
            || NSMaxY([_app.testView frame]) > NSMinY([_app.modePopUp frame])
            || NSMinY([_app.testView frame]) < NSMaxY([_app.keyboardView frame]) - 0.5) {
            [failures addObject:@"with the keyboard up, the control bar, typing view and keyboard overlap"];
        }
        if (![_app.amountPopUp isHidden] || ![_app.modePopUp isHidden]) [failures addObject:@"the test controls are still showing in a course"];
        if (![[[[NSApp mainMenu] itemWithTitle:@"Test"] submenu] itemWithTitle:HRLoc(@"Time Test")]) {
            [failures addObject:@"there is no way out of the course: Test > Time Test is missing"];
        }
        NSUInteger pages = 0, exercises = 0;
        NSString *lit = nil;
        NSTimeInterval t = HRMonotonicNow();
        for (NSUInteger guard = 0; _app.course.run && guard < 1000; guard++) {
            HRTypStep *step = [_app.course.run currentStep];
            if (_app.testView.pageText) { pages++; [_app.stage testViewDidDismissPage:_app.testView]; }
            else {
                if (!lit) lit = [_app.keyboardView litKeyDescription];
                exercises++; t += 10.0; [_app.testView typeText:step.text atTime:t];
            }
        }
        if (_app.course.run) [failures addObject:@"the lesson did not come to an end"];
        if (pages == 0 || exercises == 0) [failures addObject:@"the lesson had no pages or no exercises"];
        if (![lit hasPrefix:@"key:"]) [failures addObject:@"the keyboard did not light the first key of the first drill"];
        if ([_app.resultsView isHidden]) [failures addObject:@"the lesson did not end on the results"];
        if (_app.model.store) {
            HRCourseProgress *progress = [_app.model.store progressForCourse:@"q.typ"];
            if ([progress.lessonIndex integerValue] != 1 || [progress.stepIndex integerValue] != 0) {
                [failures addObject:@"the course did not move on to its second lesson"];
            }
            HRLessonRecord *record = [_app.model.store lessonRecordsForCourse:@"q.typ"][@0];
            if ([record.completions integerValue] != 1) [failures addObject:@"the finished lesson was not recorded"];
        }
        /* Return on the results: the next lesson, not a free test */
        [_app restartTest:self];
        if (!_app.course.run || _app.course.lessonIndex != 1) [failures addObject:@"Return after a lesson did not start the next one"];
        /* taking the first lesson again is practice: recorded, but the
         * place in the course stays at lesson two */
        [(id<HRCourseWindowDelegate>)_app.course courseWindow:nil didRequestLesson:0];
        for (NSUInteger guard = 0; _app.course.run && guard < 1000; guard++) {
            if (_app.testView.pageText) [_app.stage testViewDidDismissPage:_app.testView];
            else { t += 10.0; [_app.testView typeText:[_app.course.run currentStep].text atTime:t]; }
        }
        if (_app.model.store) {
            if ([[_app.model.store progressForCourse:@"q.typ"].lessonIndex integerValue] != 1) {
                [failures addObject:@"taking a lesson again moved the place in the course"];
            }
            HRLessonRecord *again = [_app.model.store lessonRecordsForCourse:@"q.typ"][@0];
            if ([again.completions integerValue] != 2) [failures addObject:@"the lesson taken again was not recorded"];
        }
        /* a second course alongside: start it, switch back, and find the
         * first one where it was */
        [(id<HRCourseWindowDelegate>)_app.course courseWindow:nil didSelectCourse:@"p.typ"];
        [_app continueCourse:self];
        if (![_app.course.courseFile isEqual:@"p.typ"] || _app.course.lessonIndex != 0) [failures addObject:@"a second course did not start"];
        [_app.menus rebuildStartedCourseItems];
        NSMenuItem *back = nil;
        for (NSMenuItem *item in _app.menus.startedCourseItems) if ([[item representedObject] isEqual:@"q.typ"]) back = item;
        if (!back) {
            [failures addObject:@"the Course menu does not list the courses in progress"];
        } else {
            [_app switchToCourse:back];
            if (![_app.course.courseFile isEqual:@"q.typ"] || _app.course.lessonIndex != 1) [failures addObject:@"switching back did not return to the first course's place"];
            if (_app.model.store && [[_app.model.store progressForCourse:@"p.typ"].lessonIndex integerValue] != 0) [failures addObject:@"the other course lost its place"];
        }
        [[_app.course windowController] showWindow:self];
        if ([[_app.course windowController].lessonTable numberOfRows] < 2) [failures addObject:@"the Courses window lists no lessons"];
        [[[_app.course windowController] window] orderOut:self];
        printf("HomeRow smoke test: lesson with %lu pages and %lu exercises, first key %s\n",
               (unsigned long)pages, (unsigned long)exercises, [lit UTF8String] ?: "-");
    }
    /* Code: every bundled file must load and cut into sections (a grammar
     * that fails to compile shows up here), and one section must type
     * through, be recorded, and hand over to the next. */
    {
        HRCodeLibrary *library = _app.code.library;
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
            [_app.model.store resetCourse:first.identifier error:NULL];
            [_app.code startSection:0 ofFile:first];
            if (!_app.code.file || !_app.testView.codeLayout || _app.model.configuration.mode != HRTestModeCode) {
                [failures addObject:@"a section of code did not start"];
            }
            if (![_app.modePopUp isHidden]) [failures addObject:@"the test controls are still showing in code mode"];
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:HRKeyboardInCodeDefaultsKey];
            [_app syncKeyboard];
            if (!_app.keyboardDock.isShown || [_app.keyboardView isHidden]) [failures addObject:@"the keyboard is not shown in code mode"];
            if (![[_app.keyboardView litKeyDescription] hasPrefix:@"key:"]) [failures addObject:@"the keyboard did not light the first key of the code"];
            if (NSMinY([_app.testView frame]) < NSMaxY([_app.keyboardView frame]) - 0.5) [failures addObject:@"the keyboard covers the code"];
            NSMutableString *text = [NSMutableString string];
            BOOL styled = NO;
            NSUInteger count = [_app.stage.session.words count];
            for (NSUInteger i = 0; i < count; i++) {
                HRWord *w = _app.stage.session.words[i];
                [text appendString:w.text];
                if (i + 1 < count) [text appendString:(w.separator == HRSeparatorNewline ? @"\n" : @" ")];
                for (NSUInteger c = 0; c < [w.characters count]; c++) {
                    if ([w styleOfCharacterAtIndex:c] != HRTextStylePlain) styled = YES;
                }
            }
            if (!styled) [failures addObject:@"the code has no syntax colouring"];
            [[_app.window contentView] display];
            /* a wrong key must not go in */
            [_app.testView typeText:@"§" atTime:HRMonotonicNow() - 20.0];
            if ([_app.stage.session caretIndexInCurrentWord] != 0) [failures addObject:@"code mode let a wrong key in"];
            if (_app.stage.session.wrongInputCount != 1 || !_app.stage.session.lastWrongInputWasRefused) {
                [failures addObject:@"the refused key was not reported for feedback"];
            }
            [[_app.window contentView] display];   /* with the flash on */
            [_app.testView typeText:text atTime:HRMonotonicNow()];
            if (_app.stage.session.state != HRSessionFinished || [_app.resultsView isHidden]) {
                [failures addObject:@"typing a section of code did not finish it"];
            }
            if (_app.model.store) {
                HRLessonRecord *record = [_app.model.store lessonRecordsForCourse:first.identifier][@0];
                if ([record.completions integerValue] != 1) [failures addObject:@"the section of code was not recorded"];
                if ([[_app.model.store progressForCourse:first.identifier].lessonIndex integerValue] != 1) {
                    [failures addObject:@"the file did not move on to its second part"];
                }
            }
            [_app restartTest:self];
            if (!_app.code.file || _app.code.section != 1) [failures addObject:@"Return after a section did not start the next one"];
            [[_app.window contentView] display];
            [[_app.code windowController] showWindow:self];
            if ([[_app.code windowController].sectionTable numberOfRows] < 2) [failures addObject:@"the Code window lists no sections"];
            if (![_app.code windowController].folderButton || ![_app.code windowController].removeButton) {
                [failures addObject:@"CodeWindow.xib: the folder or the remove button is not connected"];
            }
            [_app.model.store resetCourse:first.identifier error:NULL];

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
            if (![[_app.code windowController] addPaths:@[folder]]) [failures addObject:@"a folder of code was not taken in"];
            HRCodeFile *mine = nil;
            NSUInteger fromFolder = 0;
            for (HRCodeFile *file in [library filesForLanguage:[library languageWithIdentifier:@"c"]]) {
                if ([[library folderOfFile:file] isEqualToString:folder]) { fromFolder++; mine = file; }
            }
            if (fromFolder != 1) [failures addObject:[NSString stringWithFormat:@"the folder brought %lu files, not the one outside node_modules", (unsigned long)fromFolder]];
            if (mine) {
                [defaults setBool:YES forKey:HRCodeTypeTabsDefaultsKey];
                [_app.code startSection:0 ofFile:mine];
                NSMutableString *typed = [NSMutableString string];
                NSUInteger tabs = 0, n = [_app.stage.session.words count];
                for (NSUInteger i = 0; i < n; i++) {
                    HRWord *w = _app.stage.session.words[i];
                    if ([w.text hasPrefix:@"\t"]) tabs++;
                    [typed appendString:w.text];
                    if (i + 1 < n) [typed appendString:(w.separator == HRSeparatorNewline ? @"\n" : @" ")];
                }
                if (tabs != 2) [failures addObject:[NSString stringWithFormat:@"%lu Tabs to type where the code goes deeper twice", (unsigned long)tabs]];
                if (![[_app.keyboardView litKeyDescription] hasPrefix:@"key:"]) [failures addObject:@"no key is lit at the start of one's own file"];
                [[_app.window contentView] display];   /* the arrows of the Tabs */
                [_app.testView typeText:typed atTime:HRMonotonicNow()];
                if (_app.stage.session.state != HRSessionFinished) [failures addObject:@"a section with Tabs in it did not type through"];
                if ([[_app.detailField stringValue] rangeOfString:@"overhead"].location == NSNotFound) {
                    [failures addObject:@"the result of a section of code does not give the keystroke overhead"];
                }
                [defaults setBool:NO forKey:HRCodeTypeTabsDefaultsKey];
                [_app.code startSection:0 ofFile:mine];
                for (HRWord *w in _app.stage.session.words) {
                    if ([w.text rangeOfString:@"\t"].location != NSNotFound) { [failures addObject:@"Tab is asked for with the preference off"]; break; }
                }
                [[_app.code windowController] revealFile:mine section:0];
                [[_app.code windowController] removeSelected:self];
                if ([library fileWithIdentifier:mine.identifier]) [failures addObject:@"removing a folder left its files"];
                [_app.model.store resetCourse:mine.identifier error:NULL];
            }
            [[NSFileManager defaultManager] removeItemAtPath:folder error:NULL];
            for (NSArray *pair in @[@[HRCodeTypeTabsDefaultsKey, tabsBefore ?: [NSNull null]],
                                    @[HRCodeUserFoldersDefaultsKey, foldersBefore ?: [NSNull null]],
                                    @[HRCodeUserFilesDefaultsKey, filesBefore ?: [NSNull null]]]) {
                if (pair[1] == [NSNull null]) [defaults removeObjectForKey:pair[0]];
                else [defaults setObject:pair[1] forKey:pair[0]];
            }
            [[[_app.code windowController] window] orderOut:self];
        } else {
            [failures addObject:@"there is no C file to type"];
        }
        printf("HomeRow smoke test: %lu code files in %lu languages\n",
               (unsigned long)files, (unsigned long)[library.languages count]);
    }
    /* a keyword list is a language like any other, under its own submenu,
     * typed as it stands */
    {
        NSMenuItem *python = (NSMenuItem *)[_app.menus.programmingMenu itemWithTitle:@"Python"];
        if (!python || [_app.menus.languageMenu itemWithTitle:@"Python"]) [failures addObject:@"Python's keywords are not under Language > Programming"];
        if (python) {
            BOOL punctuationBefore = _app.model.configuration.punctuation;
            _app.model.configuration.punctuation = YES;
            [_app selectLanguage:python];
            if (![_app.model currentLanguage].isCode || [_app.stage.session.words count] == 0) [failures addObject:@"choosing Python did not start a test of its keywords"];
            if ([_app.punctuationCheck isEnabled]) [failures addObject:@"punctuation is on offer for a keyword list"];
            if ([_app.menus.programmingItem state] != NSControlStateValueMixed) [failures addObject:@"the Programming submenu does not show that the language is inside it"];
            _app.model.configuration.punctuation = punctuationBefore;
        }
    }
    [_app selectLanguage:[_app.menus.languageMenu itemWithTitle:@"Russian"]];
    if (_app.keyboardDock.isShown) [failures addObject:@"the keyboard stayed up outside the course"];
    if (_app.code.file || _app.testView.codeLayout) [failures addObject:@"the code layout stayed on outside code mode"];
    if ([_app.amountPopUp isHidden] || [_app.modePopUp isHidden] || NSMaxY([_app.modePopUp frame]) < NSMaxY([[_app.window contentView] bounds]) - 30.0
        || fabs(NSMinY([_app.testView frame])) > 0.5 || NSMaxY([_app.testView frame]) > NSMinY([_app.modePopUp frame])) {
        [failures addObject:@"after the course, the window did not go back to its test layout"];
    }
    if (![[_app.model currentLanguage].identifier isEqualToString:@"russian"] || _app.stage.session == nil
        || [_app.stage.session.words count] == 0) {
        [failures addObject:@"switching to Russian did not start a Russian test"];
    }
    if ([_app.menus.wordListMenu numberOfItems] < 2) [failures addObject:@"the word-list menu was not rebuilt"];

    /* Statistics: by now there are results of all three kinds in the store */
    {
        HRStatsWindowController *stats = [_app statsWindow];
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
        if (_app.model.store) {
            /* on a machine that never ran HomeRow that is two: the words
             * test and the section of code (the lesson's drills are typed
             * in no time at all, and a result without a duration is not
             * kept).  Whatever else the store holds is shown too. */
            NSUInteger saved = [[_app.model.store recentResultsWithLimit:0 error:NULL] count];
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
            board.keyboardLayout = [_app.model.packs layoutNamed:@"qwerty"];
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
        for (NSView *v in @[stats.keysField ?: (id)_app.window.contentView, stats.keyboardView ?: (id)_app.window.contentView,
                            stats.heatPopUp ?: (id)_app.window.contentView, stats.daysPlot ?: (id)_app.window.contentView,
                            stats.accuracyPlot ?: (id)_app.window.contentView, stats.speedPlot ?: (id)_app.window.contentView, stats.tilesView ?: (id)_app.window.contentView]) {
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

        if (_app.model.store) {
            /* History: every result listed, the chart follows the selection,
             * out to a file and back without doubling, and one can be deleted */
            stats.pane = HRStatsPaneHistory;
            NSUInteger saved = [[_app.model.store recentResultsWithLimit:0 error:NULL] count];
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
                if ([[_app.model.store recentResultsWithLimit:0 error:NULL] count] != saved) {
                    [failures addObject:[NSString stringWithFormat:@"importing our own %@ doubled the history", name]];
                }
            }
            [[NSFileManager defaultManager] removeItemAtPath:directory error:NULL];
            if ([stats respondsToSelector:@selector(deleteSelectedResultWithoutAsking)]) {
                [stats performSelector:@selector(deleteSelectedResultWithoutAsking)];
                if ([[_app.model.store recentResultsWithLimit:0 error:NULL] count] != saved - 1 || [stats.historyTable numberOfRows] != (NSInteger)saved - 1) {
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
        [_app practiseWeakKeys:self];
        if (_app.model.configuration.mode != HRTestModePractice) [failures addObject:@"Practise Weak Keys did not switch to practice"];
        if (![_app.freeTests currentWeakSpots] && _app.testView.pageText == nil) {
            [failures addObject:@"with nothing to go by, practice did not say so"];
        }
        _app.freeTests.weakSpotsForTesting = [HRWeakSpots weakSpotsFromCounts:@{@"e": @{@"hits": @2000, @"misses": @10},
                                                                   @"q": @{@"hits": @30, @"misses": @10},
                                                                   @"#": @{@"hits": @20, @"misses": @10}}
                                              minimumKeyPresses:10 minimumTotalPresses:300 maximum:6];
        [_app restartTest:nil];
        NSUInteger withWeak = 0;
        for (HRWord *w in _app.stage.session.words) {
            if ([w.text rangeOfString:@"q"].location != NSNotFound || [w.text rangeOfString:@"#"].location != NSNotFound) withWeak++;
        }
        if (_app.testView.pageText != nil || [_app.stage.session.words count] == 0) [failures addObject:@"a practice round did not start"];
        /* the draw is random and q is rare in any word list: a handful, not a share
         * (the unit tests pin the shares down with a seed) */
        else if (withWeak < 2) [failures addObject:@"the practice round hardly contains the weak keys"];
        if ([_app.testView.caption rangeOfString:@"#"].location == NSNotFound) [failures addObject:@"the practice round does not say which keys it is for"];
        if ([_app.modePopUp isHidden]) [failures addObject:@"the mode pop-up is hidden in practice"];
        [[_app.window contentView] display];
        NSMutableArray *practiceTexts = [NSMutableArray array];
        for (HRWord *w in _app.stage.session.words) [practiceTexts addObject:w.text];
        NSUInteger savedBefore = [[_app.model.store recentResultsWithLimit:0 error:NULL] count];
        if ([practiceTexts count] > 0) {
            [_app.testView typeText:[practiceTexts[0] stringByAppendingString:@" "] atTime:HRMonotonicNow() - 8.0];
            [practiceTexts removeObjectAtIndex:0];
            /* the source hands words out as they are needed: type what there is until it is done */
            for (NSUInteger guard = 0; _app.stage.session.state != HRSessionFinished && guard < 200; guard++) {
                HRWord *w = _app.stage.session.currentWordIndex < [_app.stage.session.words count] ? _app.stage.session.words[_app.stage.session.currentWordIndex] : nil;
                if (!w) break;
                BOOL last = (_app.stage.session.currentWordIndex + 1 == [_app.stage.session.words count]);
                [_app.testView typeText:(last ? w.text : [w.text stringByAppendingString:@" "]) atTime:HRMonotonicNow()];
                if (last && _app.stage.session.state != HRSessionFinished) [_app.testView typeText:@" " atTime:HRMonotonicNow()];
            }
        }
        if (_app.stage.session.state != HRSessionFinished) [failures addObject:@"the practice round did not come to an end"];
        if (_app.model.store && [[_app.model.store recentResultsWithLimit:0 error:NULL] count] != savedBefore + 1) [failures addObject:@"the practice round was not saved"];
        if (_app.model.store && ![[(HRTestResult *)[[_app.model.store recentResultsWithLimit:1 error:NULL] firstObject] mode] isEqualToString:@"practice"]) {
            [failures addObject:@"the practice round was not saved as practice"];
        }
        _app.freeTests.weakSpotsForTesting = nil;
        [_app.modePopUp selectItemWithTag:HRTestModeTime];
        [_app modeChanged:self];
    }

    /* Preferences: every control connected, and a change made there takes
     * effect here -- then everything is put back as it was found. */
    {
        NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
        NSArray *keys = @[HRThemeDefaultsKey, HRProseFontSizeDefaultsKey, HRCodeFontSizeDefaultsKey, HRFontFamilyDefaultsKey,
                          HRBeepOnErrorDefaultsKey, HRKeyboardInTestsDefaultsKey];
        NSMutableDictionary *before = [NSMutableDictionary dictionary];
        for (NSString *key in keys) if ([d objectForKey:key]) before[key] = [d objectForKey:key];
        HRStopPolicy stopBefore = _app.model.configuration.stopPolicy;
        HRBackspacePolicy backspaceBefore = _app.model.configuration.backspacePolicy;

        HRPreferencesWindowController *prefs = [_app preferencesWindow];
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
        if (![[prefs.layoutField stringValue] isEqualToString:[HRLayoutChooserController titleForIdentifier:_app.model.configuration.layoutID]]) {
            [failures addObject:@"Preferences does not show the current layout"];
        }
        /* the layout chooser: searched, previewed, chosen -- and put back */
        {
            NSString *layoutBefore = [_app.model.configuration.layoutID copy];
            HRLayoutChooserController *chooser = [_app layoutChooser];
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
            if (![_app.model.configuration.layoutID isEqualToString:@"dvorak"] || ![[prefs.layoutField stringValue] isEqualToString:@"dvorak"]) {
                [failures addObject:@"choosing a layout did not take effect"];
            }
            if ([[_app.menus.layoutMenuItem title] rangeOfString:@"dvorak"].location == NSNotFound) [failures addObject:@"the Language menu does not name the layout"];
            [(id<HRLayoutChooserDelegate>)_app layoutChooser:chooser didChoose:layoutBefore];
        }

        HRTestSession *sessionBefore = _app.stage.session;
        [prefs.stopPopUp selectItemAtIndex:2];       /* on every word */
        [prefs.backspacePopUp selectItemAtIndex:1];  /* current word only */
        [prefs.themePopUp selectItemAtIndex:([[HRTheme currentTheme].name isEqualToString:@"dark"] ? 1 : 2)];
        [prefs.proseSizePopUp selectItemAtIndex:0];  /* 16 */
        [prefs.keyboardTestsCheck setState:NSControlStateValueOn];
        NSString *themeBefore = [[HRTheme currentTheme].name copy];
        [prefs changed:self];
        if (_app.model.configuration.stopPolicy != HRStopOnWord || _app.model.configuration.backspacePolicy != HRBackspaceCurrentWord) {
            [failures addObject:@"Preferences did not change the typing rules"];
        }
        if (_app.stage.session == sessionBefore || _app.stage.session.configuration.stopPolicy != HRStopOnWord) {
            [failures addObject:@"the test under way did not start over under the new rules"];
        }
        if ([[HRTheme currentTheme].name isEqualToString:themeBefore] || ![_app.testView.theme.name isEqualToString:[HRTheme currentTheme].name]) [failures addObject:@"Preferences did not switch the theme"];
        if (fabs([_app.testView.font pointSize] - 16.0) > 0.01) [failures addObject:@"Preferences did not change the text size"];
        if (!_app.keyboardDock.isShown) [failures addObject:@"Preferences did not bring up the keyboard"];
        NSDictionary *saved = [d dictionaryForKey:@"HRConfiguration"];
        if ([saved[@"stopPolicy"] integerValue] != HRStopOnWord) [failures addObject:@"Preferences did not save the configuration"];
        [[_app.window contentView] display];
        [[[prefs window] contentView] display];

        for (NSString *key in keys) {
            if (before[key]) [d setObject:before[key] forKey:key]; else [d removeObjectForKey:key];
        }
        _app.model.configuration.stopPolicy = stopBefore;
        _app.model.configuration.backspacePolicy = backspaceBefore;
        [_app.model saveConfiguration];
        [_app applyAppearance];
        [_app syncKeyboard];
        [prefs sync];
        [[prefs window] orderOut:self];
        [_app restartTest:nil];
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
    [_app toggleKeyboard:self];
    [[_app.window contentView] display];
    [_app toggleKeyboard:self];
    [[_app.window contentView] display];

#if defined(GNUSTEP)
    /* Inside the AppImage the link in the Info panel goes through
     * NSWorkspace to "xdg-open", looked up in GNUstep's own tool directories
     * first: the image has to carry one (Scripts/appimage/open) that hands
     * the job to the host, or the link does nothing. */
    if ([[[NSProcessInfo processInfo] environment] objectForKey:@"HR_HOST_PATH"]) {   /* set by the image's AppRun */
        NSString *opener = [NSTask launchPathForTool:@"xdg-open"];
        if ([opener rangeOfString:@"/usr/System/Tools/"].location == NSNotFound) {
            [failures addObject:[NSString stringWithFormat:@"the AppImage's own xdg-open is not the one NSWorkspace would find (%@)", opener]];
        }
    }
#endif

    /* The welcome: every launch starts with it.  By now there are results
     * on record, so there is something to carry on with; each of the three
     * answers must put something on the stage, whatever was on before. */
    {
        HRWelcomeWindowController *welcome = [_app welcomeWindow];
        id courseBefore = [smokeDefaults objectForKey:HRCurrentCourseDefaultsKey];
        HRTestMode modeBefore = _app.model.configuration.mode;
        [smokeDefaults removeObjectForKey:HRCurrentCourseDefaultsKey];
        if ([_app isNewHere]) [failures addObject:@"someone with results on record was taken for new"];

        /* carry on: a words test, as the configuration says */
        _app.model.configuration.mode = HRTestModeWords;
        [_app showWelcome];
        if (!welcome.resumeButton || !welcome.resumeField || !welcome.teachButton || !welcome.testButton) {
            [failures addObject:@"WelcomeWindow.xib: an outlet is not connected"];
        }
        if (![welcome.resumeButton isEnabled] || [[welcome.resumeField stringValue] rangeOfString:@"word"].location == NSNotFound) {
            [failures addObject:[NSString stringWithFormat:@"the welcome does not say what there is to carry on with (\"%@\")", [welcome.resumeField stringValue]]];
        }
        [[[welcome window] contentView] display];
        HRTestSession *before = _app.stage.session;
        [welcome resume:self];
        if ([[welcome window] isVisible]) [failures addObject:@"the welcome stayed up after its answer"];
        if (_app.activity != _app.freeTests || _app.stage.session == before || _app.stage.session.configuration.mode != HRTestModeWords) {
            [failures addObject:@"\"Carry on\" did not start the kind of test that was on"];
        }

        /* teach me: with no course under way, the one for the layout in use */
        NSString *beginners = [_app.course beginnersCourseFile];
        if (!beginners) {
            [failures addObject:@"there is no course to start a beginner on"];
        } else {
            BOOL started = [_app.model.store progressForCourse:beginners] != nil;
            [_app showWelcome];
            [welcome teachMe:self];
            if (_app.activity != _app.course || !_app.course.run || ![_app.course.courseFile isEqual:beginners]) {
                [failures addObject:@"\"Teach me\" did not start the beginners' course"];
            }
            /* test me, from inside a lesson: a test all the same */
            [_app showWelcome];
            if ([[welcome.resumeField stringValue] rangeOfString:@"lesson"].location == NSNotFound) {
                [failures addObject:@"in a course, the welcome does not offer to carry on with its lesson"];
            }
            [welcome testMe:self];
            if (_app.activity != _app.freeTests || _app.course.run || _app.stage.session.state != HRSessionIdle
                || (_app.model.configuration.mode != HRTestModeTime && _app.model.configuration.mode != HRTestModeWords)) {
                [failures addObject:@"\"Test me\" did not put a test on in place of the lesson"];
            }
            if (!started) [_app.model.store resetCourse:beginners error:NULL];
        }
        /* closing the window instead of answering is an answer */
        [_app showWelcome];
        before = _app.stage.session;
        [[welcome window] performClose:self];
        if (_app.stage.session == before) [failures addObject:@"closing the welcome did not carry on"];

        if (courseBefore) [smokeDefaults setObject:courseBefore forKey:HRCurrentCourseDefaultsKey];
        else [smokeDefaults removeObjectForKey:HRCurrentCourseDefaultsKey];
        _app.model.configuration.mode = modeBefore;
        [_app.model saveConfiguration];
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

@end
