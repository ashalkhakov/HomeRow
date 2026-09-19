/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * HomeRow is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version.  It comes with ABSOLUTELY NO WARRANTY.  See COPYING.
 */
#import "HRTextMateGrammar.h"
#import "HRRegex.h"
#import "HRWord.h"

typedef NS_ENUM(NSInteger, HRTMRuleKind) {
    HRTMIncludeOnly = 0,   /* nothing to match itself: a bag of patterns */
    HRTMMatch,
    HRTMBeginEnd,
    HRTMBeginWhile
};

#pragma mark - Tokens and state

@interface HRTextMateToken ()
- (instancetype)initWithRange:(NSRange)range scopes:(NSArray *)scopes;
@end

@implementation HRTextMateToken
- (instancetype)initWithRange:(NSRange)range scopes:(NSArray *)scopes
{
    if ((self = [super init])) { _range = range; _scopes = [scopes copy]; }
    return self;
}
- (BOOL)hasScopeWithPrefix:(NSString *)prefix
{
    NSString *dotted = [prefix stringByAppendingString:@"."];
    for (NSString *s in _scopes) {
        if ([s isEqualToString:prefix] || [s hasPrefix:dotted]) return YES;
    }
    return NO;
}
- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@ %@>", NSStringFromRange(_range), [_scopes componentsJoinedByString:@" "]];
}
@end

@class HRTMRule;

/* One element of the rule stack; `parent` links make the stack. */
@interface HRTextMateState ()
{
@public
    HRTMRule *rule;
    HRTextMateState *parent;
    NSInteger enterPos;          /* where in the line the rule was pushed; -1 on later lines */
    NSInteger anchorPos;         /* where \G matches for this rule's patterns */
    BOOL beginCapturedEOL;
    NSString *endSource;         /* end/while pattern with back-references filled in */
    NSArray *nameScopes;         /* scopes including this rule's name */
    NSArray *contentScopes;      /* ...and its contentName: what its contents get */
}
@end

@implementation HRTextMateState
- (HRTextMateState *)push:(HRTMRule *)r enter:(NSInteger)enter anchor:(NSInteger)anchor eol:(BOOL)eol
                   scopes:(NSArray *)scopes
{
    HRTextMateState *s = [[HRTextMateState alloc] init];
    s->rule = r; s->parent = self; s->enterPos = enter; s->anchorPos = anchor; s->beginCapturedEOL = eol;
    s->nameScopes = scopes; s->contentScopes = scopes;
    return s;
}
- (HRTextMateState *)copyWithContentScopes:(NSArray *)scopes endSource:(NSString *)end
{
    HRTextMateState *s = [[HRTextMateState alloc] init];
    s->rule = rule; s->parent = parent; s->enterPos = enterPos; s->anchorPos = anchorPos;
    s->beginCapturedEOL = beginCapturedEOL; s->nameScopes = nameScopes;
    s->contentScopes = scopes ?: contentScopes; s->endSource = end ?: endSource;
    return s;
}
@end

#pragma mark - Rules

@interface HRTMRule : NSObject
{
@public
    HRTMRuleKind kind;
    __weak HRTextMateGrammar *grammar;
    NSDictionary *repository;     /* what "#name" is looked up in */
    NSString *name, *contentName;
    HRRegex *regex;               /* match, or begin */
    NSString *endSource;          /* end or while, as written */
    BOOL endHasBackReferences;
    BOOL applyEndPatternLast;
    NSArray *captures;            /* index -> HRTMRule or NSNull; match / begin */
    NSArray *endCaptures;         /* ... end / while */
    NSArray *patternsRaw;
    /* leaf rules with includes resolved, built on first use -- per base
     * grammar, because $base means "the grammar tokenizing started in":
     * C's blocks include $base so that Objective-C works inside them */
    NSMutableDictionary *compiledPatterns;
}
@end

@implementation HRTMRule
@end

