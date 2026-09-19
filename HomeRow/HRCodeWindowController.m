/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * HomeRow is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version.  It comes with ABSOLUTELY NO WARRANTY.  See COPYING.
 */
#import "HRCodeWindowController.h"
#import "HRCodeLibrary.h"
#import "HRCodeDocument.h"
#import "HRResultStore.h"

#define HRLoc(key) NSLocalizedString(key, nil)

NSString * const HRCodeTypeCommentsDefaultsKey = @"HRCodeTypeComments";

@implementation HRCodeWindowController
{
    HRCodeLibrary *_library;
    HRResultStore *_store;
    __weak id<HRCodeWindowDelegate> _delegate;
    NSArray *_rows;                   /* @[HRCodeFile, @(section), @(sections), NSValue lineRange] */
    NSMutableDictionary *_records;    /* file identifier -> (section -> HRLessonRecord) */
    NSDateFormatter *_dateFormatter;
}

- (instancetype)initWithLibrary:(HRCodeLibrary *)library store:(HRResultStore *)store
                       delegate:(id<HRCodeWindowDelegate>)delegate
{
    if ((self = [super initWithWindowNibName:@"CodeWindow"])) {
        _library = library;
        _store = store;
        _delegate = delegate;
        _rows = @[];
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    [_languagePopUp removeAllItems];
    for (HRCodeLanguage *language in _library.languages) {
        [_languagePopUp addItemWithTitle:language.displayName];
        [[_languagePopUp lastItem] setRepresentedObject:language.identifier];
    }
    [_commentsCheck setState:([[NSUserDefaults standardUserDefaults] boolForKey:HRCodeTypeCommentsDefaultsKey]
                              ? NSControlStateValueOn : NSControlStateValueOff)];
    [_sectionTable setTarget:self];
    [_sectionTable setDoubleAction:@selector(typeSelectedSection:)];
    [self selectLanguageInPopUp];
    [self reloadProgress];
}

- (void)selectLanguageInPopUp
{
    for (NSMenuItem *item in [_languagePopUp itemArray]) {
        if ([[item representedObject] isEqual:_selectedLanguageID]) { [_languagePopUp selectItem:item]; return; }
    }
    if ([_languagePopUp numberOfItems] > 0) [_languagePopUp selectItemAtIndex:0];
}

- (HRCodeLanguage *)shownLanguage
{
    return [_library languageWithIdentifier:[[_languagePopUp selectedItem] representedObject]];
}

- (void)setSelectedLanguageID:(NSString *)identifier
{
    _selectedLanguageID = [identifier copy];
    if ([self isWindowLoaded]) {
        [self selectLanguageInPopUp];
        [self reloadProgress];
    }
}

- (void)reloadProgress
{
    if (![self isWindowLoaded]) return;
    NSInteger selected = [_sectionTable selectedRow];
    HRCodeLanguage *language = [self shownLanguage];
    NSMutableArray *rows = [NSMutableArray array];
    _records = [NSMutableDictionary dictionary];
    NSUInteger done = 0;
    NSInteger firstOpen = -1;
    for (HRCodeFile *file in [_library filesForLanguage:language]) {
        HRCodeDocument *document = [_library documentForFile:file error:NULL];
        if (!document) continue;
        NSDictionary *records = [_store lessonRecordsForCourse:file.identifier] ?: @{};
        _records[file.identifier] = records;
        for (NSUInteger s = 0; s < document.numberOfSections; s++) {
            if ([[(HRLessonRecord *)records[@(s)] completions] integerValue] > 0) done++;
            else if (firstOpen < 0) firstOpen = (NSInteger)[rows count];
            [rows addObject:@[file, @(s), @(document.numberOfSections),
                              [NSValue valueWithRange:[document lineRangeOfSection:s]]]];
        }
    }
    _rows = rows;
    [_summaryField setStringValue:[NSString stringWithFormat:HRLoc(@"%lu of %lu sections typed."),
                                   (unsigned long)done, (unsigned long)[rows count]]];
    [_sectionTable reloadData];
    NSInteger row = (selected >= 0 && selected < (NSInteger)[rows count]) ? selected : firstOpen;
    if (row >= 0) {
        [_sectionTable selectRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)row] byExtendingSelection:NO];
        [_sectionTable scrollRowToVisible:row];
    }
    [_typeButton setEnabled:[_sectionTable selectedRow] >= 0];
}

