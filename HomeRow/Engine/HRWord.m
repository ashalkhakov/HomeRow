/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * HomeRow is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version.  It comes with ABSOLUTELY NO WARRANTY.  See COPYING.
 */
#import "HRWord.h"

/* Precomposed (NFC) throughout: a word list saved decomposed and a keyboard
 * that delivers precomposed characters must still compare equal.
 *
 * gnustep-base implements the normalization through ICU and raises "not
 * implemented" when it was configured without it.  The CI stack has ICU;
 * a stack without it still has to run, just without this nicety. */
static NSString *HRPrecomposed(NSString *string)
{
    static int available = -1;
    if (available == 0 || [string canBeConvertedToEncoding:NSASCIIStringEncoding]) return string;
    @try {
        NSString *normalized = [string precomposedStringWithCanonicalMapping];
        available = 1;
        return normalized ?: string;
    } @catch (NSException *e) {
        available = 0;
        return string;
    }
}

@implementation HRWord

+ (NSArray *)linesOfString:(NSString *)string
{
    NSMutableArray *lines = [NSMutableArray array];
    NSUInteger n = [string length], start = 0;
    for (NSUInteger i = 0; i < n; i++) {
        unichar c = [string characterAtIndex:i];
        if (c != '\n' && c != '\r') continue;
        [lines addObject:[string substringWithRange:NSMakeRange(start, i - start)]];
        if (c == '\r' && i + 1 < n && [string characterAtIndex:i + 1] == '\n') i++;
        start = i + 1;
    }
    [lines addObject:[string substringFromIndex:start]];
    return lines;
}

+ (NSArray *)charactersOfString:(NSString *)string
{
    string = HRPrecomposed(string);
    NSMutableArray *out = [NSMutableArray arrayWithCapacity:[string length]];
    NSUInteger i = 0, n = [string length];
    while (i < n) {
        NSRange r = [string rangeOfComposedCharacterSequenceAtIndex:i];
        [out addObject:[string substringWithRange:r]];
        i = NSMaxRange(r);
    }
    return out;
}

- (instancetype)initWithText:(NSString *)text separator:(HRSeparator)separator
{
    if ((self = [super init])) {
        _text = [HRPrecomposed(text) copy];
        _characters = [[[self class] charactersOfString:_text] copy];
        _separator = separator;
    }
    return self;
}

+ (instancetype)wordWithText:(NSString *)text
{
    return [[self alloc] initWithText:text separator:HRSeparatorSpace];
}

+ (instancetype)wordWithText:(NSString *)text separator:(HRSeparator)separator
                      prefix:(NSString *)prefix suffix:(NSString *)suffix styles:(NSData *)styles
{
    HRWord *w = [[self alloc] initWithText:text separator:separator];
    w->_prefix = [prefix length] > 0 ? [prefix copy] : nil;
    w->_suffix = [suffix length] > 0 ? [suffix copy] : nil;
    /* styles are per composed character; a mismatch means "do not trust" */
    w->_styles = [styles length] == [w->_characters count] ? [styles copy] : nil;
    return w;
}

- (uint8_t)styleOfCharacterAtIndex:(NSUInteger)index
{
    return index < [_styles length] ? ((const uint8_t *)[_styles bytes])[index] : HRTextStylePlain;
}

+ (instancetype)wordWithText:(NSString *)text separator:(HRSeparator)separator
{
    return [[self alloc] initWithText:text separator:separator];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<HRWord %@%@>", _text,
            _separator == HRSeparatorNewline ? @"\\n" : @""];
}

@end

@implementation NSString (HRNormalization)
- (NSString *)precomposedStringWithCanonicalMappingIfAvailable
{
    return HRPrecomposed(self);
}
@end