static NSArray *HRScopesPushing(NSArray *scopes, NSString *name)
{
    if ([name length] == 0) return scopes;
    NSMutableArray *out = [scopes mutableCopy] ?: [NSMutableArray array];
    /* "a.b c.d" names two scopes */
    for (NSString *part in [name componentsSeparatedByString:@" "]) {
        if ([part length] > 0) [out addObject:part];
    }
    return out;
}

static NSString *HRSubstring(const unichar *chars, NSRange r)
{
    if (r.location == NSNotFound) return @"";
    return [NSString stringWithCharacters:chars + r.location length:r.length];
}

/* "$1", "${2:/downcase}" in a scope name stand for captured text. */
static NSString *HRExpandName(NSString *name, const unichar *chars, HRRegexMatch *match)
{
    if (!name || [name rangeOfString:@"$" options:NSLiteralSearch].location == NSNotFound) return name;
    NSMutableString *out = [NSMutableString string];
    NSUInteger n = [name length], i = 0;
    while (i < n) {
        unichar c = [name characterAtIndex:i];
        if (c != '$' || i + 1 >= n) { [out appendFormat:@"%C", c]; i++; continue; }
        /* two forms only, as in the reference: $1 and ${1:/downcase|upcase}.
         * Anything else after a "$" (TextMate's ${1/regex/format/}) stays
         * as it is written. */
        NSUInteger j = i + 1;
        BOOL braced = [name characterAtIndex:j] == '{';
        if (braced) j++;
        NSUInteger digitsStart = j;
        while (j < n && [name characterAtIndex:j] >= '0' && [name characterAtIndex:j] <= '9') j++;
        if (j == digitsStart) { [out appendString:@"$"]; i++; continue; }
        NSUInteger group = (NSUInteger)[[name substringWithRange:NSMakeRange(digitsStart, j - digitsStart)] integerValue];
        NSString *command = nil;
        if (braced) {
            NSString *rest = [name substringFromIndex:j];
            if ([rest hasPrefix:@":/downcase}"]) command = @":/downcase";
            else if ([rest hasPrefix:@":/upcase}"]) command = @":/upcase";
            else { [out appendString:@"$"]; i++; continue; }
            j += [command length] + 1;
        }
        NSString *text = HRSubstring(chars, [match rangeAtIndex:group]);
        while ([text hasPrefix:@"."]) text = [text substringFromIndex:1];
        if ([command isEqualToString:@":/downcase"]) text = [text lowercaseString];
        else if ([command isEqualToString:@":/upcase"]) text = [text uppercaseString];
        [out appendString:text];
        i = j;
    }
    return out;
}

static BOOL HRHasBackReferences(NSString *source)
{
    NSUInteger n = [source length];
    for (NSUInteger i = 0; i + 1 < n; i++) {
        if ([source characterAtIndex:i] != '\\') continue;
        unichar d = [source characterAtIndex:i + 1];
        if (d >= '0' && d <= '9') return YES;
        i++;   /* an escaped backslash is not the start of anything */
    }
    return NO;
}

/* \1 in an end pattern is the text the begin pattern captured, literally. */
static NSString *HRResolveBackReferences(NSString *source, const unichar *chars, HRRegexMatch *match)
{
    NSMutableString *out = [NSMutableString string];
    /* exactly the reference's set: escaping "#" or "-" as well changes what
     * the text means inside (?x) and inside a character class */
    NSCharacterSet *special = [NSCharacterSet characterSetWithCharactersInString:@"\\|([{}]).?*+^$"];
    NSUInteger n = [source length], i = 0;
    while (i < n) {
        unichar c = [source characterAtIndex:i];
        if (c == '\\' && i + 1 < n) {
            unichar d = [source characterAtIndex:i + 1];
            if (d >= '0' && d <= '9') {
                NSUInteger j = i + 1;
                while (j < n && [source characterAtIndex:j] >= '0' && [source characterAtIndex:j] <= '9') j++;
                NSUInteger group = (NSUInteger)[[source substringWithRange:NSMakeRange(i + 1, j - i - 1)] integerValue];
                NSString *text = HRSubstring(chars, [match rangeAtIndex:group]);
                for (NSUInteger k = 0; k < [text length]; k++) {
                    unichar t = [text characterAtIndex:k];
                    if ([special characterIsMember:t]) [out appendString:@"\\"];
                    [out appendFormat:@"%C", t];
                }
                i = j;
                continue;
            }
            [out appendFormat:@"%C%C", c, d];
            i += 2;
            continue;
        }
        [out appendFormat:@"%C", c];
        i++;
    }
    return out;
}

