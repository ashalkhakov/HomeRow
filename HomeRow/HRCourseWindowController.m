/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * HomeRow is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version.  It comes with ABSOLUTELY NO WARRANTY.  See COPYING.
 */
#import "HRCourseWindowController.h"
#import "HRResultStore.h"
#import "HRStatistics.h"
#import "HRTypScript.h"

#define HRLoc(key) NSLocalizedString(key, nil)

@implementation HRCourseWindowController
{
    NSArray *_courses;
    NSDictionary *_languageNames;
    HRResultStore *_store;
    __weak id<HRCourseWindowDelegate> _delegate;
    NSArray *_lessons;        /* HRTypLesson, of the selected course */
    NSDictionary *_records;   /* lesson index -> HRLessonRecord */
    NSInteger _nextLesson;    /* -1: not started */
    NSDateFormatter *_dateFormatter;
}

- (instancetype)initWithCourses:(NSArray *)courses
                  languageNames:(NSDictionary *)languageNames
                          store:(HRResultStore *)store
                       delegate:(id<HRCourseWindowDelegate>)delegate
{
    if ((self = [super initWithWindowNibName:@"CourseWindow"])) {
        /* by language, then as the index orders them */
        NSMutableArray *sorted = [courses mutableCopy];
        [sorted sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
            NSString *la = languageNames[a[@"language"]] ?: a[@"language"] ?: @"";
            NSString *lb = languageNames[b[@"language"]] ?: b[@"language"] ?: @"";
            NSComparisonResult r = [la caseInsensitiveCompare:lb];
            if (r != NSOrderedSame) return r;
            NSUInteger ia = [courses indexOfObject:a], ib = [courses indexOfObject:b];
            return ia < ib ? NSOrderedAscending : (ia > ib ? NSOrderedDescending : NSOrderedSame);
        }];
        _courses = sorted;
        _languageNames = [languageNames copy];
        _store = store;
        _delegate = delegate;
        _nextLesson = -1;
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    [_coursePopUp removeAllItems];
    for (NSDictionary *course in _courses) {
        NSString *language = _languageNames[course[@"language"]] ?: course[@"language"] ?: @"";
        [_coursePopUp addItemWithTitle:[NSString stringWithFormat:@"%@ — %@", language, course[@"title"]]];
        [[_coursePopUp lastItem] setRepresentedObject:course[@"file"]];
    }
    [_lessonTable setTarget:self];
    [_lessonTable setDoubleAction:@selector(startSelectedLesson:)];
    [self selectCourseInPopUp];
    [self reloadProgress];
}

/* A bullet in front of the courses that have been started, so the ones on
 * the go stand out among forty-six. */
- (void)markStartedCourses
{
    NSSet *started = [NSSet setWithArray:[[_store startedCourses] valueForKey:@"courseFile"]];
    for (NSMenuItem *item in [_coursePopUp itemArray]) {
        NSString *title = [item title];
        if ([title hasPrefix:@"\u2022 "]) title = [title substringFromIndex:2];
        if ([started containsObject:[item representedObject]]) title = [@"\u2022 " stringByAppendingString:title];
        [item setTitle:title];
    }
}

- (void)selectCourseInPopUp
{
    for (NSMenuItem *item in [_coursePopUp itemArray]) {
        if ([[item representedObject] isEqual:_selectedCourseFile]) {
            [_coursePopUp selectItem:item];
            return;
        }
    }
    /* nothing chosen yet: show the first course without choosing it */
    if ([_coursePopUp numberOfItems] > 0) [_coursePopUp selectItemAtIndex:0];
}

- (NSString *)shownCourseFile
{
    return [[_coursePopUp selectedItem] representedObject] ?: _selectedCourseFile;
}

- (void)setSelectedCourseFile:(NSString *)file
{
    _selectedCourseFile = [file copy];
    if ([self isWindowLoaded]) {
        [self selectCourseInPopUp];
        [self reloadProgress];
    }
}

