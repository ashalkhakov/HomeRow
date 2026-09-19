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
#import "HRTypScript.h"
#import "HRTestSession.h"

@interface HRTypScriptTests : XCTestCase
@end

@implementation HRTypScriptTests

- (NSString *)lessonsDirectory
{
    NSString *env = [[[NSProcessInfo processInfo] environment] objectForKey:@"HR_LESSONS_DIR"];
    if ([env length] > 0) return env;
    return [[[NSBundle bundleForClass:[self class]] resourcePath] stringByAppendingPathComponent:@"Lessons"];
}

- (void)testCommandsContinuationsAndLessons
{
    NSString *src =
        @"# a comment\n"
        @"\n"
        @"G:MENU\n"
        @"*:L1\n"
        @"B:   Lesson One   \n"
        @"T:Welcome.\n"
        @" :\n"
        @" :Second paragraph.   \n"
        @"E:3%\n"
        @"I:Home row.\n"
        @"D:asdf jkl;\n"
        @" :fjfj dkdk\n"
        @"s:The quick brown fox.\n"
        @"*:L2\n"
        @"B:Lesson Two\n"
        @"T:Nothing to type here.\n"
        @"*:MENU\n"
        @"M: UP=_EXIT \"Pick one\"\n"
        @" :L1 \"Lesson \\\"1\\\"\"\n"
        @" :L2 \"Lesson 2\"\n"
        @"X:\n";
    NSError *e = nil;
    HRTypScript *s = [HRTypScript scriptWithString:src error:&e];
    XCTAssertNotNil(s, @"%@", e);
    XCTAssertEqualObjects(s.warnings, @[]);
    XCTAssertEqual([s.commands count], (NSUInteger)14);
    XCTAssertNotEqual([s indexOfLabel:@"L2"], (NSUInteger)NSNotFound);
    XCTAssertEqual([s indexOfLabel:@"nope"], (NSUInteger)NSNotFound);

    /* Lesson Two has nothing to type, so it is not a lesson */
    XCTAssertEqual([s.lessons count], (NSUInteger)1);
    HRTypLesson *l = s.lessons[0];
    XCTAssertEqualObjects(l.title, @"Lesson One");
    XCTAssertEqualObjects(l.label, @"L1");
    XCTAssertEqual([l.steps count], (NSUInteger)3);

    HRTypStep *tutorial = l.steps[0], *drill = l.steps[1], *speed = l.steps[2];
    XCTAssertFalse(tutorial.isExercise);
    XCTAssertEqualObjects(tutorial.text, @"Welcome.\n\nSecond paragraph.");
    XCTAssertTrue(drill.isExercise);
    XCTAssertEqual(drill.kind, HRTypDrill);
    XCTAssertFalse(drill.practiceOnly);
    XCTAssertEqualObjects(drill.instruction, @"Home row.");
    XCTAssertEqualObjects(drill.text, @"asdf jkl;\nfjfj dkdk");
    XCTAssertEqualWithAccuracy(drill.maxErrorPercent, 3.0, 1e-9);
    XCTAssertEqual(speed.kind, HRTypSpeedTest);
    XCTAssertTrue(speed.practiceOnly);
    XCTAssertNil(speed.instruction, @"an instruction belongs to one exercise");
    XCTAssertEqualWithAccuracy(speed.maxErrorPercent, -1.0, 1e-9, @"E: without * covers one exercise");

    XCTAssertEqual([s.menus count], (NSUInteger)1);
    HRTypMenu *m = s.menus[0];
    XCTAssertEqualObjects(m.title, @"Pick one");
    XCTAssertEqualObjects(m.upLabel, @"_EXIT");
    XCTAssertEqual([m.items count], (NSUInteger)2);
    XCTAssertEqualObjects(((HRTypMenuItem *)m.items[1]).label, @"L2");
}

- (void)testMalformedLinesAreErrorsAndDanglingLabelsAreWarnings
{
    NSError *e = nil;
    XCTAssertNil([HRTypScript scriptWithString:@"B banner\n" error:&e]);
    XCTAssertEqual([e code], (NSInteger)1);
    XCTAssertNil([HRTypScript scriptWithString:@" :continues nothing\n" error:&e]);
    XCTAssertNil([HRTypScript scriptWithString:@"B:ok\nZ:what\n" error:&e]);
    XCTAssertEqual([e code], (NSInteger)2);

    HRTypScript *s = [HRTypScript scriptWithString:@"*:A\n*:A\nG:B\nD:x\n" error:&e];
    XCTAssertNotNil(s);
    XCTAssertEqual([s.warnings count], (NSUInteger)2);
}

/* A drill is typed line by line with Return between the lines -- which is
 * exactly what the session does with a fixed text. */
- (void)testADrillRunsAsAFixedText
{
    HRTypScript *s = [HRTypScript scriptWithString:@"D:ab cd\n :ef\n" error:NULL];
    HRTypStep *drill = ((HRTypLesson *)s.lessons[0]).steps[0];
    HRTestConfiguration *c = [HRTestConfiguration defaultConfiguration];
    c.mode = HRTestModeCustom;
    HRTestSession *session = [[HRTestSession alloc] initWithConfiguration:c
                                                                   source:[[HRFixedTextSource alloc] initWithText:drill.text]];
    [session insertText:@"ab cd\nef" atTime:0.0];
    XCTAssertEqual(session.state, HRSessionFinished);
    XCTAssertEqualWithAccuracy([session summary].accuracy, 100.0, 1e-9);
}

/* Every course that ships: parses, resolves its labels, and has something
 * to type.  A contributed or updated .typ that is broken fails here. */
- (void)testEveryBundledCourseIsSound
{
    NSString *dir = [[self lessonsDirectory] stringByAppendingPathComponent:@"gtypist"];
    NSArray *files = [[[NSFileManager defaultManager] contentsOfDirectoryAtPath:dir error:NULL]
                      filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self ENDSWITH '.typ'"]];
    XCTAssertGreaterThan([files count], (NSUInteger)40, @"no courses in %@", dir);

    NSDictionary *index = [NSDictionary dictionaryWithContentsOfFile:[dir stringByAppendingPathComponent:@"index.plist"]];
    NSArray *courses = index[@"courses"];
    XCTAssertEqual([courses count], [files count], @"index.plist and the folder disagree");

    NSUInteger exercises = 0;
    for (NSDictionary *course in courses) {
        NSString *file = course[@"file"];
        XCTAssertTrue([files containsObject:file], @"%@ is indexed but missing", file);
        XCTAssertTrue([course[@"title"] length] > 0 && [course[@"language"] length] > 0 && [course[@"layout"] length] > 0,
                      @"%@: title, language and layout are required", file);
        NSError *e = nil;
        HRTypScript *s = [HRTypScript scriptWithContentsOfFile:[dir stringByAppendingPathComponent:file] error:&e];
        XCTAssertNotNil(s, @"%@: %@", file, e);
        /* The files are upstream's, unmodified; a few carry gotos to labels
         * that do not exist (gtypist only minds when it gets there).  The
         * index says how many, so that a new one is still noticed. */
        XCTAssertEqual([s.warnings count], [course[@"upstreamWarnings"] unsignedIntegerValue],
                       @"%@: %@", file, [s.warnings valueForKey:@"localizedDescription"]);
        XCTAssertGreaterThan([s.lessons count], (NSUInteger)0, @"%@ has nothing to type", file);
        for (HRTypLesson *l in s.lessons) exercises += [l exerciseCount];
    }
    XCTAssertGreaterThan(exercises, (NSUInteger)5000);
}

@end
