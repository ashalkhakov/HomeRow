/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * HomeRow is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version.  It comes with ABSOLUTELY NO WARRANTY.  See COPYING.
 */
#import "HRResultExchange.h"
#import "HRWord.h"

NSString * const HRResultExchangeFormatName = @"homerow-results";
const NSInteger HRResultExchangeFormatVersion = 1;

/* MonkeyType's columns, as frontend/src/ts/utils/misc.ts writes them... */
static NSArray *HRMonkeyTypeColumns(void)
{
    return @[@"_id", @"isPb", @"wpm", @"acc", @"rawWpm", @"consistency", @"charStats", @"mode", @"mode2",
             @"quoteLength", @"restartCount", @"testDuration", @"afkDuration", @"incompleteTestSeconds",
             @"punctuation", @"numbers", @"language", @"funbox", @"difficulty", @"lazyMode", @"blindMode",
             @"bailedOut", @"tags", @"timestamp"];
}

/* ...and what HomeRow adds after them. */
static NSArray *HRHomeRowColumns(void)
{
    return @[@"homerowMode", @"layout", @"courseFile", @"lessonIndex", @"stepIndex"];
}

@implementation HRResultExchange

#pragma mark - JSON

+ (NSDictionary *)JSONObjectFromRecord:(NSDictionary *)r
{
    NSMutableDictionary *o = [NSMutableDictionary dictionary];
    for (NSString *key in r) {
        id value = r[key];
        if ([value isKindOfClass:[NSDate class]]) {
            /* milliseconds since 1970, as MonkeyType's timestamp: no time zones, no formats */
            o[@"timestamp"] = @((long long)llround([(NSDate *)value timeIntervalSince1970] * 1000.0));
        } else if ([value isKindOfClass:[NSNumber class]] && !isfinite([value doubleValue])) {
            continue;   /* JSON has no NaN */
        } else {
            o[key] = value;
        }
    }
    return o;
}

+ (NSData *)JSONDataFromRecords:(NSArray *)records error:(NSError **)error
{
    NSMutableArray *results = [NSMutableArray arrayWithCapacity:[records count]];
    for (NSDictionary *r in records) [results addObject:[self JSONObjectFromRecord:r]];
    NSDictionary *document = @{@"format": HRResultExchangeFormatName,
                               @"version": @(HRResultExchangeFormatVersion),
                               @"results": results};
    return [NSJSONSerialization dataWithJSONObject:document options:NSJSONWritingPrettyPrinted error:error];
}

#pragma mark - CSV

+ (NSString *)monkeyTypeModeForRecord:(NSDictionary *)r
{
    NSString *mode = r[@"mode"];
    if ([mode isEqualToString:@"time"] || [mode isEqualToString:@"words"] || [mode isEqualToString:@"zen"]) return mode;
    return @"custom";   /* lessons, code, practice and custom texts: a text that was given */
}

+ (NSString *)CSVField:(id)value
{
    if (!value || value == [NSNull null]) return @"";
    NSString *s = [value isKindOfClass:[NSString class]] ? value : [value description];
    if ([s rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@",\"\n\r"]].location == NSNotFound) return s;
    return [NSString stringWithFormat:@"\"%@\"", [s stringByReplacingOccurrencesOfString:@"\"" withString:@"\"\""]];
}

+ (NSString *)number:(id)value decimals:(int)decimals
{
    if (![value isKindOfClass:[NSNumber class]] || !isfinite([value doubleValue])) return @"";
    return [NSString stringWithFormat:@"%.*f", decimals, [value doubleValue]];
}

