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

extern NSString * const HRPackErrorDomain;

/* A language pack: Languages/<id>/ holding info.plist and word lists.
 * See docs/adding-a-language.md for the format.  Bundled packs and the
 * user's own (Application Support/HomeRow/Languages) load through this one
 * path, which is what keeps "add a language" a matter of adding files. */
@interface HRLanguage : NSObject

@property (nonatomic, readonly, copy) NSString *identifier;
@property (nonatomic, readonly, copy) NSString *displayName;
@property (nonatomic, readonly, copy) NSString *defaultLayoutID;
@property (nonatomic, readonly, copy) NSString *direction; /* "ltr"; "rtl" is reserved */
@property (nonatomic, readonly, copy) NSString *alphabet;
@property (nonatomic, readonly, copy) NSString *directory;
/* Names of the word lists present, without extension, e.g. "words-200". */
@property (nonatomic, readonly, copy) NSArray *wordListNames;

+ (instancetype)languageWithDirectory:(NSString *)directory error:(NSError **)error;

/* Every valid pack under `directory`, sorted by identifier.  Invalid packs
 * are skipped and reported through `problems` (an array of NSError), never
 * thrown: a broken user pack must not stop the app from starting. */
+ (NSArray *)languagesInDirectory:(NSString *)directory problems:(NSArray **)problems;

/* One word per line, UTF-8; blank lines and lines starting with '#' are
 * ignored. */
- (NSArray *)wordsNamed:(NSString *)listName error:(NSError **)error;

@end
