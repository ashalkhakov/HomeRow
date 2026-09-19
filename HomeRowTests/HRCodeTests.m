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
#import "HRCodeDocument.h"
#import "HRTextMateGrammar.h"
#import "HRTestSession.h"
#import <objc/runtime.h>

@interface HRCodeTests : XCTestCase
@end

@implementation HRCodeTests

- (NSString *)codeDirectory
{
    NSString *env = [[[NSProcessInfo processInfo] environment] objectForKey:@"HR_CODE_DIR"];
    if ([env length] > 0) return env;
    return [[[NSBundle bundleForClass:[self class]] resourcePath] stringByAppendingPathComponent:@"Code"];
}

- (HRTextMateGrammar *)grammarForScope:(NSString *)scope
{
    HRTextMateRegistry *registry = [[HRTextMateRegistry alloc] init];
    [registry addGrammarsInDirectory:[[self codeDirectory] stringByAppendingPathComponent:@"Grammars"]];
    HRTextMateGrammar *g = [registry grammarForScopeName:scope];
    XCTAssertNotNil(g, @"no grammar for %@", scope);
    /* the registry is only held weakly by its grammars */
    objc_setAssociatedObject(g, "registry", registry, OBJC_ASSOCIATION_RETAIN);
    return g;
}

- (void)testIndentationBlankLinesAndCommentsFillThemselvesIn
{
    NSString *src =
        @"// header comment\n"
        @"\n"
        @"int  add(int a, int b)   // adds\n"
        @"{\n"
        @"\treturn a + b; /* sum */\n"
        @"}\n"
        @"// the end\n";
    HRCodeDocument *doc = [[HRCodeDocument alloc] initWithText:src grammar:[self grammarForScope:@"source.c"]
                                                      tabWidth:4 targetSectionLines:0];
    NSArray *words = [doc wordsForLines:NSMakeRange(0, [doc.lines count]) typeComments:NO];
    XCTAssertEqualObjects([words valueForKey:@"text"],
                          (@[@"int", @"add(int", @"a,", @"int", @"b)", @"{", @"return", @"a", @"+", @"b;", @"}"]));

    HRWord *first = words[0], *add = words[1], *b = words[4], *ret = words[6], *sum = words[9], *close = words[10];
    XCTAssertEqualObjects(first.prefix, @"// header comment\n\n", @"comment and blank line come before the first word");
    XCTAssertEqualObjects(add.prefix, @" ", @"of two blanks one is typed, one fills itself in");
    XCTAssertEqualObjects(b.suffix, @"   // adds");
    XCTAssertEqual(b.separator, HRSeparatorNewline);
    XCTAssertEqualObjects(ret.prefix, @"    ", @"a tab is four columns of indentation, not typed");
    XCTAssertEqualObjects(sum.suffix, @" /* sum */");
    XCTAssertEqualObjects(close.suffix, @"\n// the end");

    XCTAssertEqual([first styleOfCharacterAtIndex:0], (uint8_t)HRTextStyleKeyword);
    XCTAssertEqual([add styleOfCharacterAtIndex:0], (uint8_t)HRTextStyleFunction);

    /* what is typed: the code, one blank between words, Return at line ends */
    HRTestConfiguration *c = [HRTestConfiguration defaultConfiguration];
    c.mode = HRTestModeCode;
    HRTestSession *s = [[HRTestSession alloc] initWithConfiguration:c source:[[HRWordArraySource alloc] initWithWords:words]];
    [s insertText:@"int add(int a, int b)\n{\nreturn a + b;\n}" atTime:0.0];
    XCTAssertEqual(s.state, HRSessionFinished);
    XCTAssertEqualWithAccuracy([s summary].accuracy, 100.0, 1e-9);
}

- (void)testCommentsCanBeTypedAndNoGrammarMeansPlain
{
    NSString *src = @"x = 1  # one\n";
    HRCodeDocument *doc = [[HRCodeDocument alloc] initWithText:src grammar:[self grammarForScope:@"source.python"]
                                                      tabWidth:0 targetSectionLines:0];
    XCTAssertEqualObjects([[doc wordsForLines:NSMakeRange(0, 1) typeComments:NO] valueForKey:@"text"], (@[@"x", @"=", @"1"]));
    XCTAssertEqualObjects([[doc wordsForLines:NSMakeRange(0, 1) typeComments:YES] valueForKey:@"text"],
                          (@[@"x", @"=", @"1", @"#", @"one"]));

    HRCodeDocument *plain = [[HRCodeDocument alloc] initWithText:src grammar:nil tabWidth:0 targetSectionLines:0];
    NSArray *words = [plain wordsForLines:NSMakeRange(0, 1) typeComments:NO];
    XCTAssertEqual([words count], (NSUInteger)5, @"without a grammar nothing is known to be a comment");
    XCTAssertEqual([(HRWord *)words[0] styleOfCharacterAtIndex:0], (uint8_t)HRTextStylePlain);
}

