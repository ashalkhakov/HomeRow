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

/* A small seedable generator (xorshift64*).  Text generation must be
 * reproducible from a seed so that tests can pin its output; arc4random
 * and friends cannot be seeded. */
@interface HRRandom : NSObject

- (instancetype)initWithSeed:(uint64_t)seed;
+ (instancetype)randomWithSystemSeed;

- (uint64_t)next;
/* Uniform in [0, bound); bound must be > 0. */
- (NSUInteger)nextBelow:(NSUInteger)bound;
/* Uniform in [0, 1). */
- (double)nextDouble;

@end
