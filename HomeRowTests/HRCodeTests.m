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
#import "HRStatistics.h"
#import "HRCodeLibrary.h"
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

/* Stop on word: the mistake goes in, but the word cannot be left with it --
 * and "no backspace" does not make that a trap. */
- (void)testStopOnWordHoldsTheWordUntilItIsRight
{
    HRTestConfiguration *c = [HRTestConfiguration defaultConfiguration];
    c.mode = HRTestModeCustom;
    c.stopPolicy = HRStopOnWord;
    c.backspacePolicy = HRBackspaceNone;
    HRTestSession *s = [[HRTestSession alloc] initWithConfiguration:c
                                                             source:[[HRFixedTextSource alloc] initWithText:@"ab cd"]];
    [s insertText:@"ax" atTime:0.0];
    XCTAssertEqual([s caretIndexInCurrentWord], (NSUInteger)2, @"the x went in");
    [s insertText:@" " atTime:0.1];
    XCTAssertEqual(s.currentWordIndex, (NSUInteger)0, @"but the word holds");
    XCTAssertTrue(s.lastWrongInputWasRefused);
    XCTAssertEqualObjects([s expectedInput], @"\b");
    [s deleteBackwardAtTime:0.2];
    XCTAssertEqual([s caretIndexInCurrentWord], (NSUInteger)1, @"no-backspace gives way inside the held word");
    [s insertText:@"b cd" atTime:0.3];
    XCTAssertEqual(s.state, HRSessionFinished);

    /* the old BOOL still reads and writes, and old saved settings load */
    c.stopOnError = YES;
    XCTAssertEqual(c.stopPolicy, HRStopOnLetter);
    HRTestConfiguration *old = [[HRTestConfiguration alloc] initWithDictionary:@{@"stopOnError": @YES, @"backspacePolicy": @99}];
    XCTAssertEqual(old.stopPolicy, HRStopOnLetter);
    XCTAssertEqual(old.backspacePolicy, HRBackspaceNone, @"nonsense is clamped");
    HRTestConfiguration *round = [[HRTestConfiguration alloc] initWithDictionary:[c dictionaryRepresentation]];
    XCTAssertEqual(round.stopPolicy, HRStopOnLetter);
}

/* Tab where the code goes deeper, once per level, and nowhere else. */
- (void)testTabIsTypedWhereIndentationDeepens
{
    NSString *code = @"int f(int a)\n{\n  if (a) {\n      return 1;\n  }\n  return 0;\n}\n";
    HRCodeDocument *doc = [[HRCodeDocument alloc] initWithText:code grammar:nil tabWidth:4 targetSectionLines:50];
    XCTAssertEqual([doc indentUnit], (NSUInteger)2);
    NSArray *words = [doc wordsForLines:NSMakeRange(0, 7) typeComments:NO typeTabs:YES];
    NSMutableArray *firsts = [NSMutableArray array];
    HRSeparator previous = HRSeparatorNewline;
    for (HRWord *w in words) {
        if (previous == HRSeparatorNewline) [firsts addObject:@[w.prefix ?: @"", w.text]];
        previous = w.separator;
    }
    NSArray *expected = @[@[@"", @"int"], @[@"", @"{"], @[@" ", @"\tif"], @[@"    ", @"\t\treturn"],
                          @[@"  ", @"}"], @[@"  ", @"return"], @[@"", @"}"]];
    XCTAssertEqualObjects(firsts, expected, @"prefix plus tabs is the indentation, column for column");

    HRWord *deep = nil;
    for (HRWord *w in words) if ([w.text hasPrefix:@"\t\t"]) deep = w;
    XCTAssertEqual([deep.characters count], (NSUInteger)8, @"two tabs and r-e-t-u-r-n");
    XCTAssertEqual([deep styleOfCharacterAtIndex:0], HRTextStylePlain);

    /* without the option nothing changes */
    for (HRWord *w in [doc wordsForLines:NSMakeRange(0, 7) typeComments:NO]) {
        XCTAssertEqual([w.text rangeOfString:@"\t"].location, (NSUInteger)NSNotFound);
    }

    /* and it types: Tab is a character like any other */
    HRTestConfiguration *c = [HRTestConfiguration defaultConfiguration];
    c.mode = HRTestModeCode;
    c.stopOnError = YES;
    HRTestSession *s = [[HRTestSession alloc] initWithConfiguration:c
                                                             source:[doc sourceForSection:0 typeComments:NO typeTabs:YES]];
    [s insertText:@"int f(int a)\n{\n" atTime:0.0];
    XCTAssertEqualObjects([s expectedInput], @"\t");
    [s insertText:@"if" atTime:0.1];
    XCTAssertEqual([s caretIndexInCurrentWord], (NSUInteger)0, @"the Tab has to come first");
    [s insertText:@"\tif (a) {\n\t\treturn 1;\n}\nreturn 0;\n}" atTime:0.2];
    XCTAssertEqual(s.state, HRSessionFinished);
}

