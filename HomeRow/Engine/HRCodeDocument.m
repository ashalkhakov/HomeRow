/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * HomeRow is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version.  It comes with ABSOLUTELY NO WARRANTY.  See COPYING.
 */
#import "HRCodeDocument.h"
#import "HRTextMateGrammar.h"
#import "HRWord.h"

@implementation HRWordArraySource
{
    NSArray *_words;
    NSUInteger _cursor;
}
- (instancetype)initWithWords:(NSArray *)words
{
    if ((self = [super init])) _words = [words copy];
    return self;
}
- (BOOL)isFinite { return YES; }
- (NSArray *)nextWords:(NSUInteger)count
{
    NSUInteger n = MIN(count, [_words count] - _cursor);
    NSArray *out = [_words subarrayWithRange:NSMakeRange(_cursor, n)];
    _cursor += n;
    return out;
}
@end

@implementation HRCodeDocument
{
    NSArray *_styles;      /* per line: NSData, one style byte per UTF-16 unit */
    NSArray *_sections;    /* NSValue ranges of lines */
}

+ (uint8_t)styleForScopes:(NSArray *)scopes
{
    static NSArray *table = nil;
    if (!table) {
        /* first match wins, innermost scope first; order matters where
         * prefixes overlap (constant.numeric before constant) */
        table = @[@[@"comment", @(HRTextStyleComment)],
                  @[@"string", @(HRTextStyleString)],
                  @[@"constant.numeric", @(HRTextStyleNumber)],
                  @[@"constant.character", @(HRTextStyleString)],
                  @[@"constant.language", @(HRTextStyleKeyword)],
                  @[@"keyword.operator", @(HRTextStylePlain)],
                  @[@"keyword", @(HRTextStyleKeyword)],
                  @[@"storage", @(HRTextStyleKeyword)],
                  @[@"entity.name.function", @(HRTextStyleFunction)],
                  @[@"support.function", @(HRTextStyleFunction)],
                  @[@"meta.function-call", @(HRTextStylePlain)],
                  @[@"entity.name.type", @(HRTextStyleType)],
                  @[@"entity.name.class", @(HRTextStyleType)],
                  @[@"support.type", @(HRTextStyleType)],
                  @[@"support.class", @(HRTextStyleType)]];
    }
    for (NSInteger i = (NSInteger)[scopes count] - 1; i >= 0; i--) {
        NSString *scope = scopes[(NSUInteger)i];
        for (NSArray *entry in table) {
            NSString *prefix = entry[0];
            if ([scope isEqualToString:prefix]
                || ([scope hasPrefix:prefix] && [scope length] > [prefix length]
                    && [scope characterAtIndex:[prefix length]] == '.')) {
                /* a comment or string stays one whatever is inside it */
                return (uint8_t)[entry[1] unsignedIntegerValue];
            }
        }
    }
    return HRTextStylePlain;
}

static NSString *HRExpandTabsInLine(NSString *line, NSUInteger tabWidth)
{
    if ([line rangeOfString:@"\t" options:NSLiteralSearch].location == NSNotFound) return line;
    NSMutableString *out = [NSMutableString string];
    for (NSUInteger i = 0; i < [line length]; i++) {
        unichar c = [line characterAtIndex:i];
        if (c != '\t') { [out appendFormat:@"%C", c]; continue; }
        do { [out appendString:@" "]; } while ([out length] % tabWidth != 0);
    }
    return out;
}

- (instancetype)initWithText:(NSString *)text grammar:(HRTextMateGrammar *)grammar
                    tabWidth:(NSUInteger)tabWidth targetSectionLines:(NSUInteger)target
{
    if (!(self = [super init])) return nil;
    if (tabWidth == 0) tabWidth = 4;
    if (target == 0) target = 50;

    NSMutableArray *lines = [NSMutableArray array];
    NSCharacterSet *blank = [NSCharacterSet whitespaceCharacterSet];
    for (NSString *raw in [HRWord linesOfString:[text precomposedStringWithCanonicalMappingIfAvailable]]) {
        NSString *line = HRExpandTabsInLine(raw, tabWidth);
        NSUInteger n = [line length];
        while (n > 0 && [blank characterIsMember:[line characterAtIndex:n - 1]]) n--;
        [lines addObject:[line substringToIndex:n]];
    }
    while ([lines count] > 0 && [[lines lastObject] length] == 0) [lines removeLastObject];
    _lines = [lines copy];

    /* colours for the whole file in one pass: a block comment or a string
     * may run across the places where sections are cut */
    NSMutableArray *styles = [NSMutableArray arrayWithCapacity:[lines count]];
    HRTextMateState *state = nil;
    for (NSString *line in lines) {
        NSMutableData *data = [NSMutableData dataWithLength:[line length]];
        if (grammar) {
            uint8_t *bytes = [data mutableBytes];
            for (HRTextMateToken *t in [grammar tokenizeLine:line state:state outState:&state]) {
                uint8_t style = [HRCodeDocument styleForScopes:t.scopes];
                for (NSUInteger i = t.range.location; i < NSMaxRange(t.range) && i < [line length]; i++) bytes[i] = style;
            }
        }
        [styles addObject:data];
    }
    _styles = [styles copy];

    [self cutIntoSectionsOf:target];
    return self;
}

