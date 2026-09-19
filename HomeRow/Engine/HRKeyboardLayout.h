/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * HomeRow is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version.  It comes with ABSOLUTELY NO WARRANTY.  See COPYING.
 */
#import <Foundation/Foundation.h>

/* Which finger a key belongs to in standard touch typing. */
typedef NS_ENUM(NSInteger, HRFinger) {
    HRFingerLeftLittle = 0,
    HRFingerLeftRing,
    HRFingerLeftMiddle,
    HRFingerLeftIndex,
    HRFingerRightIndex,
    HRFingerRightMiddle,
    HRFingerRightRing,
    HRFingerRightLittle,
    HRFingerThumb
};

typedef NS_ENUM(NSInteger, HRKeyboardGeometry) {
    HRKeyboardANSI = 0,
    HRKeyboardISO      /* tall Return, one more key left of Z */
};

/* Where a character is on the keyboard. */
@interface HRKeyPosition : NSObject
@property (nonatomic, readonly) NSUInteger row;      /* 0 = number row ... 3 = bottom letter row */
@property (nonatomic, readonly) NSUInteger column;   /* 0 = leftmost character key of that row */
@property (nonatomic, readonly) NSUInteger level;    /* 0 plain, 1 Shift, 2 AltGr/Option, 3 both */
@property (nonatomic, readonly) HRFinger finger;
- (BOOL)needsShift;
/* Shift is held with the hand that is not typing the key. */
- (BOOL)usesLeftShift;
@end

/* A layout pack: Layouts/<id>.plist, see docs/adding-a-layout.md.  It is a
 * DESCRIPTION of the layout the system is already set to -- HomeRow never
 * remaps a key.  The on-screen keyboard, the finger hints and (later) the
 * heat map all read it. */
@interface HRKeyboardLayout : NSObject

@property (nonatomic, readonly, copy) NSString *identifier;
@property (nonatomic, readonly, copy) NSString *displayName;
@property (nonatomic, readonly) HRKeyboardGeometry geometry;

+ (instancetype)layoutWithContentsOfFile:(NSString *)path error:(NSError **)error;
+ (instancetype)layoutWithDictionary:(NSDictionary *)dictionary error:(NSError **)error;
/* Identifiers of the packs in a directory, sorted. */
+ (NSArray *)identifiersInDirectory:(NSString *)directory;

- (NSUInteger)numberOfRows;
- (NSUInteger)numberOfKeysInRow:(NSUInteger)row;
/* The characters of a key, plain first; empty strings for unused levels. */
- (NSArray *)charactersForKeyAtRow:(NSUInteger)row column:(NSUInteger)column;
- (HRFinger)fingerForKeyAtRow:(NSUInteger)row column:(NSUInteger)column;

/* nil when the layout cannot type it directly.  Space and line break are
 * not character keys; the keyboard view knows where those are. */
- (HRKeyPosition *)positionOfCharacter:(NSString *)character;

@end
