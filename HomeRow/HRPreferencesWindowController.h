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

@class HRTestConfiguration;
@class HRPreferencesWindowController;

typedef NS_OPTIONS(NSUInteger, HRPreferencesChange) {
    HRPreferencesChangedAppearance = 1 << 0,   /* theme, font, sizes: redraw */
    HRPreferencesChangedTyping     = 1 << 1,   /* the rules of a test: the one under way starts over */
    HRPreferencesChangedKeyboard   = 1 << 2    /* layout, or when the keyboard shows */
};

@protocol HRPreferencesDelegate <NSObject>
/* The live configuration: Preferences edits it in place. */
- (HRTestConfiguration *)configurationForPreferences:(HRPreferencesWindowController *)controller;
/* Opens the layout chooser; the choice comes back through the delegate's
 * own handling and a -sync. */
- (void)preferencesWantsLayoutChooser:(HRPreferencesWindowController *)controller;
/* Where the results are, for "Show in Finder"; nil when nothing is saved. */
- (NSURL *)storeURLForPreferences:(HRPreferencesWindowController *)controller;
- (void)preferences:(HRPreferencesWindowController *)controller didChange:(HRPreferencesChange)change;
@end

/* Everything that is a setting rather than a choice of what to type, in one
 * window: PreferencesWindow.xib.  Every control applies at once; there is
 * no OK button to forget. */
@interface HRPreferencesWindowController : NSWindowController

@property (nonatomic, strong) IBOutlet NSPopUpButton *themePopUp;
@property (nonatomic, strong) IBOutlet NSPopUpButton *fontPopUp;
@property (nonatomic, strong) IBOutlet NSPopUpButton *proseSizePopUp;
@property (nonatomic, strong) IBOutlet NSPopUpButton *codeSizePopUp;
@property (nonatomic, strong) IBOutlet NSPopUpButton *stopPopUp;
@property (nonatomic, strong) IBOutlet NSPopUpButton *backspacePopUp;
@property (nonatomic, strong) IBOutlet NSButton *beepCheck;
/* a name and a button: a pop-up of 239 layouts is no way to choose one */
@property (nonatomic, strong) IBOutlet NSTextField *layoutField;
@property (nonatomic, strong) IBOutlet NSButton *layoutButton;
@property (nonatomic, strong) IBOutlet NSButton *keyboardCourseCheck;
@property (nonatomic, strong) IBOutlet NSButton *keyboardCodeCheck;
@property (nonatomic, strong) IBOutlet NSButton *keyboardTestsCheck;
@property (nonatomic, strong) IBOutlet NSPopUpButton *codeFontPopUp;
@property (nonatomic, strong) IBOutlet NSButton *commentsCheck;
@property (nonatomic, strong) IBOutlet NSButton *tabsCheck;
@property (nonatomic, strong) IBOutlet NSTextField *dataField;
@property (nonatomic, strong) IBOutlet NSButton *revealButton;

- (instancetype)initWithDelegate:(id<HRPreferencesDelegate>)delegate;

/* Shows what the settings are now -- they can also change from the menus. */
- (void)sync;

- (IBAction)changed:(id)sender;
- (IBAction)revealData:(id)sender;
- (IBAction)chooseLayout:(id)sender;

@end

/* User defaults the window shares with the rest of the app. */
extern NSString * const HRCodeTypeTabsDefaultsKey;        /* Tab is typed where code indents deeper */
extern NSString * const HRBeepOnErrorDefaultsKey;
extern NSString * const HRKeyboardInCourseDefaultsKey;   /* on unless set */
extern NSString * const HRKeyboardInCodeDefaultsKey;     /* on unless set */
extern NSString * const HRKeyboardInTestsDefaultsKey;    /* off unless set */
