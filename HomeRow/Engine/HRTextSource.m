/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * This library is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2.1 of the License, or (at
 * your option) any later version.  See COPYING.LIB.
 */
#import "HRTextSource.h"
#import "HRRandom.h"

@implementation HRWordListSource
{
    NSArray *_words;
    HRRandom *_random;
    NSString *_previous;
    NSUInteger _produced;
    BOOL _capitalizeNext;
}

- (instancetype)initWithWords:(NSArray *)words random:(HRRandom *)random
{
    NSParameterAssert([words count] > 0);
    if ((self = [super init])) {
        _words = [words copy];
        _random = random ?: [[HRRandom alloc] initWithSeed:1];
        _capitalizeNext = YES;
    }
    return self;
}

- (BOOL)isFinite
{
    return _limit > 0;
}

- (NSString *)pickWord
{
    NSString *w = nil;
    NSUInteger tries = 0;
    do {
        w = _words[[_random nextBelow:[_words count]]];
    } while ([w isEqualToString:_previous] && [_words count] > 1 && ++tries < 16);
    _previous = w;
    return w;
}

- (NSString *)numberWord
{
    NSUInteger digits = 1 + [_random nextBelow:4];
    NSMutableString *s = [NSMutableString string];
    for (NSUInteger i = 0; i < digits; i++) {
        [s appendFormat:@"%lu", (unsigned long)[_random nextBelow:10]];
    }
    return s;
}

- (NSString *)capitalized:(NSString *)w
{
    if ([w length] == 0) return w;
    NSRange first = [w rangeOfComposedCharacterSequenceAtIndex:0];
    return [[[w substringWithRange:first] uppercaseString]
            stringByAppendingString:[w substringFromIndex:NSMaxRange(first)]];
}

/* The rates follow what typing sites converged on: a sentence end about
 * every ten words, a comma about as often, the rest rare.  They belong in
 * the language pack eventually (French spaces its "?" and ":"). */
- (NSString *)punctuate:(NSString *)w isLast:(BOOL)isLast
{
    if (_capitalizeNext) {
        w = [self capitalized:w];
        _capitalizeNext = NO;
    }
    double p = [_random nextDouble];
    if (isLast || p < 0.10) {
        double q = [_random nextDouble];
        NSString *end = q < 0.80 ? @"." : (q < 0.90 ? @"?" : @"!");
        _capitalizeNext = YES;
        return [w stringByAppendingString:end];
    }
    if (p < 0.20) return [w stringByAppendingString:@","];
    if (p < 0.23) return [NSString stringWithFormat:@"\"%@\"", w];
    if (p < 0.25) return [NSString stringWithFormat:@"(%@)", w];
    if (p < 0.27) return [w stringByAppendingString:@";"];
    if (p < 0.29) return [w stringByAppendingString:@":"];
    return w;
}

- (NSArray *)nextWords:(NSUInteger)count
{
    NSMutableArray *out = [NSMutableArray arrayWithCapacity:count];
    while ([out count] < count) {
        if (_limit > 0 && _produced >= _limit) break;
        _produced++;
        BOOL isLast = (_limit > 0 && _produced == _limit);
        NSString *w;
        if (_numbers && [_random nextDouble] < 0.10) {
            w = [self numberWord];
            if (_punctuation && isLast) w = [w stringByAppendingString:@"."];
        } else {
            w = [self pickWord];
            if (_punctuation) w = [self punctuate:w isLast:isLast];
        }
        [out addObject:[HRWord wordWithText:w]];
    }
    return out;
}

@end

@implementation HRFixedTextSource
{
    NSArray *_all;
    NSUInteger _cursor;
}

- (instancetype)initWithText:(NSString *)text
{
    if ((self = [super init])) {
        NSMutableArray *words = [NSMutableArray array];
        NSString *normalized = [text stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"];
        normalized = [normalized stringByReplacingOccurrencesOfString:@"\r" withString:@"\n"];
        NSCharacterSet *blank = [NSCharacterSet whitespaceCharacterSet];
        for (NSString *line in [normalized componentsSeparatedByString:@"\n"]) {
            NSMutableArray *lineWords = [NSMutableArray array];
            for (NSString *piece in [line componentsSeparatedByCharactersInSet:blank]) {
                if ([piece length] > 0) [lineWords addObject:piece];
            }
            /* blank lines carry nothing to type */
            NSUInteger n = [lineWords count];
            for (NSUInteger i = 0; i < n; i++) {
                HRSeparator sep = (i + 1 == n) ? HRSeparatorNewline : HRSeparatorSpace;
                [words addObject:[HRWord wordWithText:lineWords[i] separator:sep]];
            }
        }
        _all = [words copy];
    }
    return self;
}

- (BOOL)isFinite
{
    return YES;
}

- (NSArray *)nextWords:(NSUInteger)count
{
    NSUInteger n = MIN(count, [_all count] - _cursor);
    NSArray *out = [_all subarrayWithRange:NSMakeRange(_cursor, n)];
    _cursor += n;
    return out;
}

@end