#pragma mark - Registry

@implementation HRTextMateRegistry
{
    NSMutableDictionary *_grammars;
}
- (instancetype)init
{
    if ((self = [super init])) _grammars = [NSMutableDictionary dictionary];
    return self;
}
- (void)addGrammar:(HRTextMateGrammar *)grammar
{
    if (!grammar.scopeName) return;
    _grammars[grammar.scopeName] = grammar;
    grammar.registry = self;
}
- (HRTextMateGrammar *)grammarForScopeName:(NSString *)scopeName
{
    return scopeName ? _grammars[scopeName] : nil;
}
- (NSUInteger)addGrammarsInDirectory:(NSString *)directory
{
    NSUInteger n = 0;
    for (NSString *f in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directory error:NULL]) {
        if (![[f pathExtension] isEqualToString:@"json"]) continue;
        HRTextMateGrammar *g = [HRTextMateGrammar grammarWithContentsOfFile:[directory stringByAppendingPathComponent:f] error:NULL];
        if (g) { [self addGrammar:g]; n++; }
    }
    return n;
}
@end

#pragma mark - Grammar

@implementation HRTextMateGrammar
{
    NSDictionary *_raw;
    HRTMRule *_root;
    NSMapTable *_rules;               /* raw rule dictionary (by identity) -> HRTMRule */
    NSMutableDictionary *_regexes;    /* source -> HRRegex or NSNull */
    NSMutableArray *_problems;
}

+ (instancetype)grammarWithContentsOfFile:(NSString *)path error:(NSError **)error
{
    NSData *data = [NSData dataWithContentsOfFile:path options:0 error:error];
    if (!data) return nil;
    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
    /* the original format: a property list (.tmLanguage, .plist) */
    if (!json) json = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:NULL];
    if (![json isKindOfClass:[NSDictionary class]] || ![json[@"scopeName"] isKindOfClass:[NSString class]]) {
        if (error) {
            *error = [NSError errorWithDomain:@"HRTextMateErrorDomain" code:1
                                     userInfo:@{NSLocalizedDescriptionKey:
                                         [NSString stringWithFormat:@"%@ is not a TextMate grammar", [path lastPathComponent]]}];
        }
        return nil;
    }
    return [self grammarWithDictionary:json];
}

+ (instancetype)grammarWithDictionary:(NSDictionary *)dictionary
{
    HRTextMateGrammar *g = [[self alloc] init];
    g->_raw = dictionary;
    g->_scopeName = [dictionary[@"scopeName"] copy];
    g->_name = [(dictionary[@"name"] ?: dictionary[@"scopeName"]) copy];
    g->_rules = [NSMapTable mapTableWithKeyOptions:(NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPointerPersonality)
                                      valueOptions:NSPointerFunctionsStrongMemory];
    g->_regexes = [NSMutableDictionary dictionary];
    g->_problems = [NSMutableArray array];
    return g;
}

- (NSArray *)problems { return _problems; }

- (HRRegex *)regexForSource:(NSString *)source
{
    if (![source isKindOfClass:[NSString class]]) return nil;
    id cached = _regexes[source];
    if (cached) return cached == [NSNull null] ? nil : cached;
    /* every line is tokenized with its "\n": \z must not mean that one */
    NSString *prepared = [source stringByReplacingOccurrencesOfString:@"\\z" withString:@"$(?!\\n)(?<!\\n)"
                                                              options:NSLiteralSearch range:NSMakeRange(0, [source length])];
    NSError *error = nil;
    HRRegex *regex = [HRRegex regexWithPattern:prepared error:&error];
    if (!regex) [_problems addObject:[error localizedDescription] ?: source];
    _regexes[source] = regex ?: (id)[NSNull null];
    return regex;
}

