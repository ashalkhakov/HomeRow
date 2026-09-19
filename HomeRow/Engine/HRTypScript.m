/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * HomeRow is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version.  It comes with ABSOLUTELY NO WARRANTY.  See COPYING.
 */
#import "HRTypScript.h"
#import "HRWord.h"

NSString * const HRTypErrorDomain = @"HRTypErrorDomain";

static NSError *HRTypError(NSUInteger line, NSString *what)
{
    NSString *msg = [NSString stringWithFormat:@"line %lu: %@", (unsigned long)line, what];
    return [NSError errorWithDomain:HRTypErrorDomain code:(NSInteger)line
                           userInfo:@{NSLocalizedDescriptionKey: msg}];
}

@interface HRTypCommand ()
- (instancetype)initWithType:(unichar)type data:(NSString *)data line:(NSUInteger)line;
- (void)appendLine:(NSString *)more;
@end

@implementation HRTypCommand
{
    NSMutableString *_buffer;
}
- (instancetype)initWithType:(unichar)type data:(NSString *)data line:(NSUInteger)line
{
    if ((self = [super init])) {
        _type = type;
        _buffer = [data mutableCopy];
        _line = line;
    }
    return self;
}
- (void)appendLine:(NSString *)more
{
    [_buffer appendString:@"\n"];
    [_buffer appendString:more];
}
- (NSString *)data { return [_buffer copy]; }
- (NSString *)description
{
    return [NSString stringWithFormat:@"<%C: line %lu>", _type, (unsigned long)_line];
}
@end

@implementation HRTypMenuItem
- (instancetype)initWithLabel:(NSString *)label title:(NSString *)title
{
    if ((self = [super init])) { _label = [label copy]; _title = [title copy]; }
    return self;
}
@end

@implementation HRTypMenu
- (instancetype)initWithTitle:(NSString *)title upLabel:(NSString *)up items:(NSArray *)items
{
    if ((self = [super init])) { _title = [title copy]; _upLabel = [up copy]; _items = [items copy]; }
    return self;
}
@end

@implementation HRTypStep
- (instancetype)initTutorial:(NSString *)text
{
    if ((self = [super init])) { _text = [text copy]; _maxErrorPercent = -1.0; }
    return self;
}
- (instancetype)initExercise:(NSString *)text kind:(HRTypExerciseKind)kind practiceOnly:(BOOL)practice
                 instruction:(NSString *)instruction maxError:(double)maxError
{
    if ((self = [super init])) {
        _isExercise = YES;
        _text = [text copy];
        _kind = kind;
        _practiceOnly = practice;
        _instruction = [instruction copy];
        _maxErrorPercent = maxError;
    }
    return self;
}
@end

@implementation HRTypLesson
- (instancetype)initWithTitle:(NSString *)title label:(NSString *)label steps:(NSArray *)steps
{
    if ((self = [super init])) { _title = [title copy]; _label = [label copy]; _steps = [steps copy]; }
    return self;
}
- (NSUInteger)exerciseCount
{
    NSUInteger n = 0;
    for (HRTypStep *s in _steps) if (s.isExercise) n++;
    return n;
}
@end

@implementation HRTypScript
{
    NSDictionary *_labelIndex;
}

+ (instancetype)scriptWithContentsOfFile:(NSString *)path error:(NSError **)error
{
    NSString *text = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:error];
    if (!text) return nil;
    return [self scriptWithString:text error:error];
}

static NSString *HRTrimRight(NSString *s)
{
    NSUInteger n = [s length];
    NSCharacterSet *ws = [NSCharacterSet whitespaceCharacterSet];
    while (n > 0 && [ws characterIsMember:[s characterAtIndex:n - 1]]) n--;
    return [s substringToIndex:n];
}

/* Lines of an exercise or tutorial with the trailing blank ones dropped and
 * trailing blanks on each line removed: what is on screen but cannot be
 * seen cannot be typed either. */
