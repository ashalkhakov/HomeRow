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
    HRTestModeLesson,     /* an exercise of a course; the lesson decides the text */
    HRTestModeCode,       /* a section of a source file */
    HRTestModePractice    /* words chosen for the keys that are missed most; amount = number of words */
};

typedef NS_ENUM(NSInteger, HRBackspacePolicy) {
    HRBackspaceFree = 0,      /* may return to earlier incorrect words */
    HRBackspaceCurrentWord,   /* only within the word being typed */
    HRBackspaceNone           /* "confidence mode" */
};

typedef NS_ENUM(NSInteger, HRStopPolicy) {
    HRStopNever = 0,   /* mistakes go in and may be left behind */
    HRStopOnLetter,    /* a wrong key is counted but not entered: nothing to take back */
    HRStopOnWord       /* mistakes go in, but a word cannot be left until it is right */
};

/* What a test is.  Value object: copied into the session and stored with
 * the result, so a result can always say what it measured. */
@interface HRTestConfiguration : NSObject <NSCopying>

@property (nonatomic) HRTestMode mode;
@property (nonatomic) NSInteger amount;
@property (nonatomic) BOOL punctuation;
@property (nonatomic) BOOL numbers;
@property (nonatomic) HRBackspacePolicy backspacePolicy;
/* How far a mistake may be carried.  HRStopOnLetter is the way Typing.io
 * works and what code mode always uses. */
@property (nonatomic) HRStopPolicy stopPolicy;
/* stopPolicy == HRStopOnLetter, as a BOOL; setting it NO means HRStopNever. */
@property (nonatomic) BOOL stopOnError;
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
