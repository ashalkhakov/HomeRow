/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * HomeRow is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version.  It comes with ABSOLUTELY NO WARRANTY.  See COPYING.
 */
#import "HRCourseActivity.h"
#import "HRAppModel.h"
#import "HRStage.h"
#import "HRPacks.h"
#import "HRLanguage.h"
#import "HRResultStore.h"
#import "HRManagedObjects.h"
#import "HRTestSession.h"
#import "HRTextSource.h"
#import "HRTypScript.h"
#import "HRCourseRun.h"
#import "HRCourseWindowController.h"
#import "HRPreferencesWindowController.h"   /* the keyboard's defaults keys */

#define HRLoc(key) NSLocalizedString(key, nil)

NSString * const HRCurrentCourseDefaultsKey = @"HRCurrentCourse";

@interface HRCourseActivity () <HRCourseWindowDelegate>
@end

@implementation HRCourseActivity
{
    HRCourseWindowController *_windowController;
    NSString *_unsavedCourseFile;    /* the place in the course when there is no store */
    NSUInteger _unsavedNextLesson;
}

#pragma mark - Which course

- (NSString *)currentCourseFile
{
    NSString *file = [[NSUserDefaults standardUserDefaults] stringForKey:HRCurrentCourseDefaultsKey];
    return [self.model.packs courseEntryForFile:file] ? file : nil;
}

- (NSString *)beginnersCourseFile
{
    HRTestConfiguration *configuration = self.model.configuration;
    NSString *layout = configuration.layoutID ?: @"qwerty";
    NSString *fallback = nil;
    for (NSDictionary *course in self.model.packs.courses) {
        if (![course[@"layout"] isEqual:layout]) continue;
        if ([course[@"language"] isEqual:configuration.languageID]) return course[@"file"];
        if (!fallback) fallback = course[@"file"];
    }
    return fallback;
}

- (BOOL)isInLesson
{
    return _run != nil;
}

- (void)switchToCourse:(NSString *)file
{
    if (![self.model.packs courseEntryForFile:file]) return;
    /* the lesson that was running keeps its place: it is saved at every step */
    [self leave];
    [[NSUserDefaults standardUserDefaults] setObject:file forKey:HRCurrentCourseDefaultsKey];
    _windowController.selectedCourseFile = file;
    [self begin];
}

#pragma mark - The window

- (HRCourseWindowController *)windowController
{
    if (!_windowController) {
        NSMutableDictionary *names = [NSMutableDictionary dictionary];
        for (HRLanguage *l in self.model.packs.languages) names[l.identifier] = l.displayName;
        _windowController = [[HRCourseWindowController alloc] initWithCourses:self.model.packs.courses languageNames:names
                                                              store:self.model.store delegate:self];
        _windowController.selectedCourseFile = [self currentCourseFile];
    }
    return _windowController;
}

- (void)showWindow
{
    [[self windowController] showWindow:self];
    [[self windowController] reloadProgress];
}

- (void)reloadWindowIfLoaded
{
    [_windowController reloadProgress];
}

#pragma mark - HRActivity

/* Where the current course was left; the Courses window when there is no
 * current course to go on with. */
- (void)begin
{
    HRResultStore *store = self.model.store;
    NSString *file = [self currentCourseFile];
    if (!file) {
        [self presentPlaceholder:HRLoc(@"No course chosen yet.\n\nPick one in the Courses window \u2014 it keeps your place\nfrom then on.")
                          inMode:HRTestModeLesson];
        [self showWindow];
        return;
    }
    NSArray *lessons = [self.model.packs scriptForCourseFile:file].lessons;
    if ([lessons count] == 0) {
        [self presentPlaceholder:HRLoc(@"This course could not be read.") inMode:HRTestModeLesson];
        return;
    }
    HRCourseProgress *progress = [store progressForCourse:file];
    NSUInteger lesson = progress ? (NSUInteger)MAX(0, [progress.lessonIndex integerValue]) : 0;
    NSUInteger step = progress ? (NSUInteger)MAX(0, [progress.stepIndex integerValue]) : 0;
    if (!store && [_unsavedCourseFile isEqual:file]) {
        /* no store to ask: at least do not go round in circles */
        lesson = _unsavedNextLesson;
        step = 0;
    }
    if (lesson >= [lessons count]) {
        /* the course is done; the window is where one picks what to repeat */
        [self presentPlaceholder:HRLoc(@"You have finished this course.\n\nPick another one, or a lesson to take again,\nin the Courses window.")
                          inMode:HRTestModeLesson];
        [self showWindow];
        return;
    }
    [self startLesson:lesson ofCourse:file atStep:step];
}

