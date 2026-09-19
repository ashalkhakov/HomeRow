/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * HomeRow is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version.  It comes with ABSOLUTELY NO WARRANTY.  See COPYING.
 */
#import "HRTestSession.h"

/* How far ahead of the caret an endless source is kept filled.  Enough for
 * the three visible lines at any sane window width. */
static const NSUInteger HRLookahead = 60;
/* Extra characters accepted past a word's end; more is only noise. */
static const NSUInteger HRMaxExtra = 20;
/* a key that took longer than this was not being typed: it was being looked for, or waited on */
static const NSTimeInterval HRLongestKeyTime = 2.0;

@implementation HRTestSession
{
    id<HRTextSource> _source;
    NSMutableArray *_words;        /* HRWord */
    NSMutableArray *_typed;        /* NSMutableArray of NSString, one per word reached */
    NSMutableArray *_committed;    /* NSNumber BOOL per word: separator was typed */
    BOOL _sourceExhausted;

    NSTimeInterval _startTime;
    NSTimeInterval _endTime;

    NSTimeInterval _lastKeystrokeTime;   /* for the time a key takes, see -recordKeystrokeCorrect: */
    BOOL _lastKeystrokeWasCorrect, _haveLastKeystroke;

    NSUInteger _correctKeystrokes;
    NSUInteger _incorrectKeystrokes;
    NSMutableArray *_keysPerSecond;    /* NSNumber */
    NSMutableArray *_errorsPerSecond;  /* NSNumber */
    NSMutableDictionary *_keyStats;    /* char -> NSMutableDictionary */
}

- (instancetype)initWithConfiguration:(HRTestConfiguration *)configuration
                               source:(id<HRTextSource>)source
{
    if ((self = [super init])) {
        _configuration = [configuration copy];
        _source = source;
        _words = [NSMutableArray array];
        _typed = [NSMutableArray arrayWithObject:[NSMutableArray array]];
        _committed = [NSMutableArray array];
        _keysPerSecond = [NSMutableArray array];
        _errorsPerSecond = [NSMutableArray array];
        _keyStats = [NSMutableDictionary dictionary];
        if (_configuration.mode == HRTestModeZen) {
            _sourceExhausted = YES;
        } else {
            [self fill];
        }
    }
    return self;
}

- (NSArray *)words
{
    return _words;
}

- (BOOL)isZen
{
    return _configuration.mode == HRTestModeZen;
}

- (void)fill
{
    if (_sourceExhausted || _source == nil) return;
    if ([_source isFinite]) {
        /* finite texts are loaded whole: "words left" needs the total */
        for (;;) {
            NSArray *more = [_source nextWords:256];
            [_words addObjectsFromArray:more];
            if ([more count] < 256) break;
        }
        _sourceExhausted = YES;
        return;
    }
    while ([_words count] < _currentWordIndex + HRLookahead) {
        NSArray *more = [_source nextWords:HRLookahead];
        if ([more count] == 0) { _sourceExhausted = YES; break; }
        [_words addObjectsFromArray:more];
    }
}

#pragma mark - Clock and bookkeeping

- (void)startIfNeededAtTime:(NSTimeInterval)time
{
    if (_state == HRSessionIdle) {
        _state = HRSessionRunning;
        _startTime = time;
    }
}

/* YES when the test is (now) over and the input must be dropped. */
- (BOOL)expireAtTime:(NSTimeInterval)time
{
    if (_state == HRSessionFinished) return YES;
    if (_state == HRSessionRunning && _configuration.mode == HRTestModeTime
        && time - _startTime >= (NSTimeInterval)_configuration.amount) {
        /* the test ended when its time ran out, not when we noticed */
        [self endAtTime:_startTime + (NSTimeInterval)_configuration.amount];
        return YES;
    }
    return NO;
}

- (void)endAtTime:(NSTimeInterval)time
{
    if (_state == HRSessionFinished) return;
    if (_state == HRSessionIdle) _startTime = time;
    _endTime = time;
    _state = HRSessionFinished;
}

