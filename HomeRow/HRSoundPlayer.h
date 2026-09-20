/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * HomeRow is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version.  It comes with ABSOLUTELY NO WARRANTY.  See COPYING.
 */
#import <AppKit/AppKit.h>

/* Key sounds: a scheme is a folder under Resources/Sounds (see
 * Scripts/make-sounds.py).  Best effort by design -- where there is no way to
 * make a sound (a gnustep-gui built without libsndfile and libao, a machine
 * without audio) nothing happens, and nothing is said about it. */
@interface HRSoundPlayer : NSObject

/* Folder names, sorted: what Preferences offers besides "Off". */
+ (NSArray *)schemeNames;

/* nil or @"" for silence. */
@property (nonatomic, copy) NSString *scheme;
/* How many sounds the scheme has loaded; 0 when it is silent or unplayable. */
@property (nonatomic, readonly) NSUInteger loadedSounds;

/* `input` as HRTestSession spells it: @" " and @"\n" have sounds of their
 * own, everything else is a key. */
- (void)playKey:(NSString *)input;
- (void)playError;

@end

extern NSString * const HRSoundSchemeDefaultsKey;   /* @"" or absent: off */
