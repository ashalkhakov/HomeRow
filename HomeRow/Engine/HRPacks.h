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

@class HRLanguage;
@class HRKeyboardLayout;
@class HRTypScript;

/* Everything HomeRow types from or draws that is data rather than code:
 * language packs, keyboard layouts and courses.  One object knows where they
 * are and keeps what it has read; nothing else touches the folders.
 *
 *   <resources>/Languages/<id>/      and the user's own, under <user>/Languages
 *   <resources>/Layouts/<id>.plist
 *   <resources>/Lessons/gtypist/     index.plist and the .typ files
 *
 * (Code has a library of its own, HRCodeLibrary: it also remembers files and
 * folders, which none of these do.) */
@interface HRPacks : NSObject

/* `userDirectory` may be nil; a pack there replaces a bundled one of the
 * same identifier. */
- (instancetype)initWithResourceDirectory:(NSString *)resourceDirectory
                            userDirectory:(NSString *)userDirectory;

/* Valid packs, sorted by identifier.  Invalid ones are skipped, and said
 * why in `problems` (NSError). */
@property (nonatomic, readonly, copy) NSArray *languages;
@property (nonatomic, readonly, copy) NSArray *problems;
- (HRLanguage *)languageWithIdentifier:(NSString *)identifier;

@property (nonatomic, readonly, copy) NSArray *layoutIdentifiers;
/* Read when first asked for; nil for a layout there is no pack for. */
- (HRKeyboardLayout *)layoutNamed:(NSString *)identifier;

/* The entries of the courses' index.plist: file, title, language, layout. */
@property (nonatomic, readonly, copy) NSArray *courses;
- (NSDictionary *)courseEntryForFile:(NSString *)file;
/* Parsed when first asked for; nil, with a line in the log, for a file that
 * cannot be read. */
- (HRTypScript *)scriptForCourseFile:(NSString *)file;

@end
