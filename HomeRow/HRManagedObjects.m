/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * HomeRow is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version.  It comes with ABSOLUTELY NO WARRANTY.  See COPYING.
 */
#import "HRManagedObjects.h"

@implementation HRTestResult

@dynamic date, mode, amount, settingsKey, languageID, layoutID;
@dynamic wpm, rawWpm, accuracy, consistency, duration;
@dynamic correctCharacters, incorrectCharacters, extraCharacters, missedCharacters;
@dynamic series, keyStats;
@dynamic courseFile, lessonIndex, stepIndex, uuid;

- (NSDictionary *)seriesDictionary
{
    NSData *data = self.series;
    if (!data) return @{};
    id plist = [NSPropertyListSerialization propertyListWithData:data
                                                         options:NSPropertyListImmutable
                                                          format:NULL
                                                           error:NULL];
    return [plist isKindOfClass:[NSDictionary class]] ? plist : @{};
}

@end

@implementation HRKeyStat

@dynamic character, hits, misses, timedHits, totalTime, result;

@end

@implementation HRCourseProgress
@dynamic courseFile, lessonIndex, stepIndex, startedDate, lastDate;
@end

@implementation HRLessonRecord
@dynamic courseFile, lessonIndex, title, attempts, completions;
@dynamic bestWpm, bestAccuracy, lastWpm, lastAccuracy, totalDuration, lastDate;
@end
