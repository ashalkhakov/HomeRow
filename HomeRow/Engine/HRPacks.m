/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * HomeRow is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version.  It comes with ABSOLUTELY NO WARRANTY.  See COPYING.
 */
#import "HRPacks.h"
#import "HRLanguage.h"
#import "HRKeyboardLayout.h"
#import "HRTypScript.h"

@implementation HRPacks
{
    NSString *_layoutsDirectory;
    NSString *_lessonsDirectory;
    NSMutableDictionary *_layouts;   /* identifier -> HRKeyboardLayout, or NSNull for "looked, none" */
    NSMutableDictionary *_scripts;   /* course file -> HRTypScript */
}

- (instancetype)initWithResourceDirectory:(NSString *)resourceDirectory
                            userDirectory:(NSString *)userDirectory
{
    if ((self = [super init])) {
        _layoutsDirectory = [[resourceDirectory stringByAppendingPathComponent:@"Layouts"] copy];
        _lessonsDirectory = [[[resourceDirectory stringByAppendingPathComponent:@"Lessons"]
                              stringByAppendingPathComponent:@"gtypist"] copy];
        _layouts = [NSMutableDictionary dictionary];
        _scripts = [NSMutableDictionary dictionary];

        NSMutableDictionary *byID = [NSMutableDictionary dictionary];
        NSMutableArray *allProblems = [NSMutableArray array];
        NSMutableArray *directories = [NSMutableArray arrayWithObject:[resourceDirectory stringByAppendingPathComponent:@"Languages"]];
        if (userDirectory) [directories addObject:[userDirectory stringByAppendingPathComponent:@"Languages"]];
        for (NSString *directory in directories) {
            NSArray *problems = nil;
            for (HRLanguage *l in [HRLanguage languagesInDirectory:directory problems:&problems]) {
                byID[l.identifier] = l;
            }
            [allProblems addObjectsFromArray:problems ?: @[]];
        }
        _languages = [[byID allValues] sortedArrayUsingDescriptors:
                      @[[NSSortDescriptor sortDescriptorWithKey:@"identifier" ascending:YES]]];
        _problems = [allProblems copy];

        _courses = [[NSDictionary dictionaryWithContentsOfFile:
                     [_lessonsDirectory stringByAppendingPathComponent:@"index.plist"]][@"courses"] copy] ?: @[];
    }
    return self;
}

- (HRLanguage *)languageWithIdentifier:(NSString *)identifier
{
    for (HRLanguage *l in _languages) if ([l.identifier isEqualToString:identifier]) return l;
    return nil;
}

- (NSArray *)layoutIdentifiers
{
    return [HRKeyboardLayout identifiersInDirectory:_layoutsDirectory];
}

- (HRKeyboardLayout *)layoutNamed:(NSString *)identifier
{
    if ([identifier length] == 0) return nil;
    id cached = _layouts[identifier];
    if (cached) return cached == [NSNull null] ? nil : cached;
    NSString *path = [[_layoutsDirectory stringByAppendingPathComponent:identifier] stringByAppendingPathExtension:@"plist"];
    HRKeyboardLayout *layout = [[NSFileManager defaultManager] fileExistsAtPath:path]
        ? [HRKeyboardLayout layoutWithContentsOfFile:path error:NULL] : nil;
    _layouts[identifier] = layout ?: (id)[NSNull null];
    return layout;
}

- (NSDictionary *)courseEntryForFile:(NSString *)file
{
    for (NSDictionary *course in _courses) if ([course[@"file"] isEqual:file]) return course;
    return nil;
}

- (HRTypScript *)scriptForCourseFile:(NSString *)file
{
    if ([file length] == 0) return nil;
    HRTypScript *script = _scripts[file];
    if (!script) {
        NSError *error = nil;
        script = [HRTypScript scriptWithContentsOfFile:[_lessonsDirectory stringByAppendingPathComponent:file]
                                                 error:&error];
        if (!script) {
            NSLog(@"HomeRow: %@ could not be read: %@", file, [error localizedDescription]);
            return nil;
        }
        _scripts[file] = script;
    }
    return script;
}

@end
