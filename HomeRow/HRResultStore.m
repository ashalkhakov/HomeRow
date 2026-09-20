/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * HomeRow is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version.  It comes with ABSOLUTELY NO WARRANTY.  See COPYING.
 */
#import "HRResultStore.h"
#import "HRTestSummary.h"
#import "HRTestConfiguration.h"
#import "HRCourseRun.h"

@implementation HRResultStore

+ (NSURL *)defaultStoreURL
{
    NSArray *dirs = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *base = [dirs count] > 0 ? dirs[0] : NSTemporaryDirectory();
    NSString *dir = [base stringByAppendingPathComponent:@"HomeRow"];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:NULL];
    return [NSURL fileURLWithPath:[dir stringByAppendingPathComponent:@"HomeRow.sqlite"]];
}

- (instancetype)initWithStoreURL:(NSURL *)storeURL bundle:(NSBundle *)bundle error:(NSError **)error
{
    if (!(self = [super init])) return nil;

    if (!bundle) bundle = [NSBundle bundleForClass:[self class]];
    NSURL *modelURL = [bundle URLForResource:@"HomeRow" withExtension:@"momd"];
    NSManagedObjectModel *model = modelURL ? [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL] : nil;
    if (!model) {
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadNoSuchFileError
                                     userInfo:@{NSLocalizedDescriptionKey: @"HomeRow.momd was not found in the bundle"}];
        }
        return nil;
    }

    NSPersistentStoreCoordinator *psc = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
    NSString *type = storeURL ? NSSQLiteStoreType : NSInMemoryStoreType;
    /* so that a new model version does not orphan everyone's history */
    NSDictionary *options = @{NSMigratePersistentStoresAutomaticallyOption: @YES,
                              NSInferMappingModelAutomaticallyOption: @YES};
    NSError *openError = nil;
    if (![psc addPersistentStoreWithType:type configuration:nil URL:storeURL options:options error:&openError]) {
        /* A store that cannot be opened or migrated must not mean an app
         * that cannot save: set it aside -- never delete it -- and start a
         * new one.  The file stays beside the new store for whoever wants
         * to rescue it. */
        BOOL recovered = NO;
        /* Automatic migration looks for the old model in the MAIN bundle
         * only (Apple's Core Data and FreeCoreData alike), which is the
         * wrong place under a test runner.  Do by hand what it would have
         * done, with the bundle we were given. */
        if (storeURL && [self migrateStoreAtURL:storeURL toModel:model modelDirectory:modelURL]) {
            psc = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
            recovered = [psc addPersistentStoreWithType:type configuration:nil URL:storeURL
                                                 options:options error:&openError] != nil;
        }
        if (!recovered && storeURL && [[NSFileManager defaultManager] fileExistsAtPath:[storeURL path]]) {
            NSString *aside = [NSString stringWithFormat:@"%@.unreadable-%ld", [storeURL path],
                               (long)[[NSDate date] timeIntervalSince1970]];
            NSLog(@"HomeRow: the store could not be opened (%@); moving it to %@", openError, aside);
            if ([[NSFileManager defaultManager] moveItemAtPath:[storeURL path] toPath:aside error:NULL]) {
                for (NSString *suffix in @[@"-wal", @"-shm"]) {
                    [[NSFileManager defaultManager] moveItemAtPath:[[storeURL path] stringByAppendingString:suffix]
                                                            toPath:[aside stringByAppendingString:suffix]
                                                             error:NULL];
                }
                psc = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
                recovered = [psc addPersistentStoreWithType:type configuration:nil URL:storeURL
                                                     options:options error:&openError] != nil;
                _didSetAsideUnreadableStore = recovered;
            }
        }
        if (!recovered) {
            if (error) *error = openError;
            return nil;
        }
    }
    /* The app only touches the store from the main thread.  Plain -init
     * (confinement) is what FreeCoreData offers; with Apple's CoreData it is
     * deprecated, and main-queue concurrency is the same thing said in the
     * modern way. */
#if defined(__APPLE__)
    _context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
#else
    _context = [[NSManagedObjectContext alloc] init];
#endif
    [_context setPersistentStoreCoordinator:psc];
    return self;
}

