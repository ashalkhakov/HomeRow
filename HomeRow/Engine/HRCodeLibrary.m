/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * HomeRow is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version.  It comes with ABSOLUTELY NO WARRANTY.  See COPYING.
 */
#import "HRCodeLibrary.h"
#import "HRCodeDocument.h"
#import "HRTextMateGrammar.h"

@interface HRCodeLanguage ()
- (instancetype)initWithDictionary:(NSDictionary *)d;
@property (nonatomic, copy) NSString *grammarFile;
@property (nonatomic, copy) NSArray *bundledFiles;
@end

@implementation HRCodeLanguage
- (instancetype)initWithDictionary:(NSDictionary *)d
{
    if ((self = [super init])) {
        _identifier = [d[@"identifier"] copy];
        _displayName = [(d[@"displayName"] ?: d[@"identifier"]) copy];
        _scopeName = [d[@"scopeName"] copy];
        _extensions = [(d[@"extensions"] ?: @[]) copy];
        _grammarFile = [d[@"grammar"] copy];
    }
    return self;
}
@end

@interface HRCodeFile ()
- (instancetype)initWithIdentifier:(NSString *)identifier title:(NSString *)title path:(NSString *)path
                        languageID:(NSString *)languageID bundled:(BOOL)bundled provenance:(NSString *)provenance;
@end

@implementation HRCodeFile
- (instancetype)initWithIdentifier:(NSString *)identifier title:(NSString *)title path:(NSString *)path
                        languageID:(NSString *)languageID bundled:(BOOL)bundled provenance:(NSString *)provenance
{
    if ((self = [super init])) {
        _identifier = [identifier copy]; _title = [title copy]; _path = [path copy];
        _languageID = [languageID copy]; _isBundled = bundled; _provenance = [provenance copy];
    }
    return self;
}
@end

@implementation HRCodeLibrary
{
    NSString *_directory;
    HRTextMateRegistry *_registry;
    NSMutableDictionary *_documents;   /* file identifier -> HRCodeDocument */
    NSArray *_userFiles;               /* HRCodeFile */
}

- (instancetype)initWithDirectory:(NSString *)directory
{
    if (!(self = [super init])) return nil;
    _directory = [directory copy];
    _documents = [NSMutableDictionary dictionary];
    _userFiles = @[];
    _userFilePaths = @[];

    NSDictionary *index = [NSDictionary dictionaryWithContentsOfFile:[directory stringByAppendingPathComponent:@"index.plist"]];
    NSMutableArray *languages = [NSMutableArray array];
    for (NSDictionary *d in index[@"languages"]) {
        if (![d[@"identifier"] isKindOfClass:[NSString class]]) continue;
        HRCodeLanguage *language = [[HRCodeLanguage alloc] initWithDictionary:d];
        NSMutableArray *files = [NSMutableArray array];
        for (NSDictionary *f in d[@"files"]) {
            NSString *relative = f[@"file"];
            if (![relative isKindOfClass:[NSString class]]) continue;
            NSString *host = [[NSURL URLWithString:(f[@"repository"] ?: @"")] host] ?: @"";
            NSString *provenance = [NSString stringWithFormat:@"%@, %@%@", f[@"licence"] ?: @"",
                                    host, [[NSURL URLWithString:(f[@"repository"] ?: @"")] path] ?: @""];
            [files addObject:[[HRCodeFile alloc] initWithIdentifier:[@"code:" stringByAppendingString:relative]
                                                              title:(f[@"title"] ?: [relative lastPathComponent])
                                                               path:[[directory stringByAppendingPathComponent:@"Files"]
                                                                     stringByAppendingPathComponent:relative]
                                                         languageID:language.identifier
                                                            bundled:YES
                                                         provenance:provenance]];
        }
        language.bundledFiles = files;
        [languages addObject:language];
    }
    [languages sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"displayName" ascending:YES
                                                                     selector:@selector(caseInsensitiveCompare:)]]];
    _languages = [languages copy];
    return self;
}