- (void)leave
{
    _run = nil;
    _courseFile = nil;
}

/* Tab in a lesson: this exercise again, not a way out of it.  Between
 * lessons: on to the next one. */
- (void)next
{
    if (_run) [self presentStep];
    else [self begin];
}

- (void)pageDismissed
{
    if (!_run) {
        /* the page that says there is no course to go on with */
        [self showWindow];
        return;
    }
    [_run advancePastPage];
    [self presentStep];
}

- (NSString *)statusPrefix
{
    if (!_run) return nil;
    return [NSString stringWithFormat:@"%@   %lu/%lu", _run.lesson.title,
            (unsigned long)MIN(_run.stepIndex + 1, [_run.lesson.steps count]),
            (unsigned long)[_run.lesson.steps count]];
}

- (NSString *)keyboardDefaultsKey { return HRKeyboardInCourseDefaultsKey; }
- (BOOL)keyboardShowsByDefault { return YES; }

/* A course names its layout in index.plist; a course without one (the
 * numeric keypad, or a national layout there is no pack for) gets no
 * keyboard rather than a wrong one. */
- (HRKeyboardLayout *)keyboardLayout
{
    NSString *file = _courseFile ?: [self currentCourseFile];
    return [self.model.packs layoutNamed:[self.model.packs courseEntryForFile:file][@"layout"]];
}

#pragma mark - A lesson

- (void)restartLesson
{
    if (_run) [self startLesson:_lessonIndex ofCourse:_courseFile atStep:0];
}

- (void)startLesson:(NSUInteger)lessonIndex ofCourse:(NSString *)file atStep:(NSUInteger)step
{
    HRResultStore *store = self.model.store;
    NSArray *lessons = [self.model.packs scriptForCourseFile:file].lessons;
    if (lessonIndex >= [lessons count]) return;
    HRTypLesson *lesson = lessons[lessonIndex];
    _courseFile = [file copy];
    _lessonIndex = lessonIndex;
    _run = [[HRCourseRun alloc] initWithLesson:lesson startingAtStep:step];
    /* picked up in the middle (a relaunch): what was typed before counts too */
    if (_run.stepIndex > 0) {
        [_run addEarlierExercises:[store earlierExercisesOfLesson:lessonIndex inCourse:file beforeStep:_run.stepIndex] ?: @[]];
    }
    if (_run.stepIndex == 0) {
        [store noteLessonStarted:lessonIndex title:lesson.title inCourse:file error:NULL];
    }
    /* (the course's language goes on its results -- see -presentStep -- and
     * no further: following a German course must not turn the tests and the
     * weak-key rounds German) */
    [self.host activity:self willPresentInMode:HRTestModeLesson save:YES];
    [self.stage.window makeKeyAndOrderFront:self];
    [self presentStep];
}

/* The course's bookmark only moves forwards.  Taking an earlier lesson
 * again is practice: it gets recorded, but it must not drag the place in
 * the course back to lesson 2 for someone who was at lesson 9. */
- (BOOL)lessonIsAtOrPastBookmark
{
    HRCourseProgress *progress = [self.model.store progressForCourse:_courseFile];
    return !progress || (NSInteger)_lessonIndex >= [progress.lessonIndex integerValue];
}

- (void)saveCoursePosition
{
    if (!_run || !_courseFile || ![self lessonIsAtOrPastBookmark]) return;
    HRResultStore *store = self.model.store;
    NSError *error = nil;
    if (![store setLessonIndex:_lessonIndex stepIndex:_run.stepIndex forCourse:_courseFile error:&error] && store) {
        NSLog(@"HomeRow: the position in the course was not saved: %@", error);
    }
}

