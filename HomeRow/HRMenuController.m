/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * HomeRow is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version.  It comes with ABSOLUTELY NO WARRANTY.  See COPYING.
 */
#import "HRMenuController.h"
#import "HRAppModel.h"
#import "HRCourseActivity.h"
#import "HRTestConfiguration.h"
#import "HRPacks.h"
#import "HRLanguage.h"
#import "HRTypScript.h"
#import "HRResultStore.h"
#import "HRManagedObjects.h"
#import "HRLayoutChooserController.h"
#import <objc/runtime.h>

#define HRLoc(key) NSLocalizedString(key, nil)

@implementation HRMenuController
{
    HRAppModel *_model;
    HRCourseActivity *_course;
    __weak id<HRMenuActions> _target;
    NSMenuItem *_keyboardMenuItem;
    NSMenuItem *_testKeyboardMenuItem;   /* the same command in the Test menu, where code and tests look for it */
    NSMenu *_courseMenu;
    NSMutableArray *_startedCourseItems;   /* the part of the Course menu that is rebuilt */
}

- (instancetype)initWithModel:(HRAppModel *)model course:(HRCourseActivity *)course target:(id<HRMenuActions>)target
{
    if ((self = [super init])) {
        _model = model;
        _course = course;
        _target = target;
    }
    return self;
}

