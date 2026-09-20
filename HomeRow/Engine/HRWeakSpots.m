/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * HomeRow is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version.  It comes with ABSOLUTELY NO WARRANTY.  See COPYING.
 */
#import "HRWeakSpots.h"
#import "HRStatistics.h"
#import "HRRandom.h"
#import "HRWord.h"

@implementation HRWeakSpots
{
    NSDictionary *_weakness;
}

+ (NSDictionary *)counts:(NSDictionary *)counts keepingCharacters:(NSSet *)characters
{
    if (!characters) return counts;
    NSMutableDictionary *kept = [NSMutableDictionary dictionary];
    for (NSString *ch in counts) {
        /* space and Return belong to every text; they count towards the averages */
        if ([characters containsObject:ch] || [ch isEqualToString:@" "] || [ch isEqualToString:@"\n"]) kept[ch] = counts[ch];
    }
    return kept;
}

+ (instancetype)weakSpotsFromCounts:(NSDictionary *)counts minimumKeyPresses:(NSUInteger)minimumKeyPresses
              minimumTotalPresses:(NSUInteger)minimumTotalPresses maximum:(NSUInteger)maximum
{
    NSUInteger hits = 0, misses = 0;
    for (NSString *ch in counts) {
        hits += [counts[ch][@"hits"] unsignedIntegerValue];
        misses += [counts[ch][@"misses"] unsignedIntegerValue];
    }
    NSUInteger total = hits + misses;
    if (total == 0 || total < minimumTotalPresses) return nil;
    double overall = (double)misses / (double)total;
    /* clearly worse than the rest: half again the overall rate, and never
     * less than one miss in a hundred */
    double threshold = MAX(0.01, overall * 1.5);

    NSMutableArray *weak = [NSMutableArray array];
    for (HRStatKey *k in [HRStatistics keysFromCounts:counts minimumPresses:minimumKeyPresses]) {
        if ([k.character isEqualToString:@" "] || [k.character isEqualToString:@"\n"]) continue;
        if (k.misses < 2 || [k errorRate] < threshold) continue;
        [weak addObject:k];
        if (maximum > 0 && [weak count] >= maximum) break;
    }
    NSMutableArray *characters = [NSMutableArray array];
    NSMutableDictionary *weakness = [NSMutableDictionary dictionary];
    double worst = [weak count] > 0 ? [(HRStatKey *)weak[0] errorRate] : 0.0;
    for (HRStatKey *k in weak) {
        [characters addObject:k.character];
        weakness[k.character] = @(worst > 0.0 ? [k errorRate] / worst : 1.0);
    }
    NSArray *missed = [characters copy];

    /* slow keys fill what room the missed ones leave */
    NSMutableArray *slowOnes = [NSMutableArray array];
    NSTimeInterval average = [HRStatistics averageKeyTimeInCounts:counts];
    if (average > 0.0) {
        double slowest = 0.0;
        for (HRStatKey *k in [HRStatistics slowKeysFromCounts:counts minimumTimed:minimumKeyPresses]) {
            if (maximum > 0 && [characters count] >= maximum) break;
            if ([k.character isEqualToString:@" "] || [k.character isEqualToString:@"\n"]) continue;
            if ([k averageTime] < average * 1.33) break;   /* sorted: the rest is faster still */
            if ([characters containsObject:k.character]) continue;
            double excess = [k averageTime] / average - 1.0;
            if (slowest == 0.0) slowest = excess;
            [characters addObject:k.character];
            [slowOnes addObject:k.character];
            /* a slow key is pressed right, only late: it weighs less than a missed one */
            weakness[k.character] = @(0.6 * (slowest > 0.0 ? excess / slowest : 1.0));
        }
    }
    if ([characters count] == 0) return nil;

    HRWeakSpots *w = [[self alloc] init];
    w->_missedCharacters = missed;
    w->_slowCharacters = [slowOnes copy];
    w->_characters = [characters copy];
    w->_weakness = [weakness copy];
    w->_overallErrorRate = overall;
    return w;
}

- (double)weaknessOfCharacter:(NSString *)character
{
    return [_weakness[character] doubleValue];
}

@end

@implementation HRWeakSpotSource
{
    NSArray *_words;
    HRWeakSpots *_weakSpots;
    HRRandom *_random;
    NSArray *_cumulative;        /* running totals of the word weights, for the draw */
    double _totalWeight;
    NSMutableDictionary *_byInitial;   /* lowercase letter -> words beginning with it, for weak capitals */
    NSArray *_attached;          /* weak characters no word contains and that are not capitals of a letter */
    NSArray *_capitals;          /* weak capitals whose lowercase begins some word */
    NSString *_previous;
}

static NSDictionary *HRClosers(void)
{
    static NSDictionary *pairs = nil;
    if (!pairs) {
        pairs = @{@"(": @")", @"[": @"]", @"{": @"}", @"<": @">", @"\"": @"\"", @"'": @"'", @"`": @"`",
                  @")": @"(", @"]": @"[", @"}": @"{", @">": @"<"};
    }
    return pairs;
}

