/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * HomeRow is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version.  It comes with ABSOLUTELY NO WARRANTY.  See COPYING.
 */
#import "HRTheme.h"
#import "HRWord.h"

@implementation HRTheme
{
    NSColor *_styleColors[HRTextStyleCount];
}

+ (NSColor *)colorFromHex:(NSString *)hex
{
    if ([hex hasPrefix:@"#"]) hex = [hex substringFromIndex:1];
    unsigned int v = 0;
    if ([hex length] != 6 || ![[NSScanner scannerWithString:hex] scanHexInt:&v]) return nil;
    return [NSColor colorWithCalibratedRed:((v >> 16) & 0xFF) / 255.0
                                     green:((v >> 8) & 0xFF) / 255.0
                                      blue:(v & 0xFF) / 255.0
                                     alpha:1.0];
}

- (instancetype)initWithName:(NSString *)name dictionary:(NSDictionary *)d
{
    if ((self = [super init])) {
        _name = [name copy];
        _background = [HRTheme colorFromHex:d[@"background"]] ?: [NSColor whiteColor];
        _untyped    = [HRTheme colorFromHex:d[@"untyped"]]    ?: [NSColor grayColor];
        _correct    = [HRTheme colorFromHex:d[@"correct"]]    ?: [NSColor blackColor];
        _incorrect  = [HRTheme colorFromHex:d[@"incorrect"]]  ?: [NSColor redColor];
        _extra      = [HRTheme colorFromHex:d[@"extra"]]      ?: _incorrect;
        _caret      = [HRTheme colorFromHex:d[@"caret"]]      ?: [NSColor orangeColor];
        _accent     = [HRTheme colorFromHex:d[@"accent"]]     ?: _caret;
        NSArray *keys = @[@"", @"codeComment", @"codeString", @"codeKeyword", @"codeNumber", @"codeType", @"codeFunction"];
        for (NSUInteger i = 0; i < HRTextStyleCount; i++) {
            NSColor *c = i < [keys count] && [keys[i] length] > 0 ? [HRTheme colorFromHex:d[keys[i]]] : nil;
            _styleColors[i] = c ?: _untyped;
        }
    }
    return self;
}

- (NSColor *)colorForTextStyle:(uint8_t)style
{
    return style < HRTextStyleCount ? _styleColors[style] : _untyped;
}

+ (instancetype)themeNamed:(NSString *)name
{
    NSString *dir = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Themes"];
    NSString *path = [[dir stringByAppendingPathComponent:name] stringByAppendingPathExtension:@"plist"];
    NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:path];
    /* with no file the fallbacks above still give a usable surface */
    return [[self alloc] initWithName:name dictionary:d ?: @{}];
}

+ (BOOL)systemIsDark
{
#if defined(__APPLE__)
    if (@available(macOS 10.14, *)) {
        NSAppearanceName best = [[NSApp effectiveAppearance]
            bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]];
        return [best isEqualToString:NSAppearanceNameDarkAqua];
    }
#endif
    return NO;
}

+ (instancetype)currentTheme
{
    NSString *name = [[NSUserDefaults standardUserDefaults] stringForKey:@"HRTheme"];
    if ([name length] == 0 || [name isEqualToString:@"auto"]) {
        name = [self systemIsDark] ? @"dark" : @"light";
    }
    return [self themeNamed:name];
}

@end
