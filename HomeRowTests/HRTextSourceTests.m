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
#import "HRTextSource.h"
#import "HRRandom.h"

@interface HRTextSourceTests : XCTestCase
@end

@implementation HRTextSourceTests

- (NSArray *)textsOf:(NSArray *)words
{
    return [words valueForKey:@"text"];
}

- (void)testSameSeedSameWords
{
    NSArray *list = @[@"one", @"two", @"three", @"four"];
    HRWordListSource *a = [[HRWordListSource alloc] initWithWords:list random:[[HRRandom alloc] initWithSeed:42]];
    HRWordListSource *b = [[HRWordListSource alloc] initWithWords:list random:[[HRRandom alloc] initWithSeed:42]];
    HRWordListSource *c = [[HRWordListSource alloc] initWithWords:list random:[[HRRandom alloc] initWithSeed:43]];
    NSArray *wa = [self textsOf:[a nextWords:50]];
    XCTAssertEqualObjects(wa, [self textsOf:[b nextWords:50]]);
    XCTAssertNotEqualObjects(wa, [self textsOf:[c nextWords:50]]);
}

- (void)testNoImmediateRepeats
{
    HRWordListSource *s = [[HRWordListSource alloc] initWithWords:@[@"x", @"y", @"z"]
                                                           random:[[HRRandom alloc] initWithSeed:5]];
    NSArray *w = [self textsOf:[s nextWords:300]];
    for (NSUInteger i = 1; i < [w count]; i++) {
        XCTAssertNotEqualObjects(w[i], w[i - 1]);
    }
}

- (void)testLimitMakesItFinite
{
    HRWordListSource *s = [[HRWordListSource alloc] initWithWords:@[@"x", @"y"]
                                                           random:[[HRRandom alloc] initWithSeed:5]];
    XCTAssertFalse([s isFinite]);
    s.limit = 25;
    XCTAssertTrue([s isFinite]);
    XCTAssertEqual([[s nextWords:20] count], (NSUInteger)20);
    XCTAssertEqual([[s nextWords:20] count], (NSUInteger)5);
    XCTAssertEqual([[s nextWords:20] count], (NSUInteger)0);
}

- (void)testPunctuationStartsCapitalizedAndEndsTheText
{
    HRWordListSource *s = [[HRWordListSource alloc] initWithWords:@[@"alpha", @"beta", @"gamma"]
                                                           random:[[HRRandom alloc] initWithSeed:11]];
    s.punctuation = YES;
    s.limit = 40;
    NSArray *w = [self textsOf:[s nextWords:40]];
    NSString *first = w[0];
    NSString *stripped = [first stringByTrimmingCharactersInSet:[NSCharacterSet punctuationCharacterSet]];
    XCTAssertTrue([[NSCharacterSet uppercaseLetterCharacterSet] characterIsMember:[stripped characterAtIndex:0]]);
    NSString *last = [w lastObject];
    unichar end = [last characterAtIndex:[last length] - 1];
    XCTAssertTrue(end == '.' || end == '?' || end == '!');
}

- (void)testNumbers
{
    HRWordListSource *s = [[HRWordListSource alloc] initWithWords:@[@"alpha", @"beta"]
                                                           random:[[HRRandom alloc] initWithSeed:9]];
    s.numbers = YES;
    NSUInteger numeric = 0;
    NSCharacterSet *nonDigits = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
    for (NSString *w in [self textsOf:[s nextWords:400]]) {
        if ([w rangeOfCharacterFromSet:nonDigits].location == NSNotFound) numeric++;
    }
    XCTAssertGreaterThan(numeric, (NSUInteger)10);
    XCTAssertLessThan(numeric, (NSUInteger)100);
}

- (void)testFixedTextSplitsOnWhitespaceAndKeepsLineBreaks
{
    HRFixedTextSource *s = [[HRFixedTextSource alloc] initWithText:@"  int  x;\r\n\r\n\treturn x;\n"];
    NSArray *w = [s nextWords:100];
    XCTAssertEqualObjects([self textsOf:w], (@[@"int", @"x;", @"return", @"x;"]));
    XCTAssertEqual(((HRWord *)w[0]).separator, HRSeparatorSpace);
    XCTAssertEqual(((HRWord *)w[1]).separator, HRSeparatorNewline);
    XCTAssertEqual([[s nextWords:10] count], (NSUInteger)0);
}

@end
