/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * HomeRow is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version.  It comes with ABSOLUTELY NO WARRANTY.  See COPYING.
 */
#import <XCTest/XCTest.h>
#import "HRCourseRun.h"
#import "HRResultStore.h"
#import "HRTestConfiguration.h"

@interface HRCourseTests : XCTestCase
@end

@implementation HRCourseTests
{
    NSString *_dir;
}

- (void)setUp
{
    [super setUp];
    _dir = [NSTemporaryDirectory() stringByAppendingPathComponent:
            [NSString stringWithFormat:@"hr-course-%d-%u", (int)[[NSProcessInfo processInfo] processIdentifier], arc4random()]];
    [[NSFileManager defaultManager] createDirectoryAtPath:_dir withIntermediateDirectories:YES attributes:nil error:NULL];
}

- (void)tearDown
{
    [[NSFileManager defaultManager] removeItemAtPath:_dir error:NULL];
    [super tearDown];
}

- (HRTypLesson *)lesson
{
    HRTypScript *s = [HRTypScript scriptWithString:
        @"B:One\nT:Read me.\nD:aaaa\nE:10%\nD:bbbb\nd:cccc\n" error:NULL];
    return s.lessons[0];
}

- (HRTestSummary *)summaryWithWpm:(double)wpm correct:(NSUInteger)correct wrong:(NSUInteger)wrong seconds:(double)seconds
{
    HRTestSummary *s = [[HRTestSummary alloc] init];
    s.wpm = wpm;
    s.duration = seconds;
    s.correctKeystrokes = correct;
    s.incorrectKeystrokes = wrong;
    s.accuracy = 100.0 * (double)correct / (double)(correct + wrong);
    return s;
}

- (void)testARunRepeatsWhatWasTypedBadlyAndAddsItAllUp
{
    HRCourseRun *run = [[HRCourseRun alloc] initWithLesson:[self lesson] startingAtStep:0];
    XCTAssertFalse([run currentStep].isExercise);
    /* typing results do not move a page */
    [run advancePastPage];
    XCTAssertEqual(run.stepIndex, (NSUInteger)1);

    /* 5% wrong against the default 3%: again */
    XCTAssertFalse([run recordExercise:[self summaryWithWpm:20 correct:95 wrong:5 seconds:10]]);
    XCTAssertTrue(run.isRepeating);
    XCTAssertEqual(run.stepIndex, (NSUInteger)1);
    /* exactly 3% passes */
    XCTAssertTrue([run recordExercise:[self summaryWithWpm:40 correct:97 wrong:3 seconds:10]]);
    XCTAssertFalse(run.isRepeating);

    /* E:10% covers the next exercise only */
    XCTAssertEqualWithAccuracy([run currentStep].maxErrorPercent, 10.0, 1e-9);
    XCTAssertTrue([run recordExercise:[self summaryWithWpm:30 correct:92 wrong:8 seconds:20]]);
    /* practice only: anything goes */
    XCTAssertTrue([run currentStep].practiceOnly);
    XCTAssertTrue([run recordExercise:[self summaryWithWpm:10 correct:50 wrong:50 seconds:10]]);
    XCTAssertTrue(run.isFinished);
    XCTAssertNil([run currentStep]);

    HRLessonSummary *l = [run summary];
    XCTAssertEqual(l.exercises, (NSUInteger)3);
    XCTAssertEqual(l.repeats, (NSUInteger)1);
    XCTAssertEqualWithAccuracy(l.duration, 50.0, 1e-9);
    XCTAssertEqualWithAccuracy(l.wpm, (20.0 * 10 + 40.0 * 10 + 30.0 * 20 + 10.0 * 10) / 50.0, 1e-9);
    XCTAssertEqualWithAccuracy(l.accuracy, 100.0 * 334.0 / 400.0, 1e-9);
}

