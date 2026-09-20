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

@class HRCodeLibrary;
@class HRCodeFile;
@class HRResultStore;
@class HRCodeWindowController;

@protocol HRCodeWindowDelegate <NSObject>
- (void)codeWindow:(HRCodeWindowController *)controller didRequestFile:(HRCodeFile *)file section:(NSUInteger)section;
@end

/* The Code window: a language, its files cut into sections, and what each
 * section came to.  CodeWindow.xib. */
@interface HRCodeWindowController : NSWindowController <NSTableViewDataSource, NSTableViewDelegate>

@property (nonatomic, strong) IBOutlet NSPopUpButton *languagePopUp;
@property (nonatomic, strong) IBOutlet NSTextField *summaryField;
@property (nonatomic, strong) IBOutlet NSTableView *sectionTable;
@property (nonatomic, strong) IBOutlet NSButton *typeButton;
@property (nonatomic, strong) IBOutlet NSButton *openButton;
@property (nonatomic, strong) IBOutlet NSButton *commentsCheck;
@property (nonatomic, strong) IBOutlet NSButton *folderButton;
@property (nonatomic, strong) IBOutlet NSButton *removeButton;

- (instancetype)initWithLibrary:(HRCodeLibrary *)library
                          store:(HRResultStore *)store
                       delegate:(id<HRCodeWindowDelegate>)delegate;

/* The language shown; remembered by the caller. */
@property (nonatomic, copy) NSString *selectedLanguageID;
- (void)reloadProgress;
/* Shows a file's language and selects one of its sections. */
- (void)revealFile:(HRCodeFile *)file section:(NSUInteger)section;

- (IBAction)languageChanged:(id)sender;
- (IBAction)typeSelectedSection:(id)sender;
- (IBAction)openFile:(id)sender;
- (IBAction)addFolder:(id)sender;
/* Forgets the selected file of one's own, or the folder it came in with.
 * Nothing on disk is touched, and progress in the files is kept. */
- (IBAction)removeSelected:(id)sender;
/* What was dropped on the window, or chosen in a panel: files and folders. */
- (BOOL)addPaths:(NSArray *)paths;
- (IBAction)commentsChanged:(id)sender;

@end

/* User defaults: the folders and files of one's own. */
extern NSString * const HRCodeUserFilesDefaultsKey;
extern NSString * const HRCodeUserFoldersDefaultsKey;
/* User default: type the comments too (off: they are shown, not typed). */
extern NSString * const HRCodeTypeCommentsDefaultsKey;
