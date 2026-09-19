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

/* GNU Typist lesson scripts (.typ).
 *
 * The format, from the gtypist manual: every line is `C:data`, the colon in
 * column two.  C is the command; a space there continues the previous
 * command on a new line.  `#` lines and blank lines are ignored.
 *
 *   B banner        T tutorial text      I instruction (above an exercise)
 *   D/d drill       S/s speed test       (lowercase: practice only)
 *   * label         G goto               M menu
 *   Q yes/no query  Y/N goto on answer   K bind a function key (old menus)
 *   E max error %   F on-failure label   X exit
 *
 * HRTypScript keeps the commands as they are, so a faithful interpreter can
 * be written over them; -lessons is the simpler view HomeRow's course UI
 * wants: the script walked top to bottom, cut into lessons at each banner. */

extern NSString * const HRTypErrorDomain;

typedef NS_ENUM(NSInteger, HRTypExerciseKind) {
    HRTypDrill = 0,   /* D, d: finger training, line by line */
    HRTypSpeedTest    /* S, s: running text */
};

@interface HRTypCommand : NSObject
@property (nonatomic, readonly) unichar type;
@property (nonatomic, readonly, copy) NSString *data;   /* continuation lines joined with \n */
@property (nonatomic, readonly) NSUInteger line;         /* 1-based */
@end

@interface HRTypMenuItem : NSObject
@property (nonatomic, readonly, copy) NSString *label;
@property (nonatomic, readonly, copy) NSString *title;
@end

@interface HRTypMenu : NSObject
@property (nonatomic, readonly, copy) NSString *title;
@property (nonatomic, readonly, copy) NSString *upLabel;   /* nil, a label, or "_EXIT" */
@property (nonatomic, readonly, copy) NSArray *items;      /* HRTypMenuItem */
@end

/* A tutorial page or an exercise, in script order. */
@interface HRTypStep : NSObject
@property (nonatomic, readonly) BOOL isExercise;
@property (nonatomic, readonly, copy) NSString *text;          /* tutorial text, or the text to type */
/* exercises only */
@property (nonatomic, readonly) HRTypExerciseKind kind;
@property (nonatomic, readonly) BOOL practiceOnly;
@property (nonatomic, readonly, copy) NSString *instruction;   /* the preceding I:, may be nil */
@property (nonatomic, readonly) double maxErrorPercent;        /* from E:, -1 = the default */
@end

@interface HRTypLesson : NSObject
@property (nonatomic, readonly, copy) NSString *title;    /* the banner, trimmed */
@property (nonatomic, readonly, copy) NSString *label;    /* nearest label before the banner, may be nil */
@property (nonatomic, readonly, copy) NSArray *steps;     /* HRTypStep */
- (NSUInteger)exerciseCount;
@end

@interface HRTypScript : NSObject

@property (nonatomic, readonly, copy) NSArray *commands;   /* HRTypCommand */
@property (nonatomic, readonly, copy) NSArray *menus;      /* HRTypMenu, in script order */
@property (nonatomic, readonly, copy) NSArray *lessons;    /* HRTypLesson, empty ones dropped */
/* Problems that did not stop the parse: gotos to labels that do not exist,
 * duplicate labels.  NSError objects. */
@property (nonatomic, readonly, copy) NSArray *warnings;

+ (instancetype)scriptWithContentsOfFile:(NSString *)path error:(NSError **)error;
+ (instancetype)scriptWithString:(NSString *)string error:(NSError **)error;

/* Index into -commands of the `*:` command, or NSNotFound. */
- (NSUInteger)indexOfLabel:(NSString *)label;

@end