- (void)testResumingInTheMiddle
{
    HRCourseRun *run = [[HRCourseRun alloc] initWithLesson:[self lesson] startingAtStep:2];
    XCTAssertEqualObjects([run currentStep].text, @"bbbb");
    run = [[HRCourseRun alloc] initWithLesson:[self lesson] startingAtStep:99];
    XCTAssertEqual(run.stepIndex, (NSUInteger)0, @"a position past the end means from the top");
}

/* Relaunched in the middle of a lesson: the exercises typed before count
 * towards its totals, once the store hands them over. */
- (void)testAResumedRunTakesInWhatWasTypedBefore
{
    HRCourseRun *run = [[HRCourseRun alloc] initWithLesson:[self lesson] startingAtStep:2];
    XCTAssertFalse(run.coversWholeLesson);
    /* aaaa was typed twice (the first time badly); the entry for step 0 is
     * a page and the one for step 3 is still to come: both ignored */
    [run addEarlierExercises:@[@{@"step": @1, @"wpm": @20, @"accuracy": @80, @"duration": @10, @"keystrokes": @10},
                               @{@"step": @1, @"wpm": @40, @"accuracy": @100, @"duration": @10, @"keystrokes": @10},
                               @{@"step": @0, @"wpm": @99, @"accuracy": @100, @"duration": @99, @"keystrokes": @99},
                               @{@"step": @3, @"wpm": @99, @"accuracy": @100, @"duration": @99, @"keystrokes": @99}]];
    XCTAssertTrue(run.coversWholeLesson, @"the one exercise before the resume point is accounted for");
    XCTAssertTrue([run recordExercise:[self summaryWithWpm:60 correct:10 wrong:0 seconds:20]]);
    XCTAssertTrue([run recordExercise:[self summaryWithWpm:60 correct:10 wrong:0 seconds:20]]);
    XCTAssertTrue(run.isFinished);
    HRLessonSummary *l = [run summary];
    XCTAssertEqual(l.exercises, (NSUInteger)3);
    XCTAssertEqual(l.repeats, (NSUInteger)1);
    XCTAssertEqualWithAccuracy(l.duration, 60.0, 1e-9);
    XCTAssertEqualWithAccuracy(l.wpm, (20.0 * 10 + 40.0 * 10 + 60.0 * 40) / 60.0, 1e-9);
    XCTAssertEqualWithAccuracy(l.accuracy, 100.0 * 38.0 / 40.0, 1e-9);

    /* nothing on record for the part that was skipped: still a partial run */
    HRCourseRun *partial = [[HRCourseRun alloc] initWithLesson:[self lesson] startingAtStep:2];
    [partial addEarlierExercises:@[]];
    XCTAssertFalse(partial.coversWholeLesson);
}

- (HRResultStore *)storeAtURL:(NSURL *)url
{
    NSError *e = nil;
    HRResultStore *store = [[HRResultStore alloc] initWithStoreURL:url
                                                            bundle:[NSBundle bundleForClass:[self class]]
                                                             error:&e];
    XCTAssertNotNil(store, @"%@", e);
    return store;
}

- (void)testTheStoreHandsOverTheEarlierExercisesOfThisAttemptOnly
{
    HRResultStore *store = [self storeAtURL:nil];
    HRTestConfiguration *c = [HRTestConfiguration defaultConfiguration];
    c.mode = HRTestModeLesson;
    HRTestSummary *s = [self summaryWithWpm:30 correct:38 wrong:2 seconds:12];
    s.correctCharacters = 38;
    s.incorrectCharacters = 2;
    NSError *e = nil;
    /* an exercise from an attempt long ago, then the lesson is started again */
    XCTAssertNotNil([store recordSummary:s configuration:c courseFile:@"q.typ" lessonIndex:0 stepIndex:1
                                    date:[NSDate dateWithTimeIntervalSinceNow:-86400.0] error:&e], @"%@", e);
    XCTAssertTrue([store noteLessonStarted:0 title:@"One" inCourse:@"q.typ" error:&e], @"%@", e);
    XCTAssertEqual([[store earlierExercisesOfLesson:0 inCourse:@"q.typ" beforeStep:2] count], (NSUInteger)0);
    XCTAssertNotNil([store recordSummary:s configuration:c courseFile:@"q.typ" lessonIndex:0 stepIndex:1
                                    date:[NSDate dateWithTimeIntervalSinceNow:1.0] error:&e], @"%@", e);
    XCTAssertNotNil([store recordSummary:s configuration:c courseFile:@"q.typ" lessonIndex:1 stepIndex:1
                                    date:[NSDate dateWithTimeIntervalSinceNow:1.0] error:&e], @"another lesson: %@", e);
    NSArray *earlier = [store earlierExercisesOfLesson:0 inCourse:@"q.typ" beforeStep:2];
    XCTAssertEqual([earlier count], (NSUInteger)1);
    XCTAssertEqualObjects(earlier[0][@"step"], @1);
    XCTAssertEqualObjects(earlier[0][@"keystrokes"], @40);
    XCTAssertEqual([[store earlierExercisesOfLesson:0 inCourse:@"q.typ" beforeStep:1] count], (NSUInteger)0);
}

