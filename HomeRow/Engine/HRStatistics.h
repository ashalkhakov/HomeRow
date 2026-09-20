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

/* What the Statistics window shows, worked out from plain values so that
 * it can be tested without Core Data or a window: the store hands over one
 * HRStatSample per saved result, and everything here is arithmetic. */

typedef NS_ENUM(NSInteger, HRStatKind) {
    HRStatKindAll = 0,
    HRStatKindTests,     /* time, words, custom, zen */
    HRStatKindCourse,    /* exercises of a course */
    HRStatKindCode       /* sections of source files */
};

@interface HRStatSample : NSObject
@property (nonatomic, strong) NSDate *date;
@property (nonatomic, copy) NSString *mode;      /* HRTestConfiguration's modeName */
@property (nonatomic) double wpm;
@property (nonatomic) double rawWpm;
@property (nonatomic) double accuracy;           /* 0...100 */
@property (nonatomic) NSTimeInterval duration;
/* Share of the keystrokes that did not end up as text, 0...1; negative when
 * the result is from before it was recorded. */
@property (nonatomic) double overhead;
- (HRStatKind)kind;
@end

/* One day, in the time zone given. */
@interface HRStatDay : NSObject
@property (nonatomic, strong) NSDate *day;       /* its first moment */
@property (nonatomic) NSUInteger count;
@property (nonatomic) NSTimeInterval duration;   /* seconds of typing */
@property (nonatomic) double wpm;                /* time-weighted */
@property (nonatomic) double accuracy;           /* time-weighted */
@end

@interface HRStatKey : NSObject
@property (nonatomic, copy) NSString *character;
@property (nonatomic) NSUInteger hits;
@property (nonatomic) NSUInteger misses;
@property (nonatomic) NSUInteger timedHits;      /* hits whose time was taken */
@property (nonatomic) NSTimeInterval totalTime;  /* what those took together */
- (double)errorRate;                             /* misses / (hits + misses), 0...1 */
- (NSTimeInterval)averageTime;                   /* seconds per timed hit; 0 when none */
@end

extern NSString * const HRKeyClassLetters;
extern NSString * const HRKeyClassCapitals;
extern NSString * const HRKeyClassDigits;
extern NSString * const HRKeyClassBrackets;
extern NSString * const HRKeyClassOperators;
extern NSString * const HRKeyClassPunctuation;
extern NSString * const HRKeyClassWhitespace;

@interface HRStatistics : NSObject

/* `samples` in any order; kept oldest first.  `days` 0 = everything,
 * otherwise only what is younger than that many days before `now`. */
- (instancetype)initWithSamples:(NSArray *)samples
                           kind:(HRStatKind)kind
                           days:(NSUInteger)days
                            now:(NSDate *)now
                       timeZone:(NSTimeZone *)timeZone;

@property (nonatomic, readonly, copy) NSArray *samples;      /* HRStatSample, oldest first */

/* headline numbers; 0 when there are no samples */
@property (nonatomic, readonly) NSUInteger count;
@property (nonatomic, readonly) NSTimeInterval totalDuration;
@property (nonatomic, readonly) double averageWpm;           /* time-weighted */
@property (nonatomic, readonly) double bestWpm;
@property (nonatomic, readonly) double averageAccuracy;      /* time-weighted */
@property (nonatomic, readonly) double recentWpm;            /* mean of the last ten */
/* Keystroke-weighted would be truer, but the keystrokes are not always on
 * record: time-weighted, over the results that have it; negative when none. */
@property (nonatomic, readonly) double averageOverhead;

/* The mean of each sample and the up to `window - 1` before it: the trend
 * line under the dots.  One NSNumber per sample. */
- (NSArray *)movingAverageOfKey:(NSString *)key window:(NSUInteger)window;

/* Every day from the first with a sample to the last, the empty ones
 * included -- a gap in the practice is part of the picture. */
- (NSArray *)days;

/* Keys sorted by error rate, worst first; those pressed fewer than
 * `minimumPresses` times are left out (one slip in two presses is not 50%
 * of anything).  `counts`: character -> @{@"hits", @"misses"}. */
+ (NSArray *)keysFromCounts:(NSDictionary *)counts minimumPresses:(NSUInteger)minimumPresses;

/* Keys sorted by the time they take, slowest first; those timed fewer than
 * `minimumTimed` times are left out.  Same `counts`, with @"timed" and
 * @"time" beside the hits and misses (results saved before timing was
 * recorded simply have none). */
+ (NSArray *)slowKeysFromCounts:(NSDictionary *)counts minimumTimed:(NSUInteger)minimumTimed;
/* Seconds per timed hit over all keys; 0 when nothing was timed. */
+ (NSTimeInterval)averageKeyTimeInCounts:(NSDictionary *)counts;

/* Keys by kind -- what code is made of, and prose mostly is not.  Rows in a
 * fixed order (letters, capitals, digits, brackets, operators, punctuation,
 * space and return), those without presses left out: HRStatKey, with
 * `character` holding the class's name (HRKeyClass...). */
+ (NSArray *)keyClassesFromCounts:(NSDictionary *)counts;
/* "letters 1% 190 ms   brackets 6% 480 ms   ..." -- names through `names`
 * (class -> display name), times left out where nothing was timed. */
+ (NSString *)lineForKeyClasses:(NSArray *)classes names:(NSDictionary *)names;
+ (NSString *)classOfCharacter:(NSString *)character;

/* "Jan 10" -- by arithmetic, for the same reason -days avoids NSCalendar
 * (NSDateFormatter is as empty-handed without ICU). */
+ (NSString *)shortStringForDate:(NSDate *)date timeZone:(NSTimeZone *)timeZone;
/* "Jan 10, 2026" -- for the tables of lessons and sections. */
+ (NSString *)mediumStringForDate:(NSDate *)date timeZone:(NSTimeZone *)timeZone;

/* "1 h 05 min", "12 min", "40 s" */
+ (NSString *)stringForDuration:(NSTimeInterval)duration;

@end
