/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * HomeRow is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version.  It comes with ABSOLUTELY NO WARRANTY.  See COPYING.
 */
#import "HRPreferencesWindowController.h"
#import "HRCodeWindowController.h"
#import "HRTestConfiguration.h"
#import "HRPace.h"
#import "HRSoundPlayer.h"
#import "HRTheme.h"

#define HRLoc(key) NSLocalizedString(key, nil)

NSString * const HRCodeTypeTabsDefaultsKey = @"HRCodeTypeTabs";
NSString * const HRBeepOnErrorDefaultsKey = @"HRBeepOnError";
NSString * const HRPaceKindDefaultsKey = @"HRPaceKind";
NSString * const HRPaceCustomWpmDefaultsKey = @"HRPaceCustomWpm";
NSString * const HRKeyboardInCourseDefaultsKey = @"HRShowKeyboardInCourse";
NSString * const HRKeyboardInCodeDefaultsKey = @"HRShowKeyboardInCode";
NSString * const HRKeyboardInTestsDefaultsKey = @"HRShowKeyboardInTests";

@implementation HRPreferencesWindowController
{
    __weak id<HRPreferencesDelegate> _delegate;
}

- (instancetype)initWithDelegate:(id<HRPreferencesDelegate>)delegate
{
    if ((self = [super initWithWindowNibName:@"PreferencesWindow"])) {
        _delegate = delegate;
    }
    return self;
}

- (void)fill:(NSPopUpButton *)popUp titles:(NSArray *)titles values:(NSArray *)values
{
    [popUp removeAllItems];
    for (NSUInteger i = 0; i < [titles count]; i++) {
        [popUp addItemWithTitle:titles[i]];
        [[popUp lastItem] setRepresentedObject:values[i]];
    }
}

- (void)select:(id)value in:(NSPopUpButton *)popUp
{
    for (NSMenuItem *item in [popUp itemArray]) {
        if ([[item representedObject] isEqual:value]) { [popUp selectItem:item]; return; }
    }
    if ([popUp numberOfItems] > 0) [popUp selectItemAtIndex:0];
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    [self fill:_themePopUp titles:@[HRLoc(@"Follow the system"), HRLoc(@"Light"), HRLoc(@"Dark")]
        values:@[@"auto", @"light", @"dark"]];

    NSArray *families = [HRTheme fixedPitchFontFamilies];
    [self fill:_fontPopUp titles:[@[HRLoc(@"Automatic")] arrayByAddingObjectsFromArray:families]
        values:[@[@""] arrayByAddingObjectsFromArray:families]];
    [self fill:_codeFontPopUp titles:[@[HRLoc(@"The same as the text")] arrayByAddingObjectsFromArray:families]
        values:[@[@""] arrayByAddingObjectsFromArray:families]];

    NSMutableArray *proseTitles = [NSMutableArray array], *proseValues = [NSMutableArray array];
    for (NSInteger size = 16; size <= 40; size += 2) {
        [proseTitles addObject:[NSString stringWithFormat:@"%ld", (long)size]];
        [proseValues addObject:@(size)];
    }
    [self fill:_proseSizePopUp titles:proseTitles values:proseValues];
    NSMutableArray *codeTitles = [NSMutableArray array], *codeValues = [NSMutableArray array];
    for (NSInteger size = 11; size <= 24; size++) {
        [codeTitles addObject:[NSString stringWithFormat:@"%ld", (long)size]];
        [codeValues addObject:@(size)];
    }
    [self fill:_codeSizePopUp titles:codeTitles values:codeValues];

    [self fill:_stopPopUp titles:@[HRLoc(@"Never — mistakes go in"), HRLoc(@"On every letter — a wrong key does not go in"),
                                   HRLoc(@"On every word — a word must be right to be left")]
        values:@[@(HRStopNever), @(HRStopOnLetter), @(HRStopOnWord)]];
    [self fill:_backspacePopUp titles:@[HRLoc(@"Anywhere, back into earlier mistakes"), HRLoc(@"Only in the word being typed"),
                                        HRLoc(@"Off")]
        values:@[@(HRBackspaceFree), @(HRBackspaceCurrentWord), @(HRBackspaceNone)]];

    [self fill:_pacePopUp titles:@[HRLoc(@"Off"), HRLoc(@"My average"), HRLoc(@"My best"), HRLoc(@"A speed I choose:")]
        values:@[@(HRPaceOff), @(HRPaceAverage), @(HRPaceBest), @(HRPaceCustom)]];
    NSMutableArray *soundTitles = [NSMutableArray arrayWithObject:HRLoc(@"Off")], *soundValues = [NSMutableArray arrayWithObject:@""];
    for (NSString *scheme in [HRSoundPlayer schemeNames]) {
        [soundTitles addObject:[NSString stringWithFormat:@"%@%@", [[scheme substringToIndex:1] uppercaseString], [scheme substringFromIndex:1]]];
        [soundValues addObject:scheme];
    }
    [self fill:_soundPopUp titles:soundTitles values:soundValues];

#if defined(__APPLE__)
    [_revealButton setTitle:HRLoc(@"Show in Finder")];
#endif
    [self sync];
}

