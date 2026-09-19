/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * This library is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2.1 of the License, or (at
 * your option) any later version.  See COPYING.LIB.
 */
#import <Foundation/Foundation.h>

/* What has to be pressed after a word to move on to the next one. */
typedef NS_ENUM(NSInteger, HRSeparator) {
    HRSeparatorSpace = 0,
    HRSeparatorNewline
};

/* One target word, split into the units a learner types.
 *
 * The unit is the composed character sequence, not the unichar: "é" typed
 * through a dead key and an emoji outside the BMP are one target each.
 * Every language pack relies on this, so nothing else in the engine may
 * index a target string by UTF-16 offset. */
@interface HRWord : NSObject

@property (nonatomic, readonly, copy) NSString *text;
@property (nonatomic, readonly, copy) NSArray *characters; /* of NSString */
@property (nonatomic, readonly) HRSeparator separator;

+ (instancetype)wordWithText:(NSString *)text;
+ (instancetype)wordWithText:(NSString *)text separator:(HRSeparator)separator;

/* Splits a string into its composed character sequences. */
+ (NSArray *)charactersOfString:(NSString *)string;

@end