- (NSArray *)captureRulesFrom:(NSDictionary *)raw repository:(NSDictionary *)repository
{
    if (![raw isKindOfClass:[NSDictionary class]] || [raw count] == 0) return nil;
    NSInteger max = -1;
    for (NSString *key in raw) max = MAX(max, [key integerValue]);
    NSMutableArray *out = [NSMutableArray array];
    for (NSInteger i = 0; i <= max; i++) {
        NSDictionary *c = raw[[NSString stringWithFormat:@"%ld", (long)i]];
        if (![c isKindOfClass:[NSDictionary class]]) { [out addObject:[NSNull null]]; continue; }
        HRTMRule *r = [[HRTMRule alloc] init];
        r->kind = HRTMIncludeOnly;
        r->grammar = self;
        r->repository = repository;
        r->name = c[@"name"];
        r->contentName = c[@"contentName"];
        r->patternsRaw = [c[@"patterns"] isKindOfClass:[NSArray class]] ? c[@"patterns"] : nil;
        [out addObject:r];
    }
    return out;
}

- (HRTMRule *)ruleForRaw:(NSDictionary *)raw repository:(NSDictionary *)repository
{
    if (![raw isKindOfClass:[NSDictionary class]]) return nil;
    HRTMRule *r = [_rules objectForKey:raw];
    if (r) return r;
    r = [[HRTMRule alloc] init];
    [_rules setObject:r forKey:raw];
    r->grammar = self;
    if ([raw[@"repository"] isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *merged = [repository mutableCopy] ?: [NSMutableDictionary dictionary];
        [merged addEntriesFromDictionary:raw[@"repository"]];
        repository = merged;
    }
    r->repository = repository;
    r->name = raw[@"name"];
    r->contentName = raw[@"contentName"];
    r->patternsRaw = [raw[@"patterns"] isKindOfClass:[NSArray class]] ? raw[@"patterns"] : nil;
    if ([raw[@"match"] isKindOfClass:[NSString class]]) {
        r->kind = HRTMMatch;
        r->regex = [self regexForSource:raw[@"match"]];
        r->captures = [self captureRulesFrom:raw[@"captures"] repository:repository];
        r->patternsRaw = nil;
    } else if ([raw[@"begin"] isKindOfClass:[NSString class]]) {
        BOOL isWhile = [raw[@"while"] isKindOfClass:[NSString class]];
        r->kind = isWhile ? HRTMBeginWhile : HRTMBeginEnd;
        r->regex = [self regexForSource:raw[@"begin"]];
        r->endSource = isWhile ? raw[@"while"] : ([raw[@"end"] isKindOfClass:[NSString class]] ? raw[@"end"] : @"");
        r->endHasBackReferences = HRHasBackReferences(r->endSource);
        r->applyEndPatternLast = [raw[@"applyEndPatternLast"] boolValue];
        r->captures = [self captureRulesFrom:(raw[@"beginCaptures"] ?: raw[@"captures"]) repository:repository];
        r->endCaptures = [self captureRulesFrom:((isWhile ? raw[@"whileCaptures"] : raw[@"endCaptures"]) ?: raw[@"captures"])
                                     repository:repository];
    } else {
        r->kind = HRTMIncludeOnly;
        /* a repository entry that is nothing but an include */
        if (!r->patternsRaw && [raw[@"include"] isKindOfClass:[NSString class]]) {
            r->patternsRaw = @[@{@"include": raw[@"include"]}];
        }
    }
    return r;
}

- (HRTMRule *)rootRule
{
    if (!_root) {
        _root = [[HRTMRule alloc] init];
        _root->kind = HRTMIncludeOnly;
        _root->grammar = self;
        _root->repository = [_raw[@"repository"] isKindOfClass:[NSDictionary class]] ? _raw[@"repository"] : @{};
        _root->name = _scopeName;
        _root->patternsRaw = [_raw[@"patterns"] isKindOfClass:[NSArray class]] ? _raw[@"patterns"] : @[];
    }
    return _root;
}

- (HRTMRule *)ruleNamed:(NSString *)name
{
    NSDictionary *repository = [self rootRule]->repository;
    return [self ruleForRaw:repository[name] repository:repository];
}

/* What an `include` points at; nil when it points at nothing we have. */
- (HRTMRule *)resolveInclude:(NSString *)include from:(HRTMRule *)rule base:(HRTextMateGrammar *)base
{
    if ([include hasPrefix:@"#"]) {
        NSString *key = [include substringFromIndex:1];
        return [self ruleForRaw:rule->repository[key] repository:rule->repository];
    }
    if ([include isEqualToString:@"$self"]) return [self rootRule];
    if ([include isEqualToString:@"$base"]) return [(base ?: self) rootRule];
    NSRange hash = [include rangeOfString:@"#" options:NSLiteralSearch];
    NSString *scope = hash.location == NSNotFound ? include : [include substringToIndex:hash.location];
    HRTextMateGrammar *other = [scope isEqualToString:_scopeName] ? self : [_registry grammarForScopeName:scope];
    if (!other) return nil;
    if (hash.location == NSNotFound) return [other rootRule];
    return [other ruleNamed:[include substringFromIndex:hash.location + 1]];
}

- (NSUInteger)resolvablePatternCountOf:(HRTMRule *)rule base:(HRTextMateGrammar *)base
{
    NSUInteger n = 0;
    for (NSDictionary *raw in rule->patternsRaw) {
        if (![raw isKindOfClass:[NSDictionary class]]) continue;
        if (![raw[@"include"] isKindOfClass:[NSString class]]
            || [self resolveInclude:raw[@"include"] from:rule base:base]) n++;
    }
    return n;
}

- (void)collectPatternsOf:(HRTMRule *)rule into:(NSMutableArray *)out visited:(NSMutableSet *)visited
                     base:(HRTextMateGrammar *)base
{
    for (NSDictionary *raw in rule->patternsRaw) {
        if (![raw isKindOfClass:[NSDictionary class]] || [raw[@"disabled"] boolValue]) continue;
        HRTMRule *target;
        if ([raw[@"include"] isKindOfClass:[NSString class]]) {
            target = [rule->grammar ?: self resolveInclude:raw[@"include"] from:rule base:base];
        } else {
            target = [rule->grammar ?: self ruleForRaw:raw repository:rule->repository];
        }
        if (!target) continue;
        /* a rule all of whose patterns point at grammars we do not have is
         * dropped whole, as the reference does: a begin with nothing to put
         * inside it would swallow the text it was meant to hand on */
        if (target->kind != HRTMMatch && [target->patternsRaw count] > 0
            && [target->grammar ?: self resolvablePatternCountOf:target base:base] == 0) continue;
        if (target->kind == HRTMIncludeOnly) {
            NSValue *key = [NSValue valueWithNonretainedObject:target];
            if ([visited containsObject:key]) continue;
            [visited addObject:key];
            [target->grammar ?: self collectPatternsOf:target into:out visited:visited base:base];
        } else if (target->regex) {
            [out addObject:target];
        }
    }
}

- (NSArray *)patternsOf:(HRTMRule *)rule base:(HRTextMateGrammar *)base
{
    NSString *key = base.scopeName ?: @"";
    NSArray *compiled = rule->compiledPatterns[key];
    if (!compiled) {
        NSMutableArray *out = [NSMutableArray array];
        [self collectPatternsOf:rule into:out visited:[NSMutableSet set] base:base];
        if (!rule->compiledPatterns) rule->compiledPatterns = [NSMutableDictionary dictionary];
        rule->compiledPatterns[key] = out;
        compiled = out;
    }
    return compiled;
}

#pragma mark - Tokenizing

typedef struct {
    const unichar *chars;
    NSUInteger length;            /* including the appended "\n" */
    NSUInteger lastEnd;
    __unsafe_unretained NSMutableArray *tokens;
} HRTMLine;

static void HRProduce(HRTMLine *line, NSArray *scopes, NSUInteger end)
{
    if (end <= line->lastEnd) return;
    [line->tokens addObject:[[HRTextMateToken alloc] initWithRange:NSMakeRange(line->lastEnd, end - line->lastEnd)
                                                             scopes:scopes]];
    line->lastEnd = end;
}

- (void)handleCaptures:(NSArray *)captures match:(HRRegexMatch *)match line:(HRTMLine *)line
                 stack:(HRTextMateState *)stack isFirstLine:(BOOL)isFirstLine
{
    if ([captures count] == 0) return;
    NSMutableArray *local = [NSMutableArray array];   /* of @[scopes, @(end)] */
    NSUInteger maxEnd = NSMaxRange([match range]);
    NSUInteger count = MIN([captures count], [match numberOfRanges]);
    for (NSUInteger i = 0; i < count; i++) {
        HRTMRule *capture = captures[i];
        if ((id)capture == [NSNull null]) continue;
        NSRange r = [match rangeAtIndex:i];
        if (r.location == NSNotFound || r.length == 0) continue;
        if (r.location > maxEnd) break;

        while ([local count] > 0 && [[local lastObject][1] unsignedIntegerValue] <= r.location) {
            HRProduce(line, [local lastObject][0], [[local lastObject][1] unsignedIntegerValue]);
            [local removeLastObject];
        }
        if ([local count] > 0) HRProduce(line, [local lastObject][0], r.location);
        else HRProduce(line, stack->contentScopes, r.location);

        NSString *name = HRExpandName(capture->name, line->chars, match);
        if ([capture->patternsRaw count] > 0) {
            /* the captured text is tokenized again, with patterns of its own */
            NSArray *nameScopes = HRScopesPushing(stack->contentScopes, name);
            NSArray *contentScopes = HRScopesPushing(nameScopes, HRExpandName(capture->contentName, line->chars, match));
            HRTextMateState *inner = [stack push:capture enter:(NSInteger)r.location anchor:-1 eol:NO scopes:nameScopes];
            inner = [inner copyWithContentScopes:contentScopes endSource:nil];
            HRTMLine sub = *line;
            sub.length = NSMaxRange(r);
            [self tokenizeFrom:r.location line:&sub stack:inner isFirstLine:(isFirstLine && r.location == 0) checkWhile:NO];
            line->lastEnd = sub.lastEnd;
            continue;
        }
        if ([name length] > 0) {
            NSArray *base = [local count] > 0 ? [local lastObject][0] : stack->contentScopes;
            [local addObject:@[HRScopesPushing(base, name), @(NSMaxRange(r))]];
        }
    }
    while ([local count] > 0) {
        HRProduce(line, [local lastObject][0], [[local lastObject][1] unsignedIntegerValue]);
        [local removeLastObject];
    }
}

/* begin/while rules stay on the stack only while their `while` pattern
 * matches at the start of each following line. */
- (HRTextMateState *)checkWhileConditions:(HRTextMateState *)stack line:(HRTMLine *)line
                                  linePos:(NSUInteger *)linePos anchor:(NSInteger *)anchor isFirstLine:(BOOL *)isFirstLine
{
    NSMutableArray *whiles = [NSMutableArray array];
    for (HRTextMateState *s = stack; s; s = s->parent) {
        if (s->rule->kind == HRTMBeginWhile) [whiles insertObject:s atIndex:0];
    }
    for (HRTextMateState *s in whiles) {
        HRRegex *regex = [self regexForSource:(s->endSource ?: s->rule->endSource)];
        HRRegexSearchOptions options = 0;
        if (!*isFirstLine) options |= HRRegexNotBeginString;
        if ((NSInteger)*linePos != *anchor) options |= HRRegexNotBeginPosition;
        HRRegexMatch *m = regex ? [regex firstMatchInCharacters:line->chars length:line->length fromIndex:*linePos options:options] : nil;
        if (!m) {
            stack = s->parent;
            break;
        }
        HRProduce(line, s->contentScopes, [m range].location);
        [self handleCaptures:s->rule->endCaptures match:m line:line stack:s isFirstLine:*isFirstLine];
        HRProduce(line, s->contentScopes, NSMaxRange([m range]));
        *anchor = (NSInteger)NSMaxRange([m range]);
        if (NSMaxRange([m range]) > *linePos) {
            *linePos = NSMaxRange([m range]);
            *isFirstLine = NO;
        }
    }
    return stack;
}

- (HRTextMateState *)tokenizeFrom:(NSUInteger)linePos line:(HRTMLine *)line stack:(HRTextMateState *)stack
                      isFirstLine:(BOOL)isFirstLine checkWhile:(BOOL)checkWhile
{
    NSInteger anchor = -1;
    if (checkWhile) {
        anchor = stack->beginCapturedEOL ? 0 : -1;
        stack = [self checkWhileConditions:stack line:line linePos:&linePos anchor:&anchor isFirstLine:&isFirstLine];
    }

    for (;;) {
        HRTMRule *top = stack->rule;
        /* self is the base: -tokenizeLine: is only ever called on it */
        NSArray *patterns = [top->grammar ?: self patternsOf:top base:self];
        HRRegex *endRegex = top->kind == HRTMBeginEnd ? [self regexForSource:(stack->endSource ?: top->endSource)] : nil;

        HRRegexSearchOptions options = 0;
        if (!isFirstLine) options |= HRRegexNotBeginString;
        if ((NSInteger)linePos != anchor) options |= HRRegexNotBeginPosition;

        /* the leftmost match wins; among equals, the pattern listed first.
         * The end pattern is listed first unless the rule says otherwise. */
        HRRegexMatch *best = nil;
        HRTMRule *bestRule = nil;
        BOOL bestIsEnd = NO;
        NSUInteger total = [patterns count] + (endRegex ? 1 : 0);
        for (NSUInteger k = 0; k < total; k++) {
            BOOL isEnd = NO;
            HRTMRule *candidate = nil;
            if (endRegex) {
                NSUInteger endSlot = top->applyEndPatternLast ? total - 1 : 0;
                if (k == endSlot) isEnd = YES;
                else candidate = patterns[k < endSlot ? k : k - 1];
            } else {
                candidate = patterns[k];
            }
            HRRegex *regex = isEnd ? endRegex : candidate->regex;
            HRRegexMatch *m = [regex firstMatchInCharacters:line->chars length:line->length fromIndex:linePos options:options];
            if (!m) continue;
            if (!best || [m range].location < [best range].location) {
                best = m; bestRule = candidate; bestIsEnd = isEnd;
                if ([m range].location == linePos) break;
            }
        }
        if (!best) {
            HRProduce(line, stack->contentScopes, line->length);
            return stack;
        }

        NSRange whole = [best range];
        BOOL hasAdvanced = NSMaxRange(whole) > linePos;

        if (bestIsEnd) {
            HRProduce(line, stack->contentScopes, whole.location);
            HRTextMateState *closing = [stack copyWithContentScopes:stack->nameScopes endSource:nil];
            [self handleCaptures:top->endCaptures match:best line:line stack:closing isFirstLine:isFirstLine];
            HRProduce(line, closing->contentScopes, NSMaxRange(whole));
            HRTextMateState *popped = stack;
            stack = stack->parent;
            anchor = popped->anchorPos;
            if (!hasAdvanced && popped->enterPos == (NSInteger)linePos) {
                /* a rule that begins and ends on nothing, here, for ever:
                 * keep it and give the rest of the line up */
                stack = popped;
                HRProduce(line, stack->contentScopes, line->length);
                return stack;
            }
        } else {
            HRProduce(line, stack->contentScopes, whole.location);
            HRTextMateState *before = stack;
            NSArray *nameScopes = HRScopesPushing(stack->contentScopes, HRExpandName(bestRule->name, line->chars, best));
            stack = [stack push:bestRule enter:(NSInteger)linePos anchor:anchor
                            eol:(NSMaxRange(whole) == line->length) scopes:nameScopes];

            if (bestRule->kind == HRTMMatch) {
                [self handleCaptures:bestRule->captures match:best line:line stack:stack isFirstLine:isFirstLine];
                HRProduce(line, stack->contentScopes, NSMaxRange(whole));
                stack = stack->parent;
                if (!hasAdvanced) {
                    /* matched nothing and would again: step out, give up the line */
                    if (stack->parent) stack = stack->parent;
                    HRProduce(line, stack->contentScopes, line->length);
                    return stack;
                }
            } else {
                [self handleCaptures:bestRule->captures match:best line:line stack:stack isFirstLine:isFirstLine];
                HRProduce(line, stack->contentScopes, NSMaxRange(whole));
                anchor = (NSInteger)NSMaxRange(whole);
                NSArray *contentScopes = HRScopesPushing(nameScopes, HRExpandName(bestRule->contentName, line->chars, best));
                NSString *end = bestRule->endHasBackReferences
                    ? HRResolveBackReferences(bestRule->endSource, line->chars, best) : nil;
                stack = [stack copyWithContentScopes:contentScopes endSource:end];
                BOOL looping = NO;
                if (!hasAdvanced) {
                    /* the same rule already pushed at this very position,
                     * however many other rules deep: test -> test_this ->
                     * test_this_line -> test ... */
                    for (HRTextMateState *el = before; el && el->enterPos == stack->enterPos; el = el->parent) {
                        if (el->rule == stack->rule) { looping = YES; break; }
                    }
                }
                if (looping) {
                    stack = stack->parent;
                    HRProduce(line, stack->contentScopes, line->length);
                    return stack;
                }
            }
        }

        if (NSMaxRange(whole) > linePos) {
            linePos = NSMaxRange(whole);
            isFirstLine = NO;
        }
    }
}

- (NSArray *)tokenizeLine:(NSString *)text state:(HRTextMateState *)state outState:(HRTextMateState **)outState
{
    BOOL isFirstLine = (state == nil);
    if (!state) {
        HRTMRule *root = [self rootRule];
        NSArray *scopes = HRScopesPushing(@[], root->name);
        state = [[[HRTextMateState alloc] init] push:root enter:-1 anchor:-1 eol:NO scopes:scopes];
        state->parent = nil;
    } else {
        /* positions are per line */
        for (HRTextMateState *s = state; s; s = s->parent) { s->enterPos = -1; s->anchorPos = -1; }
    }

    NSUInteger n = [text length];
    unichar *chars = malloc(sizeof(unichar) * (n + 2));
    [text getCharacters:chars range:NSMakeRange(0, n)];
    chars[n] = '\n';
    NSMutableArray *tokens = [NSMutableArray array];
    HRTMLine line = { chars, n + 1, 0, tokens };
    HRTextMateState *end = [self tokenizeFrom:0 line:&line stack:state isFirstLine:isFirstLine checkWhile:YES];
    free(chars);

    /* the "\n" was ours: a token that is only that goes, the last one that
     * runs over it is cut back */
    if ([tokens count] > 0 && ((HRTextMateToken *)[tokens lastObject]).range.location >= n) [tokens removeLastObject];
    HRTextMateToken *last = [tokens lastObject];
    if (last && NSMaxRange(last.range) > n) {
        [tokens removeLastObject];
        [tokens addObject:[[HRTextMateToken alloc] initWithRange:NSMakeRange(last.range.location, n - last.range.location)
                                                          scopes:last.scopes]];
    }
    if ([tokens count] == 0) {
        [tokens addObject:[[HRTextMateToken alloc] initWithRange:NSMakeRange(0, n) scopes:end->contentScopes]];
    }
    if (outState) *outState = end;
    return tokens;
}

- (NSArray *)tokenizeText:(NSString *)text
{
    NSMutableArray *lines = [NSMutableArray array];
    HRTextMateState *state = nil;
    for (NSString *line in [HRWord linesOfString:text]) {
        [lines addObject:[self tokenizeLine:line state:state outState:&state]];
    }
    return lines;
}

@end