- (void)build
{
    NSMenu *main = [NSApp mainMenu];
    NSInteger at = MAX(0, [main numberOfItems] - 1);   /* before Window */

    _languageMenu = [[NSMenu alloc] initWithTitle:HRLoc(@"Language")];
    _wordListMenu = [[NSMenu alloc] initWithTitle:HRLoc(@"Word List")];
    NSMenuItem *lists = [[NSMenuItem alloc] initWithTitle:HRLoc(@"Word List") action:NULL keyEquivalent:@""];
    [lists setSubmenu:_wordListMenu];
    [_languageMenu addItem:lists];
    [_languageMenu addItem:[NSMenuItem separatorItem]];
    NSArray *byName = [_model.packs.languages sortedArrayUsingDescriptors:
                       @[[NSSortDescriptor sortDescriptorWithKey:@"displayName" ascending:YES]]];
    /* keyword lists of programming languages: words to type like any
     * other, but sixty more names do not belong among Afrikaans and Zulu */
    _programmingMenu = [[NSMenu alloc] initWithTitle:HRLoc(@"Programming")];
    for (HRLanguage *l in byName) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:l.displayName
                                                      action:@selector(selectLanguage:)
                                               keyEquivalent:@""];
        [item setTarget:_target];
        [item setRepresentedObject:l.identifier];
        [(l.isCode ? _programmingMenu : _languageMenu) addItem:item];
    }
    if ([_programmingMenu numberOfItems] > 0) {
        _programmingItem = [[NSMenuItem alloc] initWithTitle:HRLoc(@"Programming") action:NULL keyEquivalent:@""];
        [_programmingItem setSubmenu:_programmingMenu];
        [_languageMenu insertItem:_programmingItem atIndex:2];
    }
    NSMenuItem *languageItem = [[NSMenuItem alloc] initWithTitle:HRLoc(@"Language") action:NULL keyEquivalent:@""];
    [languageItem setSubmenu:_languageMenu];
    [main insertItem:languageItem atIndex:at];

    /* Language > Keyboard Layout: what the on-screen keyboard draws when no
     * course says otherwise.  It describes the system's layout; it never
     * changes it. */
    /* one item that names the layout and opens the chooser: a submenu of 239
     * layouts could be scrolled but hardly used */
    _layoutMenuItem = [[NSMenuItem alloc] initWithTitle:HRLoc(@"Keyboard Layout\u2026") action:@selector(showLayoutChooser:)
                                          keyEquivalent:@""];
    [_layoutMenuItem setTarget:_target];
    [_languageMenu insertItem:_layoutMenuItem atIndex:1];


    /* Preferences… under About, in the application menu (the first one) */
    NSMenu *appMenu = [main numberOfItems] > 0 ? [[main itemAtIndex:0] submenu] : nil;
    if (appMenu) {
        NSMenuItem *prefsItem = [[NSMenuItem alloc] initWithTitle:HRLoc(@"Preferences\u2026") action:@selector(showPreferences:)
                                                    keyEquivalent:@","];
        [prefsItem setTarget:_target];
        /* About / ---- / Preferences… / ---- / Services … */
        NSInteger where = MIN((NSInteger)1, [appMenu numberOfItems]);
        if (where < [appMenu numberOfItems] && [[appMenu itemAtIndex:where] isSeparatorItem]) where++;
        [appMenu insertItem:prefsItem atIndex:where];
        if (where + 1 < [appMenu numberOfItems] && ![[appMenu itemAtIndex:where + 1] isSeparatorItem]) {
            [appMenu insertItem:(NSMenuItem *)[NSMenuItem separatorItem] atIndex:where + 1];
        }
    }

    NSMenu *testMenu = [[main itemWithTitle:@"Test"] submenu];
    if (testMenu) {
        [testMenu addItem:(NSMenuItem *)[NSMenuItem separatorItem]];
        NSArray *modes = @[@[HRLoc(@"Time Test"), @(HRTestModeTime), @"1"],
                           @[HRLoc(@"Words Test"), @(HRTestModeWords), @"2"],
                           @[HRLoc(@"Zen"), @(HRTestModeZen), @"3"]];
        /* Code is not among them: choosing it opens a window, see below */
        for (NSArray *mode in modes) {
            NSMenuItem *modeItem = (NSMenuItem *)[testMenu addItemWithTitle:mode[0] action:@selector(selectMode:)
                                                              keyEquivalent:mode[2]];
            [modeItem setTarget:_target];
            [modeItem setTag:[mode[1] integerValue]];
        }
        NSMenuItem *practiceItem = (NSMenuItem *)[testMenu addItemWithTitle:HRLoc(@"Practise Weak Keys") action:@selector(selectMode:)
                                                              keyEquivalent:@"5"];
        [practiceItem setTarget:_target];
        [practiceItem setTag:HRTestModePractice];
        NSMenuItem *codeItem = (NSMenuItem *)[testMenu addItemWithTitle:HRLoc(@"Code\u2026") action:@selector(showCode:)
                                                          keyEquivalent:@"4"];
        [codeItem setTarget:_target];
        [testMenu addItem:(NSMenuItem *)[NSMenuItem separatorItem]];
        _testKeyboardMenuItem = (NSMenuItem *)[testMenu addItemWithTitle:HRLoc(@"Show Keyboard") action:@selector(toggleKeyboard:)
                                                          keyEquivalent:@""];
        [_testKeyboardMenuItem setTarget:_target];
        NSMenuItem *statsItem = (NSMenuItem *)[testMenu addItemWithTitle:HRLoc(@"Statistics\u2026") action:@selector(showStatistics:)
                                                           keyEquivalent:@"S"];
        [statsItem setTarget:_target];
        NSMenuItem *replayItem = (NSMenuItem *)[testMenu addItemWithTitle:HRLoc(@"Replay the Last Test") action:@selector(replayLastTest:)
                                                            keyEquivalent:@"R"];   /* Cmd-R is New Test */
        [replayItem setTarget:_target];
        NSMenuItem *beepItem = (NSMenuItem *)[testMenu addItemWithTitle:HRLoc(@"Beep on a Wrong Key") action:@selector(toggleBeep:)
                                                          keyEquivalent:@""];
        [beepItem setTarget:_target];
    }

    NSMenu *courseMenu = [[NSMenu alloc] initWithTitle:HRLoc(@"Course")];
    _courseMenu = courseMenu;
    /* informal NSMenuDelegate, see -menuNeedsUpdate: */
    [courseMenu setDelegate:(id)self];
    NSMenuItem *item = (NSMenuItem *)[courseMenu addItemWithTitle:HRLoc(@"Courses\u2026") action:@selector(showCourses:) keyEquivalent:@"l"];
    [item setTarget:_target];
    item = (NSMenuItem *)[courseMenu addItemWithTitle:HRLoc(@"Restart Lesson") action:@selector(restartLesson:) keyEquivalent:@""];
    [item setTarget:_target];
    [courseMenu addItem:[NSMenuItem separatorItem]];
    _keyboardMenuItem = (NSMenuItem *)[courseMenu addItemWithTitle:HRLoc(@"Show Keyboard") action:@selector(toggleKeyboard:) keyEquivalent:@"K"];
    [_keyboardMenuItem setTarget:_target];
    NSMenuItem *courseItem = [[NSMenuItem alloc] initWithTitle:HRLoc(@"Course") action:NULL keyEquivalent:@""];
    [courseItem setSubmenu:courseMenu];
    [main insertItem:courseItem atIndex:at + 1];
}

/* Several courses can be on the go at once -- a QWERTY course and the
 * programmers' symbols, say, or two languages.  Each keeps its own place;
 * the Course menu lists the ones that have been started, the current one
 * ticked, and choosing another switches to it and carries on from ITS
 * place.  Rebuilt whenever the menu is about to open. */
