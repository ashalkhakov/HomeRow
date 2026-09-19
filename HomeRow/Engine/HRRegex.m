/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * HomeRow is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version.  It comes with ABSOLUTELY NO WARRANTY.  See COPYING.
 */
#import "HRRegex.h"
#include "oniguruma.h"

@interface HRRegexMatch ()
- (instancetype)initWithRegion:(OnigRegion *)region;
@end

@implementation HRRegexMatch
{
    NSRange *_ranges;
}

- (instancetype)initWithRegion:(OnigRegion *)region
{
    if ((self = [super init])) {
        _numberOfRanges = (NSUInteger)region->num_regs;
        _ranges = malloc(sizeof(NSRange) * MAX((NSUInteger)1, _numberOfRanges));
        for (NSUInteger i = 0; i < _numberOfRanges; i++) {
            if (region->beg[i] < 0) _ranges[i] = NSMakeRange(NSNotFound, 0);
            /* byte offsets into UTF-16: two bytes to the unit */
            else _ranges[i] = NSMakeRange((NSUInteger)region->beg[i] / 2,
                                          (NSUInteger)(region->end[i] - region->beg[i]) / 2);
        }
    }
    return self;
}

- (void)dealloc
{
    free(_ranges);
}

- (NSRange)rangeAtIndex:(NSUInteger)index
{
    return index < _numberOfRanges ? _ranges[index] : NSMakeRange(NSNotFound, 0);
}

- (NSRange)range
{
    return [self rangeAtIndex:0];
}

@end

@implementation HRRegex
{
    OnigRegex _regex;
}

+ (void)initialize
{
    if (self == [HRRegex class]) {
        OnigEncoding encodings[] = { ONIG_ENCODING_UTF16_LE };
        onig_initialize(encodings, 1);
    }
}

/* "\x20" is one BYTE to Oniguruma, and one byte is not a character in
 * UTF-16 ("too short multibyte code string").  Grammars are written with
 * UTF-8 engines in mind, where it is; "\x{0020}" says the same thing as a
 * code point.  An escaped backslash before the x is left alone. */
static NSString *HRWidenHexEscapes(NSString *pattern)
{
    if ([pattern rangeOfString:@"\\x" options:NSLiteralSearch].location == NSNotFound) return pattern;
    NSMutableString *out = [NSMutableString string];
    NSUInteger n = [pattern length], i = 0;
    NSCharacterSet *hex = [NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdefABCDEF"];
    while (i < n) {
        unichar c = [pattern characterAtIndex:i];
        if (c != '\\' || i + 1 >= n) { [out appendFormat:@"%C", c]; i++; continue; }
        unichar d = [pattern characterAtIndex:i + 1];
        if (d == 'x' && i + 3 < n && [hex characterIsMember:[pattern characterAtIndex:i + 2]]
            && [hex characterIsMember:[pattern characterAtIndex:i + 3]]) {
            [out appendFormat:@"\\x{00%C%C}", [pattern characterAtIndex:i + 2], [pattern characterAtIndex:i + 3]];
            i += 4;
            continue;
        }
        [out appendFormat:@"%C%C", c, d];   /* any other escape, "\\\\" included, as it is */
        i += 2;
    }
    return out;
}

+ (instancetype)regexWithPattern:(NSString *)pattern error:(NSError **)error
{
    HRRegex *r = [[self alloc] init];
    r->_pattern = [pattern copy];
    pattern = HRWidenHexEscapes(pattern);
    NSUInteger n = [pattern length];
    unichar *buffer = malloc(sizeof(unichar) * (n + 1));
    [pattern getCharacters:buffer range:NSMakeRange(0, n)];
    OnigErrorInfo info;
    /* CAPTURE_GROUP: numbered groups stay numbered beside named ones, which
     * is what grammars that mix the two expect */
    int status = onig_new(&r->_regex, (const OnigUChar *)buffer, (const OnigUChar *)(buffer + n),
                          ONIG_OPTION_CAPTURE_GROUP, ONIG_ENCODING_UTF16_LE, ONIG_SYNTAX_DEFAULT, &info);
    free(buffer);
    if (status != ONIG_NORMAL) {
        if (error) {
            OnigUChar message[ONIG_MAX_ERROR_MESSAGE_LEN];
            /* the message quotes the pattern in its own encoding; the code
             * alone is unambiguous */
            onig_error_code_to_str(message, status);
            NSString *text = [NSString stringWithFormat:@"%s: %@", (const char *)message, pattern];
            *error = [NSError errorWithDomain:@"HRRegexErrorDomain" code:status
                                     userInfo:@{NSLocalizedDescriptionKey: text}];
        }
        return nil;
    }
    return r;
}

- (void)dealloc
{
    if (_regex) onig_free(_regex);
}

- (HRRegexMatch *)firstMatchInCharacters:(const unichar *)characters
                                  length:(NSUInteger)length
                               fromIndex:(NSUInteger)start
                                 options:(HRRegexSearchOptions)options
{
    if (start > length) return nil;
    const OnigUChar *begin = (const OnigUChar *)characters;
    const OnigUChar *end = (const OnigUChar *)(characters + length);
    const OnigUChar *from = (const OnigUChar *)(characters + start);
    OnigOptionType onigOptions = ONIG_OPTION_NONE;
    if (options & HRRegexNotBeginString)   onigOptions |= ONIG_OPTION_NOT_BEGIN_STRING;
    if (options & HRRegexNotBeginPosition) onigOptions |= ONIG_OPTION_NOT_BEGIN_POSITION;
    OnigRegion *region = onig_region_new();
    int result = onig_search(_regex, begin, end, from, end, region, onigOptions);
    HRRegexMatch *match = result >= 0 ? [[HRRegexMatch alloc] initWithRegion:region] : nil;
    onig_region_free(region, 1);
    return match;
}

- (HRRegexMatch *)firstMatchInString:(NSString *)string fromIndex:(NSUInteger)start
{
    NSUInteger n = [string length];
    unichar *buffer = malloc(sizeof(unichar) * (n + 1));
    [string getCharacters:buffer range:NSMakeRange(0, n)];
    HRRegexMatch *m = [self firstMatchInCharacters:buffer length:n fromIndex:start options:0];
    free(buffer);
    return m;
}

@end