- (void)bump:(NSMutableArray *)buckets atTime:(NSTimeInterval)time
{
    NSUInteger second = (NSUInteger)MAX(0.0, floor(time - _startTime));
    while ([buckets count] <= second) [buckets addObject:@0];
    buckets[second] = @([buckets[second] unsignedIntegerValue] + 1);
}

- (void)recordKeystrokeCorrect:(BOOL)correct expected:(NSString *)expected atTime:(NSTimeInterval)time
{
    if (correct) _correctKeystrokes++; else _incorrectKeystrokes++;
    [self bump:_keysPerSecond atTime:time];
    if (!correct) [self bump:_errorsPerSecond atTime:time];
    if ([expected length] > 0) {
        NSMutableDictionary *s = _keyStats[expected];
        if (!s) {
            s = [@{@"hits": @0, @"misses": @0} mutableCopy];
            _keyStats[expected] = s;
        }
        NSString *k = correct ? @"hits" : @"misses";
        s[k] = @([s[k] unsignedIntegerValue] + 1);
        /* How long the key took: the time since the keystroke before it --
         * for a key that was hit, straight after a key that was hit.  After
         * a mistake the hand is somewhere else; after a pause the mind was;
         * and text typed in one go (paste, tests) has no time in it. */
        NSTimeInterval gap = time - _lastKeystrokeTime;
        if (correct && _lastKeystrokeWasCorrect && _haveLastKeystroke && gap > 0.0 && gap <= HRLongestKeyTime) {
            s[@"time"] = @([s[@"time"] doubleValue] + gap);
            s[@"timed"] = @([s[@"timed"] unsignedIntegerValue] + 1);
        }
    }
    _lastKeystrokeTime = time;
    _lastKeystrokeWasCorrect = correct;
    _haveLastKeystroke = YES;
}

#pragma mark - Input

- (NSMutableArray *)currentTyped
{
    return _typed[_currentWordIndex];
}

- (HRWord *)currentWord
{
    return _currentWordIndex < [_words count] ? _words[_currentWordIndex] : nil;
}

- (void)insertText:(NSString *)text atTime:(NSTimeInterval)time
{
    for (NSString *ch in [HRWord charactersOfString:text]) {
        if ([self expireAtTime:time]) return;
        if ([ch isEqualToString:@" "]) {
            [self typeSeparator:HRSeparatorSpace atTime:time];
        } else if ([ch isEqualToString:@"\n"] || [ch isEqualToString:@"\r"]) {
            [self typeSeparator:HRSeparatorNewline atTime:time];
        } else {
            [self typeCharacter:ch atTime:time];
        }
    }
}

- (void)noteWrongInput:(NSString *)input refused:(BOOL)refused
{
    _wrongInputCount++;
    _lastWrongInput = [input copy];
    _lastWrongInputWasRefused = refused;
}

- (void)typeCharacter:(NSString *)ch atTime:(NSTimeInterval)time
{
    [self startIfNeededAtTime:time];
    NSMutableArray *typed = [self currentTyped];

    if ([self isZen]) {
        [typed addObject:ch];
        [self recordKeystrokeCorrect:YES expected:ch atTime:time];
        return;
    }

    HRWord *word = [self currentWord];
    if (!word) return;
    NSArray *target = word.characters;
    NSUInteger pos = [typed count];
    if (pos >= [target count] + HRMaxExtra) return;

    NSString *expected = pos < [target count] ? target[pos] : nil;
    BOOL correct = expected != nil && [expected isEqualToString:ch];
    /* stop on error: the wrong key counts, and that is all it does */
    if (correct || !_configuration.stopOnError) [typed addObject:ch];
    if (!correct) [self noteWrongInput:ch refused:_configuration.stopOnError];
    /* an extra character is charged to the separator that should have
     * been pressed instead */
    [self recordKeystrokeCorrect:correct expected:(expected ?: @" ") atTime:time];

    /* A finite test ends with the last character of its last word, as long
     * as that word is right; a wrong one waits for a fix or a separator. */
    if (_sourceExhausted && _currentWordIndex + 1 == [_words count]
        && [typed isEqualToArray:target]) {
        [self endAtTime:time];
    }
}

