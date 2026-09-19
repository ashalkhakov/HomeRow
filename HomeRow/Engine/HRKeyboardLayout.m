/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * HomeRow is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version.  It comes with ABSOLUTELY NO WARRANTY.  See COPYING.
 */
#import "HRKeyboardLayout.h"
#import "HRLanguage.h"   /* HRPackErrorDomain */
#import "HRWord.h"

@interface HRKeyPosition ()
- (instancetype)initWithRow:(NSUInteger)row column:(NSUInteger)column level:(NSUInteger)level finger:(HRFinger)finger;
@end

@implementation HRKeyPosition
- (instancetype)initWithRow:(NSUInteger)row column:(NSUInteger)column level:(NSUInteger)level finger:(HRFinger)finger
{
    if ((self = [super init])) { _row = row; _column = column; _level = level; _finger = finger; }
    return self;
}
- (BOOL)needsShift { return (_level & 1) != 0; }
- (BOOL)usesLeftShift { return _finger >= HRFingerRightIndex; }
@end

@implementation HRKeyboardLayout
{
    NSArray *_rows;              /* rows of keys; a key is an NSArray of NSString */
    NSDictionary *_positions;    /* character -> HRKeyPosition */
}

static NSError *HRLayoutError(NSString *what)
{
    return [NSError errorWithDomain:HRPackErrorDomain code:2 userInfo:@{NSLocalizedDescriptionKey: what}];
}

+ (instancetype)layoutWithContentsOfFile:(NSString *)path error:(NSError **)error
{
    NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:path];
    if (![d isKindOfClass:[NSDictionary class]]) {
        if (error) *error = HRLayoutError([NSString stringWithFormat:@"%@ is not a property list dictionary", [path lastPathComponent]]);
        return nil;
    }
    return [self layoutWithDictionary:d error:error];
}

+ (NSArray *)identifiersInDirectory:(NSString *)directory
{
    NSMutableArray *ids = [NSMutableArray array];
    for (NSString *f in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directory error:NULL]) {
        if ([[f pathExtension] isEqualToString:@"plist"]) [ids addObject:[f stringByDeletingPathExtension]];
    }
    return [ids sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
}

/* The standard assignment, by column.  Both geometries share it except on
 * the bottom row, where ISO's extra key pushes everything one to the right. */
+ (HRFinger)fingerForRow:(NSUInteger)row column:(NSUInteger)column geometry:(HRKeyboardGeometry)geometry
{
    static const HRFinger numberRow[] = {
        HRFingerLeftLittle, HRFingerLeftLittle, HRFingerLeftRing, HRFingerLeftMiddle, HRFingerLeftIndex,
        HRFingerLeftIndex, HRFingerRightIndex, HRFingerRightIndex, HRFingerRightMiddle, HRFingerRightRing };
    static const HRFinger letterRow[] = {
        HRFingerLeftLittle, HRFingerLeftRing, HRFingerLeftMiddle, HRFingerLeftIndex, HRFingerLeftIndex,
        HRFingerRightIndex, HRFingerRightIndex, HRFingerRightMiddle, HRFingerRightRing };
    if (row == 0) return column < 10 ? numberRow[column] : HRFingerRightLittle;
    if (row == 3 && geometry == HRKeyboardISO) {
        if (column == 0) return HRFingerLeftLittle;
        column--;
    }
    return column < 9 ? letterRow[column] : HRFingerRightLittle;
}

+ (instancetype)layoutWithDictionary:(NSDictionary *)d error:(NSError **)error
{
    NSString *identifier = d[@"identifier"];
    NSArray *rows = d[@"rows"];
    if (![identifier isKindOfClass:[NSString class]] || [identifier length] == 0) {
        if (error) *error = HRLayoutError(@"the layout has no identifier");
        return nil;
    }
    if (![rows isKindOfClass:[NSArray class]] || [rows count] != 4) {
        if (error) *error = HRLayoutError([NSString stringWithFormat:@"%@: \"rows\" must hold four rows", identifier]);
        return nil;
    }
    HRKeyboardLayout *l = [[self alloc] init];
    l->_identifier = [identifier copy];
    l->_displayName = [(d[@"displayName"] ?: identifier) copy];
    l->_geometry = [d[@"geometry"] isEqual:@"iso"] ? HRKeyboardISO : HRKeyboardANSI;

    NSMutableArray *parsedRows = [NSMutableArray array];
    NSMutableDictionary *positions = [NSMutableDictionary dictionary];
    for (NSUInteger r = 0; r < 4; r++) {
        NSArray *row = rows[r];
        if (![row isKindOfClass:[NSArray class]] || [row count] == 0) {
            if (error) *error = HRLayoutError([NSString stringWithFormat:@"%@: row %lu is empty", identifier, (unsigned long)(r + 1)]);
            return nil;
        }
        NSMutableArray *keys = [NSMutableArray array];
        for (NSUInteger c = 0; c < [row count]; c++) {
            id key = row[c];
            /* "qQ" is short for ("q", "Q") */
            NSArray *chars = [key isKindOfClass:[NSString class]] ? [HRWord charactersOfString:key]
                           : ([key isKindOfClass:[NSArray class]] ? key : @[]);
            [keys addObject:chars];
            HRFinger finger = [self fingerForRow:r column:c geometry:l->_geometry];
            for (NSUInteger level = 0; level < [chars count]; level++) {
                NSString *ch = chars[level];
                /* the first place a character is found wins: plain before
                 * shifted, and the main block before a duplicate elsewhere */
                if ([ch length] == 0 || positions[ch]) continue;
                positions[ch] = [[HRKeyPosition alloc] initWithRow:r column:c level:level finger:finger];
            }
        }
        [parsedRows addObject:keys];
    }
    l->_rows = parsedRows;
    l->_positions = positions;
    return l;
}

- (NSUInteger)numberOfRows { return [_rows count]; }

- (NSUInteger)numberOfKeysInRow:(NSUInteger)row
{
    return row < [_rows count] ? [_rows[row] count] : 0;
}

- (NSArray *)charactersForKeyAtRow:(NSUInteger)row column:(NSUInteger)column
{
    if (row >= [_rows count] || column >= [_rows[row] count]) return @[];
    return _rows[row][column];
}

- (HRFinger)fingerForKeyAtRow:(NSUInteger)row column:(NSUInteger)column
{
    return [[self class] fingerForRow:row column:column geometry:_geometry];
}

- (HRKeyPosition *)positionOfCharacter:(NSString *)character
{
    return character ? _positions[character] : nil;
}

@end
