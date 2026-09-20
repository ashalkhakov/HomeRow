/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * HomeRow is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version.  It comes with ABSOLUTELY NO WARRANTY.  See COPYING.
 */
#import "HRReplay.h"
#import "HRTestSession.h"
#import "HRCodeDocument.h"   /* HRWordArraySource */

@implementation HRInputEvent

+ (instancetype)eventWithKind:(HRInputKind)kind text:(NSString *)text time:(NSTimeInterval)time
{
    HRInputEvent *e = [[self alloc] init];
    e->_kind = kind;
    e->_text = [text copy];
    e->_time = time;
    return e;
}

@end

@implementation HRReplay {
    HRTestSession *_session;
    NSUInteger _next;
}

- (instancetype)initWithSession:(HRTestSession *)session
{
    if ((self = [super init])) {
        _configuration = [session.configuration copy];
        _words = (_configuration.mode == HRTestModeZen) ? @[] : [session.words copy];
        _events = [session.inputLog copy];
        _startTime = [(HRInputEvent *)[_events firstObject] time];
        _duration = [session summary].duration;
    }
    return self;
}

- (HRTestSession *)begin
{
    _session = [[HRTestSession alloc] initWithConfiguration:_configuration
                                                     source:[[HRWordArraySource alloc] initWithWords:_words]];
    _next = 0;
    return _session;
}

- (NSTimeInterval)timeAtElapsed:(NSTimeInterval)seconds
{
    return _startTime + seconds;
}

- (BOOL)advanceToElapsed:(NSTimeInterval)seconds
{
    NSTimeInterval now = [self timeAtElapsed:seconds];
    while (_next < [_events count]) {
        HRInputEvent *e = _events[_next];
        if (e.time > now) break;
        switch (e.kind) {
            case HRInputText:           [_session insertText:e.text atTime:e.time]; break;
            case HRInputDeleteBackward: [_session deleteBackwardAtTime:e.time]; break;
            case HRInputDeleteWord:     [_session deleteWordBackwardAtTime:e.time]; break;
            case HRInputFinish:         [_session finishAtTime:e.time]; break;
        }
        _next++;
    }
    [_session tickAtTime:now];
    return _session.state != HRSessionFinished && (_next < [_events count] || seconds < _duration);
}

@end
