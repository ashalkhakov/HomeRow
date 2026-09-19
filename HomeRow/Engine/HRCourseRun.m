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