- (BOOL)boolForKey:(NSString *)key unlessSet:(BOOL)fallback
{
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    return [d objectForKey:key] ? [d boolForKey:key] : fallback;
}

- (void)sync
{
    if (![self isWindowLoaded]) return;
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    HRTestConfiguration *c = [_delegate configurationForPreferences:self];

    NSString *theme = [d stringForKey:HRThemeDefaultsKey];
    [self select:([theme length] > 0 ? theme : @"auto") in:_themePopUp];
    [self select:([d stringForKey:HRFontFamilyDefaultsKey] ?: @"") in:_fontPopUp];
    [self select:@((NSInteger)[HRTheme proseFontSize]) in:_proseSizePopUp];
    [self select:@((NSInteger)[HRTheme codeFontSize]) in:_codeSizePopUp];

    [self select:@(c.stopPolicy) in:_stopPopUp];
    [self select:@(c.backspacePolicy) in:_backspacePopUp];
    [_beepCheck setState:([d boolForKey:HRBeepOnErrorDefaultsKey] ? NSControlStateValueOn : NSControlStateValueOff)];

    [self select:@([d integerForKey:HRPaceKindDefaultsKey]) in:_pacePopUp];
    NSInteger paceWpm = [d integerForKey:HRPaceCustomWpmDefaultsKey];
    [_paceField setIntegerValue:(paceWpm > 0 ? paceWpm : 60)];
    [_paceField setEnabled:[d integerForKey:HRPaceKindDefaultsKey] == HRPaceCustom];
    [self select:([d stringForKey:HRSoundSchemeDefaultsKey] ?: @"") in:_soundPopUp];

    [_layoutField setStringValue:[(c.layoutID ?: @"qwerty") stringByReplacingOccurrencesOfString:@"_" withString:@" "]];
    [_keyboardCourseCheck setState:([self boolForKey:HRKeyboardInCourseDefaultsKey unlessSet:YES] ? NSControlStateValueOn : NSControlStateValueOff)];
    [_keyboardCodeCheck setState:([self boolForKey:HRKeyboardInCodeDefaultsKey unlessSet:YES] ? NSControlStateValueOn : NSControlStateValueOff)];
    [_keyboardTestsCheck setState:([self boolForKey:HRKeyboardInTestsDefaultsKey unlessSet:NO] ? NSControlStateValueOn : NSControlStateValueOff)];
    [_commentsCheck setState:([d boolForKey:HRCodeTypeCommentsDefaultsKey] ? NSControlStateValueOn : NSControlStateValueOff)];
    [_tabsCheck setState:([d boolForKey:HRCodeTypeTabsDefaultsKey] ? NSControlStateValueOn : NSControlStateValueOff)];
    [self select:([d stringForKey:HRCodeFontFamilyDefaultsKey] ?: @"") in:_codeFontPopUp];

    NSURL *store = [_delegate storeURLForPreferences:self];
    [_dataField setStringValue:(store ? [[store path] stringByAbbreviatingWithTildeInPath]
                                      : HRLoc(@"Results are not being saved."))];
    [_revealButton setEnabled:store != nil];
}

/* One action for every control: read them all, write what differs, and say
 * what kind of thing changed. */
