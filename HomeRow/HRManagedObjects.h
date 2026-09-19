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

/* Classes for HomeRow.xcdatamodeld.  Written by hand rather than generated:
 * Xcode's codegen is switched off for both entities so that one set of
 * files serves Apple's CoreData and FreeCoreData alike.  Numeric attributes
 * are NSNumber (usesScalarValueType = NO) for the same reason. */

@class HRKeyStat;

@interface HRTestResult : NSManagedObject

@property (nonatomic, strong) NSDate *date;
@property (nonatomic, copy) NSString *mode;
@property (nonatomic, strong) NSNumber *amount;
@property (nonatomic, copy) NSString *settingsKey;
@property (nonatomic, copy) NSString *languageID;
@property (nonatomic, copy) NSString *layoutID;

@property (nonatomic, strong) NSNumber *wpm;
@property (nonatomic, strong) NSNumber *rawWpm;
@property (nonatomic, strong) NSNumber *accuracy;
@property (nonatomic, strong) NSNumber *consistency;
@property (nonatomic, strong) NSNumber *duration;

@property (nonatomic, strong) NSNumber *correctCharacters;
@property (nonatomic, strong) NSNumber *incorrectCharacters;
@property (nonatomic, strong) NSNumber *extraCharacters;
@property (nonatomic, strong) NSNumber *missedCharacters;

/* Property-list data: @{ @"raw": [...], @"errors": [...] }, one entry per
 * second.  A blob keeps the schema flat; nothing queries inside it. */
@property (nonatomic, strong) NSData *series;

/* set when the result is an exercise of a course (mode "lesson") */
@property (nonatomic, copy) NSString *courseFile;
@property (nonatomic, strong) NSNumber *lessonIndex;
@property (nonatomic, strong) NSNumber *stepIndex;

@property (nonatomic, strong) NSSet *keyStats;

- (NSDictionary *)seriesDictionary;

@end

@interface HRKeyStat : NSManagedObject

@property (nonatomic, copy) NSString *character;
@property (nonatomic, strong) NSNumber *hits;
@property (nonatomic, strong) NSNumber *misses;
@property (nonatomic, strong) HRTestResult *result;

@end

/* Where the learner is in one course.  One row per course ever started;
 * which course is the current one is a user default, not data. */
@interface HRCourseProgress : NSManagedObject

@property (nonatomic, copy) NSString *courseFile;
@property (nonatomic, strong) NSNumber *lessonIndex;   /* the lesson to do next */
@property (nonatomic, strong) NSNumber *stepIndex;     /* where to resume inside it */
@property (nonatomic, strong) NSDate *startedDate;
@property (nonatomic, strong) NSDate *lastDate;

@end

/* What happened in one lesson of one course, over all the times it was
 * taken.  The exercises themselves are HRTestResult rows. */
@interface HRLessonRecord : NSManagedObject

@property (nonatomic, copy) NSString *courseFile;
@property (nonatomic, strong) NSNumber *lessonIndex;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, strong) NSNumber *attempts;      /* times started */
@property (nonatomic, strong) NSNumber *completions;   /* times finished */
@property (nonatomic, strong) NSNumber *bestWpm;
@property (nonatomic, strong) NSNumber *bestAccuracy;
@property (nonatomic, strong) NSNumber *lastWpm;
@property (nonatomic, strong) NSNumber *lastAccuracy;
@property (nonatomic, strong) NSNumber *totalDuration;
@property (nonatomic, strong) NSDate *lastDate;

@end