- (void)revealFile:(HRCodeFile *)file section:(NSUInteger)section
{
    (void)[self window];
    if ([file.languageID length] > 0) self.selectedLanguageID = file.languageID;
    [self reloadProgress];
    for (NSUInteger i = 0; i < [_rows count]; i++) {
        NSArray *row = _rows[i];
        if ([((HRCodeFile *)row[0]).identifier isEqualToString:file.identifier] && [row[1] unsignedIntegerValue] == section) {
            [_sectionTable selectRowIndexes:[NSIndexSet indexSetWithIndex:i] byExtendingSelection:NO];
            [_sectionTable scrollRowToVisible:(NSInteger)i];
            break;
        }
    }
    [_typeButton setEnabled:[_sectionTable selectedRow] >= 0];
}

#pragma mark - Actions

- (IBAction)languageChanged:(id)sender
{
    _selectedLanguageID = [[[_languagePopUp selectedItem] representedObject] copy];
    [_sectionTable deselectAll:self];
    [self reloadProgress];
}

- (IBAction)typeSelectedSection:(id)sender
{
    if (sender == _sectionTable && [_sectionTable clickedRow] < 0) return;
    NSInteger row = [_sectionTable selectedRow];
    if (row < 0 || row >= (NSInteger)[_rows count]) return;
    NSArray *entry = _rows[(NSUInteger)row];
    [_delegate codeWindow:self didRequestFile:entry[0] section:[entry[1] unsignedIntegerValue]];
}

/* One of your own files.  Its language goes by the extension; a language
 * HomeRow has no grammar for is typed as plain text. */
- (IBAction)openFile:(id)sender
{
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setAllowsMultipleSelection:NO];
    [panel setCanChooseDirectories:NO];
    if ([panel runModal] != NSModalResponseOK) return;
    NSString *path = [[[panel URLs] firstObject] path];
    if (!path) return;
    HRCodeFile *file = [_library addUserFileAtPath:path];
    NSError *error = nil;
    if (!file || ![_library documentForFile:file error:&error]) {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:HRLoc(@"That file could not be read as UTF-8 text.")];
        if (error) [alert setInformativeText:[error localizedDescription]];
        [alert runModal];
        return;
    }
    [[NSUserDefaults standardUserDefaults] setObject:_library.userFilePaths forKey:@"HRCodeUserFiles"];
    if ([file.languageID length] == 0) {
        /* no language to list it under: straight to typing */
        [_delegate codeWindow:self didRequestFile:file section:0];
        return;
    }
    [self revealFile:file section:0];
}

- (IBAction)commentsChanged:(id)sender
{
    [[NSUserDefaults standardUserDefaults] setBool:([_commentsCheck state] == NSControlStateValueOn)
                                            forKey:HRCodeTypeCommentsDefaultsKey];
}

#pragma mark - Table

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return (NSInteger)[_rows count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)column row:(NSInteger)row
{
    NSArray *entry = _rows[(NSUInteger)row];
    HRCodeFile *file = entry[0];
    NSUInteger section = [entry[1] unsignedIntegerValue];
    NSRange lines = [entry[3] rangeValue];
    HRLessonRecord *record = _records[file.identifier][@(section)];
    BOOL done = [record.completions integerValue] > 0;
    NSString *key = [column identifier];
    if ([key isEqualToString:@"status"]) return done ? @"✓" : @"";
    if ([key isEqualToString:@"file"]) {
        /* the name once per file; the rows under it are its sections */
        return section == 0 ? file.title : @"";
    }
    if ([key isEqualToString:@"part"]) {
        return [NSString stringWithFormat:@"%lu / %lu", (unsigned long)(section + 1), (unsigned long)[entry[2] unsignedIntegerValue]];
    }
    if ([key isEqualToString:@"lines"]) {
        return [NSString stringWithFormat:@"%lu–%lu", (unsigned long)(lines.location + 1), (unsigned long)NSMaxRange(lines)];
    }
    if ([key isEqualToString:@"source"]) return section == 0 ? (file.provenance ?: @"") : @"";
    if (!done) return @"";
    if ([key isEqualToString:@"wpm"])      return [NSString stringWithFormat:@"%.0f", [record.bestWpm doubleValue]];
    if ([key isEqualToString:@"accuracy"]) return [NSString stringWithFormat:@"%.0f%%", [record.bestAccuracy doubleValue]];
    if ([key isEqualToString:@"times"])    return [NSString stringWithFormat:@"%ld", (long)[record.completions integerValue]];
    if ([key isEqualToString:@"last"] && record.lastDate) {
        if (!_dateFormatter) {
            _dateFormatter = [[NSDateFormatter alloc] init];
            [_dateFormatter setDateStyle:NSDateFormatterMediumStyle];
            [_dateFormatter setTimeStyle:NSDateFormatterNoStyle];
        }
        return [_dateFormatter stringFromDate:record.lastDate];
    }
    return @"";
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
    [_typeButton setEnabled:[_sectionTable selectedRow] >= 0];
}

@end