- (void)typeSeparator:(HRSeparator)separator atTime:(NSTimeInterval)time
{
    NSMutableArray *typed = [self currentTyped];

    if ([self isZen]) {
        if ([typed count] == 0) return;
        [self startIfNeededAtTime:time];
        [self recordKeystrokeCorrect:YES expected:@" " atTime:time];
        [_words addObject:[HRWord wordWithText:[typed componentsJoinedByString:@""] separator:separator]];
        [_committed addObject:@YES];
        _currentWordIndex++;
        [_typed addObject:[NSMutableArray array]];
        return;
    }

    HRWord *word = [self currentWord];
    if (!word) return;
    /* a separator before anything is typed is a stray key, not a skipped
     * word: skipping whole words by leaning on the space bar helps nobody */
    if ([typed count] == 0) return;

    [self startIfNeededAtTime:time];
    NSString *expected = word.separator == HRSeparatorNewline ? @"\n" : @" ";
    if (separator != word.separator) {
        /* Return where a space belongs, or the reverse: wrong key, no move */
        [self noteWrongInput:(separator == HRSeparatorNewline ? @"\n" : @" ") refused:YES];
        [self recordKeystrokeCorrect:NO expected:expected atTime:time];
        return;
    }
    BOOL wordCorrect = [typed isEqualToArray:word.characters];
    if (!wordCorrect && _configuration.stopPolicy != HRStopNever) {
        /* the word is not finished: a separator here is a wrong key too */
        [self noteWrongInput:expected refused:YES];
        [self recordKeystrokeCorrect:NO expected:([typed count] < [word.characters count] ? word.characters[[typed count]] : expected) atTime:time];
        return;
    }
    /* leaving a wrong or unfinished word is itself the error */
    if (!wordCorrect) [self noteWrongInput:expected refused:NO];
    [self recordKeystrokeCorrect:wordCorrect expected:expected atTime:time];
    [_committed addObject:@YES];

    if (_currentWordIndex + 1 >= [_words count] && _sourceExhausted) {
        [self endAtTime:time];
        return;
    }
    _currentWordIndex++;
    [_typed addObject:[NSMutableArray array]];
    [self fill];
}

- (BOOL)stepBackIntoPreviousWord
{
    if (_currentWordIndex == 0) return NO;
    if (_configuration.backspacePolicy != HRBackspaceFree) return NO;
    if ([self isZen]) return NO;
    HRWord *prev = _words[_currentWordIndex - 1];
    /* a word that was right is done with; only mistakes can be revisited */
    if ([_typed[_currentWordIndex - 1] isEqualToArray:prev.characters]) return NO;
    [_typed removeLastObject];
    [_committed removeLastObject];
    _currentWordIndex--;
    return YES;
}

/* "No backspace" and "a word must be right before it is left" together
 * would be a trap: one slip and the test can neither go on nor back.  The
 * word being typed can then still be corrected. */
- (BOOL)backspaceIsOff
{
    return _configuration.backspacePolicy == HRBackspaceNone && _configuration.stopPolicy != HRStopOnWord;
}

- (void)deleteBackwardAtTime:(NSTimeInterval)time
{
    if ([self expireAtTime:time] || _state != HRSessionRunning) return;
    if ([self backspaceIsOff]) return;
    _lastKeystrokeWasCorrect = NO;   /* the hand has been to Backspace: the next key is not timed */
    NSMutableArray *typed = [self currentTyped];
    if ([typed count] > 0) {
        [typed removeLastObject];
    } else {
        [self stepBackIntoPreviousWord];
    }
}

- (void)deleteWordBackwardAtTime:(NSTimeInterval)time
{
    if ([self expireAtTime:time] || _state != HRSessionRunning) return;
    if ([self backspaceIsOff]) return;
    _lastKeystrokeWasCorrect = NO;   /* the hand has been to Backspace: the next key is not timed */
    NSMutableArray *typed = [self currentTyped];
    if ([typed count] == 0 && ![self stepBackIntoPreviousWord]) return;
    [[self currentTyped] removeAllObjects];
}