/* Lightweight migration, spelled out: find the model version the store was
 * written with among the .mom files of HomeRow.momd, infer the mapping,
 * migrate into a new file, and swap the files.  The old store is renamed,
 * not deleted.  NO means "could not", for any reason; the caller has a
 * fallback. */
- (BOOL)migrateStoreAtURL:(NSURL *)storeURL toModel:(NSManagedObjectModel *)model modelDirectory:(NSURL *)momd
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *path = [storeURL path];
    if (![fm fileExistsAtPath:path]) return NO;
    @try {
#if defined(__APPLE__)
        NSDictionary *metadata = [NSPersistentStoreCoordinator metadataForPersistentStoreOfType:NSSQLiteStoreType
                                                                                            URL:storeURL options:nil error:NULL];
        /* one file, no -wal/-shm beside it: the swap below is then a rename */
        NSDictionary *destinationOptions = @{NSSQLitePragmasOption: @{@"journal_mode": @"DELETE"}};
#else
        NSDictionary *metadata = [NSPersistentStoreCoordinator metadataForPersistentStoreOfType:NSSQLiteStoreType
                                                                                            URL:storeURL error:NULL];
        NSDictionary *destinationOptions = nil;
#endif
        if (!metadata || [model isConfiguration:nil compatibleWithStoreMetadata:metadata]) return NO;

        NSManagedObjectModel *source = nil;
        for (NSString *file in [fm contentsOfDirectoryAtPath:[momd path] error:NULL]) {
            if (![[file pathExtension] isEqualToString:@"mom"]) continue;
            NSURL *url = [NSURL fileURLWithPath:[[momd path] stringByAppendingPathComponent:file]];
            NSManagedObjectModel *candidate = [[NSManagedObjectModel alloc] initWithContentsOfURL:url];
            if (candidate && [candidate isConfiguration:nil compatibleWithStoreMetadata:metadata]) {
                source = candidate;
                break;
            }
        }
        if (!source) return NO;

        NSError *error = nil;
        NSMappingModel *mapping = [NSMappingModel inferredMappingModelForSourceModel:source
                                                                    destinationModel:model error:&error];
        if (!mapping) {
            NSLog(@"HomeRow: no mapping model could be inferred: %@", error);
            return NO;
        }
        NSString *stamp = [NSString stringWithFormat:@"%ld", (long)[[NSDate date] timeIntervalSince1970]];
        NSString *migrated = [path stringByAppendingFormat:@".migrating-%@", stamp];
        NSMigrationManager *manager = [[NSMigrationManager alloc] initWithSourceModel:source destinationModel:model];
        if (![manager migrateStoreFromURL:storeURL type:NSSQLiteStoreType options:nil withMappingModel:mapping
                         toDestinationURL:[NSURL fileURLWithPath:migrated] destinationType:NSSQLiteStoreType
                       destinationOptions:destinationOptions error:&error]) {
            NSLog(@"HomeRow: migrating the store failed: %@", error);
            for (NSString *suffix in @[@"", @"-wal", @"-shm"]) {
                [fm removeItemAtPath:[migrated stringByAppendingString:suffix] error:NULL];
            }
            return NO;
        }
        NSString *backup = [path stringByAppendingFormat:@".before-migration-%@", stamp];
        if (![fm moveItemAtPath:path toPath:backup error:NULL]) return NO;
        /* the old store's sidecars go with it; the new store has none */
        for (NSString *suffix in @[@"-wal", @"-shm"]) {
            [fm moveItemAtPath:[path stringByAppendingString:suffix] toPath:[backup stringByAppendingString:suffix] error:NULL];
        }
        if (![fm moveItemAtPath:migrated toPath:path error:NULL]) {
            for (NSString *suffix in @[@"", @"-wal", @"-shm"]) {
                [fm moveItemAtPath:[backup stringByAppendingString:suffix] toPath:[path stringByAppendingString:suffix] error:NULL];
            }
            return NO;
        }
        NSLog(@"HomeRow: the store was migrated to the current model; the old one is %@", [backup lastPathComponent]);
        return YES;
    } @catch (NSException *exception) {
        NSLog(@"HomeRow: migrating the store raised %@", exception);
        return NO;
    }
}

