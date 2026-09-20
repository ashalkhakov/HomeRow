/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * HomeRow is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version.  It comes with ABSOLUTELY NO WARRANTY.  See COPYING.
 */
#import "HRAppModel.h"
#import "HRTestConfiguration.h"
#import "HRResultStore.h"
#import "HRPacks.h"
#import "HRLanguage.h"

static NSString * const HRConfigurationDefaultsKey = @"HRConfiguration";

@implementation HRAppModel

- (instancetype)init
{
    if ((self = [super init])) {
        NSDictionary *saved = [[NSUserDefaults standardUserDefaults] dictionaryForKey:HRConfigurationDefaultsKey];
        _configuration = saved ? [[HRTestConfiguration alloc] initWithDictionary:saved]
                               : [HRTestConfiguration defaultConfiguration];
        /* a custom text does not outlive the run that opened it */
        if (_configuration.mode == HRTestModeCustom) _configuration.mode = HRTestModeTime;

        _packs = [[HRPacks alloc] initWithResourceDirectory:[[NSBundle mainBundle] resourcePath]
                                             userDirectory:[[[HRResultStore defaultStoreURL] path] stringByDeletingLastPathComponent]];
        for (NSError *e in _packs.problems) NSLog(@"HomeRow: language pack skipped: %@", [e localizedDescription]);

        NSError *error = nil;
        _store = [[HRResultStore alloc] initWithStoreURL:[HRResultStore defaultStoreURL]
                                                  bundle:[NSBundle mainBundle]
                                                   error:&error];
        /* typing still works without history; say why there is none */
        if (!_store) NSLog(@"HomeRow: results will not be saved: %@", error);
    }
    return self;
}

- (void)saveConfiguration
{
    [[NSUserDefaults standardUserDefaults] setObject:[_configuration dictionaryRepresentation]
                                              forKey:HRConfigurationDefaultsKey];
}

- (HRLanguage *)currentLanguage
{
    return [_packs languageWithIdentifier:_configuration.languageID] ?: [_packs.languages firstObject];
}

- (NSString *)currentWordListName
{
    HRLanguage *language = [self currentLanguage];
    if ([language.wordListNames containsObject:_configuration.wordListName]) return _configuration.wordListName;
    return [language.wordListNames firstObject];
}

- (NSArray *)currentWords
{
    NSString *list = [self currentWordListName];
    return list ? [[self currentLanguage] wordsNamed:list error:NULL] : nil;
}

- (HRKeyboardLayout *)currentLayout
{
    return [_packs layoutNamed:_configuration.layoutID] ?: [_packs layoutNamed:@"qwerty"];
}

- (NSString *)displayNameOfLanguage:(NSString *)identifier
{
    return [_packs languageWithIdentifier:identifier].displayName ?: identifier;
}

@end
