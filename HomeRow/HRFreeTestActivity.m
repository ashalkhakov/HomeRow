/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * HomeRow is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version.  It comes with ABSOLUTELY NO WARRANTY.  See COPYING.
 */
#import "HRFreeTestActivity.h"
#import "HRAppModel.h"
#import "HRStage.h"
#import "HRPacks.h"
#import "HRLanguage.h"
#import "HRKeyboardLayout.h"
#import "HRResultStore.h"
#import "HRManagedObjects.h"
#import "HRTestSession.h"
#import "HRTextSource.h"
#import "HRRandom.h"
#import "HRWeakSpots.h"
#import "HRPace.h"
#import "HRStatistics.h"
#import "HRPreferencesWindowController.h"   /* the pace caret's defaults keys */

#define HRLoc(key) NSLocalizedString(key, nil)

const NSUInteger HRPracticeWords = 40;

@implementation HRFreeTestActivity

#pragma mark - Weak spots

/* What can be practised here: the characters on the keyboard layout in use
 * and those in the word list the round is drawn from (with their capitals).
 * Everything else on record -- the umlauts of a German course, while the
 * round is English on a US keyboard -- is somebody else's weak spot. */
- (NSSet *)practisableCharacters
{
    NSMutableSet *characters = [NSMutableSet set];
    HRKeyboardLayout *layout = [self.model currentLayout];
    for (NSUInteger row = 0; row < [layout numberOfRows]; row++) {
        for (NSUInteger col = 0; col < [layout numberOfKeysInRow:row]; col++) {
            for (NSString *ch in [layout charactersForKeyAtRow:row column:col]) if ([ch length] > 0) [characters addObject:ch];
        }
    }
    for (NSString *word in [self.model currentWords]) {
        for (NSString *ch in [HRWord charactersOfString:word]) {
            [characters addObject:ch];
            [characters addObject:[ch uppercaseString]];
        }
    }
    return characters;
}

/* From the last thirty days if that is enough to go by, otherwise from
 * everything there is: what was a weak key a year ago need not be one now. */
- (HRWeakSpots *)currentWeakSpots
{
    HRResultStore *store = self.model.store;
    if (!store) return nil;
    NSSet *practisable = [self practisableCharacters];
    NSDate *month = [NSDate dateWithTimeIntervalSinceNow:-30.0 * 86400.0];
    for (NSDate *since in @[month, [NSDate distantPast]]) {
        NSDictionary *counts = [HRWeakSpots counts:[store keyCountsForKind:HRStatKindAll since:since]
                                 keepingCharacters:practisable];
        HRWeakSpots *spots = [HRWeakSpots weakSpotsFromCounts:counts
                                            minimumKeyPresses:10 minimumTotalPresses:300 maximum:6];
        if (spots) return spots;
    }
    return nil;
}

#pragma mark - A test

- (id<HRTextSource>)makeSource
{
    HRTestConfiguration *configuration = self.model.configuration;
    switch (configuration.mode) {
        case HRTestModeZen:
        case HRTestModeLesson:   /* not ours */
        case HRTestModeCode:
            return nil;
        case HRTestModePractice: {
            HRWeakSpotSource *source = [[HRWeakSpotSource alloc] initWithWords:[self.model currentWords] weakSpots:_weakSpots
                                                                        random:[HRRandom randomWithSystemSeed]];
            source.limit = HRPracticeWords;
            return source;
        }
        case HRTestModeCustom:
            return [[HRFixedTextSource alloc] initWithText:_customText ?: @""];
        case HRTestModeTime:
        case HRTestModeWords: {
            HRLanguage *language = [self.model currentLanguage];
            NSArray *words = [self.model currentWords];
            /* no pack at all should not mean no app */
            if ([words count] == 0) words = @[@"home", @"row"];
            HRWordListSource *source = [[HRWordListSource alloc] initWithWords:words
                                                                        random:[HRRandom randomWithSystemSeed]];
            source.punctuation = configuration.punctuation && !language.isCode;
            source.numbers = configuration.numbers && !language.isCode;
            if (configuration.mode == HRTestModeWords) source.limit = (NSUInteger)configuration.amount;
            return source;
        }
    }
    return nil;
}