- (HRTestResult *)recordSummary:(HRTestSummary *)s
                  configuration:(HRTestConfiguration *)c
                           date:(NSDate *)date
                          error:(NSError **)error
{
    return [self recordSummary:s configuration:c courseFile:nil lessonIndex:0 stepIndex:0 date:date error:error];
}

- (HRTestResult *)recordSummary:(HRTestSummary *)s
                  configuration:(HRTestConfiguration *)c
                     courseFile:(NSString *)courseFile
                    lessonIndex:(NSUInteger)lessonIndex
                      stepIndex:(NSUInteger)stepIndex
                           date:(NSDate *)date
                          error:(NSError **)error
{
    HRTestResult *r = [NSEntityDescription insertNewObjectForEntityForName:@"TestResult"
                                                   inManagedObjectContext:_context];
    r.date = date ?: [NSDate date];
    r.uuid = [[NSUUID UUID] UUIDString];
    r.mode = [c modeName];
    r.amount = @(c.amount);
    r.settingsKey = [c settingsKey];
    r.languageID = c.languageID;
    r.layoutID = c.layoutID;
    if (courseFile) {
        r.courseFile = courseFile;
        r.lessonIndex = @(lessonIndex);
        r.stepIndex = @(stepIndex);
    }
    r.wpm = @(s.wpm);
    r.rawWpm = @(s.rawWpm);
    r.accuracy = @(s.accuracy);
    r.consistency = @(s.consistency);
    r.duration = @(s.duration);
    r.correctCharacters = @(s.correctCharacters);
    r.incorrectCharacters = @(s.incorrectCharacters);
    r.extraCharacters = @(s.extraCharacters);
    r.missedCharacters = @(s.missedCharacters);

    /* the blob takes what has no column of its own: no migration for a number */
    NSDictionary *series = @{@"raw": s.rawWpmPerSecond ?: @[], @"errors": s.errorsPerSecond ?: @[],
                             @"overhead": @([s keystrokeOverhead]), @"deletions": @(s.deletions),
                             @"keystrokes": @(s.correctKeystrokes + s.incorrectKeystrokes + s.deletions)};
    r.series = [NSPropertyListSerialization dataWithPropertyList:series
                                                          format:NSPropertyListBinaryFormat_v1_0
                                                         options:0
                                                           error:NULL];

    for (NSString *ch in s.keyStats) {
        NSDictionary *counts = s.keyStats[ch];
        HRKeyStat *k = [NSEntityDescription insertNewObjectForEntityForName:@"KeyStat"
                                                    inManagedObjectContext:_context];
        k.character = ch;
        k.hits = counts[@"hits"] ?: @0;
        k.misses = counts[@"misses"] ?: @0;
        k.timedHits = counts[@"timed"] ?: @0;
        k.totalTime = counts[@"time"] ?: @0.0;
        k.result = r;
    }

    if (![_context save:error]) {
        [_context rollback];
        return nil;
    }
    return r;
}

- (HRStatSample *)sampleForResult:(HRTestResult *)r
{
    HRStatSample *s = [[HRStatSample alloc] init];
    s.date = r.date;
    s.mode = r.mode;
    s.wpm = [r.wpm doubleValue];
    s.rawWpm = [r.rawWpm doubleValue];
    s.accuracy = [r.accuracy doubleValue];
    s.duration = [r.duration doubleValue];
    NSNumber *overhead = [r seriesDictionary][@"overhead"];
    if ([overhead isKindOfClass:[NSNumber class]]) s.overhead = [overhead doubleValue];
    return s;
}

- (NSArray *)statSamples
{
    NSMutableArray *out = [NSMutableArray array];
    for (HRTestResult *r in [self recentResultsWithLimit:0 error:NULL]) [out addObject:[self sampleForResult:r]];
    return out;
}

