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

@class HRTestConfiguration;
@class HRResultStore;
@class HRPacks;
@class HRLanguage;
@class HRKeyboardLayout;

/* What every part of the app works from: the settings of the tests, the
 * results on disk, and the packs.  One of it, made at launch and handed to
 * whoever needs it; nobody else reads the configuration's defaults key or
 * opens the store. */
@interface HRAppModel : NSObject

/* The live configuration: edited in place, written with -saveConfiguration. */
@property (nonatomic, readonly) HRTestConfiguration *configuration;
/* nil when the store could not be opened: typing still works, without history. */
@property (nonatomic, readonly) HRResultStore *store;
@property (nonatomic, readonly) HRPacks *packs;

/* Reads the saved configuration, opens the default store, finds the packs
 * in the app bundle and beside the store. */
- (instancetype)init;

- (void)saveConfiguration;

/* The configured language, or the first there is. */
- (HRLanguage *)currentLanguage;
/* The configured word list if the language has it, else its smallest. */
- (NSString *)currentWordListName;
- (NSArray *)currentWords;
/* The configured layout, or QWERTY when there is no pack for it. */
- (HRKeyboardLayout *)currentLayout;
/* A language's name for a person, by identifier; the identifier if unknown. */
- (NSString *)displayNameOfLanguage:(NSString *)identifier;

@end