- (void)begin
{
    HRTestConfiguration *configuration = self.model.configuration;
    /* whoever sent us here with a course's or a file's mode meant a test */
    if (configuration.mode == HRTestModeLesson || configuration.mode == HRTestModeCode) configuration.mode = HRTestModeTime;
    /* a custom mode with no text behind it */
    if (configuration.mode == HRTestModeCustom && _customText == nil) configuration.mode = HRTestModeTime;

    NSString *caption = nil;
    if (configuration.mode == HRTestModePractice) {
        /* looked up afresh every round: the round before has just changed it */
        _weakSpots = _weakSpotsForTesting ?: [self currentWeakSpots];
        if (!_weakSpots) {
            [self presentPlaceholder:HRLoc(@"There is not enough on record yet to say which keys are weak \u2014\nor none stands out.\n\nType a few tests, lessons or sections of code first.\nreturn \u2014 a time test")
                              inMode:HRTestModePractice];
            return;
        }
        NSMutableArray *parts = [NSMutableArray array];
        if ([_weakSpots.missedCharacters count] > 0) {
            [parts addObject:[NSString stringWithFormat:HRLoc(@"missed most:   %@"), [_weakSpots.missedCharacters componentsJoinedByString:@"   "]]];
        }
        if ([_weakSpots.slowCharacters count] > 0) {
            [parts addObject:[NSString stringWithFormat:HRLoc(@"slowest:   %@"), [_weakSpots.slowCharacters componentsJoinedByString:@"   "]]];
        }
        /* the words come from the language chosen in the Language menu: say which */
        caption = [NSString stringWithFormat:HRLoc(@"Practising the keys, in %@ \u2014 %@"),
                   [self.model currentLanguage].displayName ?: @"?", [parts componentsJoinedByString:@"      "]];
    }
    [self.host activity:self willPresentInMode:configuration.mode save:NO];
    HRTestSession *session = [[HRTestSession alloc] initWithConfiguration:configuration source:[self makeSource]];
    [self.stage presentSession:session caption:caption codeLayout:NO paceWpm:[self paceWpm]];
}

- (void)leave
{
    _weakSpots = nil;
}

- (void)pageDismissed
{
    /* the "nothing to practise yet" page: on to something that makes a record */
    [self.host activity:self wantsMode:HRTestModeTime];
}

#pragma mark - The pace caret

/* Settled when a test starts: a caret that changed its mind half-way would
 * be no pace at all. */
- (double)paceWpm
{
    HRTestConfiguration *configuration = self.model.configuration;
    if (configuration.mode == HRTestModeZen) return 0.0;
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    NSString *key = [configuration settingsKey];
    switch ((HRPaceKind)[d integerForKey:HRPaceKindDefaultsKey]) {
        case HRPaceOff:
            return 0.0;
        case HRPaceAverage:
            /* nothing on record with these settings yet: nothing to race */
            return [HRPace averageOfRecentSpeeds:[self.model.store recentSpeedsForSettingsKey:key limit:10]];
        case HRPaceBest:
            return [[self.model.store personalBestForSettingsKey:key error:NULL].wpm doubleValue];
        case HRPaceCustom: {
            double wpm = (double)[d integerForKey:HRPaceCustomWpmDefaultsKey];
            return wpm > 0.0 ? wpm : 60.0;
        }
    }
    return 0.0;
}

- (void)paceDidChange
{
    if (self.stage.session && !self.stage.showsResult) self.stage.paceWpm = [self paceWpm];
}

#pragma mark - What it came to

- (void)sessionDidFinish:(HRTestSession *)session
{
    HRTestSummary *s = [session summary];
    HRTestConfiguration *configuration = session.configuration ?: self.model.configuration;
    HRResultStore *store = self.model.store;
    BOOL isBest = NO;
    if (store && [HRActivity summaryIsWorthKeeping:s]) {
        HRTestResult *best = [store personalBestForSettingsKey:[configuration settingsKey] error:NULL];
        isBest = (configuration.mode == HRTestModeTime || configuration.mode == HRTestModeWords)
                 && best != nil && s.wpm > [best.wpm doubleValue];
        NSError *error = nil;
        if (![store recordSummary:s configuration:configuration date:[NSDate date] error:&error]) {
            NSLog(@"HomeRow: the result was not saved: %@", error);
        }
        [self.host activityDidRecordResult:self];
    }
    HRStageResult *result = [HRStageResult resultWithSummary:s];
    result.detail = [NSString stringWithFormat:
        HRLoc(@"raw %.0f   consistency %.0f%%   characters %lu/%lu/%lu/%lu   %.0fs%@"),
        s.rawWpm, s.consistency,
        (unsigned long)s.correctCharacters, (unsigned long)s.incorrectCharacters,
        (unsigned long)s.extraCharacters, (unsigned long)s.missedCharacters,
        s.duration, isBest ? HRLoc(@"   — new personal best") : @""];
    result.hint = HRLoc(@"tab, esc or return — next test");
    result.replayable = YES;
    [self.stage presentResult:result];
}

@end
