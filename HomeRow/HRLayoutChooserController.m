/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * HomeRow is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version.  It comes with ABSOLUTELY NO WARRANTY.  See COPYING.
 */
#import <objc/runtime.h>
#import "HRLayoutChooserController.h"
#import "HRKeyboardView.h"
#import "HRKeyboardLayout.h"
#import "HRTheme.h"

#define HRLoc(key) NSLocalizedString(key, nil)

@implementation HRLayoutChooserController
{
    __weak id<HRLayoutChooserDelegate> _delegate;
    NSArray *_all;        /* every identifier, the well-known ones first */
    NSUInteger _common;   /* how many of those lead the list */
    NSArray *_shown;
}

- (instancetype)initWithDelegate:(id<HRLayoutChooserDelegate>)delegate theme:(HRTheme *)theme
{
    if ((self = [super initWithWindowNibName:@"LayoutChooser"])) {
        _delegate = delegate;
        _theme = theme;
        _shown = @[];
    }
    return self;
}

+ (NSString *)titleForIdentifier:(NSString *)identifier
{
    return [identifier stringByReplacingOccurrencesOfString:@"_" withString:@" "];
}

/* The layouts most people come looking for, in the order they are asked
 * for; whichever of them exist lead the unsearched list. */
+ (NSArray *)wellKnownIdentifiers
{
    return @[@"qwerty", @"dvorak", @"colemak", @"colemak_dh", @"workman", @"qwertz", @"azerty", @"norman",
             @"programmer_dvorak", @"russian", @"JCUKEN", @"german", @"french", @"spanish", @"bepo", @"neo"];
}

- (void)loadIdentifiers
{
    NSArray *every = [[_delegate layoutIdentifiersForChooser:self] ?: @[]
                      sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    NSMutableArray *first = [NSMutableArray array];
    for (NSString *identifier in [[self class] wellKnownIdentifiers]) {
        if ([every containsObject:identifier]) [first addObject:identifier];
    }
    NSMutableArray *rest = [every mutableCopy];
    [rest removeObjectsInArray:first];
    _common = [first count];
    _all = [first arrayByAddingObjectsFromArray:rest];
}

/* Every word of the search must occur in the name; names that START with
 * the search come before names that merely contain it. */
- (NSArray *)identifiersMatching:(NSString *)search
{
    if (!_all) [self loadIdentifiers];
    NSMutableArray *words = [NSMutableArray array];
    for (NSString *w in [[search lowercaseString] componentsSeparatedByCharactersInSet:
                         [NSCharacterSet characterSetWithCharactersInString:@" _-"]]) {
        if ([w length] > 0) [words addObject:w];
    }
    if ([words count] == 0) return _all;
    NSMutableArray *starts = [NSMutableArray array], *contains = [NSMutableArray array];
    for (NSString *identifier in _all) {
        NSString *name = [identifier lowercaseString];
        BOOL every = YES;
        for (NSString *w in words) {
            if ([name rangeOfString:w options:NSLiteralSearch].location == NSNotFound) { every = NO; break; }
        }
        if (!every) continue;
        if ([name hasPrefix:words[0]]) [starts addObject:identifier]; else [contains addObject:identifier];
    }
    return [starts arrayByAddingObjectsFromArray:contains];
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    _keyboardView.theme = _theme;
    [_layoutTable setTarget:self];
    [_layoutTable setDoubleAction:@selector(choose:)];
    [self show:nil selecting:nil];
}

- (void)setTheme:(HRTheme *)theme
{
    _theme = theme;
    _keyboardView.theme = theme;
}

- (void)show:(NSString *)search selecting:(NSString *)identifier
{
    _shown = [self identifiersMatching:search ?: @""];
    [_layoutTable reloadData];
    NSUInteger row = identifier ? [_shown indexOfObject:identifier] : NSNotFound;
    if (row == NSNotFound && [_shown count] > 0) row = 0;
    if (row != NSNotFound) {
        [_layoutTable selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
        [_layoutTable scrollRowToVisible:(NSInteger)row];
    }
    NSUInteger total = [_all count];
    [_countField setStringValue:([_shown count] == total
        ? [NSString stringWithFormat:HRLoc(@"%lu layouts"), (unsigned long)total]
        : [NSString stringWithFormat:HRLoc(@"%lu of %lu layouts"), (unsigned long)[_shown count], (unsigned long)total])];
    [self selectionChanged];
}

- (void)chooseStartingFrom:(NSString *)identifier
{
    (void)[self window];
    [_searchField setStringValue:@""];
    [self show:nil selecting:identifier];
    [self showWindow:self];
    [[self window] makeFirstResponder:_searchField];
}

- (NSString *)selectedIdentifier
{
    NSInteger row = [_layoutTable selectedRow];
    return (row >= 0 && row < (NSInteger)[_shown count]) ? _shown[(NSUInteger)row] : nil;
}

- (void)selectionChanged
{
    NSString *identifier = [self selectedIdentifier];
    _keyboardView.keyboardLayout = identifier ? [_delegate layoutChooser:self layoutNamed:identifier] : nil;
    [_keyboardView setNeedsDisplay:YES];
    [_chooseButton setEnabled:identifier != nil];
}

#pragma mark - Actions

- (IBAction)searchChanged:(id)sender
{
    [self show:[_searchField stringValue] selecting:[self selectedIdentifier]];
}

/* live, not only on Return */
- (void)controlTextDidChange:(NSNotification *)notification
{
    if ([notification object] == _searchField) [self searchChanged:_searchField];
}

/* Return in the search field takes what is selected; the arrow keys move
 * the selection without leaving the field. */
- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)command
{
    if (control != _searchField) return NO;
    if (sel_isEqual(command, @selector(insertNewline:))) { [self choose:control]; return YES; }
    NSInteger step = sel_isEqual(command, @selector(moveDown:)) ? 1 : (sel_isEqual(command, @selector(moveUp:)) ? -1 : 0);
    if (step == 0) return NO;
    NSInteger row = [_layoutTable selectedRow] + step;
    if (row >= 0 && row < (NSInteger)[_shown count]) {
        [_layoutTable selectRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)row] byExtendingSelection:NO];
        [_layoutTable scrollRowToVisible:row];
        [self selectionChanged];
    }
    return YES;
}

- (IBAction)choose:(id)sender
{
    if (sender == _layoutTable && [_layoutTable clickedRow] < 0) return;
    NSString *identifier = [self selectedIdentifier];
    if (!identifier) return;
    [[self window] orderOut:self];
    [_delegate layoutChooser:self didChoose:identifier];
}

- (IBAction)cancel:(id)sender
{
    [[self window] orderOut:self];
}

#pragma mark - Table

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return (NSInteger)[_shown count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)column row:(NSInteger)row
{
    return [[self class] titleForIdentifier:_shown[(NSUInteger)row]];
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
    [self selectionChanged];
}

@end