- (NSDictionary *)keyCountsForKind:(HRStatKind)kind since:(NSDate *)since
{
    NSMutableDictionary *hits = [NSMutableDictionary dictionary], *misses = [NSMutableDictionary dictionary];
    NSMutableDictionary *timed = [NSMutableDictionary dictionary], *time = [NSMutableDictionary dictionary];
    for (HRTestResult *r in [self recentResultsWithLimit:0 error:NULL]) {
        if (since && r.date && [r.date compare:since] == NSOrderedAscending) continue;
        if (kind != HRStatKindAll && [[self sampleForResult:r] kind] != kind) continue;
        for (HRKeyStat *k in r.keyStats) {
            if ([k.character length] == 0) continue;
            hits[k.character] = @([hits[k.character] unsignedIntegerValue] + [k.hits unsignedIntegerValue]);
            misses[k.character] = @([misses[k.character] unsignedIntegerValue] + [k.misses unsignedIntegerValue]);
            timed[k.character] = @([timed[k.character] unsignedIntegerValue] + [k.timedHits unsignedIntegerValue]);
            time[k.character] = @([time[k.character] doubleValue] + [k.totalTime doubleValue]);
        }
    }
    NSMutableDictionary *out = [NSMutableDictionary dictionary];
    for (NSString *ch in hits) {
        out[ch] = @{@"hits": hits[ch], @"misses": misses[ch] ?: @0, @"timed": timed[ch] ?: @0, @"time": time[ch] ?: @0.0};
    }
    return out;
}

- (NSArray *)recentResultsWithLimit:(NSUInteger)limit error:(NSError **)error
{
    NSFetchRequest *req = [[NSFetchRequest alloc] init];
    [req setEntity:[NSEntityDescription entityForName:@"TestResult" inManagedObjectContext:_context]];
    [req setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"date" ascending:NO]]];
    if (limit > 0) [req setFetchLimit:limit];
    return [_context executeFetchRequest:req error:error];
}

- (HRTestResult *)personalBestForSettingsKey:(NSString *)settingsKey error:(NSError **)error
{
    NSFetchRequest *req = [[NSFetchRequest alloc] init];
    [req setEntity:[NSEntityDescription entityForName:@"TestResult" inManagedObjectContext:_context]];
    [req setPredicate:[NSPredicate predicateWithFormat:@"settingsKey == %@", settingsKey]];
    [req setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"wpm" ascending:NO]]];
    [req setFetchLimit:1];
    return [[_context executeFetchRequest:req error:error] firstObject];
}

#pragma mark - History

- (NSArray *)personalBests
{
    NSMutableDictionary *best = [NSMutableDictionary dictionary];
    for (HRTestResult *r in [self recentResultsWithLimit:0 error:NULL]) {
        if (![r.mode isEqualToString:@"time"] && ![r.mode isEqualToString:@"words"]) continue;
        if ([r.settingsKey length] == 0) continue;
        HRTestResult *have = best[r.settingsKey];
        if (!have || [r.wpm doubleValue] > [have.wpm doubleValue]) best[r.settingsKey] = r;
    }
    return [[best allValues] sortedArrayUsingComparator:^NSComparisonResult(HRTestResult *a, HRTestResult *b) {
        return [b.wpm compare:a.wpm];
    }];
}

- (BOOL)deleteResult:(HRTestResult *)result error:(NSError **)error
{
    if (!result) return NO;
    /* the key stats first, by hand: not every Core Data cascades a delete the same way */
    for (HRKeyStat *k in [result.keyStats allObjects]) [_context deleteObject:k];
    [_context deleteObject:result];
    return [self save:error];
}

