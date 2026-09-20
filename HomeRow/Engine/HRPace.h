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

typedef NS_ENUM(NSInteger, HRPaceKind) {
    HRPaceOff = 0,
    HRPaceAverage,   /* the average of the last ten tests with these settings */
    HRPaceBest,      /* the personal best with these settings */
    HRPaceCustom     /* a speed of one's choosing */
};

/* The pace caret: a second caret that goes through the text at a steady
 * speed, to be kept up with or beaten.  Pure arithmetic; the view draws. */
@interface HRPace : NSObject

/* How far a typist at `wpm` is after `seconds`, in characters (a word is
 * five, the space after it included). */
+ (double)charactersAtWpm:(double)wpm elapsed:(NSTimeInterval)seconds;

/* Where that is in `words` (HRWord): the word, and the character in it --
 * equal to the word's length when the caret is on the separator after it.
 * NO when the pace has run past the words there are. */
+ (BOOL)getWordIndex:(NSUInteger *)wordIndex characterIndex:(NSUInteger *)characterIndex
       forCharacters:(double)characters inWords:(NSArray *)words;

/* The average for HRPaceAverage: of the last ten of `speeds` (oldest first);
 * 0 when there are none. */
+ (double)averageOfRecentSpeeds:(NSArray *)speeds;

@end