- (instancetype)initWithWords:(NSArray *)words weakSpots:(HRWeakSpots *)weakSpots random:(HRRandom *)random
{
    if ((self = [super init])) {
        _words = [words count] > 0 ? [words copy] : @[@"home", @"row"];
        _weakSpots = weakSpots;
        _random = random ?: [[HRRandom alloc] initWithSeed:1];

        NSSet *weak = [NSSet setWithArray:weakSpots.characters ?: @[]];
        NSMutableSet *found = [NSMutableSet set];
        NSMutableArray *cumulative = [NSMutableArray arrayWithCapacity:[_words count]];
        _byInitial = [NSMutableDictionary dictionary];
        for (NSString *word in _words) {
            double weight = 1.0;
            NSArray *characters = [HRWord charactersOfString:word];
            for (NSString *ch in characters) {
                if (![weak containsObject:ch]) continue;
                [found addObject:ch];
                /* each occurrence counts: "pepper" is better practice for p than "cup" */
                weight += 6.0 * [weakSpots weaknessOfCharacter:ch];
            }
            _totalWeight += weight;
            [cumulative addObject:@(_totalWeight)];
            if ([characters count] > 0) {
                NSString *initial = characters[0];
                NSMutableArray *list = _byInitial[initial];
                if (!list) { list = [NSMutableArray array]; _byInitial[initial] = list; }
                [list addObject:word];
            }
        }
        _cumulative = cumulative;

        NSMutableArray *attached = [NSMutableArray array], *capitals = [NSMutableArray array];
        for (NSString *ch in weakSpots.characters) {
            if ([found containsObject:ch]) continue;
            NSString *lower = [ch lowercaseString];
            if (![lower isEqualToString:ch] && [_byInitial[lower] count] > 0) [capitals addObject:ch];
            else [attached addObject:ch];
        }
        _attached = attached;
        _capitals = capitals;
    }
    return self;
}

- (BOOL)isFinite
{
    return _limit > 0;
}

- (NSString *)weightedWord
{
    NSString *w = nil;
    for (NSUInteger tries = 0; tries < 16; tries++) {
        double target = [_random nextDouble] * _totalWeight;
        /* the first running total above the target */
        NSUInteger lo = 0, hi = [_cumulative count] - 1;
        while (lo < hi) {
            NSUInteger mid = (lo + hi) / 2;
            if ([_cumulative[mid] doubleValue] > target) hi = mid; else lo = mid + 1;
        }
        w = _words[lo];
        if (![w isEqualToString:_previous] || [_words count] < 2) break;
    }
    _previous = w;
    return w;
}

- (NSString *)capitalized:(NSString *)w
{
    NSRange first = [w rangeOfComposedCharacterSequenceAtIndex:0];
    return [[[w substringWithRange:first] uppercaseString] stringByAppendingString:[w substringFromIndex:NSMaxRange(first)]];
}

- (NSString *)attach:(NSString *)ch to:(NSString *)word
{
    NSString *other = HRClosers()[ch];
    if (other) {
        BOOL opens = [@"([{<\"'`" rangeOfString:ch].location != NSNotFound;
        return opens ? [NSString stringWithFormat:@"%@%@%@", ch, word, other]
                     : [NSString stringWithFormat:@"%@%@%@", other, word, ch];
    }
    /* what usually trails stays behind the word, the rest goes where a coin says */
    if ([@".,;:!?%" rangeOfString:ch].location != NSNotFound) return [word stringByAppendingString:ch];
    if ([@"#$@&*~^-+=_\\|/" rangeOfString:ch].location != NSNotFound && [_random nextDouble] < 0.5) {
        return [ch stringByAppendingString:word];
    }
    return [_random nextDouble] < 0.5 ? [ch stringByAppendingString:word] : [word stringByAppendingString:ch];
}

- (NSArray *)nextWords:(NSUInteger)count
{
    NSSet *weak = [NSSet setWithArray:_weakSpots.characters ?: @[]];
    NSMutableArray *out = [NSMutableArray arrayWithCapacity:count];
    while ([out count] < count) {
        if (_limit > 0 && _produced >= _limit) break;
        NSString *w = nil;
        double p = [_random nextDouble];
        NSUInteger specials = [_capitals count] + [_attached count];
        /* up to two words in five go to what the word list cannot supply */
        double share = specials == 0 ? 0.0 : MIN(0.4, 0.15 * (double)specials);
        if (p < share) {
            NSUInteger pick = [_random nextBelow:specials];
            if (pick < [_capitals count]) {
                NSString *capital = _capitals[pick];
                NSArray *candidates = _byInitial[[capital lowercaseString]];
                w = [self capitalized:candidates[[_random nextBelow:[candidates count]]]];
            } else {
                w = [self attach:_attached[pick - [_capitals count]] to:[self weightedWord]];
            }
        } else {
            w = [self weightedWord];
        }
        _produced++;
        for (NSString *ch in [HRWord charactersOfString:w]) {
            if ([weak containsObject:ch]) { _producedWithWeakCharacter++; break; }
        }
        [out addObject:[HRWord wordWithText:w]];
    }
    return out;
}

@end
