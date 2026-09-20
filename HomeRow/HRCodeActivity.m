/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * HomeRow is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version.  It comes with ABSOLUTELY NO WARRANTY.  See COPYING.
 */
#import "HRCodeActivity.h"
#import "HRAppModel.h"
#import "HRStage.h"
#import "HRResultStore.h"
#import "HRManagedObjects.h"
#import "HRTestSession.h"
#import "HRCourseRun.h"        /* HRLessonSummary */
#import "HRCodeLibrary.h"
#import "HRCodeDocument.h"
#import "HRCodeWindowController.h"
#import "HRStatistics.h"
#import "HRPreferencesWindowController.h"   /* the keyboard's and Tab's defaults keys */

#define HRLoc(key) NSLocalizedString(key, nil)

/* the file being typed, by its identifier */
static NSString * const HRCurrentCodeFileDefaultsKey = @"HRCurrentCodeFile";

@interface HRCodeActivity () <HRCodeWindowDelegate>
@end

@implementation HRCodeActivity
{
    HRCodeLibrary *_library;
    HRCodeWindowController *_windowController;
    BOOL _sectionDone;               /* typed to the end: Return moves on */
    NSString *_unsavedFile;          /* the place in the file when there is no store */
    NSUInteger _unsavedNextSection;
}

#pragma mark - The library and its window

- (HRCodeLibrary *)library
{
    if (!_library) {
        NSString *directory = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Code"];
        _library = [[HRCodeLibrary alloc] initWithDirectory:directory];
        NSArray *paths = [[NSUserDefaults standardUserDefaults] arrayForKey:HRCodeUserFilesDefaultsKey];
        if (paths) _library.userFilePaths = paths;
        NSArray *folders = [[NSUserDefaults standardUserDefaults] arrayForKey:HRCodeUserFoldersDefaultsKey];
        if (folders) _library.userFolderPaths = folders;
    }
    return _library;
}

- (HRCodeFile *)currentFile
{
    return [[self library] fileWithIdentifier:
            [[NSUserDefaults standardUserDefaults] stringForKey:HRCurrentCodeFileDefaultsKey]];
}

