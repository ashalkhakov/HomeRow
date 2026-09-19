/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * HomeRow is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version.  It comes with ABSOLUTELY NO WARRANTY.  See COPYING.
 */

#import "HRRandom.h"

@implementation HRRandom
{
    uint64_t _state;
}

- (instancetype)initWithSeed:(uint64_t)seed
{
    if ((self = [super init])) {
        /* xorshift has a fixed point at zero */
        _state = seed ? seed : 0x9E3779B97F4A7C15ULL;
    }
    return self;
}

- (instancetype)init
{
    return [self initWithSeed:0];
}

+ (instancetype)randomWithSystemSeed
{
    uint64_t seed = (uint64_t)([NSDate timeIntervalSinceReferenceDate] * 1000000.0);
    seed ^= (uint64_t)[[NSProcessInfo processInfo] processIdentifier] << 32;
    return [[self alloc] initWithSeed:seed];
}

- (uint64_t)next
{
    _state ^= _state >> 12;
    _state ^= _state << 25;
    _state ^= _state >> 27;
    return _state * 0x2545F4914F6CDD1DULL;
}

- (NSUInteger)nextBelow:(NSUInteger)bound
{
    NSParameterAssert(bound > 0);
    /* the high bits are the good ones */
    return (NSUInteger)(([self next] >> 11) % (uint64_t)bound);
}

- (double)nextDouble
{
    return (double)([self next] >> 11) / 9007199254740992.0; /* 2^53 */
}

@end