- (IBAction)changed:(id)sender
{
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    HRTestConfiguration *c = [_delegate configurationForPreferences:self];
    HRPreferencesChange change = 0;

    NSString *theme = [[_themePopUp selectedItem] representedObject] ?: @"auto";
    if (![theme isEqual:([d stringForKey:HRThemeDefaultsKey] ?: @"auto")]) {
        [d setObject:theme forKey:HRThemeDefaultsKey];
        change |= HRPreferencesChangedAppearance;
    }
    NSString *family = [[_fontPopUp selectedItem] representedObject] ?: @"";
    if (![family isEqual:([d stringForKey:HRFontFamilyDefaultsKey] ?: @"")]) {
        [d setObject:family forKey:HRFontFamilyDefaultsKey];
        change |= HRPreferencesChangedAppearance;
    }
    NSInteger prose = [[[_proseSizePopUp selectedItem] representedObject] integerValue];
    if (prose > 0 && prose != (NSInteger)[HRTheme proseFontSize]) {
        [d setInteger:prose forKey:HRProseFontSizeDefaultsKey];
        change |= HRPreferencesChangedAppearance;
    }
    NSInteger code = [[[_codeSizePopUp selectedItem] representedObject] integerValue];
    if (code > 0 && code != (NSInteger)[HRTheme codeFontSize]) {
        [d setInteger:code forKey:HRCodeFontSizeDefaultsKey];
        change |= HRPreferencesChangedAppearance;
    }

    HRStopPolicy stop = (HRStopPolicy)[[[_stopPopUp selectedItem] representedObject] integerValue];
    if (stop != c.stopPolicy) { c.stopPolicy = stop; change |= HRPreferencesChangedTyping; }
    HRBackspacePolicy backspace = (HRBackspacePolicy)[[[_backspacePopUp selectedItem] representedObject] integerValue];
    if (backspace != c.backspacePolicy) { c.backspacePolicy = backspace; change |= HRPreferencesChangedTyping; }
    BOOL beep = [_beepCheck state] == NSControlStateValueOn;
    if (beep != [d boolForKey:HRBeepOnErrorDefaultsKey]) {
        [d setBool:beep forKey:HRBeepOnErrorDefaultsKey];
        change |= HRPreferencesChangedAppearance;
    }

    if (_pacePopUp) {
        NSInteger pace = [[[_pacePopUp selectedItem] representedObject] integerValue];
        if (pace != [d integerForKey:HRPaceKindDefaultsKey]) {
            [d setInteger:pace forKey:HRPaceKindDefaultsKey];
            change |= HRPreferencesChangedPace;
        }
        [_paceField setEnabled:pace == HRPaceCustom];
        /* anything typed is brought to a speed a person might type at */
        NSInteger wpm = MAX(5, MIN(300, [_paceField integerValue]));
        NSInteger before = [d integerForKey:HRPaceCustomWpmDefaultsKey];
        if (wpm != (before > 0 ? before : 60)) {
            [d setInteger:wpm forKey:HRPaceCustomWpmDefaultsKey];
            change |= HRPreferencesChangedPace;
        }
        if (wpm != [_paceField integerValue]) [_paceField setIntegerValue:wpm];
    }
    NSString *sound = [[_soundPopUp selectedItem] representedObject] ?: @"";
    if (_soundPopUp && ![sound isEqual:([d stringForKey:HRSoundSchemeDefaultsKey] ?: @"")]) {
        [d setObject:sound forKey:HRSoundSchemeDefaultsKey];
        change |= HRPreferencesChangedSound;
    }

    NSArray *shows = @[@[_keyboardCourseCheck ?: (id)[NSNull null], HRKeyboardInCourseDefaultsKey, @YES],
                       @[_keyboardCodeCheck ?: (id)[NSNull null], HRKeyboardInCodeDefaultsKey, @YES],
                       @[_keyboardTestsCheck ?: (id)[NSNull null], HRKeyboardInTestsDefaultsKey, @NO]];
    for (NSArray *show in shows) {
        if (show[0] == [NSNull null]) continue;
        BOOL on = [(NSButton *)show[0] state] == NSControlStateValueOn;
        if (on != [self boolForKey:show[1] unlessSet:[show[2] boolValue]]) {
            [d setBool:on forKey:show[1]];
            change |= HRPreferencesChangedKeyboard;
        }
    }
    NSString *codeFamily = [[_codeFontPopUp selectedItem] representedObject] ?: @"";
    if (_codeFontPopUp && ![codeFamily isEqual:([d stringForKey:HRCodeFontFamilyDefaultsKey] ?: @"")]) {
        [d setObject:codeFamily forKey:HRCodeFontFamilyDefaultsKey];
        change |= HRPreferencesChangedAppearance;
    }
    BOOL tabs = [_tabsCheck state] == NSControlStateValueOn;
    if (_tabsCheck && tabs != [d boolForKey:HRCodeTypeTabsDefaultsKey]) {
        [d setBool:tabs forKey:HRCodeTypeTabsDefaultsKey];
        change |= HRPreferencesChangedTyping;
    }
    BOOL comments = [_commentsCheck state] == NSControlStateValueOn;
    if (comments != [d boolForKey:HRCodeTypeCommentsDefaultsKey]) {
        [d setBool:comments forKey:HRCodeTypeCommentsDefaultsKey];
        change |= HRPreferencesChangedTyping;
    }
    if (change != 0) [_delegate preferences:self didChange:change];
}

- (IBAction)chooseLayout:(id)sender
{
    [_delegate preferencesWantsLayoutChooser:self];
}

- (IBAction)revealData:(id)sender
{
    NSURL *store = [_delegate storeURLForPreferences:self];
    if (!store) return;
    NSString *folder = [[store path] stringByDeletingLastPathComponent];
    /* GNUstep asks a GNUstep file manager to do this, and there often is
     * none: then let the desktop open the folder */
    if (![[NSWorkspace sharedWorkspace] selectFile:[store path] inFileViewerRootedAtPath:folder]) {
        [[NSWorkspace sharedWorkspace] openURL:[NSURL fileURLWithPath:folder]];
    }
}

@end
