/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * This library is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2.1 of the License, or (at
 * your option) any later version.  See COPYING.LIB.
 */
/*
 * Force-included on GNUstep (see GNUmakefile.preamble); never seen by
 * Xcode.  AppKit names that a given gnustep-gui does not have yet get
 * defined here in terms of the ones it has, so the sources can be written
 * against current AppKit and stay free of #ifdefs.
 *
 * Keep it small: anything that needs behaviour, not just a name, belongs
 * upstream in gnustep-gui.
 */
#ifndef HRGNUstepCompat_h
#define HRGNUstepCompat_h

#ifdef __OBJC__
#import <AppKit/AppKit.h>
#endif

#endif