- (void)testProgressAndLessonRecordsSurviveReopening
{
    NSURL *url = [NSURL fileURLWithPath:[_dir stringByAppendingPathComponent:@"c.sqlite"]];
    NSError *e = nil;
    @autoreleasepool {
        HRResultStore *store = [self storeAtURL:url];
        XCTAssertNil([store progressForCourse:@"q.typ"]);
        XCTAssertTrue([store setLessonIndex:2 stepIndex:5 forCourse:@"q.typ" error:&e], @"%@", e);
        XCTAssertTrue([store setLessonIndex:0 stepIndex:1 forCourse:@"ru.typ" error:&e], @"%@", e);
        XCTAssertTrue([store noteLessonStarted:1 title:@"Lesson Q2" inCourse:@"q.typ" error:&e], @"%@", e);

        HRLessonSummary *first = [[HRLessonSummary alloc] init];
        first.wpm = 30; first.accuracy = 96; first.duration = 100;
        HRLessonSummary *second = [[HRLessonSummary alloc] init];
        second.wpm = 25; second.accuracy = 99; second.duration = 80;
        XCTAssertTrue([store noteLessonCompleted:1 summary:first countsForBest:YES inCourse:@"q.typ" error:&e], @"%@", e);
        XCTAssertTrue([store noteLessonStarted:1 title:@"Lesson Q2" inCourse:@"q.typ" error:&e], @"%@", e);
        XCTAssertTrue([store noteLessonCompleted:1 summary:second countsForBest:YES inCourse:@"q.typ" error:&e], @"%@", e);

        HRTestSummary *exercise = [self summaryWithWpm:33 correct:40 wrong:0 seconds:12];
        HRTestConfiguration *c = [HRTestConfiguration defaultConfiguration];
        c.mode = HRTestModeLesson;
        XCTAssertNotNil([store recordSummary:exercise configuration:c courseFile:@"q.typ"
                                 lessonIndex:1 stepIndex:4 date:nil error:&e], @"%@", e);
    }

    HRResultStore *store = [self storeAtURL:url];
    /* two courses on the go at once, the one touched last first */
    NSArray *started = [[store startedCourses] valueForKey:@"courseFile"];
    XCTAssertEqualObjects(started, (@[@"ru.typ", @"q.typ"]));
    HRCourseProgress *p = [store progressForCourse:@"q.typ"];
    XCTAssertEqual([p.lessonIndex integerValue], (NSInteger)2);
    XCTAssertEqual([p.stepIndex integerValue], (NSInteger)5);
    XCTAssertEqual([[store progressForCourse:@"ru.typ"].stepIndex integerValue], (NSInteger)1);

    NSDictionary *records = [store lessonRecordsForCourse:@"q.typ"];
    XCTAssertEqual([records count], (NSUInteger)1);
    HRLessonRecord *r = records[@1];
    XCTAssertEqualObjects(r.title, @"Lesson Q2");
    XCTAssertEqual([r.attempts integerValue], (NSInteger)2);
    XCTAssertEqual([r.completions integerValue], (NSInteger)2);
    XCTAssertEqualWithAccuracy([r.bestWpm doubleValue], 30.0, 1e-9);
    XCTAssertEqualWithAccuracy([r.bestAccuracy doubleValue], 99.0, 1e-9);
    XCTAssertEqualWithAccuracy([r.lastWpm doubleValue], 25.0, 1e-9);
    XCTAssertEqualWithAccuracy([r.totalDuration doubleValue], 180.0, 1e-9);

    HRTestResult *saved = [[store recentResultsWithLimit:1 error:&e] firstObject];
    XCTAssertEqualObjects(saved.mode, @"lesson");
    XCTAssertEqualObjects(saved.courseFile, @"q.typ");
    XCTAssertEqual([saved.stepIndex integerValue], (NSInteger)4);

    XCTAssertTrue([store resetCourse:@"q.typ" error:&e], @"%@", e);
    XCTAssertNil([store progressForCourse:@"q.typ"]);
    XCTAssertEqual([[store lessonRecordsForCourse:@"q.typ"] count], (NSUInteger)0);
    XCTAssertNotNil([store progressForCourse:@"ru.typ"], @"other courses are untouched");
    XCTAssertEqual([[store recentResultsWithLimit:0 error:&e] count], (NSUInteger)1, @"history stays");
}