+ (NSData *)CSVDataFromRecords:(NSArray *)records
{
    NSMutableArray *lines = [NSMutableArray array];
    [lines addObject:[[HRMonkeyTypeColumns() arrayByAddingObjectsFromArray:HRHomeRowColumns()] componentsJoinedByString:@","]];
    for (NSDictionary *r in records) {
        NSString *mode = [self monkeyTypeModeForRecord:r];
        BOOL counted = [mode isEqualToString:@"time"] || [mode isEqualToString:@"words"];
        NSString *chars = [NSString stringWithFormat:@"%ld;%ld;%ld;%ld",
                           (long)[r[@"correctCharacters"] integerValue], (long)[r[@"incorrectCharacters"] integerValue],
                           (long)[r[@"extraCharacters"] integerValue], (long)[r[@"missedCharacters"] integerValue]];
        long long ms = (long long)llround([(NSDate *)r[@"date"] timeIntervalSince1970] * 1000.0);
        NSArray *fields = @[
            r[@"uuid"] ?: @"",
            [r[@"isBest"] boolValue] ? @"true" : @"false",
            [self number:r[@"wpm"] decimals:2], [self number:r[@"accuracy"] decimals:2],
            [self number:r[@"rawWpm"] decimals:2], [self number:r[@"consistency"] decimals:2],
            chars, mode,
            counted ? [NSString stringWithFormat:@"%ld", (long)[r[@"amount"] integerValue]] : mode,
            @"", @"0", [self number:r[@"duration"] decimals:2], @"0", @"0",
            [r[@"punctuation"] boolValue] ? @"true" : @"false", [r[@"numbers"] boolValue] ? @"true" : @"false",
            r[@"languageID"] ?: @"", @"none", @"normal", @"false", @"false", @"false", @"",
            [NSString stringWithFormat:@"%lld", ms],
            /* HomeRow's own */
            r[@"mode"] ?: @"", r[@"layoutID"] ?: @"", r[@"courseFile"] ?: @"",
            r[@"lessonIndex"] ? [r[@"lessonIndex"] description] : @"", r[@"stepIndex"] ? [r[@"stepIndex"] description] : @""];
        NSMutableArray *escaped = [NSMutableArray arrayWithCapacity:[fields count]];
        for (id f in fields) [escaped addObject:[self CSVField:f]];
        [lines addObject:[escaped componentsJoinedByString:@","]];
    }
    return [[[lines componentsJoinedByString:@"\n"] stringByAppendingString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding];
}

+ (NSArray *)fieldsOfCSVLine:(NSString *)line
{
    NSMutableArray *fields = [NSMutableArray array];
    NSMutableString *field = [NSMutableString string];
    BOOL quoted = NO;
    NSUInteger n = [line length];
    for (NSUInteger i = 0; i < n; i++) {
        unichar c = [line characterAtIndex:i];
        if (quoted) {
            if (c == '"') {
                if (i + 1 < n && [line characterAtIndex:i + 1] == '"') { [field appendString:@"\""]; i++; }
                else quoted = NO;
            } else {
                [field appendFormat:@"%C", c];
            }
        } else if (c == '"' && [field length] == 0) {
            quoted = YES;
        } else if (c == ',') {
            [fields addObject:[field copy]];
            [field setString:@""];
        } else {
            [field appendFormat:@"%C", c];
        }
    }
    [fields addObject:[field copy]];
    return fields;
}

#pragma mark - Reading

+ (NSNumber *)numberFrom:(id)value
{
    if ([value isKindOfClass:[NSNumber class]]) return isfinite([value doubleValue]) ? value : nil;
    if (![value isKindOfClass:[NSString class]] || [value length] == 0) return nil;
    NSScanner *scanner = [NSScanner scannerWithString:value];
    double d = 0.0;
    if (![scanner scanDouble:&d] || ![scanner isAtEnd] || !isfinite(d)) return nil;
    return @(d);
}

/* nil when the record is not one: a date, a mode and a speed are the least */
+ (NSDictionary *)checkedRecord:(NSMutableDictionary *)r
{
    if (![r[@"date"] isKindOfClass:[NSDate class]]) return nil;
    if (![r[@"mode"] isKindOfClass:[NSString class]] || [r[@"mode"] length] == 0) return nil;
    NSNumber *wpm = [self numberFrom:r[@"wpm"]];
    if (!wpm || [wpm doubleValue] < 0.0 || [wpm doubleValue] > 1000.0) return nil;
    /* a history from the future or from before typewriters is a broken file */
    NSTimeInterval t = [(NSDate *)r[@"date"] timeIntervalSince1970];
    if (t < 0.0 || t > [[NSDate date] timeIntervalSince1970] + 366.0 * 86400.0) return nil;
    return r;
}

+ (NSArray *)recordsFromJSONObject:(id)document skipped:(NSUInteger *)skipped error:(NSError **)error
{
    NSArray *results = [document isKindOfClass:[NSDictionary class]] ? document[@"results"] : nil;
    if (![[document valueForKey:@"format"] isEqual:HRResultExchangeFormatName] || ![results isKindOfClass:[NSArray class]]) {
        if (error) *error = [NSError errorWithDomain:@"HRResultExchange" code:1
                                            userInfo:@{NSLocalizedDescriptionKey: @"This is JSON, but not a HomeRow results file."}];
        return nil;
    }
    if ([[document valueForKey:@"version"] integerValue] > HRResultExchangeFormatVersion) {
        if (error) *error = [NSError errorWithDomain:@"HRResultExchange" code:2
                                            userInfo:@{NSLocalizedDescriptionKey: @"This results file was written by a newer HomeRow."}];
        return nil;
    }
    NSArray *numeric = @[@"amount", @"wpm", @"rawWpm", @"accuracy", @"consistency", @"duration", @"correctCharacters",
                         @"incorrectCharacters", @"extraCharacters", @"missedCharacters", @"lessonIndex", @"stepIndex",
                         @"punctuation", @"numbers", @"isBest"];
    NSArray *textual = @[@"uuid", @"mode", @"settingsKey", @"languageID", @"layoutID", @"courseFile"];
    NSMutableArray *out = [NSMutableArray array];
    for (id item in results) {
        if (![item isKindOfClass:[NSDictionary class]]) { if (skipped) (*skipped)++; continue; }
        NSMutableDictionary *r = [NSMutableDictionary dictionary];
        NSNumber *ms = [self numberFrom:item[@"timestamp"]];
        if (ms) r[@"date"] = [NSDate dateWithTimeIntervalSince1970:[ms doubleValue] / 1000.0];
        for (NSString *key in numeric) {
            NSNumber *n = [self numberFrom:item[key]];
            if (n) r[key] = n;
        }
        for (NSString *key in textual) {
            if ([item[key] isKindOfClass:[NSString class]]) r[key] = item[key];
        }
        /* keys and series: only what has the right shape comes through */
        if ([item[@"keys"] isKindOfClass:[NSDictionary class]]) {
            NSMutableDictionary *keys = [NSMutableDictionary dictionary];
            for (id ch in item[@"keys"]) {
                NSDictionary *c = item[@"keys"][ch];
                if (![ch isKindOfClass:[NSString class]] || ![c isKindOfClass:[NSDictionary class]]) continue;
                keys[ch] = @{@"hits": [self numberFrom:c[@"hits"]] ?: @0, @"misses": [self numberFrom:c[@"misses"]] ?: @0,
                             @"timed": [self numberFrom:c[@"timed"]] ?: @0, @"time": [self numberFrom:c[@"time"]] ?: @0.0};
            }
            r[@"keys"] = keys;
        }
        if ([item[@"series"] isKindOfClass:[NSDictionary class]]) {
            NSMutableDictionary *series = [NSMutableDictionary dictionary];
            for (NSString *name in @[@"raw", @"errors"]) {
                NSMutableArray *values = [NSMutableArray array];
                if ([item[@"series"][name] isKindOfClass:[NSArray class]]) {
                    for (id v in item[@"series"][name]) [values addObject:[self numberFrom:v] ?: @0];
                }
                series[name] = values;
            }
            r[@"series"] = series;
        }
        NSDictionary *checked = [self checkedRecord:r];
        if (checked) [out addObject:checked]; else if (skipped) (*skipped)++;
    }
    return out;
}

+ (NSArray *)recordsFromCSV:(NSString *)text skipped:(NSUInteger *)skipped error:(NSError **)error
{
    NSArray *lines = [HRWord linesOfString:text];
    NSArray *header = [lines count] > 0 ? [self fieldsOfCSVLine:lines[0]] : @[];
    NSUInteger (^column)(NSString *) = ^NSUInteger(NSString *name) { return [header indexOfObject:name]; };
    if (column(@"wpm") == NSNotFound || column(@"timestamp") == NSNotFound || column(@"mode") == NSNotFound) {
        if (error) *error = [NSError errorWithDomain:@"HRResultExchange" code:3
                                            userInfo:@{NSLocalizedDescriptionKey: @"This is neither a HomeRow results file nor a MonkeyType results.csv."}];
        return nil;
    }
    BOOL ours = column(@"homerowMode") != NSNotFound;
    NSMutableArray *out = [NSMutableArray array];
    for (NSUInteger i = 1; i < [lines count]; i++) {
        if ([[lines[i] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] length] == 0) continue;
        NSArray *f = [self fieldsOfCSVLine:lines[i]];
        NSString *(^field)(NSString *) = ^NSString *(NSString *name) {
            NSUInteger c = column(name);
            return (c != NSNotFound && c < [f count]) ? f[c] : @"";
        };
        NSMutableDictionary *r = [NSMutableDictionary dictionary];
        NSNumber *ms = [self numberFrom:field(@"timestamp")];
        if (ms) r[@"date"] = [NSDate dateWithTimeIntervalSince1970:[ms doubleValue] / 1000.0];
        NSString *mode = field(@"mode");
        if (ours && [field(@"homerowMode") length] > 0) mode = field(@"homerowMode");
        /* a MonkeyType quote is, to HomeRow, a text that was given */
        else if ([mode isEqualToString:@"quote"]) mode = @"custom";
        r[@"mode"] = mode;
        NSDictionary *numbers = @{@"wpm": @"wpm", @"rawWpm": @"rawWpm", @"accuracy": @"acc", @"consistency": @"consistency",
                                  @"duration": @"testDuration", @"lessonIndex": @"lessonIndex", @"stepIndex": @"stepIndex"};
        for (NSString *key in numbers) {
            NSNumber *n = [self numberFrom:field(numbers[key])];
            if (n) r[key] = n;
        }
        NSNumber *amount = [self numberFrom:field(@"mode2")];
        if (amount) r[@"amount"] = amount;
        NSArray *chars = [field(@"charStats") componentsSeparatedByString:@";"];
        NSArray *names = @[@"correctCharacters", @"incorrectCharacters", @"extraCharacters", @"missedCharacters"];
        for (NSUInteger c = 0; c < [names count] && c < [chars count]; c++) {
            NSNumber *n = [self numberFrom:chars[c]];
            if (n) r[names[c]] = n;
        }
        r[@"punctuation"] = @([field(@"punctuation") isEqualToString:@"true"]);
        r[@"numbers"] = @([field(@"numbers") isEqualToString:@"true"]);
        if ([field(@"language") length] > 0) r[@"languageID"] = field(@"language");
        if ([field(@"layout") length] > 0) r[@"layoutID"] = field(@"layout");
        if ([field(@"courseFile") length] > 0) r[@"courseFile"] = field(@"courseFile");
        /* an id from somewhere else is kept apart from HomeRow's own */
        if ([field(@"_id") length] > 0) r[@"uuid"] = ours ? field(@"_id") : [@"monkeytype:" stringByAppendingString:field(@"_id")];
        NSDictionary *checked = [self checkedRecord:r];
        if (checked) [out addObject:checked]; else if (skipped) (*skipped)++;
    }
    return out;
}

+ (NSArray *)recordsFromData:(NSData *)data skipped:(NSUInteger *)skipped error:(NSError **)error
{
    if (skipped) *skipped = 0;
    NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if ([text length] == 0) {
        if (error) *error = [NSError errorWithDomain:@"HRResultExchange" code:4
                                            userInfo:@{NSLocalizedDescriptionKey: @"The file is empty, or not text."}];
        return nil;
    }
    NSString *trimmed = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([trimmed hasPrefix:@"{"]) {
        id document = [NSJSONSerialization JSONObjectWithData:data options:0 error:error];
        return document ? [self recordsFromJSONObject:document skipped:skipped error:error] : nil;
    }
    return [self recordsFromCSV:text skipped:skipped error:error];
}

@end
