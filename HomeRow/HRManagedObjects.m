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

@dynamic character, hits, misses, result;

@end