/* People already have version-1 stores.  Opening one with the current model
 * must end in a store that works: migrated if the Core Data in use can do
 * that, set aside and replaced if it cannot -- but never an app that cannot
 * save, and never a deleted file. */
- (void)testAVersionOneStoreIsMigratedOrSetAside
{
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSURL *momd = [bundle URLForResource:@"HomeRow" withExtension:@"momd"];
    NSURL *v1URL = [momd URLByAppendingPathComponent:@"HomeRow.mom"];
    NSManagedObjectModel *v1 = [[NSManagedObjectModel alloc] initWithContentsOfURL:v1URL];
    XCTAssertNotNil(v1, @"the version-1 model must stay in the bundle: %@", v1URL);
    XCTAssertNil([[v1 entitiesByName] objectForKey:@"CourseProgress"]);

    NSURL *url = [NSURL fileURLWithPath:[_dir stringByAppendingPathComponent:@"old.sqlite"]];
    NSError *e = nil;
    @autoreleasepool {
        NSPersistentStoreCoordinator *psc = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:v1];
        XCTAssertNotNil([psc addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:url options:nil error:&e], @"%@", e);
#if defined(__APPLE__)
        NSManagedObjectContext *ctx = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
#else
        NSManagedObjectContext *ctx = [[NSManagedObjectContext alloc] init];
#endif
        [ctx setPersistentStoreCoordinator:psc];
        NSManagedObject *old = [NSEntityDescription insertNewObjectForEntityForName:@"TestResult" inManagedObjectContext:ctx];
        [old setValue:[NSDate date] forKey:@"date"];
        [old setValue:@"time" forKey:@"mode"];
        [old setValue:@"time:30:english/words-200" forKey:@"settingsKey"];
        [old setValue:@61.5 forKey:@"wpm"];
        XCTAssertTrue([ctx save:&e], @"%@", e);
    }

    HRResultStore *store = [self storeAtURL:url];
    XCTAssertTrue([store setLessonIndex:1 stepIndex:0 forCourse:@"q.typ" error:&e], @"the new entities must work: %@", e);
    NSArray *results = [store recentResultsWithLimit:0 error:&e];
    if (store.didSetAsideUnreadableStore) {
        NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:_dir error:NULL];
        NSArray *aside = [files filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self CONTAINS 'unreadable'"]];
        XCTAssertGreaterThan([aside count], (NSUInteger)0, @"the old store was to be kept: %@", files);
        NSLog(@"HRCourseTests: this Core Data could not migrate the version-1 store; it was set aside");
    } else {
        XCTAssertEqual([results count], (NSUInteger)1, @"migration keeps the history");
        XCTAssertEqualWithAccuracy([((HRTestResult *)[results firstObject]).wpm doubleValue], 61.5, 1e-9);
    }
}

