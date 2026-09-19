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
    /* so that adding an attribute later does not orphan everyone's history */
    NSDictionary *options = @{NSMigratePersistentStoresAutomaticallyOption: @YES,
                              NSInferMappingModelAutomaticallyOption: @YES};
    if (![psc addPersistentStoreWithType:type configuration:nil URL:storeURL options:options error:error]) {
        return nil;
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

- (HRTestResult *)recordSummary:(HRTestSummary *)s
                  configuration:(HRTestConfiguration *)c
                           date:(NSDate *)date
                          error:(NSError **)error
{
    HRTestResult *r = [NSEntityDescription insertNewObjectForEntityForName:@"TestResult"
                                                   inManagedObjectContext:_context];
    r.date = date ?: [NSDate date];
    r.mode = [c modeName];
    r.amount = @(c.amount);
    r.settingsKey = [c settingsKey];
    r.languageID = c.languageID;
    r.layoutID = c.layoutID;
    r.wpm = @(s.wpm);
    r.rawWpm = @(s.rawWpm);
    r.accuracy = @(s.accuracy);
    r.consistency = @(s.consistency);
    r.duration = @(s.duration);
    r.correctCharacters = @(s.correctCharacters);
    r.incorrectCharacters = @(s.incorrectCharacters);
    r.extraCharacters = @(s.extraCharacters);
    r.missedCharacters = @(s.missedCharacters);

    NSDictionary *series = @{@"raw": s.rawWpmPerSecond ?: @[], @"errors": s.errorsPerSecond ?: @[]};
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
        k.result = r;
    }

    if (![_context save:error]) {
        [_context rollback];
        return nil;
    }
    return r;
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

@end
