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

typedef NS_OPTIONS(NSUInteger, HRRegexSearchOptions) {
    HRRegexNotBeginString   = 1 << 0,   /* \A does not match (not the first line) */
    HRRegexNotBeginPosition = 1 << 1    /* \G does not match (the last rule did not end here) */
};

/* One match: the ranges of group 0 and the capture groups, in UTF-16
 * units of the searched string; {NSNotFound, 0} for a group that did not
 * take part. */
@interface HRRegexMatch : NSObject
@property (nonatomic, readonly) NSUInteger numberOfRanges;
- (NSRange)rangeAtIndex:(NSUInteger)index;
- (NSRange)range;
@end

/* A compiled Oniguruma pattern (Ruby syntax -- the dialect TextMate
 * grammars are written in).  Works directly on the UTF-16 of an NSString,
 * so its offsets ARE NSString indexes.  Foundation only. */
@interface HRRegex : NSObject

@property (nonatomic, readonly, copy) NSString *pattern;

/* nil, with a description of what is wrong, for a pattern Oniguruma
 * rejects. */
+ (instancetype)regexWithPattern:(NSString *)pattern error:(NSError **)error;

/* The first match at or after `start`.  The whole buffer is the subject,
 * so look-behind sees what precedes `start`; \G matches at `start` unless
 * the options say otherwise.  The buffer form exists because a tokenizer
 * tries dozens of patterns against one line. */
- (HRRegexMatch *)firstMatchInCharacters:(const unichar *)characters
                                  length:(NSUInteger)length
                               fromIndex:(NSUInteger)start
                                 options:(HRRegexSearchOptions)options;

- (HRRegexMatch *)firstMatchInString:(NSString *)string fromIndex:(NSUInteger)start;

@end