- (void)tickAtTime:(NSTimeInterval)time
{
    [self expireAtTime:time];
}

- (void)finishAtTime:(NSTimeInterval)time
{
    if (![self expireAtTime:time]) [self endAtTime:time];
}

#pragma mark - Reading

- (NSArray *)typedCharactersForWordAtIndex:(NSUInteger)index
{
    return index < [_typed count] ? _typed[index] : @[];
}

- (NSArray *)targetCharactersForWordAtIndex:(NSUInteger)index
{
    if (index < [_words count]) return ((HRWord *)_words[index]).characters;
    /* zen: the word being typed has no target yet */
    return [self typedCharactersForWordAtIndex:index];
}

- (NSUInteger)displayLengthOfWordAtIndex:(NSUInteger)index
{
    return MAX([[self targetCharactersForWordAtIndex:index] count],
               [[self typedCharactersForWordAtIndex:index] count]);
}

- (HRCharacterState)stateOfCharacterAtIndex:(NSUInteger)ci inWordAtIndex:(NSUInteger)wi
{
    NSArray *target = [self targetCharactersForWordAtIndex:wi];
    NSArray *typed = [self typedCharactersForWordAtIndex:wi];
    if (ci < [typed count]) {
        if (ci >= [target count]) return HRCharacterExtra;
        return [typed[ci] isEqualToString:target[ci]] ? HRCharacterCorrect : HRCharacterIncorrect;
    }
    return wi < _currentWordIndex ? HRCharacterMissed : HRCharacterUntyped;
}

- (NSString *)displayCharacterAtIndex:(NSUInteger)ci inWordAtIndex:(NSUInteger)wi
{
    NSArray *target = [self targetCharactersForWordAtIndex:wi];
    if (ci < [target count]) return target[ci];
    NSArray *typed = [self typedCharactersForWordAtIndex:wi];
    return ci < [typed count] ? typed[ci] : @"";
}

- (NSString *)expectedInput
{
    if (_state == HRSessionFinished || [self isZen]) return nil;
    HRWord *word = [self currentWord];
    if (!word) return nil;
    NSArray *typed = [self currentTyped];
    NSArray *target = word.characters;
    NSUInteger n = [typed count];
    /* a mistake behind the caret comes first -- if it can be taken back */
    if (![self backspaceIsOff]) {
        if (n > [target count]) return @"\b";
        for (NSUInteger i = 0; i < n; i++) {
            if (![typed[i] isEqualToString:target[i]]) return @"\b";
        }
    }
    if (n < [target count]) return target[n];
    return word.separator == HRSeparatorNewline ? @"\n" : @" ";
}

- (NSUInteger)caretIndexInCurrentWord
{
    return [[self currentTyped] count];
}

- (NSTimeInterval)elapsedAtTime:(NSTimeInterval)time
{
    switch (_state) {
        case HRSessionIdle:     return 0.0;
        case HRSessionRunning:  return MAX(0.0, time - _startTime);
        case HRSessionFinished: return _endTime - _startTime;
    }
    return 0.0;
}

- (NSInteger)remainingAtTime:(NSTimeInterval)time
{
    switch (_configuration.mode) {
        case HRTestModeTime: {
            double left = (double)_configuration.amount - [self elapsedAtTime:time];
            return (NSInteger)ceil(MAX(0.0, left));
        }
        case HRTestModeWords:
        case HRTestModeCustom:
        case HRTestModeLesson:
        case HRTestModeCode:
        case HRTestModePractice:
            return (NSInteger)[_words count] - (NSInteger)[_committed count];
        case HRTestModeZen:
            return -1;
    }
    return -1;
}

/* Walks what was typed and fills the character counts of `s`; returns the
 * characters that count towards WPM through `outWpmChars` and everything
 * typed through `outRawChars`. */
