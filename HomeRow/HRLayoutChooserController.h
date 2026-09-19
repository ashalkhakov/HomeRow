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

@class HRKeyboardLayout;
@class HRKeyboardView;
@class HRTheme;
@class HRLayoutChooserController;

@protocol HRLayoutChooserDelegate <NSObject>
- (NSArray *)layoutIdentifiersForChooser:(HRLayoutChooserController *)chooser;
- (HRKeyboardLayout *)layoutChooser:(HRLayoutChooserController *)chooser layoutNamed:(NSString *)identifier;
- (void)layoutChooser:(HRLayoutChooserController *)chooser didChoose:(NSString *)identifier;
@end

/* Picking one keyboard layout out of a couple of hundred: a pop-up or a
 * menu of that length is a scroll bar with opinions.  Here the list can be
 * searched -- type "col" and Colemak and its variants are what is left --
 * the well-known layouts come first while it is not, and the keyboard under
 * the list shows what the selected one looks like.  LayoutChooser.xib. */
@interface HRLayoutChooserController : NSWindowController <NSTableViewDataSource, NSTableViewDelegate>

@property (nonatomic, strong) IBOutlet NSSearchField *searchField;
@property (nonatomic, strong) IBOutlet NSTableView *layoutTable;
@property (nonatomic, strong) IBOutlet HRKeyboardView *keyboardView;
@property (nonatomic, strong) IBOutlet NSButton *chooseButton;
@property (nonatomic, strong) IBOutlet NSTextField *countField;

- (instancetype)initWithDelegate:(id<HRLayoutChooserDelegate>)delegate theme:(HRTheme *)theme;

@property (nonatomic, strong) HRTheme *theme;
/* Shows the window with `identifier` selected and the search cleared. */
- (void)chooseStartingFrom:(NSString *)identifier;

/* What the list shows for a search string, in order; for tests too. */
- (NSArray *)identifiersMatching:(NSString *)search;
/* "colemak_dh" -> "colemak dh" */
+ (NSString *)titleForIdentifier:(NSString *)identifier;

- (IBAction)searchChanged:(id)sender;
- (IBAction)choose:(id)sender;
- (IBAction)cancel:(id)sender;

@end
