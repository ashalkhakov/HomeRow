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

@class HRTestSummary;
@class HRTestConfiguration;

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

/* Newest first; limit 0 = all. */
- (NSArray *)recentResultsWithLimit:(NSUInteger)limit error:(NSError **)error;

/* Highest WPM recorded for these settings, or nil. */
- (HRTestResult *)personalBestForSettingsKey:(NSString *)settingsKey error:(NSError **)error;

@end
