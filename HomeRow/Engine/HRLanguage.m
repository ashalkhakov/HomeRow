/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * This library is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2.1 of the License, or (at
 * your option) any later version.  See COPYING.LIB.
 */
#import "HRLanguage.h"

NSString * const HRPackErrorDomain = @"HRPackErrorDomain";

static NSError *HRPackError(NSString *path, NSString *what)
{
    NSString *msg = [NSString stringWithFormat:@"%@: %@", [path lastPathComponent], what];
    return [NSError errorWithDomain:HRPackErrorDomain code:1
                           userInfo:@{NSLocalizedDescriptionKey: msg,
                                      NSFilePathErrorKey: path}];
}

@implementation HRLanguage

+ (instancetype)languageWithDirectory:(NSString *)directory error:(NSError **)error
{
    NSString *infoPath = [directory stringByAppendingPathComponent:@"info.plist"];
    NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:infoPath];
    if (![info isKindOfClass:[NSDictionary class]]) {
        if (error) *error = HRPackError(directory, @"info.plist is missing or is not a dictionary");
        return nil;
    }
    for (NSString *key in @[@"identifier", @"displayName", @"alphabet"]) {
        if (![info[key] isKindOfClass:[NSString class]] || [info[key] length] == 0) {
            if (error) *error = HRPackError(directory, [NSString stringWithFormat:@"info.plist has no \"%@\"", key]);
            return nil;
        }
    }
    if (![info[@"identifier"] isEqualToString:[directory lastPathComponent]]) {
        if (error) *error = HRPackError(directory, @"identifier does not match the folder name");
        return nil;
    }

    NSMutableArray *lists = [NSMutableArray array];
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directory error:NULL];
    for (NSString *f in [files sortedArrayUsingSelector:@selector(compare:)]) {
        if ([f hasPrefix:@"words-"] && [[f pathExtension] isEqualToString:@"txt"]) {
            [lists addObject:[f stringByDeletingPathExtension]];
        }
    }
    if ([lists count] == 0) {
        if (error) *error = HRPackError(directory, @"no words-*.txt word list");
        return nil;
    }

    HRLanguage *l = [[self alloc] init];
    l->_identifier = [info[@"identifier"] copy];
    l->_displayName = [info[@"displayName"] copy];
    l->_alphabet = [info[@"alphabet"] copy];
    l->_defaultLayoutID = [(info[@"defaultLayout"] ?: @"qwerty-us") copy];
    l->_direction = [(info[@"direction"] ?: @"ltr") copy];
    l->_directory = [directory copy];
    l->_wordListNames = [lists copy];
    return l;
}

+ (NSArray *)languagesInDirectory:(NSString *)directory problems:(NSArray **)problems
{
    NSMutableArray *found = [NSMutableArray array];
    NSMutableArray *errors = [NSMutableArray array];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *names = [[fm contentsOfDirectoryAtPath:directory error:NULL]
                      sortedArrayUsingSelector:@selector(compare:)];
    for (NSString *name in names) {
        if ([name hasPrefix:@"."]) continue;
        NSString *path = [directory stringByAppendingPathComponent:name];
        BOOL isDir = NO;
        if (![fm fileExistsAtPath:path isDirectory:&isDir] || !isDir) continue;
        NSError *e = nil;
        HRLanguage *l = [self languageWithDirectory:path error:&e];
        if (l) [found addObject:l];
        else if (e) [errors addObject:e];
    }
    if (problems) *problems = errors;
    return found;
}

- (NSArray *)wordsNamed:(NSString *)listName error:(NSError **)error
{
    NSString *path = [[_directory stringByAppendingPathComponent:listName]
                      stringByAppendingPathExtension:@"txt"];
    NSString *text = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:error];
    if (!text) return nil;
    NSMutableArray *words = [NSMutableArray array];
    NSCharacterSet *ws = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    for (NSString *line in [text componentsSeparatedByString:@"\n"]) {
        NSString *w = [line stringByTrimmingCharactersInSet:ws];
        if ([w length] == 0 || [w hasPrefix:@"#"]) continue;
        [words addObject:w];
    }
    if ([words count] == 0) {
        if (error) *error = HRPackError(path, @"the word list is empty");
        return nil;
    }
    return words;
}

@end
