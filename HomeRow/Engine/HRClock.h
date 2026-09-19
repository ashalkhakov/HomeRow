/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * This library is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2.1 of the License, or (at
 * your option) any later version.  See COPYING.LIB.
 */
#import <Foundation/Foundation.h>

/* Seconds on a monotonic clock: never jumps when the wall clock is set.
 *
 * On macOS this is the clock -[NSEvent timestamp] uses, so a key event's
 * own timestamp and "now" can be mixed freely.  GNUstep's event timestamps
 * come from the display server on a clock of its own, so there the view
 * reads this at the top of -keyDown: instead; see -[HRTestView keyDown:]. */
NSTimeInterval HRMonotonicNow(void);
