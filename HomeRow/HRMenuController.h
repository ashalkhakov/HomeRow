/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * HomeRow is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version.  It comes with ABSOLUTELY NO WARRANTY.  See COPYING.
 */
#import <AppKit/AppKit.h>

@class HRAppModel;
@class HRCourseActivity;

/* What the menus built here send to their target.  (The rest of the menu
 * bar is MainMenu.xib's.) */
@protocol HRMenuActions <NSObject>
- (IBAction)selectMode:(id)sender;          /* tag: HRTestMode */
- (IBAction)selectLanguage:(id)sender;      /* representedObject: a language identifier */
- (IBAction)selectWordList:(id)sender;      /* representedObject: a word list's name */
- (IBAction)switchToCourse:(id)sender;      /* representedObject: a course file */
- (IBAction)showLayoutChooser:(id)sender;
- (IBAction)showPreferences:(id)sender;
- (IBAction)showCourses:(id)sender;
- (IBAction)showCode:(id)sender;
- (IBAction)showStatistics:(id)sender;
- (IBAction)restartLesson:(id)sender;
- (IBAction)toggleKeyboard:(id)sender;
- (IBAction)toggleBeep:(id)sender;
- (IBAction)replayLastTest:(id)sender;
@end

/* The menus that depend on what is there -- the languages and word lists of
 * the packs, the courses that have been started -- and the ticks on the
 * ones that say what is on.  Built in code rather than in the XIB, which
 * cannot know either. */
@interface HRMenuController : NSObject

- (instancetype)initWithModel:(HRAppModel *)model course:(HRCourseActivity *)course target:(id<HRMenuActions>)target;

/* Once, after the main menu is loaded. */
- (void)build;
/* Ticks, the layout's name, the word lists of the language: after anything
 * they show has changed. */
- (void)sync;

/* What the ticks cannot find out by themselves. */
@property (nonatomic) BOOL beepsOnError;
@property (nonatomic) BOOL keyboardWanted;

@property (nonatomic, readonly) NSMenu *languageMenu;
@property (nonatomic, readonly) NSMenu *programmingMenu;
@property (nonatomic, readonly) NSMenuItem *programmingItem;
@property (nonatomic, readonly) NSMenu *wordListMenu;
@property (nonatomic, readonly) NSMenuItem *layoutMenuItem;

@end
