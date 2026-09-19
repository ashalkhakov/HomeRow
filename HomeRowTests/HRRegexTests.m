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
#import "HRRegex.h"

@interface HRRegexTests : XCTestCase
@end

@implementation HRRegexTests

- (void)testMatchesAndCaptureGroupsInUTF16Units
{
    NSError *e = nil;
    HRRegex *r = [HRRegex regexWithPattern:@"(\\w+)\\s*=\\s*(\\d+)?" error:&e];
    XCTAssertNotNil(r, @"%@", e);
    /* a non-BMP character first: offsets must count UTF-16 units */
    NSString *s = @"\U0001F600 café = 42;";
    HRRegexMatch *m = [r firstMatchInString:s fromIndex:0];
    XCTAssertEqualObjects([s substringWithRange:[m range]], @"café = 42");
    XCTAssertEqual([m rangeAtIndex:1].location, (NSUInteger)3);
    XCTAssertEqualObjects([s substringWithRange:[m rangeAtIndex:2]], @"42");

    m = [r firstMatchInString:@"x =" fromIndex:0];
    XCTAssertEqual([m numberOfRanges], (NSUInteger)3);
    XCTAssertEqual([m rangeAtIndex:2].location, (NSUInteger)NSNotFound, @"a group that took no part");
    XCTAssertNil([r firstMatchInString:@"nothing here" fromIndex:0]);
}

/* The things ICU does differently, which is why Oniguruma is here. */
- (void)testOnigurumaDialect
{
    /* \h is a hex digit, not horizontal white space */
    HRRegex *hex = [HRRegex regexWithPattern:@"\\h+" error:NULL];
    NSString *s = @"  ff00zz";
    XCTAssertEqualObjects([s substringWithRange:[[hex firstMatchInString:s fromIndex:0] range]], @"ff00");

    /* look-behind sees the text before the start index */
    HRRegex *behind = [HRRegex regexWithPattern:@"(?<=a)b" error:NULL];
    XCTAssertEqual([[behind firstMatchInString:@"ab" fromIndex:1] range].location, (NSUInteger)1);

    /* named and numbered groups side by side, \k back-reference */
    HRRegex *named = [HRRegex regexWithPattern:@"(?<q>['\"])(.*?)\\k<q>" error:NULL];
    HRRegexMatch *m = [named firstMatchInString:@"say 'hi' now" fromIndex:0];
    XCTAssertEqual([m range].location, (NSUInteger)4);
    XCTAssertEqual([m range].length, (NSUInteger)4);
}

/* Grammars say "\\x20"; in UTF-16 that has to become a code point. */
- (void)testByteEscapesMeanCharacters
{
    NSError *e = nil;
    HRRegex *r = [HRRegex regexWithPattern:@"a[\\x20\\x2d]+b\\\\x41" error:&e];
    XCTAssertNotNil(r, @"%@", e);
    NSString *s = @"a - b\\x41";
    XCTAssertEqual([[r firstMatchInString:s fromIndex:0] range].length, [s length]);
}

- (void)testAnchorsCanBeSwitchedOff
{
    unichar text[] = {'a', 'a', 'a'};
    HRRegex *g = [HRRegex regexWithPattern:@"\\Ga" error:NULL];
    XCTAssertEqual([[g firstMatchInCharacters:text length:3 fromIndex:1 options:0] range].location, (NSUInteger)1);
    XCTAssertNil([g firstMatchInCharacters:text length:3 fromIndex:1 options:HRRegexNotBeginPosition]);

    HRRegex *a = [HRRegex regexWithPattern:@"\\Aa" error:NULL];
    XCTAssertNotNil([a firstMatchInCharacters:text length:3 fromIndex:0 options:0]);
    XCTAssertNil([a firstMatchInCharacters:text length:3 fromIndex:0 options:HRRegexNotBeginString]);
}

- (void)testABadPatternIsAnErrorNotACrash
{
    NSError *e = nil;
    XCTAssertNil([HRRegex regexWithPattern:@"(unclosed" error:&e]);
    XCTAssertNotNil(e);
}

@end
