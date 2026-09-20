/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * HomeRow is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version.  It comes with ABSOLUTELY NO WARRANTY.  See COPYING.
 */
#import "HRPace.h"
#import "HRWord.h"

@implementation HRPace

+ (double)charactersAtWpm:(double)wpm elapsed:(NSTimeInterval)seconds
{
    if (wpm <= 0.0 || seconds <= 0.0) return 0.0;
    return wpm * 5.0 * seconds / 60.0;
}

+ (BOOL)getWordIndex:(NSUInteger *)wordIndex characterIndex:(NSUInteger *)characterIndex
       forCharacters:(double)characters inWords:(NSArray *)words
{
    NSUInteger whole = (NSUInteger)MAX(0.0, characters);
    NSUInteger i = 0;
    for (HRWord *word in words) {
        NSUInteger length = [word.characters count];
        if (whole <= length) {
            if (wordIndex) *wordIndex = i;
            if (characterIndex) *characterIndex = whole;
            return YES;
        }
        whole -= length + 1;
        i++;
    }
    return NO;
}

+ (double)averageOfRecentSpeeds:(NSArray *)speeds
{
    NSUInteger count = [speeds count], from = count > 10 ? count - 10 : 0;
    if (count == 0) return 0.0;
    double sum = 0.0;
    for (NSUInteger i = from; i < count; i++) sum += [speeds[i] doubleValue];
    return sum / (double)(count - from);
}

@end
