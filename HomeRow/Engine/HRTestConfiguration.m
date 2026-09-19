/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * HomeRow is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version.  It comes with ABSOLUTELY NO WARRANTY.  See COPYING.
 */

#import "HRTestConfiguration.h"

@implementation HRTestConfiguration

- (instancetype)init
{
    if ((self = [super init])) {
        _mode = HRTestModeTime;
        _amount = 30;
        _backspacePolicy = HRBackspaceFree;
        _languageID = @"english";
        _wordListName = @"words-200";
        _layoutID = @"qwerty";
    }
    return self;
}

+ (instancetype)defaultConfiguration
{
    return [[self alloc] init];
}

- (BOOL)stopOnError { return _stopPolicy == HRStopOnLetter; }
- (void)setStopOnError:(BOOL)stop { _stopPolicy = stop ? HRStopOnLetter : HRStopNever; }

- (id)copyWithZone:(NSZone *)zone
{
    HRTestConfiguration *c = [[[self class] allocWithZone:zone] init];
    c.mode = _mode;
    c.amount = _amount;
    c.punctuation = _punctuation;
    c.numbers = _numbers;
    c.backspacePolicy = _backspacePolicy;
    c.stopPolicy = _stopPolicy;
    c.languageID = _languageID;
    c.wordListName = _wordListName;
    c.layoutID = _layoutID;
    return c;
}

- (NSString *)modeName
{
    switch (_mode) {
        case HRTestModeTime:   return @"time";
        case HRTestModeWords:  return @"words";
        case HRTestModeCustom: return @"custom";
        case HRTestModeZen:    return @"zen";
        case HRTestModeLesson: return @"lesson";
        case HRTestModeCode:   return @"code";
    }
    return @"time";
}

+ (HRTestMode)modeForName:(NSString *)name
{
    if ([name isEqualToString:@"words"])  return HRTestModeWords;
    if ([name isEqualToString:@"custom"]) return HRTestModeCustom;
    if ([name isEqualToString:@"zen"])    return HRTestModeZen;
    if ([name isEqualToString:@"lesson"]) return HRTestModeLesson;
    if ([name isEqualToString:@"code"])   return HRTestModeCode;
    return HRTestModeTime;
}

- (NSString *)settingsKey
{
    NSMutableString *key = [NSMutableString stringWithString:[self modeName]];
    if (_mode == HRTestModeTime || _mode == HRTestModeWords) {
        [key appendFormat:@":%ld", (long)_amount];
        [key appendFormat:@":%@/%@", _languageID, _wordListName];
        if (_punctuation) [key appendString:@":p"];
        if (_numbers)     [key appendString:@":n"];
    }
    return key;
}

- (NSDictionary *)dictionaryRepresentation
{
    return @{
        @"mode": [self modeName],
        @"amount": @(_amount),
        @"punctuation": @(_punctuation),
        @"numbers": @(_numbers),
        @"backspacePolicy": @(_backspacePolicy),
        @"stopPolicy": @(_stopPolicy),
        @"languageID": _languageID ?: @"english",
        @"wordListName": _wordListName ?: @"words-200",
        @"layoutID": _layoutID ?: @"qwerty",
    };
}

- (instancetype)initWithDictionary:(NSDictionary *)d
{
    if ((self = [self init])) {
        if (d[@"mode"])            _mode = [[self class] modeForName:d[@"mode"]];
        if (d[@"amount"])          _amount = [d[@"amount"] integerValue];
        if (d[@"punctuation"])     _punctuation = [d[@"punctuation"] boolValue];
        if (d[@"numbers"])         _numbers = [d[@"numbers"] boolValue];
        if (d[@"backspacePolicy"]) _backspacePolicy = [d[@"backspacePolicy"] integerValue];
        /* "stopOnError" is how it was saved before there were three of them */
        if (d[@"stopOnError"])     _stopPolicy = [d[@"stopOnError"] boolValue] ? HRStopOnLetter : HRStopNever;
        if (d[@"stopPolicy"])      _stopPolicy = MAX(HRStopNever, MIN(HRStopOnWord, [d[@"stopPolicy"] integerValue]));
        _backspacePolicy = MAX(HRBackspaceFree, MIN(HRBackspaceNone, _backspacePolicy));
        if (d[@"languageID"])      _languageID = [d[@"languageID"] copy];
        if (d[@"wordListName"])    _wordListName = [d[@"wordListName"] copy];
        if (d[@"layoutID"])        _layoutID = [d[@"layoutID"] copy];
    }
    return self;
}

@end