- (NSArray *)exportRecords
{
    NSMutableSet *bestIDs = [NSMutableSet set];
    for (HRTestResult *b in [self personalBests]) [bestIDs addObject:[b objectID]];
    NSMutableArray *out = [NSMutableArray array];
    BOOL named = NO;
    for (HRTestResult *r in [[self recentResultsWithLimit:0 error:NULL] reverseObjectEnumerator]) {
        if (!r.date || [r.mode length] == 0) continue;
        if ([r.uuid length] == 0) { r.uuid = [[NSUUID UUID] UUIDString]; named = YES; }
        NSMutableDictionary *d = [NSMutableDictionary dictionary];
        d[@"uuid"] = r.uuid;
        d[@"date"] = r.date;
        d[@"mode"] = r.mode;
        NSDictionary *plain = @{@"amount": r.amount ?: [NSNull null], @"settingsKey": r.settingsKey ?: [NSNull null],
            @"languageID": r.languageID ?: [NSNull null], @"layoutID": r.layoutID ?: [NSNull null],
            @"wpm": r.wpm ?: @0, @"rawWpm": r.rawWpm ?: [NSNull null], @"accuracy": r.accuracy ?: [NSNull null],
            @"consistency": r.consistency ?: [NSNull null], @"duration": r.duration ?: [NSNull null],
            @"correctCharacters": r.correctCharacters ?: [NSNull null], @"incorrectCharacters": r.incorrectCharacters ?: [NSNull null],
            @"extraCharacters": r.extraCharacters ?: [NSNull null], @"missedCharacters": r.missedCharacters ?: [NSNull null],
            @"courseFile": r.courseFile ?: [NSNull null]};
        for (NSString *key in plain) if (plain[key] != [NSNull null]) d[key] = plain[key];
        if (r.courseFile) {
            d[@"lessonIndex"] = r.lessonIndex ?: @0;
            d[@"stepIndex"] = r.stepIndex ?: @0;
        }
        NSArray *flags = [r.settingsKey componentsSeparatedByString:@":"];
        d[@"punctuation"] = @([flags containsObject:@"p"]);
        d[@"numbers"] = @([flags containsObject:@"n"]);
        d[@"isBest"] = @([bestIDs containsObject:[r objectID]]);
        NSMutableDictionary *keys = [NSMutableDictionary dictionary];
        for (HRKeyStat *k in r.keyStats) {
            if ([k.character length] == 0) continue;
            keys[k.character] = @{@"hits": k.hits ?: @0, @"misses": k.misses ?: @0,
                                  @"timed": k.timedHits ?: @0, @"time": k.totalTime ?: @0.0};
        }
        if ([keys count] > 0) d[@"keys"] = keys;
        NSDictionary *series = [r seriesDictionary];
        if ([series count] > 0) d[@"series"] = series;
        [out addObject:d];
    }
    if (named) [self save:NULL];
    return out;
}

- (NSString *)fingerprintOfDate:(NSDate *)date mode:(NSString *)mode wpm:(NSNumber *)wpm
{
    return [NSString stringWithFormat:@"%lld|%@|%.2f", (long long)llround([date timeIntervalSince1970]), mode, [wpm doubleValue]];
}

