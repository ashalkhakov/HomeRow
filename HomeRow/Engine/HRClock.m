/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * This library is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2.1 of the License, or (at
 * your option) any later version.  See COPYING.LIB.
 */
#import "HRClock.h"
#include <time.h>

NSTimeInterval HRMonotonicNow(void)
{
#if defined(__APPLE__)
    return [[NSProcessInfo processInfo] systemUptime];
#else
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (NSTimeInterval)ts.tv_sec + (NSTimeInterval)ts.tv_nsec / 1e9;
#endif
}
