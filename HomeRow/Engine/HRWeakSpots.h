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

@class HRRandom;

/* Which keys to practise, worked out from the hits and misses the results
 * carry (character -> @{@"hits", @"misses"}, as HRResultStore sums them).
 *
 * A key is weak when it is missed clearly more often than this typist's
 * keys are on the whole -- so that a careful typist still gets their worst
 * keys, and a careless one is not told that every key is weak -- and it has
 * been pressed often enough for that to mean something. */
@interface HRWeakSpots : NSObject

/* The counts of the characters that can come up at all: what was typed
 * in a German course has no say in an English round on a US keyboard -- ü
 * is on no key there and in no word, and practising it would mean typing
 * "üthe".  `characters`: what the keyboard layout has and the word list uses. */
+ (NSDictionary *)counts:(NSDictionary *)counts keepingCharacters:(NSSet *)characters;

/* nil when there is too little on record to say (fewer than
 * `minimumTotalPresses` keystrokes, or no key stands out). */
+ (instancetype)weakSpotsFromCounts:(NSDictionary *)counts
                minimumKeyPresses:(NSUInteger)minimumKeyPresses
              minimumTotalPresses:(NSUInteger)minimumTotalPresses
                          maximum:(NSUInteger)maximum;

/* Worst first.  Space and Return are never among them: every word already
 * has one.  The missed ones lead, the slow ones follow. */
@property (nonatomic, readonly, copy) NSArray *characters;
/* The two kinds apart, for saying which is which.  A key is SLOW when it
 * takes clearly longer than this typist's keys do on the whole (a third
 * longer, over at least `minimumKeyPresses` timed hits); a key that is both
 * is listed as missed. */
@property (nonatomic, readonly, copy) NSArray *missedCharacters;
@property (nonatomic, readonly, copy) NSArray *slowCharacters;
/* 0...1 per character: its error rate relative to the worst one's. */
- (double)weaknessOfCharacter:(NSString *)character;
@property (nonatomic, readonly) double overallErrorRate;

@end

/* A drill for those keys out of a language's word list:
 *
 *  - words containing the weak letters come up more often, the more of them
 *    and the weaker, the more so -- but other words still appear, so that it
 *    reads like text and not like a punishment;
 *  - a weak CAPITAL gets words beginning with that letter, capitalised;
 *  - what no word contains -- digits, brackets, the symbols of code -- is
 *    attached to words: wrapped around them when it is one of a pair,
 *    otherwise put before or after.
 */
@interface HRWeakSpotSource : NSObject <HRTextSource>

- (instancetype)initWithWords:(NSArray *)words
                    weakSpots:(HRWeakSpots *)weakSpots
                       random:(HRRandom *)random;

@property (nonatomic) NSUInteger limit;   /* words; 0 = endless */

/* How many of the words produced so far contain at least one of the weak
 * characters; for tests. */
@property (nonatomic, readonly) NSUInteger produced;
@property (nonatomic, readonly) NSUInteger producedWithWeakCharacter;

@end
