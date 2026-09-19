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
#import "HRTextSource.h"

@class HRTextMateGrammar;

/* A source file prepared for typing, the way Typing.io presents one:
 *
 *  - you type the code; indentation, blank lines and the extra blanks of
 *    aligned columns fill themselves in (HRWord's prefix);
 *  - comments are shown and, unless asked for, not typed -- they practise
 *    prose, which the other modes do better;
 *  - the file is cut into sections of a sitting's length, at blank lines,
 *    preferably before top-level code.
 *
 * The grammar gives the colours and says what is a comment.  Without one
 * the text is plain and every character is typed.  Foundation only. */
@interface HRCodeDocument : NSObject

@property (nonatomic, readonly, copy) NSArray *lines;        /* NSString, tabs expanded */
@property (nonatomic, readonly) NSUInteger numberOfSections;

/* `tabWidth` 0 means 4.  `targetSectionLines` 0 means 50. */
- (instancetype)initWithText:(NSString *)text
                     grammar:(HRTextMateGrammar *)grammar
                    tabWidth:(NSUInteger)tabWidth
          targetSectionLines:(NSUInteger)targetSectionLines;

/* Lines [location, location+length) of a section. */
- (NSRange)lineRangeOfSection:(NSUInteger)section;
/* What there is to type in a section; nil if it holds nothing to type. */
- (id<HRTextSource>)sourceForSection:(NSUInteger)section typeComments:(BOOL)typeComments;
/* The same for an arbitrary run of lines. */
- (NSArray *)wordsForLines:(NSRange)lineRange typeComments:(BOOL)typeComments;

/* Maps TextMate scopes to one of HomeRow's few styles, innermost first. */
+ (uint8_t)styleForScopes:(NSArray *)scopes;

@end

/* A source over ready-made words. */
@interface HRWordArraySource : NSObject <HRTextSource>
- (instancetype)initWithWords:(NSArray *)words;
@end