- (HRCodeLanguage *)languageWithIdentifier:(NSString *)identifier
{
    for (HRCodeLanguage *l in _languages) if ([l.identifier isEqualToString:identifier]) return l;
    return nil;
}

- (HRCodeLanguage *)languageForPath:(NSString *)path
{
    NSString *extension = [[path pathExtension] lowercaseString];
    if ([extension length] == 0) return nil;
    for (HRCodeLanguage *l in _languages) if ([l.extensions containsObject:extension]) return l;
    return nil;
}

- (HRTextMateGrammar *)grammarForLanguage:(HRCodeLanguage *)language
{
    if (!language) return nil;
    if (!_registry) {
        /* all of them at once: they are small to load (compiling patterns
         * happens on first use), and one grammar may include another */
        _registry = [[HRTextMateRegistry alloc] init];
        [_registry addGrammarsInDirectory:[_directory stringByAppendingPathComponent:@"Grammars"]];
    }
    return [_registry grammarForScopeName:language.scopeName];
}

- (HRCodeFile *)userFileForPath:(NSString *)path
{
    HRCodeLanguage *language = [self languageForPath:path];
    return [[HRCodeFile alloc] initWithIdentifier:[@"code:file:" stringByAppendingString:path]
                                            title:[path lastPathComponent]
                                             path:path
                                       languageID:(language.identifier ?: @"")
                                          bundled:NO
                                       provenance:[path stringByDeletingLastPathComponent]];
}

- (void)setUserFilePaths:(NSArray *)paths
{
    NSMutableArray *kept = [NSMutableArray array], *files = [NSMutableArray array];
    for (NSString *path in paths) {
        if (![path isKindOfClass:[NSString class]] || [kept containsObject:path]) continue;
        if (![[NSFileManager defaultManager] fileExistsAtPath:path]) continue;
        [kept addObject:path];
        [files addObject:[self userFileForPath:path]];
    }
    _userFilePaths = [kept copy];
    _userFiles = [files copy];
}

- (HRCodeFile *)addUserFileAtPath:(NSString *)path
{
    NSMutableArray *paths = [_userFilePaths mutableCopy];
    [paths removeObject:path];
    [paths insertObject:path atIndex:0];
    /* a list, not an archive */
    while ([paths count] > 30) [paths removeLastObject];
    [self setUserFilePaths:paths];
    [_documents removeObjectForKey:[@"code:file:" stringByAppendingString:path]];   /* it may have been edited */
    for (HRCodeFile *f in _userFiles) if ([f.path isEqualToString:path]) return f;
    return nil;
}

- (NSArray *)filesForLanguage:(HRCodeLanguage *)language
{
    NSMutableArray *files = [NSMutableArray arrayWithArray:language.bundledFiles ?: @[]];
    for (HRCodeFile *f in _userFiles) {
        if ([f.languageID isEqualToString:(language.identifier ?: @"")]) [files addObject:f];
    }
    return files;
}

- (HRCodeFile *)fileWithIdentifier:(NSString *)identifier
{
    for (HRCodeLanguage *l in _languages) {
        for (HRCodeFile *f in l.bundledFiles) if ([f.identifier isEqualToString:identifier]) return f;
    }
    for (HRCodeFile *f in _userFiles) if ([f.identifier isEqualToString:identifier]) return f;
    return nil;
}

- (HRCodeDocument *)documentForFile:(HRCodeFile *)file error:(NSError **)error
{
    HRCodeDocument *document = _documents[file.identifier];
    if (document) return document;
    NSString *text = [NSString stringWithContentsOfFile:file.path encoding:NSUTF8StringEncoding error:error];
    if (!text) return nil;
    HRTextMateGrammar *grammar = [self grammarForLanguage:[self languageWithIdentifier:file.languageID]];
    document = [[HRCodeDocument alloc] initWithText:text grammar:grammar tabWidth:4 targetSectionLines:50];
    _documents[file.identifier] = document;
    return document;
}

@end