- (void)tallyInto:(HRTestSummary *)s wpmCharacters:(NSUInteger *)outWpmChars rawCharacters:(NSUInteger *)outRawChars
{
    NSUInteger wpmChars = 0, rawChars = 0;
    NSUInteger correct = 0, incorrect = 0, extra = 0, missed = 0;
    NSUInteger reached = [_typed count];

    for (NSUInteger wi = 0; wi < reached; wi++) {
        NSArray *typed = _typed[wi];
        NSArray *target = [self targetCharactersForWordAtIndex:wi];
        BOOL committed = wi < [_committed count];
        NSUInteger n = MIN([typed count], [target count]);
        NSUInteger wordCorrect = 0;
        for (NSUInteger i = 0; i < n; i++) {
            if ([typed[i] isEqualToString:target[i]]) wordCorrect++;
        }
        correct += wordCorrect;
        incorrect += n - wordCorrect;
        if ([typed count] > [target count]) extra += [typed count] - [target count];

        BOOL whole = [typed isEqualToArray:target];
        if (committed) {
            if ([target count] > [typed count]) missed += [target count] - [typed count];
            rawChars += [typed count] + 1;
            if (whole) wpmChars += [target count] + 1;
        } else {
            /* the word the test ended in: what is there counts if it is
             * right so far, and its untyped rest is not held against you */
            rawChars += [typed count];
            BOOL prefixOK = (wordCorrect == [typed count]) && [typed count] <= [target count];
            if (prefixOK) wpmChars += [typed count];
        }
    }
    s.correctCharacters = correct;
    s.incorrectCharacters = incorrect;
    s.extraCharacters = extra;
    s.missedCharacters = missed;
    if (outWpmChars) *outWpmChars = wpmChars;
    if (outRawChars) *outRawChars = rawChars;
}

- (double)liveWpmAtTime:(NSTimeInterval)time
{
    HRTestSummary *scratch = [[HRTestSummary alloc] init];
    NSUInteger wpmChars = 0;
    [self tallyInto:scratch wpmCharacters:&wpmChars rawCharacters:NULL];
    NSTimeInterval t = [self elapsedAtTime:time];
    /* the first second is all noise */
    return t < 1.0 ? 0.0 : [HRScorer wpmForCharacters:wpmChars duration:t];
}

- (double)liveAccuracy
{
    NSUInteger total = _correctKeystrokes + _incorrectKeystrokes;
    return total == 0 ? 100.0 : 100.0 * (double)_correctKeystrokes / (double)total;
}

- (HRTestSummary *)summary
{
    HRTestSummary *s = [[HRTestSummary alloc] init];
    NSUInteger wpmChars = 0, rawChars = 0;
    [self tallyInto:s wpmCharacters:&wpmChars rawCharacters:&rawChars];

    NSTimeInterval duration = _endTime - _startTime;
    s.duration = duration;
    s.wpm = [HRScorer wpmForCharacters:wpmChars duration:duration];
    s.rawWpm = [HRScorer wpmForCharacters:rawChars duration:duration];
    s.correctKeystrokes = _correctKeystrokes;
    s.incorrectKeystrokes = _incorrectKeystrokes;
    s.accuracy = [self liveAccuracy];

    /* One sample per second.  The last second is usually partial: scale it
     * up when there is enough of it to mean something, drop it otherwise. */
    NSUInteger whole = (NSUInteger)floor(duration);
    double tail = duration - (double)whole;
    NSMutableArray *raw = [NSMutableArray array];
    NSMutableArray *errs = [NSMutableArray array];
    NSUInteger seconds = whole + (tail >= 0.5 ? 1 : 0);
    for (NSUInteger i = 0; i < seconds; i++) {
        double keys = i < [_keysPerSecond count] ? [_keysPerSecond[i] doubleValue] : 0.0;
        double span = i < whole ? 1.0 : tail;
        [raw addObject:@((keys / 5.0) * (60.0 / span))];
        [errs addObject:(i < [_errorsPerSecond count] ? _errorsPerSecond[i] : @0)];
    }
    s.rawWpmPerSecond = raw;
    s.errorsPerSecond = errs;
    s.consistency = [HRScorer consistencyForSamples:raw];

    NSMutableDictionary *stats = [NSMutableDictionary dictionary];
    for (NSString *k in _keyStats) stats[k] = [_keyStats[k] copy];
    s.keyStats = stats;
    return s;
}

@end