/* The same from version 2 -- the stores people actually have -- with key
 * stats in it: they must come through, untimed, and new results must be
 * able to carry a time and a uuid beside them. */
- (void)testAVersionTwoStoreIsMigratedWithItsKeyStats
{
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSURL *momd = [bundle URLForResource:@"HomeRow" withExtension:@"momd"];
    NSManagedObjectModel *v2 = [[NSManagedObjectModel alloc] initWithContentsOfURL:[momd URLByAppendingPathComponent:@"HomeRow2.mom"]];
    XCTAssertNotNil(v2, @"the version-2 model must stay in the bundle");
    XCTAssertNil([[[v2 entitiesByName][@"KeyStat"] attributesByName] objectForKey:@"totalTime"]);

    NSURL *url = [NSURL fileURLWithPath:[_dir stringByAppendingPathComponent:@"v2.sqlite"]];
    NSError *e = nil;
    @autoreleasepool {
        NSPersistentStoreCoordinator *psc = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:v2];
        XCTAssertNotNil([psc addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:url options:nil error:&e], @"%@", e);
#if defined(__APPLE__)
        NSManagedObjectContext *ctx = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
#else
        NSManagedObjectContext *ctx = [[NSManagedObjectContext alloc] init];
#endif
        [ctx setPersistentStoreCoordinator:psc];
        NSManagedObject *old = [NSEntityDescription insertNewObjectForEntityForName:@"TestResult" inManagedObjectContext:ctx];
        [old setValue:[NSDate dateWithTimeIntervalSinceNow:-3600.0] forKey:@"date"];
        [old setValue:@"words" forKey:@"mode"];
        [old setValue:@"words:25:english/words-200" forKey:@"settingsKey"];
        [old setValue:@48.0 forKey:@"wpm"];
        NSManagedObject *key = [NSEntityDescription insertNewObjectForEntityForName:@"KeyStat" inManagedObjectContext:ctx];
        [key setValue:@"a" forKey:@"character"];
        [key setValue:@12 forKey:@"hits"];
        [key setValue:@3 forKey:@"misses"];
        [key setValue:old forKey:@"result"];
        XCTAssertTrue([ctx save:&e], @"%@", e);
    }

    HRResultStore *store = [self storeAtURL:url];
    if (store.didSetAsideUnreadableStore) {
        NSLog(@"HRCourseTests: this Core Data could not migrate the version-2 store; it was set aside");
        return;
    }
    XCTAssertEqual([[store recentResultsWithLimit:0 error:&e] count], (NSUInteger)1, @"migration keeps the history");
    NSDictionary *a = [store keyCountsForKind:HRStatKindAll since:nil][@"a"];
    XCTAssertEqualObjects(a[@"hits"], @12);
    XCTAssertEqualObjects(a[@"misses"], @3);
    XCTAssertEqual([a[@"timed"] unsignedIntegerValue], (NSUInteger)0, @"an old result has no times");

    HRTestSummary *s = [self summaryWithWpm:50 correct:40 wrong:0 seconds:10];
    s.keyStats = @{@"a": @{@"hits": @8, @"misses": @0, @"timed": @6, @"time": @1.5}};
    HRTestResult *r = [store recordSummary:s configuration:[HRTestConfiguration defaultConfiguration] date:nil error:&e];
    XCTAssertNotNil(r, @"%@", e);
    XCTAssertEqual([r.uuid length], (NSUInteger)36);
    a = [store keyCountsForKind:HRStatKindAll since:nil][@"a"];
    XCTAssertEqualObjects(a[@"hits"], @20);
    XCTAssertEqual([a[@"timed"] unsignedIntegerValue], (NSUInteger)6);
    XCTAssertEqualWithAccuracy([a[@"time"] doubleValue], 1.5, 1e-9);
}

@end
