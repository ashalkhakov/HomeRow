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
#import "HRPacks.h"
#import "HRLanguage.h"
#import "HRKeyboardLayout.h"
#import "HRTypScript.h"

@interface HRPacksTests : XCTestCase
@end

@implementation HRPacksTests

/* The folder that holds Languages, Layouts and Lessons: the sources under
 * gnustep-make (HR_LANGUAGES_DIR names one of its children), the test
 * bundle's resources under Xcode. */
- (NSString *)resourceDirectory
{
    NSString *env = [[[NSProcessInfo processInfo] environment] objectForKey:@"HR_LANGUAGES_DIR"];
    if ([env length] > 0) return [env stringByDeletingLastPathComponent];
    return [[NSBundle bundleForClass:[self class]] resourcePath];
}

- (void)testThePacksOfTheAppAreFound
{
    HRPacks *packs = [[HRPacks alloc] initWithResourceDirectory:[self resourceDirectory] userDirectory:nil];
    XCTAssertEqualObjects(packs.problems, @[]);
    XCTAssertEqualObjects([packs languageWithIdentifier:@"english"].identifier, @"english");
    XCTAssertNil([packs languageWithIdentifier:@"no-such-language"]);
    XCTAssertTrue([packs.layoutIdentifiers containsObject:@"qwerty"]);
    HRKeyboardLayout *qwerty = [packs layoutNamed:@"qwerty"];
    XCTAssertNotNil(qwerty);
    XCTAssertTrue(qwerty == [packs layoutNamed:@"qwerty"], @"a layout is read once");
    XCTAssertNil([packs layoutNamed:@"no-such-layout"]);
    XCTAssertNil([packs layoutNamed:@""]);

    XCTAssertGreaterThan([packs.courses count], (NSUInteger)40);
    NSDictionary *quick = [packs courseEntryForFile:@"q.typ"];
    XCTAssertEqualObjects(quick[@"layout"], @"qwerty");
    XCTAssertNil([packs courseEntryForFile:@"nothing.typ"]);
    HRTypScript *script = [packs scriptForCourseFile:@"q.typ"];
    XCTAssertGreaterThan([script.lessons count], (NSUInteger)0);
    XCTAssertTrue(script == [packs scriptForCourseFile:@"q.typ"], @"a course is parsed once");
    XCTAssertNil([packs scriptForCourseFile:nil]);
}

- (void)testAPackOfOnesOwnReplacesTheBundledOne
{
    NSString *user = [NSTemporaryDirectory() stringByAppendingPathComponent:
                      [NSString stringWithFormat:@"homerow-packs-%d", (int)[[NSProcessInfo processInfo] processIdentifier]]];
    NSString *pack = [user stringByAppendingPathComponent:@"Languages/english"];
    [[NSFileManager defaultManager] createDirectoryAtPath:pack withIntermediateDirectories:YES attributes:nil error:NULL];
    [@{@"identifier": @"english", @"displayName": @"English, mine", @"alphabet": @"abc"}
        writeToFile:[pack stringByAppendingPathComponent:@"info.plist"] atomically:YES];
    [@"abc\ncab\nbca\n" writeToFile:[pack stringByAppendingPathComponent:@"words-200.txt"] atomically:YES
                           encoding:NSUTF8StringEncoding error:NULL];

    HRPacks *packs = [[HRPacks alloc] initWithResourceDirectory:[self resourceDirectory] userDirectory:user];
    XCTAssertEqualObjects([packs languageWithIdentifier:@"english"].displayName, @"English, mine");
    XCTAssertNotNil([packs languageWithIdentifier:@"german"], @"the rest is still the app's");
    [[NSFileManager defaultManager] removeItemAtPath:user error:NULL];
}

@end
