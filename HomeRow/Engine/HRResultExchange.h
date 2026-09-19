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

/* Results on their way out of HomeRow and back in.
 *
 * There is no standard for typing results.  The nearest thing is the CSV
 * MonkeyType exports, which people already have tools for -- so the CSV
 * written here has exactly MonkeyType's columns, in MonkeyType's order and
 * units, followed by HomeRow's own; and a MonkeyType results.csv can be
 * read in.  CSV is for spreadsheets and other people's scripts: it carries
 * one line per result and none of the per-key or per-second detail.
 *
 * JSON is HomeRow's own and loses nothing: what moves a history from one
 * machine to another, macOS to Linux included.
 *
 * A RECORD is a plain dictionary (docs/results-format.md spells it out):
 *   uuid (NSString), date (NSDate), mode, settingsKey, languageID, layoutID,
 *   amount, wpm, rawWpm, accuracy, consistency, duration,
 *   correctCharacters, incorrectCharacters, extraCharacters,
 *   missedCharacters, punctuation, numbers, isBest (NSNumber),
 *   courseFile, lessonIndex, stepIndex (absent outside courses and code),
 *   keys: character -> {hits, misses, timed, time},
 *   series: {raw: [...], errors: [...]}.
 * Everything but date, mode and wpm may be missing. */

extern NSString * const HRResultExchangeFormatName;      /* @"homerow-results" */
extern const NSInteger HRResultExchangeFormatVersion;    /* 1 */

@interface HRResultExchange : NSObject

+ (NSData *)JSONDataFromRecords:(NSArray *)records error:(NSError **)error;
+ (NSData *)CSVDataFromRecords:(NSArray *)records;

/* HomeRow's JSON, HomeRow's CSV or MonkeyType's CSV, told apart by looking.
 * Records that make no sense (no date, no mode, a speed that is not a
 * number) are dropped; `skipped` says how many. */
+ (NSArray *)recordsFromData:(NSData *)data skipped:(NSUInteger *)skipped error:(NSError **)error;

/* One line of CSV into its fields: quotes, doubled quotes, commas inside. */
+ (NSArray *)fieldsOfCSVLine:(NSString *)line;

@end