/* A cut goes after a blank line.  From `target` lines on, the first blank
 * line followed by unindented text is taken; by 1.6 x target, any blank
 * line; failing that the section just ends at 2 x target. */
- (void)cutIntoSectionsOf:(NSUInteger)target
{
    NSMutableArray *sections = [NSMutableArray array];
    NSUInteger count = [_lines count], start = 0;
    while (start < count) {
        NSUInteger end = count;
        if (count - start > target + target / 2) {
            end = MIN(count, start + 2 * target);
            for (NSUInteger i = start + target; i < MIN(count, start + 2 * target); i++) {
                if ([_lines[i] length] > 0 || i + 1 >= count) continue;
                NSString *next = _lines[i + 1];
                BOOL topLevel = [next length] > 0 && [next characterAtIndex:0] != ' ';
                if (topLevel || i >= start + (target * 8) / 5) { end = i + 1; break; }
            }
        }
        [sections addObject:[NSValue valueWithRange:NSMakeRange(start, end - start)]];
        start = end;
    }
    _sections = [sections copy];
}

- (NSUInteger)numberOfSections { return [_sections count]; }

- (NSRange)lineRangeOfSection:(NSUInteger)section
{
    return section < [_sections count] ? [_sections[section] rangeValue] : NSMakeRange(0, 0);
}

/* A line is cut into typed words and untyped runs (blanks; comments unless
 * they are to be typed).  Untyped text before a word becomes its prefix --
 * together with any wholly untyped lines above it -- and untyped text after
 * the last word of a line becomes that word's suffix.  Between two words of
 * a line exactly one blank is typed, the separator; the rest of the gap is
 * prefix.  At the end of a line the separator is Return. */
- (NSArray *)wordsForLines:(NSRange)lineRange typeComments:(BOOL)typeComments
{
    NSMutableArray *words = [NSMutableArray array];
    NSMutableString *pending = [NSMutableString string];
    __block NSString *text = nil, *prefix = nil;
    __block NSData *wordStyles = nil;
    __block NSMutableString *suffix = nil;
    void (^emit)(HRSeparator) = ^(HRSeparator separator) {
        if (!text) return;
        [words addObject:[HRWord wordWithText:text separator:separator prefix:prefix suffix:suffix styles:wordStyles]];
        text = nil;
    };

    NSUInteger end = MIN(NSMaxRange(lineRange), [_lines count]);
    for (NSUInteger li = lineRange.location; li < end; li++) {
        NSString *line = _lines[li];
        const uint8_t *styles = [_styles[li] bytes];
        NSUInteger n = [line length], i = 0;
        BOOL wordOnThisLine = NO;
        while (i < n) {
            NSUInteger runStart = i;
            while (i < n && ([line characterAtIndex:i] == ' '
                             || (!typeComments && styles[i] == HRTextStyleComment))) i++;
            NSString *untyped = [line substringWithRange:NSMakeRange(runStart, i - runStart)];
            if (i >= n) {
                if (wordOnThisLine) [suffix appendString:untyped];
                else [pending appendString:untyped];
                break;
            }
            NSUInteger wordStart = i;
            while (i < n && [line characterAtIndex:i] != ' '
                   && (typeComments || styles[i] != HRTextStyleComment)) i++;

            if (wordOnThisLine) {
                emit(HRSeparatorSpace);
                if ([untyped hasPrefix:@" "]) untyped = [untyped substringFromIndex:1];
            } else {
                emit(HRSeparatorNewline);
            }
            [pending appendString:untyped];

            text = [line substringWithRange:NSMakeRange(wordStart, i - wordStart)];
            /* styles are per UTF-16 unit; a word wants them per composed character */
            NSMutableData *perCharacter = [NSMutableData data];
            for (NSUInteger k = 0; k < [text length]; k = NSMaxRange([text rangeOfComposedCharacterSequenceAtIndex:k])) {
                [perCharacter appendBytes:&styles[wordStart + k] length:1];
            }
            wordStyles = perCharacter;
            prefix = [pending copy];
            suffix = [NSMutableString string];
            [pending setString:@""];
            wordOnThisLine = YES;
        }
        /* a line with nothing to type is shown whole, break included; after
         * a typed line the break is the separator */
        if (!wordOnThisLine) [pending appendString:@"\n"];
    }
    if (text && [pending length] > 0) {
        /* untyped lines at the very end hang on the last word */
        NSString *tail = [pending hasSuffix:@"\n"] ? [pending substringToIndex:[pending length] - 1] : pending;
        if ([[tail stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length] > 0) {
            [suffix appendFormat:@"\n%@", tail];
        }
    }
    emit(HRSeparatorNewline);
    return words;
}

- (id<HRTextSource>)sourceForSection:(NSUInteger)section typeComments:(BOOL)typeComments
{
    NSArray *words = [self wordsForLines:[self lineRangeOfSection:section] typeComments:typeComments];
    return [words count] > 0 ? [[HRWordArraySource alloc] initWithWords:words] : nil;
}

@end