- (void)menuNeedsUpdate:(NSMenu *)menu
{
    if (menu == _courseMenu) [self rebuildStartedCourseItems];
}

- (void)rebuildStartedCourseItems
{
    for (NSMenuItem *item in _startedCourseItems) [_courseMenu removeItem:item];
    _startedCourseItems = [NSMutableArray array];
    NSString *current = [_course currentCourseFile];
    NSInteger at = [_courseMenu indexOfItemWithTarget:_target andAction:@selector(restartLesson:)] + 1;
    if (at <= 0) return;
    for (HRCourseProgress *progress in [_model.store startedCourses]) {
        NSDictionary *course = [_model.packs courseEntryForFile:progress.courseFile];
        if (!course) continue;
        NSUInteger total = [[_model.packs scriptForCourseFile:progress.courseFile].lessons count];
        NSUInteger next = (NSUInteger)MAX(0, [progress.lessonIndex integerValue]);
        NSString *where = next >= total ? HRLoc(@"finished")
            : [NSString stringWithFormat:HRLoc(@"lesson %lu of %lu"), (unsigned long)(next + 1), (unsigned long)total];
        NSString *language = course[@"language"];
        for (HRLanguage *l in _model.packs.languages) if ([l.identifier isEqual:course[@"language"]]) language = l.displayName;
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"%@ \u2014 %@   (%@)", language, course[@"title"], where]
                                                      action:@selector(switchToCourse:) keyEquivalent:@""];
        [item setTarget:_target];
        [item setRepresentedObject:progress.courseFile];
        [item setState:([progress.courseFile isEqual:current] ? NSControlStateValueOn : NSControlStateValueOff)];
        if ([_startedCourseItems count] == 0) {
            NSMenuItem *separator = (NSMenuItem *)[NSMenuItem separatorItem];
            [_courseMenu insertItem:separator atIndex:at++];
            [_startedCourseItems addObject:separator];
        }
        [_courseMenu insertItem:item atIndex:at++];
        [_startedCourseItems addObject:item];
    }
}

- (NSArray *)startedCourseItems
{
    return _startedCourseItems;
}

- (void)sync
{
    for (NSMenuItem *item in [[[[NSApp mainMenu] itemWithTitle:@"Test"] submenu] itemArray]) {
        if (sel_isEqual([item action], @selector(selectMode:))) {
            [item setState:([item tag] == _model.configuration.mode ? NSControlStateValueOn : NSControlStateValueOff)];
        }
        if (sel_isEqual([item action], @selector(toggleBeep:))) {
            [item setState:(_beepsOnError ? NSControlStateValueOn : NSControlStateValueOff)];
        }
        if (sel_isEqual([item action], @selector(showCode:))) {
            [item setState:(_model.configuration.mode == HRTestModeCode ? NSControlStateValueOn : NSControlStateValueOff)];
        }
    }
    NSMutableArray *languageMenus = [NSMutableArray array];   /* neither is there before buildMenus */
    if (_languageMenu) [languageMenus addObject:_languageMenu];
    if (_programmingMenu) [languageMenus addObject:_programmingMenu];
    for (NSMenu *menu in languageMenus) {
        for (NSMenuItem *item in [menu itemArray]) {
            if (![item representedObject]) continue;
            BOOL on = [[item representedObject] isEqual:[_model currentLanguage].identifier];
            [item setState:(on ? NSControlStateValueOn : NSControlStateValueOff)];
        }
    }
    /* a dash on the submenu says the tick is inside it */
    [_programmingItem setState:([_model currentLanguage].isCode ? NSControlStateValueMixed : NSControlStateValueOff)];
    [_layoutMenuItem setTitle:[NSString stringWithFormat:HRLoc(@"Keyboard Layout: %@\u2026"),
                               [HRLayoutChooserController titleForIdentifier:(_model.configuration.layoutID ?: @"qwerty")]]];
    [_wordListMenu removeAllItems];
    HRLanguage *language = [_model currentLanguage];
    NSString *current = [_model currentWordListName];
    for (NSString *name in language.wordListNames) {
        NSString *title = [name hasPrefix:@"words-"] ? [name substringFromIndex:6] : name;
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:@selector(selectWordList:) keyEquivalent:@""];
        [item setTarget:_target];
        [item setRepresentedObject:name];
        [item setState:([name isEqualToString:current] ? NSControlStateValueOn : NSControlStateValueOff)];
        [_wordListMenu addItem:item];
    }
    [_keyboardMenuItem setState:(_keyboardWanted ? NSControlStateValueOn : NSControlStateValueOff)];
    [_testKeyboardMenuItem setState:[_keyboardMenuItem state]];
}

@end
