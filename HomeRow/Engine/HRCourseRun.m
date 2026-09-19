/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * HomeRow is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version.  It comes with ABSOLUTELY NO WARRANTY.  See COPYING.
 */
#import "HRCourseRun.h"

@implementation HRLessonSummary
@end

@implementation HRCourseRun
{
    double _weightedWpm;
    NSTimeInterval _duration;
    NSUInteger _correctKeys, _incorrectKeys;
    NSUInteger _exercises, _repeats;
    NSUInteger _resumeStep;
    BOOL _earlierAdded;
}

+ (double)defaultMaxErrorPercent
{
    return 3.0;
}

- (instancetype)initWithLesson:(HRTypLesson *)lesson startingAtStep:(NSUInteger)stepIndex
{
    if ((self = [super init])) {
        _lesson = lesson;
        _stepIndex = stepIndex < [lesson.steps count] ? stepIndex : 0;
        _resumeStep = _stepIndex;
        _coversWholeLesson = (_stepIndex == 0);
    }
    return self;
}

- (BOOL)isFinished
{
    return _stepIndex >= [_lesson.steps count];
}

- (HRTypStep *)currentStep
{
    return [self isFinished] ? nil : _lesson.steps[_stepIndex];
}

- (void)advancePastPage
{
    HRTypStep *step = [self currentStep];
    if (step && !step.isExercise) _stepIndex++;
}

- (BOOL)recordExercise:(HRTestSummary *)s
{
    HRTypStep *step = [self currentStep];
    if (!step || !step.isExercise) return YES;

    _weightedWpm += s.wpm * s.duration;
    _duration += s.duration;
    _correctKeys += s.correctKeystrokes;
    _incorrectKeys += s.incorrectKeystrokes;

    double allowed = step.maxErrorPercent >= 0.0 ? step.maxErrorPercent : [HRCourseRun defaultMaxErrorPercent];
    /* a hair of slack: 3 wrong in 100 is 3%, whatever floating point says */
    BOOL passed = step.practiceOnly || (100.0 - s.accuracy) <= allowed + 1e-9;
    if (!passed) {
        _isRepeating = YES;
        _repeats++;
        return NO;
    }
    _isRepeating = NO;
    _exercises++;
    _stepIndex++;
    return YES;
}

- (void)addEarlierExercises:(NSArray *)exercises
{
    if (_coversWholeLesson || _earlierAdded) return;
    _earlierAdded = YES;
    NSMutableSet *seen = [NSMutableSet set];
    for (NSDictionary *e in exercises) {
        NSUInteger step = [e[@"step"] unsignedIntegerValue];
        if (step >= _resumeStep || step >= [_lesson.steps count]) continue;
        if (!((HRTypStep *)_lesson.steps[step]).isExercise) continue;
        double duration = [e[@"duration"] doubleValue];
        double keys = [e[@"keystrokes"] doubleValue];
        double accuracy = MAX(0.0, MIN(100.0, [e[@"accuracy"] doubleValue]));
        _weightedWpm += [e[@"wpm"] doubleValue] * duration;
        _duration += duration;
        NSUInteger correct = (NSUInteger)(keys * accuracy / 100.0 + 0.5);
        _correctKeys += correct;
        _incorrectKeys += (NSUInteger)MAX(0.0, keys - (double)correct);
        if ([seen containsObject:@(step)]) _repeats++;
        else { [seen addObject:@(step)]; _exercises++; }
    }
    NSUInteger expected = 0;
    for (NSUInteger i = 0; i < _resumeStep && i < [_lesson.steps count]; i++) {
        if (((HRTypStep *)_lesson.steps[i]).isExercise) expected++;
    }
    if ([seen count] == expected) _coversWholeLesson = YES;
}

- (HRLessonSummary *)summary
{
    HRLessonSummary *l = [[HRLessonSummary alloc] init];
    l.duration = _duration;
    l.wpm = _duration > 0.0 ? _weightedWpm / _duration : 0.0;
    NSUInteger keys = _correctKeys + _incorrectKeys;
    l.accuracy = keys > 0 ? 100.0 * (double)_correctKeys / (double)keys : 100.0;
    l.exercises = _exercises;
    l.repeats = _repeats;
    return l;
}

@end