/* Overhead: what share of the keystrokes did not end up as text. */
- (void)testKeystrokeOverheadAndKeyClasses
{
    HRTestConfiguration *c = [HRTestConfiguration defaultConfiguration];
    c.mode = HRTestModeCustom;
    HRTestSession *s = [[HRTestSession alloc] initWithConfiguration:c
                                                             source:[[HRFixedTextSource alloc] initWithText:@"ab c"]];
    [s insertText:@"ax" atTime:0.0];      /* a, and a wrong key */
    [s deleteBackwardAtTime:0.1];          /* taken back */
    [s insertText:@"b c" atTime:0.2];      /* b, space, c */
    HRTestSummary *r = [s summary];
    XCTAssertEqual(r.deletions, (NSUInteger)1);
    /* six keystrokes (a x Backspace b space c), four of them text (a b space c) */
    XCTAssertEqualWithAccuracy([r keystrokeOverhead], 1.0 - 4.0 / 6.0, 1e-9);

    HRTestSession *clean = [[HRTestSession alloc] initWithConfiguration:c
                                                                 source:[[HRFixedTextSource alloc] initWithText:@"ab c"]];
    [clean insertText:@"ab c" atTime:0.0];
    XCTAssertEqualWithAccuracy([[clean summary] keystrokeOverhead], 0.0, 1e-9);

    NSDictionary *counts = @{@"a": @{@"hits": @10, @"misses": @0}, @"Q": @{@"hits": @2, @"misses": @1},
                             @"7": @{@"hits": @3, @"misses": @0}, @"{": @{@"hits": @4, @"misses": @2, @"timed": @4, @"time": @2.0},
                             @")": @{@"hits": @4, @"misses": @0, @"timed": @4, @"time": @1.0},
                             @"=": @{@"hits": @5, @"misses": @0}, @";": @{@"hits": @6, @"misses": @0},
                             @" ": @{@"hits": @9, @"misses": @0}, @"\u00FC": @{@"hits": @1, @"misses": @0}};
    NSArray *rows = [HRStatistics keyClassesFromCounts:counts];
    NSMutableArray *names = [NSMutableArray array];
    for (HRStatKey *k in rows) [names addObject:k.character];
    NSArray *order = @[HRKeyClassLetters, HRKeyClassCapitals, HRKeyClassDigits, HRKeyClassBrackets,
                       HRKeyClassOperators, HRKeyClassPunctuation, HRKeyClassWhitespace];
    XCTAssertEqualObjects(names, order);
    HRStatKey *brackets = rows[3];
    XCTAssertEqual(brackets.hits, (NSUInteger)8);
    XCTAssertEqualWithAccuracy([brackets errorRate], 0.2, 1e-9);
    XCTAssertEqualWithAccuracy([brackets averageTime], 3.0 / 8.0, 1e-9);
    XCTAssertEqual(((HRStatKey *)rows[0]).hits, (NSUInteger)11, @"a letter with an umlaut is a letter");
}

/* A folder of one's own: what is there to be typed comes in, the rest stays out. */
- (void)testAFolderBringsItsSourceFilesAndNothingElse
{
    NSString *root = [NSTemporaryDirectory() stringByAppendingPathComponent:
                      [NSString stringWithFormat:@"hr-folder-%d-%u", (int)[[NSProcessInfo processInfo] processIdentifier], arc4random()]];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSDictionary *files = @{@"main.c": @"int main(void)\n{\n    return 0;\n}\n",
                            @"src/util/strings.py": @"def f():\n    return 1\n",
                            @"src/app.min.js": @"var a=1;",
                            @"node_modules/left-pad/index.js": @"module.exports = 1;\n",
                            @".git/hooks/pre-commit.sh": @"exit 0\n",
                            @"README.md": @"# nothing to type\n",
                            @"empty.c": @"",
                            @"types.d.ts": @"declare const x: number;\n"};
    for (NSString *relative in files) {
        NSString *path = [root stringByAppendingPathComponent:relative];
        [fm createDirectoryAtPath:[path stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:NULL];
        [files[relative] writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    }
    HRCodeLibrary *library = [[HRCodeLibrary alloc] initWithDirectory:[self codeDirectory]];
    NSArray *expected = @[@"main.c", @"src/util/strings.py"];
    XCTAssertEqualObjects([library scanFolder:root], expected);
    XCTAssertEqual([library addUserFolderAtPath:root], (NSUInteger)2);

    HRCodeFile *found = nil;
    for (HRCodeFile *f in [library filesForLanguage:[library languageWithIdentifier:@"python"]]) {
        if ([f.path hasSuffix:@"strings.py"]) found = f;
    }
    XCTAssertNotNil(found);
    XCTAssertFalse(found.isBundled);
    XCTAssertEqualObjects(found.title, [[root lastPathComponent] stringByAppendingPathComponent:@"src/util/strings.py"]);
    XCTAssertEqualObjects([library folderOfFile:found], root);
    XCTAssertEqualObjects([library fileWithIdentifier:found.identifier].path, found.path, @"progress finds it again by its path");
    XCTAssertGreaterThan([library documentForFile:found error:NULL].numberOfSections, (NSUInteger)0);

    /* the same file opened on its own as well is listed once */
    [library addUserFileAtPath:found.path];
    NSUInteger times = 0;
    for (HRCodeFile *f in [library filesForLanguage:[library languageWithIdentifier:@"python"]]) if ([f.path isEqualToString:found.path]) times++;
    XCTAssertEqual(times, (NSUInteger)1);

    [library removeUserFileAtPath:found.path];
    [library removeUserFolderAtPath:root];
    XCTAssertNil([library fileWithIdentifier:found.identifier]);
    XCTAssertEqual([library.userFolderPaths count], (NSUInteger)0);
    [fm removeItemAtPath:root error:NULL];
}

@end
