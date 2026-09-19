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
#import <CoreData/CoreData.h>
#import "HRManagedObjects.h"
#import "HRStatistics.h"

@class HRTestSummary;
@class HRTestConfiguration;
@class HRLessonSummary;

/* The Core Data stack and the few operations the app needs from it.
 * Apple's CoreData on macOS, FreeCoreData on GNUstep; nothing outside this
 * class and HRManagedObjects should have to know which. */
@interface HRResultStore : NSObject

@property (nonatomic, readonly) NSManagedObjectContext *context;

/* The store the app uses: <Application Support>/HomeRow/HomeRow.sqlite. */
+ (NSURL *)defaultStoreURL;

/* `storeURL` nil gives an in-memory store (tests).  `bundle` is where
 * HomeRow.momd is looked up; nil means the bundle this class is in. */
- (instancetype)initWithStoreURL:(NSURL *)storeURL
                          bundle:(NSBundle *)bundle
                           error:(NSError **)error;

- (HRTestResult *)recordSummary:(HRTestSummary *)summary
                  configuration:(HRTestConfiguration *)configuration
                           date:(NSDate *)date
                          error:(NSError **)error;

/* The same, for an exercise of a course. */
- (HRTestResult *)recordSummary:(HRTestSummary *)summary
                  configuration:(HRTestConfiguration *)configuration
                     courseFile:(NSString *)courseFile
                    lessonIndex:(NSUInteger)lessonIndex
                      stepIndex:(NSUInteger)stepIndex
                           date:(NSDate *)date
                          error:(NSError **)error;

/* YES when the store on disk could not be opened or migrated and was set
 * aside (as HomeRow.sqlite.unreadable-<timestamp>) in favour of a new one. */
@property (nonatomic, readonly) BOOL didSetAsideUnreadableStore;

/* --- courses ---------------------------------------------------------- */

/* Every course ever started (HRCourseProgress), most recently used first. */
- (NSArray *)startedCourses;
/* nil when the course was never started. */
- (HRCourseProgress *)progressForCourse:(NSString *)courseFile;
/* Remembers where the learner is; creates the row on first use. */
- (BOOL)setLessonIndex:(NSUInteger)lessonIndex
             stepIndex:(NSUInteger)stepIndex
             forCourse:(NSString *)courseFile
                 error:(NSError **)error;
/* All lesson records of a course, keyed by lesson index (NSNumber). */
- (NSDictionary *)lessonRecordsForCourse:(NSString *)courseFile;
- (BOOL)noteLessonStarted:(NSUInteger)lessonIndex
                    title:(NSString *)title
                 inCourse:(NSString *)courseFile
                    error:(NSError **)error;
/* `countsForBest` NO: the summary covers only part of the lesson. */
- (BOOL)noteLessonCompleted:(NSUInteger)lessonIndex
                    summary:(HRLessonSummary *)summary
              countsForBest:(BOOL)countsForBest
                   inCourse:(NSString *)courseFile
                      error:(NSError **)error;
/* The exercises of the attempt at a lesson that is under way -- saved since
 * the lesson was last started -- before `step`, oldest first, in the form
 * -[HRCourseRun addEarlierExercises:] takes.  The keystroke count is
 * estimated from the characters; results do not store it. */
- (NSArray *)earlierExercisesOfLesson:(NSUInteger)lessonIndex
                             inCourse:(NSString *)courseFile
                           beforeStep:(NSUInteger)step;
/* Forgets position and lesson records of a course; exercise results stay
 * in the history. */
- (BOOL)resetCourse:(NSString *)courseFile error:(NSError **)error;

/* --- statistics ------------------------------------------------------- */

/* Every saved result as a plain value for HRStatistics. */
- (NSArray *)statSamples;
/* character -> @{@"hits", @"misses"}, summed over the results of `kind`
 * (HRStatKindAll: every one) not older than `since` (nil: ever).  The
 * character is the one that was WANTED when the key was pressed. */
- (NSDictionary *)keyCountsForKind:(HRStatKind)kind since:(NSDate *)since;

/* --- history ---------------------------------------------------------- */

/* The best result (by WPM) of every setting of the time and words tests
 * that has one, best first: HRTestResult. */
- (NSArray *)personalBests;
/* Removes one result with its key stats.  Lesson records and the place in
 * a course are not touched. */
- (BOOL)deleteResult:(HRTestResult *)result error:(NSError **)error;

/* Every result as a record for HRResultExchange, oldest first.  Results
 * from before there were uuids are given one on the way (and keep it), so
 * that exporting twice and importing both adds nothing twice. */
- (NSArray *)exportRecords;
/* Adds the records that are not here yet: the same uuid, or -- for files
 * without them -- the same moment, mode and speed, is "here".  Returns how
 * many were added; `duplicates` how many were not.  One save for all. */
- (NSUInteger)importRecords:(NSArray *)records duplicates:(NSUInteger *)duplicates error:(NSError **)error;

/* Newest first; limit 0 = all. */
- (NSArray *)recentResultsWithLimit:(NSUInteger)limit error:(NSError **)error;

/* Highest WPM recorded for these settings, or nil. */
- (HRTestResult *)personalBestForSettingsKey:(NSString *)settingsKey error:(NSError **)error;

@end