- (NSUInteger)importRecords:(NSArray *)records duplicates:(NSUInteger *)duplicates error:(NSError **)error
{
    NSMutableSet *uuids = [NSMutableSet set], *prints = [NSMutableSet set];
    for (HRTestResult *r in [self recentResultsWithLimit:0 error:NULL]) {
        if ([r.uuid length] > 0) [uuids addObject:r.uuid];
        if (r.date) [prints addObject:[self fingerprintOfDate:r.date mode:r.mode wpm:r.wpm]];
    }
    NSUInteger added = 0, twice = 0;
    for (NSDictionary *d in records) {
        NSDate *date = d[@"date"];
        NSString *mode = d[@"mode"];
        if (![date isKindOfClass:[NSDate class]] || [mode length] == 0 || !d[@"wpm"]) continue;
        NSString *print = [self fingerprintOfDate:date mode:mode wpm:d[@"wpm"]];
        NSString *uuid = d[@"uuid"];
        if (([uuid length] > 0 && [uuids containsObject:uuid]) || [prints containsObject:print]) { twice++; continue; }

        HRTestResult *r = [NSEntityDescription insertNewObjectForEntityForName:@"TestResult" inManagedObjectContext:_context];
        r.uuid = [uuid length] > 0 ? uuid : [[NSUUID UUID] UUIDString];
        r.date = date;
        r.mode = mode;
        r.amount = d[@"amount"] ?: @0;
        r.languageID = d[@"languageID"];
        r.layoutID = d[@"layoutID"];
        NSString *key = d[@"settingsKey"];
        if ([key length] == 0) {
            /* a file from elsewhere: make the key HomeRow would have made, as far
             * as it can be known, so that bests compare like with like */
            NSMutableString *made = [NSMutableString stringWithString:mode];
            if ([mode isEqualToString:@"time"] || [mode isEqualToString:@"words"]) {
                [made appendFormat:@":%ld:%@/imported", (long)[d[@"amount"] integerValue], d[@"languageID"] ?: @"unknown"];
                if ([d[@"punctuation"] boolValue]) [made appendString:@":p"];
                if ([d[@"numbers"] boolValue]) [made appendString:@":n"];
            }
            key = made;
        }
        r.settingsKey = key;
        r.wpm = d[@"wpm"];
        r.rawWpm = d[@"rawWpm"] ?: d[@"wpm"];
        r.accuracy = d[@"accuracy"] ?: @0;
        r.consistency = d[@"consistency"] ?: @0;
        r.duration = d[@"duration"] ?: @0;
        r.correctCharacters = d[@"correctCharacters"] ?: @0;
        r.incorrectCharacters = d[@"incorrectCharacters"] ?: @0;
        r.extraCharacters = d[@"extraCharacters"] ?: @0;
        r.missedCharacters = d[@"missedCharacters"] ?: @0;
        if ([d[@"courseFile"] length] > 0) {
            r.courseFile = d[@"courseFile"];
            r.lessonIndex = d[@"lessonIndex"] ?: @0;
            r.stepIndex = d[@"stepIndex"] ?: @0;
        }
        if ([d[@"series"] isKindOfClass:[NSDictionary class]]) {
            r.series = [NSPropertyListSerialization dataWithPropertyList:d[@"series"] format:NSPropertyListBinaryFormat_v1_0
                                                                 options:0 error:NULL];
        }
        NSDictionary *keys = d[@"keys"];
        for (NSString *ch in keys) {
            HRKeyStat *k = [NSEntityDescription insertNewObjectForEntityForName:@"KeyStat" inManagedObjectContext:_context];
            k.character = ch;
            k.hits = keys[ch][@"hits"] ?: @0;
            k.misses = keys[ch][@"misses"] ?: @0;
            k.timedHits = keys[ch][@"timed"] ?: @0;
            k.totalTime = keys[ch][@"time"] ?: @0.0;
            k.result = r;
        }
        [uuids addObject:r.uuid];
        [prints addObject:print];
        added++;
    }
    if (duplicates) *duplicates = twice;
    if (added > 0 && ![self save:error]) {
        [_context rollback];
        return 0;
    }
    return added;
}

#pragma mark - Courses

- (NSArray *)fetch:(NSString *)entity where:(NSPredicate *)predicate
{
    NSFetchRequest *req = [[NSFetchRequest alloc] init];
    [req setEntity:[NSEntityDescription entityForName:entity inManagedObjectContext:_context]];
    [req setPredicate:predicate];
    return [_context executeFetchRequest:req error:NULL] ?: @[];
}

- (BOOL)save:(NSError **)error
{
    if ([_context save:error]) return YES;
    [_context rollback];
    return NO;
}

- (NSArray *)startedCourses
{
    NSArray *all = [self fetch:@"CourseProgress" where:nil];
    /* sorted here rather than by the fetch: a nil lastDate must sort last,
     * and the two Core Datas need not agree on where nil goes */
    return [all sortedArrayUsingComparator:^NSComparisonResult(HRCourseProgress *a, HRCourseProgress *b) {
        NSDate *da = a.lastDate ?: [NSDate distantPast], *db = b.lastDate ?: [NSDate distantPast];
        return [db compare:da];
    }];
}

- (HRCourseProgress *)progressForCourse:(NSString *)courseFile
{
    return [[self fetch:@"CourseProgress"
                  where:[NSPredicate predicateWithFormat:@"courseFile == %@", courseFile]] firstObject];
}

- (BOOL)setLessonIndex:(NSUInteger)lessonIndex stepIndex:(NSUInteger)stepIndex
             forCourse:(NSString *)courseFile error:(NSError **)error
{
    HRCourseProgress *p = [self progressForCourse:courseFile];
    if (!p) {
        p = [NSEntityDescription insertNewObjectForEntityForName:@"CourseProgress" inManagedObjectContext:_context];
        p.courseFile = courseFile;
        p.startedDate = [NSDate date];
    }
    p.lessonIndex = @(lessonIndex);
    p.stepIndex = @(stepIndex);
    p.lastDate = [NSDate date];
    return [self save:error];
}

