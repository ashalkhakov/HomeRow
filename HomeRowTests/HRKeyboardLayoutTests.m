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
#import "HRKeyboardLayout.h"
#import "HRTestSession.h"

@interface HRKeyboardLayoutTests : XCTestCase
@end

@implementation HRKeyboardLayoutTests

- (NSString *)layoutsDirectory
{
    NSString *env = [[[NSProcessInfo processInfo] environment] objectForKey:@"HR_LAYOUTS_DIR"];
    if ([env length] > 0) return env;
    return [[[NSBundle bundleForClass:[self class]] resourcePath] stringByAppendingPathComponent:@"Layouts"];
}

- (HRKeyboardLayout *)layoutNamed:(NSString *)name
{
    NSError *e = nil;
    NSString *path = [[[self layoutsDirectory] stringByAppendingPathComponent:name] stringByAppendingPathExtension:@"plist"];
    HRKeyboardLayout *l = [HRKeyboardLayout layoutWithContentsOfFile:path error:&e];
    XCTAssertNotNil(l, @"%@: %@", name, e);
    return l;
}

- (void)testQwertyPositionsFingersAndShift
{
    HRKeyboardLayout *l = [self layoutNamed:@"qwerty"];
    XCTAssertEqual(l.geometry, HRKeyboardANSI);
    XCTAssertEqual([l numberOfRows], (NSUInteger)4);
    XCTAssertEqual([l numberOfKeysInRow:2], (NSUInteger)11);

    HRKeyPosition *f = [l positionOfCharacter:@"f"];
    XCTAssertEqual(f.row, (NSUInteger)2);
    XCTAssertEqual(f.column, (NSUInteger)3);
    XCTAssertEqual(f.finger, HRFingerLeftIndex);
    XCTAssertFalse([f needsShift]);

    HRKeyPosition *J = [l positionOfCharacter:@"J"];
    XCTAssertEqual(J.finger, HRFingerRightIndex);
    XCTAssertTrue([J needsShift]);
    XCTAssertTrue([J usesLeftShift], @"the other hand holds Shift");
    XCTAssertFalse([[l positionOfCharacter:@"A"] usesLeftShift]);

    XCTAssertEqual([l positionOfCharacter:@"1"].finger, HRFingerLeftLittle);
    XCTAssertEqual([l positionOfCharacter:@"6"].finger, HRFingerRightIndex);
    XCTAssertEqual([l positionOfCharacter:@"b"].finger, HRFingerLeftIndex);
    XCTAssertEqual([l positionOfCharacter:@"?"].finger, HRFingerRightLittle);
    XCTAssertNil([l positionOfCharacter:@"ж"]);
    XCTAssertNil([l positionOfCharacter:@" "]);
}

- (void)testOtherLayoutsPutTheSameFingersOnOtherLetters
{
    /* the home-row index keys carry different letters, same fingers */
    HRKeyPosition *u = [[self layoutNamed:@"dvorak"] positionOfCharacter:@"u"];
    XCTAssertEqual(u.row, (NSUInteger)2);
    XCTAssertEqual(u.column, (NSUInteger)3);
    XCTAssertEqual(u.finger, HRFingerLeftIndex);

    HRKeyPosition *a = [[self layoutNamed:@"russian"] positionOfCharacter:@"а"];   /* а */
    XCTAssertEqual(a.row, (NSUInteger)2);
    XCTAssertEqual(a.column, (NSUInteger)3);
}

- (void)testIsoShiftsTheBottomRow
{
    HRKeyboardLayout *l = [self layoutNamed:@"qwertz"];
    XCTAssertEqual(l.geometry, HRKeyboardISO);
    XCTAssertEqual([l numberOfKeysInRow:3], (NSUInteger)11);
    HRKeyPosition *y = [l positionOfCharacter:@"y"];
    XCTAssertEqual(y.row, (NSUInteger)3);
    XCTAssertEqual(y.column, (NSUInteger)1, @"the extra ISO key is column 0");
    XCTAssertEqual(y.finger, HRFingerLeftLittle);
    XCTAssertEqual([l positionOfCharacter:@"v"].finger, HRFingerLeftIndex);
}

- (void)testEveryBundledLayoutLoads
{
    NSArray *ids = [HRKeyboardLayout identifiersInDirectory:[self layoutsDirectory]];
    XCTAssertGreaterThan([ids count], (NSUInteger)200);
    for (NSString *name in ids) {
        HRKeyboardLayout *l = [self layoutNamed:name];
        XCTAssertEqualObjects(l.identifier, name);
        for (NSUInteger r = 0; r < 4; r++) {
            XCTAssertGreaterThanOrEqual([l numberOfKeysInRow:r], (NSUInteger)10, @"%@ row %lu", name, (unsigned long)r);
        }
    }
}

- (void)testABrokenLayoutIsAnError
{
    NSError *e = nil;
    NSDictionary *oneRow = @{@"identifier": @"x", @"rows": @[@[@"aA"]]};
    XCTAssertNil([HRKeyboardLayout layoutWithDictionary:oneRow error:&e]);
    XCTAssertNotNil(e);
}

- (void)testTheSessionSaysWhatToPressNext
{
    HRTestConfiguration *c = [HRTestConfiguration defaultConfiguration];
    c.mode = HRTestModeCustom;
    HRTestSession *s = [[HRTestSession alloc] initWithConfiguration:c
                                                             source:[[HRFixedTextSource alloc] initWithText:@"ab\ncd"]];
    XCTAssertEqualObjects([s expectedInput], @"a");
    [s insertText:@"a" atTime:0.0];
    XCTAssertEqualObjects([s expectedInput], @"b");
    [s insertText:@"x" atTime:0.1];
    XCTAssertEqualObjects([s expectedInput], @"\b", @"a mistake has to go first");
    [s deleteBackwardAtTime:0.2];
    [s insertText:@"b" atTime:0.3];
    XCTAssertEqualObjects([s expectedInput], @"\n");
    [s insertText:@"\nc" atTime:0.4];
    XCTAssertEqualObjects([s expectedInput], @"d");
    [s insertText:@"d" atTime:0.5];
    XCTAssertNil([s expectedInput]);
}

@end