- (HRCodeWindowController *)windowController
{
    if (!_windowController) {
        _windowController = [[HRCodeWindowController alloc] initWithLibrary:[self library] store:self.model.store delegate:self];
        HRCodeFile *file = [self currentFile];
        if ([file.languageID length] > 0) _windowController.selectedLanguageID = file.languageID;
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

/* Where the current file was left; the Code window when there is nothing
 * to go on with. */
- (void)begin
{
    HRResultStore *store = self.model.store;
    HRCodeFile *file = [self currentFile];
    HRCodeDocument *document = file ? [[self library] documentForFile:file error:NULL] : nil;
    if (!document) {
        [self presentPlaceholder:HRLoc(@"No code chosen yet.\n\nPick a language and a file in the Code window —\nor open one of your own.")
                          inMode:HRTestModeCode];
        [self showWindow];
        return;
    }
    HRCourseProgress *progress = [store progressForCourse:file.identifier];
    NSUInteger section = progress ? (NSUInteger)MAX(0, [progress.lessonIndex integerValue]) : 0;
    if (!store && [_unsavedFile isEqual:file.identifier]) section = _unsavedNextSection;
    if (section >= document.numberOfSections) {
        [self presentPlaceholder:HRLoc(@"You have typed this file to the end.\n\nPick another one, or a part to type again,\nin the Code window.")
                          inMode:HRTestModeCode];
        [self showWindow];
        return;
    }
    [self startSection:section ofFile:file];
}

- (void)leave
{
    _file = nil;
    _sectionDone = NO;
}

/* Tab while typing: this section again.  After it, or with no file yet: on
 * to wherever the file was left. */
- (void)next
{
    if (_file && !_sectionDone) [self presentSection];
    else [self begin];
}

- (void)pageDismissed
{
    /* the page that says there is no file to go on with */
    [self showWindow];
}

- (NSString *)statusPrefix
{
    if (!_file) return nil;
    return [NSString stringWithFormat:HRLoc(@"%@   part %lu/%lu"), _file.title,
            (unsigned long)(_section + 1), (unsigned long)_sectionCount];
}

- (NSString *)keyboardDefaultsKey { return HRKeyboardInCodeDefaultsKey; }
- (BOOL)keyboardShowsByDefault { return YES; }

#pragma mark - A section

- (void)startSection:(NSUInteger)section ofFile:(HRCodeFile *)file
{
    HRCodeDocument *document = [[self library] documentForFile:file error:NULL];
    if (!document || section >= document.numberOfSections) return;
    _file = file;
    _section = section;
    _sectionCount = document.numberOfSections;
    [[NSUserDefaults standardUserDefaults] setObject:file.identifier forKey:HRCurrentCodeFileDefaultsKey];
    [self.host activity:self willPresentInMode:HRTestModeCode save:YES];
    [self.stage.window makeKeyAndOrderFront:self];
    [self presentSection];
}

- (void)presentSection
{
    HRCodeDocument *document = [[self library] documentForFile:_file error:NULL];
    if (!document) {
        /* one of the user's own files, gone or changed since it was opened */
        [self presentPlaceholder:HRLoc(@"This file could not be read.") inMode:HRTestModeCode];
        return;
    }
    _sectionDone = NO;
    NSRange lines = [document lineRangeOfSection:_section];
    [self.model.store noteLessonStarted:_section
                                  title:[NSString stringWithFormat:@"%@:%lu-%lu", _file.title,
                                         (unsigned long)(lines.location + 1), (unsigned long)NSMaxRange(lines)]
                               inCourse:_file.identifier error:NULL];
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    /* a compiler takes no near misses, and neither does this: the wrong
     * key does not go in.  Only for the session -- the saved configuration
     * keeps whatever the other modes use. */
    HRTestConfiguration *configuration = [self.model.configuration copy];
    configuration.stopOnError = YES;
    id<HRTextSource> source = [document sourceForSection:_section
                                            typeComments:[d boolForKey:HRCodeTypeCommentsDefaultsKey]
                                                typeTabs:[d boolForKey:HRCodeTypeTabsDefaultsKey]];
    HRTestSession *session = [[HRTestSession alloc] initWithConfiguration:configuration source:source];
    [self.stage presentSession:session caption:nil codeLayout:YES paceWpm:0.0];
}

- (void)sessionDidFinish:(HRTestSession *)session
{
    HRTestSummary *s = [session summary];
    HRResultStore *store = self.model.store;
    BOOL worthKeeping = [HRActivity summaryIsWorthKeeping:s];
    NSString *identifier = _file.identifier;
    NSUInteger next = _section + 1;
    if (store && worthKeeping) {
        NSError *error = nil;
        if (![store recordSummary:s configuration:(session.configuration ?: self.model.configuration) courseFile:identifier
                      lessonIndex:_section stepIndex:0 date:[NSDate date] error:&error]) {
            NSLog(@"HomeRow: the result was not saved: %@", error);
        }
        HRLessonSummary *l = [[HRLessonSummary alloc] init];
        l.wpm = s.wpm;
        l.accuracy = s.accuracy;
        l.duration = s.duration;
        l.exercises = 1;
        /* like a course's, the bookmark only moves forwards */
        HRCourseProgress *progress = [store progressForCourse:identifier];
        BOOL advances = !progress || (NSInteger)_section >= [progress.lessonIndex integerValue];
        if (![store noteLessonCompleted:_section summary:l countsForBest:YES inCourse:identifier error:&error]
            || (advances && ![store setLessonIndex:next stepIndex:0 forCourse:identifier error:&error])) {
            NSLog(@"HomeRow: the section was not recorded: %@", error);
        }
        [self.host activityDidRecordResult:self];
    }
    _unsavedFile = [identifier copy];
    _unsavedNextSection = next;
    HRCourseProgress *bookmark = [store progressForCourse:identifier];
    if (bookmark) next = (NSUInteger)MAX(0, [bookmark.lessonIndex integerValue]);
    _sectionDone = YES;

    HRStageResult *result = [HRStageResult resultWithSummary:s];
    /* for code, what the mistakes cost and where they were made says more than consistency does */
    NSDictionary *classNames = @{HRKeyClassLetters: HRLoc(@"letters"), HRKeyClassCapitals: HRLoc(@"capitals"), HRKeyClassDigits: HRLoc(@"digits"),
                                 HRKeyClassBrackets: HRLoc(@"brackets"), HRKeyClassOperators: HRLoc(@"operators"),
                                 HRKeyClassPunctuation: HRLoc(@"punctuation"), HRKeyClassWhitespace: HRLoc(@"space, return, tab")};
    result.detail = [NSString stringWithFormat:HRLoc(@"overhead %.0f%%   \u2014   %@   \u2014   %.0fs"),
                     [s keystrokeOverhead] * 100.0,
                     [HRStatistics lineForKeyClasses:[HRStatistics keyClassesFromCounts:s.keyStats ?: @{}] names:classNames],
                     s.duration];
    result.hint = next < _sectionCount
        ? [NSString stringWithFormat:HRLoc(@"return — part %lu of %lu"), (unsigned long)(next + 1), (unsigned long)_sectionCount]
        : HRLoc(@"That was the last part of this file.  return — code");
    result.replayable = YES;
    [self.stage presentResult:result];
    [_windowController reloadProgress];
}

#pragma mark - HRCodeWindowDelegate

- (void)codeWindow:(HRCodeWindowController *)controller didRequestFile:(HRCodeFile *)file section:(NSUInteger)section
{
    [self startSection:section ofFile:file];
}

@end
