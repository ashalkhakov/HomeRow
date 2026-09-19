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

/* TextMate grammars (.tmLanguage.json) -- the syntax descriptions TextMate
 * introduced and VS Code still uses -- and a tokenizer for them.
 *
 * The algorithm follows vscode-textmate, and the tests run that project's
 * own test cases: a line is matched against the patterns of the rule on top
 * of a stack; begin/end and begin/while rules push and pop; captures name
 * parts of a match and may be re-tokenized with patterns of their own;
 * `include` pulls in repository entries, the grammar itself ($self, $base)
 * or another grammar.  Regular expressions are Oniguruma's (HRRegex).
 *
 * Not implemented: injections.  None of the grammars HomeRow ships depends
 * on them for what HomeRow uses scopes for -- colouring, and telling
 * comments from code.
 *
 * Foundation only. */

@class HRTextMateGrammar;

/* A run of a line and the scopes it lies in, outermost first, e.g.
 * ("source.c", "string.quoted.double.c", "constant.character.escape.c"). */
@interface HRTextMateToken : NSObject
@property (nonatomic, readonly) NSRange range;
@property (nonatomic, readonly, copy) NSArray *scopes;
/* YES if any scope is `prefix` or begins with `prefix.` */
- (BOOL)hasScopeWithPrefix:(NSString *)prefix;
@end

/* What a line leaves behind for the next one: the rule stack.  Opaque;
 * nil means "the start of a file". */
@interface HRTextMateState : NSObject
@end

/* Grammars by scope name, so that one grammar can include another
 * (Objective-C includes C). */
@interface HRTextMateRegistry : NSObject
- (void)addGrammar:(HRTextMateGrammar *)grammar;
- (HRTextMateGrammar *)grammarForScopeName:(NSString *)scopeName;
/* Loads every *.json grammar in a directory; returns how many. */
- (NSUInteger)addGrammarsInDirectory:(NSString *)directory;
@end

@interface HRTextMateGrammar : NSObject

@property (nonatomic, readonly, copy) NSString *scopeName;
@property (nonatomic, readonly, copy) NSString *name;
@property (nonatomic, weak) HRTextMateRegistry *registry;
/* Patterns that did not compile (NSString descriptions).  A grammar with a
 * few of these still works; the rules concerned are skipped. */
@property (nonatomic, readonly) NSArray *problems;

+ (instancetype)grammarWithContentsOfFile:(NSString *)path error:(NSError **)error;
+ (instancetype)grammarWithDictionary:(NSDictionary *)dictionary;

/* Tokens of one line (without its line break), covering it completely and
 * in order.  `state` comes from the previous line, nil for the first;
 * `outState` goes to the next. */
- (NSArray *)tokenizeLine:(NSString *)line
                    state:(HRTextMateState *)state
                 outState:(HRTextMateState **)outState;

/* A whole text: an array with one token array per line. */
- (NSArray *)tokenizeText:(NSString *)text;

@end
