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

typedef NS_ENUM(NSInteger, HRTestMode) {
    HRTestModeTime = 0,   /* amount = seconds */
    HRTestModeWords,      /* amount = number of words */
    HRTestModeCustom,     /* the text decides */
    HRTestModeZen,        /* no target text; ended by the user */
    HRTestModeLesson      /* an exercise of a course; the lesson decides the text */
};

typedef NS_ENUM(NSInteger, HRBackspacePolicy) {
    HRBackspaceFree = 0,      /* may return to earlier incorrect words */
    HRBackspaceCurrentWord,   /* only within the word being typed */
    HRBackspaceNone           /* "confidence mode" */
};

/* What a test is.  Value object: copied into the session and stored with
 * the result, so a result can always say what it measured. */
@interface HRTestConfiguration : NSObject <NSCopying>

@property (nonatomic) HRTestMode mode;
@property (nonatomic) NSInteger amount;
@property (nonatomic) BOOL punctuation;
@property (nonatomic) BOOL numbers;
@property (nonatomic) HRBackspacePolicy backspacePolicy;
@property (nonatomic, copy) NSString *languageID;   /* language pack, e.g. "english" */
@property (nonatomic, copy) NSString *wordListName; /* e.g. "words-200" */
@property (nonatomic, copy) NSString *layoutID;     /* layout pack, e.g. "qwerty" */

+ (instancetype)defaultConfiguration;

/* Stable identifier of mode + settings; personal bests are kept per key. */
- (NSString *)settingsKey;
- (NSString *)modeName;

- (NSDictionary *)dictionaryRepresentation;
- (instancetype)initWithDictionary:(NSDictionary *)dictionary;

@end