- (void)reloadProgress
{
    if (![self isWindowLoaded]) return;
    NSString *file = [self shownCourseFile];
    _lessons = file ? [_delegate courseWindow:self lessonsOfCourse:file] : @[];
    _records = file ? [_store lessonRecordsForCourse:file] : @{};
    HRCourseProgress *progress = file ? [_store progressForCourse:file] : nil;
    _nextLesson = progress ? [progress.lessonIndex integerValue] : -1;

    NSUInteger done = 0;
    for (NSNumber *index in _records) {
        if ([((HRLessonRecord *)_records[index]).completions integerValue] > 0) done++;
    }
    NSString *summary;
    if (!progress) {
        summary = [NSString stringWithFormat:HRLoc(@"%lu lessons. Not started yet."), (unsigned long)[_lessons count]];
    } else if (_nextLesson >= (NSInteger)[_lessons count]) {
        summary = [NSString stringWithFormat:HRLoc(@"All %lu lessons done. Any of them can be taken again."),
                   (unsigned long)[_lessons count]];
    } else {
        summary = [NSString stringWithFormat:HRLoc(@"%lu of %lu lessons done. Next: %@"),
                   (unsigned long)done, (unsigned long)[_lessons count],
                   ((HRTypLesson *)_lessons[_nextLesson]).title];
    }
    [self markStartedCourses];
    [_summaryField setStringValue:summary];
    [_continueButton setTitle:(progress ? HRLoc(@"Continue") : HRLoc(@"Start Course"))];
    [_continueButton setEnabled:[_lessons count] > 0];
    [_resetButton setEnabled:progress != nil];
    [_lessonTable reloadData];
    if (_nextLesson >= 0 && _nextLesson < (NSInteger)[_lessons count]) {
        [_lessonTable selectRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)_nextLesson] byExtendingSelection:NO];
        [_lessonTable scrollRowToVisible:_nextLesson];
    }
    [_startButton setEnabled:[_lessonTable selectedRow] >= 0];
}

#pragma mark - Actions

- (IBAction)courseChanged:(id)sender
{
    [self reloadProgress];
}

/* Following a course starts here: the course shown becomes the current
 * one, and typing goes on where it was left. */
- (IBAction)continueCourse:(id)sender
{
    NSString *file = [self shownCourseFile];
    if (!file) return;
    _selectedCourseFile = [file copy];
    [_delegate courseWindow:self didSelectCourse:file];
    [_delegate courseWindowDidRequestContinue:self];
}

- (IBAction)startSelectedLesson:(id)sender
{
    /* a double click on the header is not a double click on a lesson */
    if (sender == _lessonTable && [_lessonTable clickedRow] < 0) return;
    NSInteger row = [_lessonTable selectedRow];
    NSString *file = [self shownCourseFile];
    if (row < 0 || !file) return;
    _selectedCourseFile = [file copy];
    [_delegate courseWindow:self didSelectCourse:file];
    [_delegate courseWindow:self didRequestLesson:(NSUInteger)row];
}

- (IBAction)resetProgress:(id)sender
{
    NSString *file = [self shownCourseFile];
    if (!file) return;
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:HRLoc(@"Forget the progress in this course?")];
    [alert setInformativeText:HRLoc(@"The position and the lesson records are removed. The exercises you typed stay in your history.")];
    [alert addButtonWithTitle:HRLoc(@"Forget")];
    [alert addButtonWithTitle:HRLoc(@"Cancel")];
    if ([alert runModal] != NSAlertFirstButtonReturn) return;
    NSError *error = nil;
    if (![_store resetCourse:file error:&error]) NSLog(@"HomeRow: the course was not reset: %@", error);
    [_delegate courseWindow:self didResetCourse:file];
    [self reloadProgress];
}

#pragma mark - Table

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return (NSInteger)[_lessons count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)column row:(NSInteger)row
{
    NSString *key = [column identifier];
    HRTypLesson *lesson = _lessons[(NSUInteger)row];
    HRLessonRecord *record = _records[@(row)];
    BOOL done = [record.completions integerValue] > 0;
    if ([key isEqualToString:@"status"]) {
        if (done) return @"✓";
        return row == _nextLesson ? @"▸" : @"";
    }
    if ([key isEqualToString:@"title"]) {
        return [lesson.title length] > 0 ? lesson.title
               : [NSString stringWithFormat:HRLoc(@"Lesson %ld"), (long)row + 1];
    }
    if ([key isEqualToString:@"exercises"]) return [NSString stringWithFormat:@"%lu", (unsigned long)[lesson exerciseCount]];
    if (!done) return @"";
    if ([key isEqualToString:@"wpm"])      return [NSString stringWithFormat:@"%.0f", [record.bestWpm doubleValue]];
    if ([key isEqualToString:@"accuracy"]) return [NSString stringWithFormat:@"%.0f%%", [record.bestAccuracy doubleValue]];
    if ([key isEqualToString:@"times"])    return [NSString stringWithFormat:@"%ld", (long)[record.completions integerValue]];
    if ([key isEqualToString:@"last"] && record.lastDate) {
        if (!_dateFormatter) {
            _dateFormatter = [[NSDateFormatter alloc] init];
            [_dateFormatter setDateStyle:NSDateFormatterMediumStyle];
            [_dateFormatter setTimeStyle:NSDateFormatterNoStyle];
        }
        /* the locale's own format where there is one; a gnustep-base built
         * without ICU formats nothing, and then the date is spelled by hand */
        NSString *formatted = [_dateFormatter stringFromDate:record.lastDate];
        return [formatted length] > 0 ? formatted
                                      : [HRStatistics mediumStringForDate:record.lastDate timeZone:nil];
    }
    return @"";
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
    [_startButton setEnabled:[_lessonTable selectedRow] >= 0];
}

@end
