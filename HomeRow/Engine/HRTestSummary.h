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

/* The numbers a finished test comes down to.  Definitions are in
 * docs/metrics.md and pinned by HRScorerTests; they follow MonkeyType so
 * that results are comparable. */
@interface HRTestSummary : NSObject

@property (nonatomic) double wpm;
@property (nonatomic) double rawWpm;
@property (nonatomic) double accuracy;     /* 0...100 */
@property (nonatomic) double consistency;  /* 0...100 */
@property (nonatomic) NSTimeInterval duration;

@property (nonatomic) NSUInteger correctCharacters;
@property (nonatomic) NSUInteger incorrectCharacters;
@property (nonatomic) NSUInteger extraCharacters;
@property (nonatomic) NSUInteger missedCharacters;

@property (nonatomic) NSUInteger correctKeystrokes;
@property (nonatomic) NSUInteger incorrectKeystrokes;

/* One NSNumber per second of the test: raw WPM in that second, and the
 * number of wrong keystrokes in it. */
@property (nonatomic, copy) NSArray *rawWpmPerSecond;
@property (nonatomic, copy) NSArray *errorsPerSecond;

/* character -> @{ @"hits": n, @"misses": n }.  A miss is charged to the
 * character that was expected, which is the key the learner has to
 * practise. */
@property (nonatomic, copy) NSDictionary *keyStats;

@end

@interface HRScorer : NSObject

/* characters per minute / 5 */
+ (double)wpmForCharacters:(NSUInteger)characters duration:(NSTimeInterval)seconds;

/* 100 * (1 - tanh(cv + cv^3/3 + cv^5/5)), cv = stddev / mean.
 * 100 for a perfectly even pace, falling towards 0 as it gets erratic. */
+ (double)consistencyForSamples:(NSArray *)samples;

@end