- (NSDictionary *)lessonRecordsForCourse:(NSString *)courseFile
{
    NSMutableDictionary *byIndex = [NSMutableDictionary dictionary];
    for (HRLessonRecord *r in [self fetch:@"LessonRecord"
                                    where:[NSPredicate predicateWithFormat:@"courseFile == %@", courseFile]]) {
        if (r.lessonIndex) byIndex[r.lessonIndex] = r;
    }
    return byIndex;
}

- (HRLessonRecord *)recordForLesson:(NSUInteger)lessonIndex inCourse:(NSString *)courseFile
{
    HRLessonRecord *r = [self lessonRecordsForCourse:courseFile][@(lessonIndex)];
    if (!r) {
        r = [NSEntityDescription insertNewObjectForEntityForName:@"LessonRecord" inManagedObjectContext:_context];
        r.courseFile = courseFile;
        r.lessonIndex = @(lessonIndex);
    }
    return r;
}

- (BOOL)noteLessonStarted:(NSUInteger)lessonIndex title:(NSString *)title
                 inCourse:(NSString *)courseFile error:(NSError **)error
{
    HRLessonRecord *r = [self recordForLesson:lessonIndex inCourse:courseFile];
    r.title = title;
    r.attempts = @([r.attempts integerValue] + 1);
    r.lastDate = [NSDate date];
    return [self save:error];
}

- (NSArray *)earlierExercisesOfLesson:(NSUInteger)lessonIndex inCourse:(NSString *)courseFile
                           beforeStep:(NSUInteger)step
{
    HRLessonRecord *record = [self lessonRecordsForCourse:courseFile][@(lessonIndex)];
    if (!record.lastDate || step == 0) return @[];
    NSArray *results = [self fetch:@"TestResult"
                             where:[NSPredicate predicateWithFormat:@"courseFile == %@ AND lessonIndex == %@",
                                    courseFile, @(lessonIndex)]];
    results = [results sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"date" ascending:YES]]];
    NSMutableArray *out = [NSMutableArray array];
    for (HRTestResult *r in results) {
        if (!r.date || [r.date compare:record.lastDate] == NSOrderedAscending) continue;
        if ([r.stepIndex unsignedIntegerValue] >= step) continue;
        NSUInteger keys = [r.correctCharacters unsignedIntegerValue] + [r.incorrectCharacters unsignedIntegerValue]
                        + [r.extraCharacters unsignedIntegerValue];
        [out addObject:@{@"step": r.stepIndex ?: @0, @"wpm": r.wpm ?: @0, @"accuracy": r.accuracy ?: @100,
                         @"duration": r.duration ?: @0, @"keystrokes": @(keys)}];
    }
    return out;
}

- (BOOL)noteLessonCompleted:(NSUInteger)lessonIndex summary:(HRLessonSummary *)summary
              countsForBest:(BOOL)countsForBest inCourse:(NSString *)courseFile error:(NSError **)error
{
    HRLessonRecord *r = [self recordForLesson:lessonIndex inCourse:courseFile];
    r.completions = @([r.completions integerValue] + 1);
    r.lastWpm = @(summary.wpm);
    r.lastAccuracy = @(summary.accuracy);
    BOOL first = [r.completions integerValue] == 1;
    if (countsForBest || first) {
        if (summary.wpm > [r.bestWpm doubleValue]) r.bestWpm = @(summary.wpm);
        if (summary.accuracy > [r.bestAccuracy doubleValue]) r.bestAccuracy = @(summary.accuracy);
    }
    r.totalDuration = @([r.totalDuration doubleValue] + summary.duration);
    r.lastDate = [NSDate date];
    return [self save:error];
}

- (BOOL)resetCourse:(NSString *)courseFile error:(NSError **)error
{
    NSPredicate *mine = [NSPredicate predicateWithFormat:@"courseFile == %@", courseFile];
    for (NSString *entity in @[@"CourseProgress", @"LessonRecord"]) {
        for (NSManagedObject *o in [self fetch:entity where:mine]) [_context deleteObject:o];
    }
    return [self save:error];
}

@end
