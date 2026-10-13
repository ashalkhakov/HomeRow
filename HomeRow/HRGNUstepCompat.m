/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * HomeRow is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version.  It comes with ABSOLUTELY NO WARRANTY.  See COPYING.
 */
/* GNUstep only, like HRGNUstepCompat.h: what the libc HomeRow is built
 * against may lack.  Never seen by Xcode. */
#import "HRGNUstepCompat.h"

#ifdef HR_NEEDS_ARC4RANDOM
#include <sys/random.h>

uint32_t arc4random(void)
{
    uint32_t value = 0;
    while (getrandom(&value, sizeof value, 0) != sizeof value) {
    }
    return value;
}
#endif
