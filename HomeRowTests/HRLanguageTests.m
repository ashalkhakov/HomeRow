/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * This library is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2.1 of the License, or (at
 * your option) any later version.  See COPYING.LIB.
 */
#import <XCTest/XCTest.h>
#import "HRLanguage.h"
#import "HRWord.h"

/* Runs over the packs that ship with the app, so a contributed pack that is
 * broken fails CI rather than a user's launch.  The directory comes from
 * HR_LANGUAGES_DIR (set by the makefile / the Xcode scheme) and falls back
 * to the copy inside the test bundle. */
@interface HRLanguageTests : XCTestCase
@end

@implementation HRLanguageTests

- (NSString *)languagesDirectory
{
    NSString *env = [[[NSProcessInfo processInfo] environment] objectForKey:@"HR_LANGUAGES_DIR"];
    if ([env length] > 0) return env;
    return [[[NSBundle bundleForClass:[self class]] resourcePath]
            stringByAppendingPathComponent:@"Languages"];
}

- (void)testEveryBundledPackIsValid
{
    NSArray *problems = nil;
    NSArray *langs = [HRLanguage languagesInDirectory:[self languagesDirectory] problems:&problems];
    XCTAssertEqualObjects(problems, @[]);
    XCTAssertGreaterThan([langs count], (NSUInteger)0, @"no language packs in %@", [self languagesDirectory]);

    for (HRLanguage *l in langs) {
        NSMutableSet *alphabet = [NSMutableSet setWithArray:[HRWord charactersOfString:l.alphabet]];
        for (NSString *name in l.wordListNames) {
            NSError *e = nil;
            NSArray *words = [l wordsNamed:name error:&e];
            XCTAssertNotNil(words, @"%@/%@: %@", l.identifier, name, e);
            XCTAssertEqual([[NSSet setWithArray:words] count], [words count],
                           @"%@/%@ has duplicates", l.identifier, name);
            for (NSString *w in words) {
                for (NSString *ch in [HRWord charactersOfString:[w lowercaseString]]) {
                    XCTAssertTrue([alphabet containsObject:ch] || [ch isEqualToString:@"'"],
                                  @"%@/%@: \"%@\" uses \"%@\", which is not in the alphabet",
                                  l.identifier, name, w, ch);
                }
            }
        }
    }
}

- (void)testEnglishIsThere
{
    NSString *dir = [[self languagesDirectory] stringByAppendingPathComponent:@"en"];
    NSError *e = nil;
    HRLanguage *en = [HRLanguage languageWithDirectory:dir error:&e];
    XCTAssertNotNil(en, @"%@", e);
    XCTAssertEqualObjects(en.defaultLayoutID, @"qwerty-us");
    XCTAssertTrue([en.wordListNames containsObject:@"words-200"]);
    XCTAssertEqual([[en wordsNamed:@"words-200" error:NULL] count], (NSUInteger)200);
}

- (void)testABrokenPackIsReportedNotThrown
{
    NSString *tmp = [NSTemporaryDirectory() stringByAppendingPathComponent:
                     [NSString stringWithFormat:@"hr-packs-%d", (int)[[NSProcessInfo processInfo] processIdentifier]]];
    NSString *bad = [tmp stringByAppendingPathComponent:@"xx"];
    [[NSFileManager defaultManager] createDirectoryAtPath:bad withIntermediateDirectories:YES attributes:nil error:NULL];
    [@{@"identifier": @"xx", @"displayName": @"Broken"} writeToFile:[bad stringByAppendingPathComponent:@"info.plist"] atomically:YES];

    NSArray *problems = nil;
    NSArray *langs = [HRLanguage languagesInDirectory:tmp problems:&problems];
    XCTAssertEqual([langs count], (NSUInteger)0);
    XCTAssertEqual([problems count], (NSUInteger)1);
    [[NSFileManager defaultManager] removeItemAtPath:tmp error:NULL];
}

@end