- (void)testStopOnErrorNeverEntersAWrongKey
{
    HRTestConfiguration *c = [HRTestConfiguration defaultConfiguration];
    c.mode = HRTestModeCode;
    c.stopOnError = YES;
    HRTestSession *s = [[HRTestSession alloc] initWithConfiguration:c
                                                             source:[[HRFixedTextSource alloc] initWithText:@"ab cd"]];
    [s insertText:@"ax" atTime:0.0];
    XCTAssertEqual([s caretIndexInCurrentWord], (NSUInteger)1, @"the x was refused");
    XCTAssertEqualObjects([s expectedInput], @"b", @"and there is nothing to take back");
    XCTAssertEqual(s.wrongInputCount, (NSUInteger)1);
    XCTAssertEqualObjects(s.lastWrongInput, @"x", @"the view is told which key, to show it");
    XCTAssertTrue(s.lastWrongInputWasRefused);
    [s insertText:@" " atTime:0.1];
    XCTAssertEqual(s.currentWordIndex, (NSUInteger)0, @"nor can an unfinished word be left");
    XCTAssertEqual(s.wrongInputCount, (NSUInteger)2);
    XCTAssertEqualObjects(s.lastWrongInput, @" ");
    [s insertText:@"b cd" atTime:0.2];
    XCTAssertEqual(s.wrongInputCount, (NSUInteger)2, @"right keys are not reported");
    XCTAssertEqual(s.state, HRSessionFinished);
    HRTestSummary *r = [s summary];
    XCTAssertEqual(r.incorrectKeystrokes, (NSUInteger)2);
    XCTAssertEqual(r.incorrectCharacters, (NSUInteger)0);
    XCTAssertLessThan(r.accuracy, 100.0);
}

- (void)testSectionsCoverTheFileAndCutAtBlankLines
{
    NSMutableString *src = [NSMutableString string];
    for (int f = 0; f < 12; f++) {
        [src appendFormat:@"void f%d(void)\n{\n", f];
        for (int i = 0; i < 14; i++) [src appendFormat:@"    call(%d);\n", i];
        [src appendString:@"}\n\n"];
    }
    HRCodeDocument *doc = [[HRCodeDocument alloc] initWithText:src grammar:nil tabWidth:4 targetSectionLines:50];
    XCTAssertGreaterThan(doc.numberOfSections, (NSUInteger)2);
    NSUInteger covered = 0;
    for (NSUInteger i = 0; i < doc.numberOfSections; i++) {
        NSRange r = [doc lineRangeOfSection:i];
        XCTAssertEqual(r.location, covered, @"sections follow one another without gaps");
        covered = NSMaxRange(r);
        XCTAssertLessThanOrEqual(r.length, (NSUInteger)100);
        if (i + 1 < doc.numberOfSections) {
            XCTAssertEqualObjects(doc.lines[NSMaxRange(r) - 1], @"", @"a cut comes after a blank line");
            XCTAssertTrue([doc.lines[NSMaxRange(r)] hasPrefix:@"void"], @"...and before top-level code");
        }
        XCTAssertNotNil([doc sourceForSection:i typeComments:NO]);
    }
    XCTAssertEqual(covered, [doc.lines count]);
}

/* Everything that ships: every language has its grammar, every file reads
 * as UTF-8, tokenizes without a pattern failing, and yields words whose
 * typed text plus untyped text is the file again. */
- (void)testEveryBundledLanguageAndFile
{
    NSString *root = [self codeDirectory];
    NSArray *languages = [NSDictionary dictionaryWithContentsOfFile:[root stringByAppendingPathComponent:@"index.plist"]][@"languages"];
    XCTAssertGreaterThanOrEqual([languages count], (NSUInteger)10);
    for (NSDictionary *language in languages) {
        HRTextMateGrammar *g = [self grammarForScope:language[@"scopeName"]];
        XCTAssertGreaterThan([language[@"files"] count], (NSUInteger)0, @"%@ has nothing to type", language[@"identifier"]);
        for (NSDictionary *file in language[@"files"]) {
            NSString *path = [[root stringByAppendingPathComponent:@"Files"] stringByAppendingPathComponent:file[@"file"]];
            NSString *text = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
            XCTAssertNotNil(text, @"%@", path);
            XCTAssertTrue([file[@"licence"] length] > 0 && [file[@"repository"] length] > 0 && [file[@"commit"] length] > 0,
                          @"%@: where it came from must be on record", file[@"file"]);
            HRCodeDocument *doc = [[HRCodeDocument alloc] initWithText:text grammar:g tabWidth:4 targetSectionLines:50];
            NSUInteger typed = 0, comments = 0;
            for (NSUInteger s = 0; s < doc.numberOfSections; s++) {
                for (HRWord *w in [doc wordsForLines:[doc lineRangeOfSection:s] typeComments:NO]) {
                    typed += [w.characters count];
                    for (NSUInteger i = 0; i < [w.characters count]; i++) {
                        if ([w styleOfCharacterAtIndex:i] == HRTextStyleComment) comments++;
                    }
                }
            }
            XCTAssertGreaterThan(typed, (NSUInteger)200, @"%@", file[@"file"]);
            XCTAssertEqual(comments, (NSUInteger)0, @"%@: comment text among the typed words", file[@"file"]);
        }
        XCTAssertEqualObjects(g.problems, @[], @"%@", language[@"identifier"]);
    }
}

/* Without stop on error the wrong key goes in -- it is reported all the same
 * (for the beep and the keyboard), but as entered, not refused. */
- (void)testAWrongKeyThatGoesInIsReportedAsEntered
{
    HRTestConfiguration *c = [HRTestConfiguration defaultConfiguration];
    c.mode = HRTestModeCustom;
    HRTestSession *s = [[HRTestSession alloc] initWithConfiguration:c
                                                             source:[[HRFixedTextSource alloc] initWithText:@"ab cd"]];
    [s insertText:@"ax" atTime:0.0];
    XCTAssertEqual(s.wrongInputCount, (NSUInteger)1);
    XCTAssertEqualObjects(s.lastWrongInput, @"x");
    XCTAssertFalse(s.lastWrongInputWasRefused);
    XCTAssertEqual([s caretIndexInCurrentWord], (NSUInteger)2);
    [s insertText:@"\n" atTime:0.1];
    XCTAssertEqual(s.wrongInputCount, (NSUInteger)2, @"Return where a space belongs");
    XCTAssertTrue(s.lastWrongInputWasRefused);
}

@end
