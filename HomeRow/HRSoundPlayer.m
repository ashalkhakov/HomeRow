/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * HomeRow is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version.  It comes with ABSOLUTELY NO WARRANTY.  See COPYING.
 */
#import "HRSoundPlayer.h"

NSString * const HRSoundSchemeDefaultsKey = @"HRSoundScheme";

/* An NSSound plays once at a time, and keys come faster than sounds end:
 * each file is loaded a few times over and the copies take turns. */
static const NSUInteger HRVoices = 3;

@implementation HRSoundPlayer {
    NSMutableDictionary *_voices;   /* name -> NSArray of NSSound */
    NSMutableDictionary *_turn;     /* name -> NSNumber */
    NSUInteger _nextKey;
}

+ (NSString *)soundsDirectory
{
    return [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Sounds"];
}

+ (NSArray *)schemeNames
{
    NSMutableArray *names = [NSMutableArray array];
    NSString *directory = [self soundsDirectory];
    for (NSString *name in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directory error:NULL]) {
        BOOL isDirectory = NO;
        if ([name hasPrefix:@"."]) continue;
        if ([[NSFileManager defaultManager] fileExistsAtPath:[directory stringByAppendingPathComponent:name] isDirectory:&isDirectory]
            && isDirectory) [names addObject:name];
    }
    return [names sortedArrayUsingSelector:@selector(compare:)];
}

- (void)setScheme:(NSString *)scheme
{
    if ((_scheme == scheme) || [_scheme isEqualToString:scheme]) return;
    _scheme = [scheme copy];
    _voices = [NSMutableDictionary dictionary];
    _turn = [NSMutableDictionary dictionary];
    _loadedSounds = 0;
    if ([_scheme length] == 0) return;
    NSString *directory = [[[self class] soundsDirectory] stringByAppendingPathComponent:_scheme];
    for (NSString *file in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directory error:NULL]) {
        if (![[file pathExtension] isEqualToString:@"wav"]) continue;
        NSMutableArray *copies = [NSMutableArray array];
        for (NSUInteger v = 0; v < HRVoices; v++) {
            NSSound *sound = nil;
            @try {
                sound = [[NSSound alloc] initWithContentsOfFile:[directory stringByAppendingPathComponent:file] byReference:YES];
            } @catch (NSException *e) {
                sound = nil;
            }
            if (sound) [copies addObject:sound];
        }
        if ([copies count] > 0) {
            _voices[[file stringByDeletingPathExtension]] = copies;
            _loadedSounds++;
        }
    }
}

- (void)play:(NSString *)name
{
    NSArray *copies = _voices[name];
    if ([copies count] == 0) return;
    NSUInteger turn = [_turn[name] unsignedIntegerValue];
    _turn[name] = @((turn + 1) % [copies count]);
    NSSound *sound = copies[turn];
    @try {
        if ([sound isPlaying]) [sound stop];
        [sound play];
    } @catch (NSException *e) {
        /* no sound, then */
    }
}

- (void)playKey:(NSString *)input
{
    if ([_voices count] == 0) return;
    if ([input isEqualToString:@" "] && _voices[@"space"]) { [self play:@"space"]; return; }
    if ([input isEqualToString:@"\n"] && _voices[@"return"]) { [self play:@"return"]; return; }
    _nextKey = _nextKey % 4 + 1;
    [self play:[NSString stringWithFormat:@"key-%lu", (unsigned long)_nextKey]];
}

- (void)playError
{
    if (_voices[@"error"]) [self play:@"error"];
    else [self playKey:nil];
}

@end