static NSString *HRTidyBlock(NSString *data)
{
    NSMutableArray *lines = [NSMutableArray array];
    for (NSString *l in [HRWord linesOfString:data]) [lines addObject:HRTrimRight(l)];
    while ([lines count] > 0 && [[lines lastObject] length] == 0) [lines removeLastObject];
    return [lines componentsJoinedByString:@"\n"];
}

/* `"title"` -> title; returns nil when there is no quoted string. */
static NSString *HRQuoted(NSString *s, NSString **before)
{
    NSRange open = [s rangeOfString:@"\"" options:NSLiteralSearch];
    NSRange close = [s rangeOfString:@"\"" options:(NSBackwardsSearch | NSLiteralSearch)];
    if (open.location == NSNotFound || close.location <= open.location) return nil;
    if (before) *before = [[s substringToIndex:open.location]
                           stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    return [s substringWithRange:NSMakeRange(open.location + 1, close.location - open.location - 1)];
}

+ (instancetype)scriptWithString:(NSString *)string error:(NSError **)error
{
    NSCharacterSet *known = [NSCharacterSet characterSetWithCharactersInString:@"BTIMDdSsGQYNKEFX*"];
    NSMutableArray *commands = [NSMutableArray array];
    HRTypCommand *current = nil;
    NSUInteger lineNo = 0;

    for (NSString *line in [HRWord linesOfString:string]) {
        lineNo++;
        if ([line length] == 0 || [line characterAtIndex:0] == '#') continue;
        if ([[line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] length] == 0) continue;
        if ([line length] < 2 || [line characterAtIndex:1] != ':') {
            if (error) *error = HRTypError(lineNo, @"the ':' separator is not in column two");
            return nil;
        }
        unichar c = [line characterAtIndex:0];
        NSString *data = [line substringFromIndex:2];
        if (c == ' ') {
            if (!current) {
                if (error) *error = HRTypError(lineNo, @"a continuation line with nothing to continue");
                return nil;
            }
            [current appendLine:data];
            continue;
        }
        if (![known characterIsMember:c]) {
            if (error) *error = HRTypError(lineNo, [NSString stringWithFormat:@"unknown command '%C'", c]);
            return nil;
        }
        current = [[HRTypCommand alloc] initWithType:c data:data line:lineNo];
        [commands addObject:current];
    }

    HRTypScript *script = [[self alloc] init];
    script->_commands = [commands copy];
    [script index];
    return script;
}

- (void)index
{
    NSMutableDictionary *labels = [NSMutableDictionary dictionary];
    NSMutableArray *warnings = [NSMutableArray array];
    NSMutableArray *menus = [NSMutableArray array];
    NSCharacterSet *ws = [NSCharacterSet whitespaceCharacterSet];

    for (NSUInteger i = 0; i < [_commands count]; i++) {
        HRTypCommand *c = _commands[i];
        if (c.type != '*') continue;
        NSString *label = [c.data stringByTrimmingCharactersInSet:ws];
        if (labels[label]) [warnings addObject:HRTypError(c.line, [NSString stringWithFormat:@"label %@ is defined twice", label])];
        else labels[label] = @(i);
    }
    _labelIndex = labels;

    /* lessons: a linear walk, cut at banners */
    NSMutableArray *lessons = [NSMutableArray array];
    NSMutableArray *steps = [NSMutableArray array];
    /* __block: the flush block must see the current title, not the one at
     * the time the block was made */
    __block NSString *title = nil;
    __block NSString *lessonLabel = nil;
    NSString *lastLabel = nil, *instruction = nil;
    double maxError = -1.0;      /* E:n%* */
    double maxErrorOnce = -1.0;  /* E:n%  */

    void (^flush)(void) = ^{
        HRTypLesson *l = [[HRTypLesson alloc] initWithTitle:title ?: @"" label:lessonLabel steps:steps];
        if ([l exerciseCount] > 0) [lessons addObject:l];
        [steps removeAllObjects];
    };

    for (HRTypCommand *c in _commands) {
        NSString *data = c.data;
        switch (c.type) {
            case '*':
                lastLabel = [data stringByTrimmingCharactersInSet:ws];
                break;
            case 'B':
                flush();
                title = [data stringByTrimmingCharactersInSet:ws];
                lessonLabel = lastLabel;
                instruction = nil;
                break;
            case 'T': {
                NSString *text = HRTidyBlock(data);
                if ([text length] > 0) [steps addObject:[[HRTypStep alloc] initTutorial:text]];
                break;
            }
            case 'I':
                instruction = HRTidyBlock(data);
                break;
            case 'D': case 'd': case 'S': case 's': {
                NSString *text = HRTidyBlock(data);
                if ([text length] > 0) {
                    BOOL speed = (c.type == 'S' || c.type == 's');
                    [steps addObject:[[HRTypStep alloc] initExercise:text
                                                                kind:(speed ? HRTypSpeedTest : HRTypDrill)
                                                        practiceOnly:(c.type == 'd' || c.type == 's')
                                                         instruction:instruction
                                                            maxError:(maxErrorOnce >= 0.0 ? maxErrorOnce : maxError)]];
                }
                instruction = nil;
                maxErrorOnce = -1.0;
                break;
            }
            case 'E': {
                NSString *v = [data stringByTrimmingCharactersInSet:ws];
                BOOL persistent = [v hasSuffix:@"*"];
                double value = -1.0;
                if (![[v lowercaseString] hasPrefix:@"default"]) value = [v doubleValue];
                if (persistent) { maxError = value; maxErrorOnce = -1.0; }
                else maxErrorOnce = value;
                break;
            }
            case 'M': {
                NSArray *lines = [HRWord linesOfString:data];
                NSString *head = nil;
                NSString *menuTitle = HRQuoted(lines[0], &head) ?: @"";
                NSString *up = nil;
                if ([head hasPrefix:@"UP="]) up = [head substringFromIndex:3];
                NSMutableArray *items = [NSMutableArray array];
                for (NSUInteger i = 1; i < [lines count]; i++) {
                    NSString *label = nil;
                    NSString *itemTitle = HRQuoted(lines[i], &label);
                    if (!itemTitle || [label length] == 0) continue;
                    [items addObject:[[HRTypMenuItem alloc] initWithLabel:label title:itemTitle]];
                    if (!labels[label]) [warnings addObject:HRTypError(c.line + i, [NSString stringWithFormat:@"menu item points at unknown label %@", label])];
                }
                if (up && ![up isEqualToString:@"_EXIT"] && !labels[up]) {
                    [warnings addObject:HRTypError(c.line, [NSString stringWithFormat:@"menu UP points at unknown label %@", up])];
                }
                [menus addObject:[[HRTypMenu alloc] initWithTitle:menuTitle upLabel:up items:items]];
                break;
            }
            case 'G': case 'Y': case 'N': case 'F': {
                NSString *label = [data stringByTrimmingCharactersInSet:ws];
                if ([label hasSuffix:@"*"] && c.type == 'F') label = [label substringToIndex:[label length] - 1];
                if ([label length] > 0 && ![label isEqualToString:@"NULL"] && !labels[label]) {
                    [warnings addObject:HRTypError(c.line, [NSString stringWithFormat:@"%C: points at unknown label %@", c.type, label])];
                }
                break;
            }
            default:
                break;   /* Q, K, X carry nothing a course outline needs */
        }
    }
    flush();

    _lessons = [lessons copy];
    _menus = [menus copy];
    _warnings = [warnings copy];
}

- (NSUInteger)indexOfLabel:(NSString *)label
{
    NSNumber *n = _labelIndex[label];
    return n ? [n unsignedIntegerValue] : NSNotFound;
}

@end
