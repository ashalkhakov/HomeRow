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
#import "HRStatistics.h"

#define HRLoc(key) NSLocalizedString(key, nil)

NSString * const HRCodeUserFilesDefaultsKey = @"HRCodeUserFiles";
NSString * const HRCodeUserFoldersDefaultsKey = @"HRCodeUserFolders";
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
    /* files and folders can be dropped on the list */
#if defined(GNUSTEP)
    [_sectionTable registerForDraggedTypes:@[NSFilenamesPboardType]];
#else
    [_sectionTable registerForDraggedTypes:@[NSPasteboardTypeFileURL]];
#endif
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
    [self syncButtons];
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
    [self syncButtons];
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

#pragma mark - Files and folders of one's own

- (void)saveLibrary
{
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d setObject:(_library.userFilePaths ?: @[]) forKey:HRCodeUserFilesDefaultsKey];
    [d setObject:(_library.userFolderPaths ?: @[]) forKey:HRCodeUserFoldersDefaultsKey];
}

- (void)say:(NSString *)message detail:(NSString *)detail
{
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:message];
    if (detail) [alert setInformativeText:detail];
    [alert runModal];
}

/* Files go in one by one, folders whole.  The last thing added is what the
 * list then shows; a single file in a language HomeRow has no grammar for
 * is typed straight away, as plain text, for there is no list to show it in. */
- (BOOL)addPaths:(NSArray *)paths
{
    HRCodeFile *reveal = nil, *plain = nil;
    NSString *unreadable = nil;
    NSMutableArray *emptyFolders = [NSMutableArray array];
    for (NSString *path in paths) {
        BOOL isDirectory = NO;
        if (![[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory]) continue;
        if (isDirectory) {
            if ([_library addUserFolderAtPath:path] == 0) {
                [emptyFolders addObject:[path lastPathComponent]];
                [_library removeUserFolderAtPath:path];
                continue;
            }
            for (HRCodeLanguage *language in _library.languages) {
                for (HRCodeFile *f in [_library filesForLanguage:language]) {
                    if (!reveal && [[_library folderOfFile:f] isEqualToString:path]) reveal = f;
                }
            }
        } else {
            HRCodeFile *file = [_library addUserFileAtPath:path];
            if (!file || ![_library documentForFile:file error:NULL]) {
                unreadable = [path lastPathComponent];
                if (file) [_library removeUserFileAtPath:path];
                continue;
            }
            if ([file.languageID length] == 0) plain = file; else reveal = file;
        }
    }
    [self saveLibrary];
    if (unreadable) [self say:[NSString stringWithFormat:HRLoc(@"%@ could not be read as UTF-8 text."), unreadable] detail:nil];
    if ([emptyFolders count] > 0) {
        [self say:[NSString stringWithFormat:HRLoc(@"Nothing to type was found in %@."), [emptyFolders componentsJoinedByString:@", "]]
           detail:HRLoc(@"HomeRow looks for files in the programming languages it knows, and leaves out hidden folders, dependencies, build output, generated and very large files.")];
    }
    if (reveal) [self revealFile:reveal section:0];
    else if (plain) [_delegate codeWindow:self didRequestFile:plain section:0];
    else [self reloadProgress];
    return reveal != nil || plain != nil;
}

- (IBAction)openFile:(id)sender
{
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setAllowsMultipleSelection:YES];
    [panel setCanChooseDirectories:NO];
    if ([panel runModal] != NSModalResponseOK) return;
    NSMutableArray *paths = [NSMutableArray array];
    for (NSURL *url in [panel URLs]) if ([url path]) [paths addObject:[url path]];
    [self addPaths:paths];
}

- (IBAction)addFolder:(id)sender
{
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setAllowsMultipleSelection:NO];
    [panel setCanChooseDirectories:YES];
    [panel setCanChooseFiles:NO];
    [panel setMessage:HRLoc(@"A folder of your own code: a project, a repository. Its source files turn up under their languages.")];
    if ([panel runModal] != NSModalResponseOK) return;
    NSString *path = [[[panel URLs] firstObject] path];
    if (path) [self addPaths:@[path]];
}

- (HRCodeFile *)selectedFile
{
    NSInteger row = [_sectionTable selectedRow];
    return (row >= 0 && row < (NSInteger)[_rows count]) ? _rows[(NSUInteger)row][0] : nil;
}

- (IBAction)removeSelected:(id)sender
{
    HRCodeFile *file = [self selectedFile];
    if (!file || file.isBundled) return;
    NSString *folder = [_library folderOfFile:file];
    if (folder) [_library removeUserFolderAtPath:folder];
    else [_library removeUserFileAtPath:file.path];
    [self saveLibrary];
    [_sectionTable deselectAll:self];
    [self reloadProgress];
}

- (void)syncButtons
{
    HRCodeFile *file = [self selectedFile];
    [_typeButton setEnabled:file != nil];
    [_removeButton setEnabled:(file != nil && !file.isBundled)];
    [_removeButton setTitle:([_library folderOfFile:file] ? HRLoc(@"Remove Folder") : HRLoc(@"Remove"))];
}

#pragma mark - Drag and drop

- (NSArray *)pathsOnPasteboard:(NSPasteboard *)pasteboard
{
    NSMutableArray *paths = [NSMutableArray array];
#if defined(GNUSTEP)
    id list = [pasteboard propertyListForType:NSFilenamesPboardType];
    if ([list isKindOfClass:[NSArray class]]) [paths addObjectsFromArray:list];
#else
    for (NSURL *url in [pasteboard readObjectsForClasses:@[[NSURL class]]
                                                 options:@{NSPasteboardURLReadingFileURLsOnlyKey: @YES}] ?: @[]) {
        if ([url path]) [paths addObject:[url path]];
    }
#endif
    return paths;
}

- (NSDragOperation)tableView:(NSTableView *)tableView validateDrop:(id<NSDraggingInfo>)info
                 proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)operation
{
    if ([[self pathsOnPasteboard:[info draggingPasteboard]] count] == 0) return NSDragOperationNone;
    /* on the list as a whole, not between two of its rows */
    [tableView setDropRow:-1 dropOperation:NSTableViewDropOn];
    return NSDragOperationCopy;
}

- (BOOL)tableView:(NSTableView *)tableView acceptDrop:(id<NSDraggingInfo>)info
              row:(NSInteger)row dropOperation:(NSTableViewDropOperation)operation
{
    NSArray *paths = [self pathsOnPasteboard:[info draggingPasteboard]];
    if ([paths count] == 0) return NO;
    /* after the drag has ended: an alert inside the drop would hold the other application's drag up */
    [self performSelector:@selector(addPaths:) withObject:paths afterDelay:0.0];
    return YES;
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
        /* the locale's own format where there is one; a gnustep-base built
         * without ICU formats nothing, and then the date is spelled by hand */
        NSString *formatted = [_dateFormatter stringFromDate:record.lastDate];
        return [formatted length] > 0 ? formatted
                                      : [HRStatistics mediumStringForDate:record.lastDate timeZone:nil];
    }
    return @"";
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
    [self syncButtons];
}

@end
