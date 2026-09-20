/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * HomeRow is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version.  It comes with ABSOLUTELY NO WARRANTY.  See COPYING.
 */
#import "HRActivity.h"
#import "HRAppModel.h"
#import "HRStage.h"
#import "HRTestSummary.h"
#import "HRPreferencesWindowController.h"   /* the keyboard's defaults keys */

@implementation HRActivity

- (instancetype)initWithModel:(HRAppModel *)model stage:(HRStage *)stage host:(id<HRActivityHost>)host
{
    if ((self = [super init])) {
        _model = model;
        _stage = stage;
        _host = host;
    }
    return self;
}

- (void)begin {}
- (void)leave {}
- (void)next { [self begin]; }
- (void)pageDismissed {}
- (void)sessionDidFinish:(HRTestSession *)session {}
- (NSString *)statusPrefix { return nil; }

- (NSString *)keyboardDefaultsKey { return HRKeyboardInTestsDefaultsKey; }
- (BOOL)keyboardShowsByDefault { return NO; }
- (HRKeyboardLayout *)keyboardLayout { return [_model currentLayout]; }

- (void)rulesDidChange
{
    if (!_stage.showsResult && !_stage.showsPage) [self next];
}

- (void)presentPlaceholder:(NSString *)text inMode:(HRTestMode)mode
{
    [self leave];
    [_host activity:self willPresentInMode:mode save:NO];
    [_stage presentPage:text];
}

+ (BOOL)summaryIsWorthKeeping:(HRTestSummary *)s
{
    /* a test with nothing in it is not a result */
    return s.duration >= 1.0 && (s.correctKeystrokes + s.incorrectKeystrokes) > 0;
}

@end
