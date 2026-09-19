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

#pragma mark - The fixed-pitch font

+ (BOOL)fontIsFixedPitch:(NSFont *)font
{
    if (!font) return NO;
    NSDictionary *attrs = @{NSFontAttributeName: font};
    CGFloat narrow = [@"i" sizeWithAttributes:attrs].width;
    CGFloat wide = [@"m" sizeWithAttributes:attrs].width;
    CGFloat other = [@"W" sizeWithAttributes:attrs].width;
    if (wide <= 0.0) return NO;
    return fabs(narrow - wide) < 0.01 * wide && fabs(other - wide) < 0.01 * wide;
}

+ (NSFont *)fixedPitchFontOfSize:(CGFloat)size
{
    static NSString *chosen = nil;     /* a font name; @"" = the search came up empty */
    if ([chosen length] > 0) {
        NSFont *font = [NSFont fontWithName:chosen size:size];
        if (font) return font;
    }
    NSFont *user = [NSFont userFixedPitchFontOfSize:size];
    if (chosen != nil && [chosen length] == 0) return user ?: [NSFont systemFontOfSize:size];
    if ([self fontIsFixedPitch:user]) {
        chosen = [[user fontName] copy];
        return user;
    }

    NSMutableArray *names = [NSMutableArray arrayWithArray:@[
        @"DejaVu Sans Mono", @"DejaVuSansMono", @"DejaVuSansMono-Book",
        @"Liberation Mono", @"LiberationMono", @"LiberationMono-Regular",
        @"Noto Sans Mono", @"NotoSansMono-Regular", @"Ubuntu Mono", @"UbuntuMono-Regular",
        @"Hack", @"Hack-Regular", @"FreeMono", @"Nimbus Mono PS", @"NimbusMonoPS-Regular",
        @"Menlo", @"Menlo-Regular", @"Monaco", @"Courier New", @"CourierNewPSMT", @"Courier"]];
    /* and whatever else calls itself mono, plain weights first */
    NSMutableArray *others = [NSMutableArray array];
    for (NSString *name in [[NSFontManager sharedFontManager] availableFonts]) {
        NSString *lower = [name lowercaseString];
        if ([lower rangeOfString:@"mono"].location == NSNotFound && [lower rangeOfString:@"courier"].location == NSNotFound) continue;
        BOOL fancy = [lower rangeOfString:@"bold"].location != NSNotFound || [lower rangeOfString:@"italic"].location != NSNotFound
                  || [lower rangeOfString:@"oblique"].location != NSNotFound;
        if (fancy) [others addObject:name]; else [others insertObject:name atIndex:0];
    }
    [names addObjectsFromArray:others];
    for (NSString *name in names) {
        NSFont *font = [NSFont fontWithName:name size:size];
        if ([self fontIsFixedPitch:font]) {
            chosen = [name copy];
            return font;
        }
    }
    chosen = @"";
    NSLog(@"HomeRow: no fixed-pitch font was found; the text will look uneven. Install DejaVu Sans Mono or Liberation Mono.");
    return user ?: [NSFont systemFontOfSize:size];
}

@end
