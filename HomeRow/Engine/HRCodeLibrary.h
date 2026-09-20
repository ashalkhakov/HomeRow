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

@class HRCodeDocument;
@class HRTextMateGrammar;

/* A programming language HomeRow can show: its grammar and its files. */
@interface HRCodeLanguage : NSObject
@property (nonatomic, readonly, copy) NSString *identifier;    /* "csharp" */
@property (nonatomic, readonly, copy) NSString *displayName;   /* "C#" */
@property (nonatomic, readonly, copy) NSString *scopeName;     /* "source.cs" */
@property (nonatomic, readonly, copy) NSArray *extensions;     /* ("cs") */
@end

/* Something to type: a bundled file, or one of the user's own. */
@interface HRCodeFile : NSObject
/* Stable name for progress records: "code:python/cpython--heapq.py" for a
 * bundled file, "code:file:/full/path.py" for the user's. */
@property (nonatomic, readonly, copy) NSString *identifier;
@property (nonatomic, readonly, copy) NSString *title;
@property (nonatomic, readonly, copy) NSString *path;
@property (nonatomic, readonly, copy) NSString *languageID;
@property (nonatomic, readonly) BOOL isBundled;
/* Where a bundled file came from, for the window: "MIT, github.com/..." */
@property (nonatomic, readonly, copy) NSString *provenance;
@end

/* Resources/Code: index.plist, Grammars/, Files/ -- see
 * Scripts/import-code.py -- plus the files the user has opened.
 * Foundation only. */
extern const NSUInteger HRCodeFolderFileLimit;   /* 300 */

@interface HRCodeLibrary : NSObject

@property (nonatomic, readonly, copy) NSArray *languages;   /* HRCodeLanguage, by display name */

- (instancetype)initWithDirectory:(NSString *)directory;

- (HRCodeLanguage *)languageWithIdentifier:(NSString *)identifier;
/* By file extension; nil when HomeRow has no grammar for it. */
- (HRCodeLanguage *)languageForPath:(NSString *)path;
- (HRTextMateGrammar *)grammarForLanguage:(HRCodeLanguage *)language;

/* Bundled files of a language, then the user's files of that language. */
- (NSArray *)filesForLanguage:(HRCodeLanguage *)language;
- (HRCodeFile *)fileWithIdentifier:(NSString *)identifier;

/* The user's own files: paths, most recent first.  The caller persists
 * them (user defaults); files that are gone are dropped on the way in. */
@property (nonatomic, copy) NSArray *userFilePaths;
/* Adds (or moves to the front) and returns the file; a file in a language
 * without a grammar is still typed, as plain text. */
- (HRCodeFile *)addUserFileAtPath:(NSString *)path;

/* Reads, tokenizes and sections a file; cached.  nil with an error when it
 * cannot be read as UTF-8 text. */
/* Folders of one's own code: every file in them, however deep, that has an
 * extension HomeRow knows, turns up under its language.  What is not there
 * to be typed is left out -- hidden files and folders, dependencies and
 * build output (node_modules, vendor, Pods, build, dist, target, ...),
 * minified and generated files, anything over 200 KB -- and no folder
 * contributes more than HRCodeFolderFileLimit files.  Set the paths (from
 * user defaults) or add one; both scan at once. */
@property (nonatomic, copy) NSArray *userFolderPaths;
- (NSUInteger)addUserFolderAtPath:(NSString *)path;   /* how many files it brought */
- (void)removeUserFolderAtPath:(NSString *)path;
/* Forgets a single file opened with -addUserFileAtPath:. */
- (void)removeUserFileAtPath:(NSString *)path;
/* The folder a file came in with; nil for bundled and single files. */
- (NSString *)folderOfFile:(HRCodeFile *)file;
/* The files a scan of `folder` finds, relative paths, sorted; for tests. */
- (NSArray *)scanFolder:(NSString *)folder;

- (HRCodeDocument *)documentForFile:(HRCodeFile *)file error:(NSError **)error;

@end