- (void)presentStep
{
    if (_run.isFinished) {
        [self finishLesson];
        return;
    }
    [self saveCoursePosition];
    HRTypStep *step = [_run currentStep];
    if (!step.isExercise) {
        [self.stage presentPage:step.text];
        return;
    }
    NSString *caption = step.instruction;
    if (_run.isRepeating) {
        NSString *again = HRLoc(@"Too many errors — once more.");
        caption = [caption length] > 0 ? [NSString stringWithFormat:@"%@\n%@", again, caption] : again;
    }
    HRTestConfiguration *configuration = [self.model.configuration copy];
    NSString *language = [self.model.packs courseEntryForFile:_courseFile][@"language"];
    if (language) configuration.languageID = language;
    HRTestSession *session = [[HRTestSession alloc] initWithConfiguration:configuration
                                                                   source:[[HRFixedTextSource alloc] initWithText:step.text]];
    [self.stage presentSession:session caption:caption codeLayout:NO paceWpm:0.0];
}

- (void)sessionDidFinish:(HRTestSession *)session
{
    HRTestSummary *s = [session summary];
    HRResultStore *store = self.model.store;
    if (store && [HRActivity summaryIsWorthKeeping:s]) {
        NSError *error = nil;
        if (![store recordSummary:s configuration:(session.configuration ?: self.model.configuration) courseFile:_courseFile
                      lessonIndex:_lessonIndex stepIndex:_run.stepIndex date:[NSDate date] error:&error]) {
            NSLog(@"HomeRow: the result was not saved: %@", error);
        }
        [self.host activityDidRecordResult:self];
    }
    /* a lesson goes straight on to its next exercise */
    [_run recordExercise:s];
    [self presentStep];
}

/* The lesson is done: record what it came to, move the course on to the
 * next lesson, and show the lesson -- not its last exercise -- as the
 * result. */
- (void)finishLesson
{
    HRResultStore *store = self.model.store;
    HRLessonSummary *l = [_run summary];
    NSArray *lessons = [self.model.packs scriptForCourseFile:_courseFile].lessons;
    NSUInteger next = _lessonIndex + 1;
    NSError *error = nil;
    if (store) {
        BOOL advances = [self lessonIsAtOrPastBookmark];
        if (![store noteLessonCompleted:_lessonIndex summary:l countsForBest:_run.coversWholeLesson
                               inCourse:_courseFile error:&error]
            || (advances && ![store setLessonIndex:next stepIndex:0 forCourse:_courseFile error:&error])) {
            NSLog(@"HomeRow: the lesson was not recorded: %@", error);
        }
    }
    _unsavedCourseFile = [_courseFile copy];
    _unsavedNextLesson = _lessonIndex + 1;
    NSString *title = _run.lesson.title;
    /* what Return does next is "continue the course", so say which lesson
     * that is -- after a retake it is the bookmark, not the one after this */
    HRCourseProgress *bookmark = [store progressForCourse:_courseFile];
    if (bookmark) next = (NSUInteger)MAX(0, [bookmark.lessonIndex integerValue]);
    NSString *nextTitle = next < [lessons count] ? ((HRTypLesson *)lessons[next]).title : nil;
    _run = nil;

    HRStageResult *result = [[HRStageResult alloc] init];
    result.wpm = l.wpm;
    result.accuracy = l.accuracy;
    result.detail = [NSString stringWithFormat:HRLoc(@"%@ — done.   %lu exercises   %lu repeated   %.0fs of typing"),
                     title, (unsigned long)l.exercises, (unsigned long)l.repeats, l.duration];
    result.hint = nextTitle
        ? [NSString stringWithFormat:HRLoc(@"return — next lesson: %@"), nextTitle]
        : HRLoc(@"That was the last lesson of this course.  return — courses");
    result.samples = @[];
    [self.stage presentResult:result];
    [_windowController reloadProgress];
    [self.host activityDidRecordResult:self];   /* the lesson's record, after its exercises' */
}

#pragma mark - HRCourseWindowDelegate

- (NSArray *)courseWindow:(HRCourseWindowController *)controller lessonsOfCourse:(NSString *)courseFile
{
    return [self.model.packs scriptForCourseFile:courseFile].lessons ?: @[];
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
    [self leave];
    if ([courseFile isEqual:[self currentCourseFile]]) [self begin];
}

- (void)courseWindowDidRequestContinue:(HRCourseWindowController *)controller
{
    [self begin];
}

- (void)courseWindow:(HRCourseWindowController *)controller didRequestLesson:(NSUInteger)lessonIndex
{
    [self startLesson:lessonIndex ofCourse:[self currentCourseFile] atStep:0];
}

@end
