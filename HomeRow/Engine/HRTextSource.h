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
#import "HRWord.h"

@class HRRandom;
@class HRLanguage;

/* Where target words come from.  A session pulls words as it needs them,
 * so an endless source (time mode) and a finite one (custom text) look the
 * same from the session's side. */
@protocol HRTextSource <NSObject>

/* Up to `count` further words; fewer, or none, when the source is
 * exhausted.  Endless sources always return `count`. */
- (NSArray *)nextWords:(NSUInteger)count;

/* YES when the source can run dry. */
- (BOOL)isFinite;

@end

/* Random words from a list, MonkeyType style: uniform choice, never the
 * same word twice in a row, optional punctuation and numbers. */
@interface HRWordListSource : NSObject <HRTextSource>

@property (nonatomic) BOOL punctuation;
@property (nonatomic) BOOL numbers;
/* 0 = endless.  Otherwise the source stops after this many words. */
@property (nonatomic) NSUInteger limit;

- (instancetype)initWithWords:(NSArray *)words random:(HRRandom *)random;

@end

/* A fixed text.  Runs of spaces collapse to one separator; a line break is
 * a separator of its own kind, typed with Return.  Leading whitespace on a
 * line is dropped -- Code mode will want it auto-filled, which is a later
 * source, not a change to this one. */
@interface HRFixedTextSource : NSObject <HRTextSource>

- (instancetype)initWithText:(NSString *)text;

@end
