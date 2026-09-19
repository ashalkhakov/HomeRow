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
#import "HRTextMateGrammar.h"

/* vscode-textmate's own test cases (Fixtures/textmate, MIT): grammars, lines
 * and the tokens the reference implementation produces for them.  Cases that
 * need injections are skipped -- HomeRow does not implement those. */
@interface HRTextMateTests : XCTestCase
@end

@implementation HRTextMateTests

- (NSString *)fixturesDirectory
{
    NSString *env = [[[NSProcessInfo processInfo] environment] objectForKey:@"HR_TEXTMATE_FIXTURES_DIR"];
    if ([env length] > 0) return env;
    return [[[NSBundle bundleForClass:[self class]] resourcePath] stringByAppendingPathComponent:@"textmate"];
}

- (NSString *)describe:(NSArray *)tokens
{
    NSMutableArray *parts = [NSMutableArray array];
    for (NSArray *t in tokens) [parts addObject:[NSString stringWithFormat:@"[%@ | %@]", t[0], [t[1] componentsJoinedByString:@" "]]];
    return [parts componentsJoinedByString:@" "];
}

/* Runs one suite; returns the descriptions of the cases that failed. */
- (NSArray *)failuresInSuite:(NSString *)suite file:(NSString *)file ran:(NSUInteger *)ran
{
    NSString *dir = [[self fixturesDirectory] stringByAppendingPathComponent:suite];
    NSData *data = [NSData dataWithContentsOfFile:[dir stringByAppendingPathComponent:file]];
    XCTAssertNotNil(data, @"no %@ in %@", file, dir);
    NSArray *cases = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] : @[];
    NSMutableArray *failures = [NSMutableArray array];

    /* These four rest on injections -- the grammar's own "injections" key --
     * which HomeRow leaves out; none of the grammars it ships has any. */
    NSSet *needInjections = [NSSet setWithObjects:@"TEST #42", @"TEST #45", @"TEST #64", @"Injections in PHP", nil];
    for (NSDictionary *c in cases) {
        if ([c[@"grammarInjections"] count] > 0 || [needInjections containsObject:c[@"desc"]]) continue;
        HRTextMateRegistry *registry = [[HRTextMateRegistry alloc] init];
        HRTextMateGrammar *main = nil;
        for (NSString *path in c[@"grammars"]) {
            HRTextMateGrammar *g = [HRTextMateGrammar grammarWithContentsOfFile:[dir stringByAppendingPathComponent:path] error:NULL];
            if (!g) continue;   /* a few fixtures are plists; the cases that need them fail below */
            [registry addGrammar:g];
            if ([path isEqual:c[@"grammarPath"]]) main = g;
        }
        if (c[@"grammarScopeName"]) main = [registry grammarForScopeName:c[@"grammarScopeName"]];
        if (!main) { [failures addObject:[NSString stringWithFormat:@"%@: grammar not loaded", c[@"desc"]]]; continue; }
        (*ran)++;

        HRTextMateState *state = nil;
        NSUInteger lineNo = 0;
        for (NSDictionary *expectedLine in c[@"lines"]) {
            lineNo++;
            NSString *text = expectedLine[@"line"];
            NSMutableArray *actual = [NSMutableArray array];
            for (HRTextMateToken *t in [main tokenizeLine:text state:state outState:&state]) {
                [actual addObject:@[[text substringWithRange:t.range], t.scopes]];
            }
            NSMutableArray *expected = [NSMutableArray array];
            for (NSDictionary *t in expectedLine[@"tokens"]) {
                /* the reference drops empty tokens on non-empty lines */
                if ([text length] > 0 && [t[@"value"] length] == 0) continue;
                [expected addObject:@[t[@"value"], t[@"scopes"]]];
            }
            if ([text length] > 0) {
                NSIndexSet *empty = [actual indexesOfObjectsPassingTest:^BOOL(NSArray *t, NSUInteger i, BOOL *stop) { return [t[0] length] == 0; }];
                [actual removeObjectsAtIndexes:empty];
            }
            if (![actual isEqual:expected]) {
                [failures addObject:[NSString stringWithFormat:@"%@ line %lu \"%@\"\n   expected %@\n   got      %@",
                                     c[@"desc"], (unsigned long)lineNo, text, [self describe:expected], [self describe:actual]]];
                break;
            }
        }
    }
    return failures;
}

- (void)testFirstMateCases
{
    NSUInteger ran = 0;
    NSArray *failures = [self failuresInSuite:@"first-mate" file:@"tests.json" ran:&ran];
    XCTAssertGreaterThan(ran, (NSUInteger)50);
    XCTAssertEqual([failures count], (NSUInteger)0, @"%lu of %lu cases:\n%@", (unsigned long)[failures count],
                   (unsigned long)ran, [failures componentsJoinedByString:@"\n"]);
}

- (void)testSuite1Cases
{
    NSUInteger ran = 0;
    NSArray *failures = [self failuresInSuite:@"suite1" file:@"tests.json" ran:&ran];
    XCTAssertGreaterThan(ran, (NSUInteger)10);
    XCTAssertEqual([failures count], (NSUInteger)0, @"%lu of %lu cases:\n%@", (unsigned long)[failures count],
                   (unsigned long)ran, [failures componentsJoinedByString:@"\n"]);
}

- (void)testWhileCases
{
    NSUInteger ran = 0;
    NSArray *failures = [self failuresInSuite:@"suite1" file:@"whileTests.json" ran:&ran];
    XCTAssertGreaterThan(ran, (NSUInteger)0);
    XCTAssertEqual([failures count], (NSUInteger)0, @"%lu of %lu cases:\n%@", (unsigned long)[failures count],
                   (unsigned long)ran, [failures componentsJoinedByString:@"\n"]);
}

@end
