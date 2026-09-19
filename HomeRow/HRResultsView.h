/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * This library is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2.1 of the License, or (at
 * your option) any later version.  See COPYING.LIB.
 */
#import <AppKit/AppKit.h>

/* The panel that replaces the typing surface when a test ends.  It holds
 * ordinary controls laid out in MainMenu.xib; its one job of its own is the
 * keyboard: Tab, Esc or Return start the next test, so the hands never have
 * to leave the keys. */
/* What the target is expected to implement. */
@interface NSObject (HRResultsViewTarget)
- (IBAction)restartTest:(id)sender;
@end

@interface HRResultsView : NSView

@property (nonatomic, assign) IBOutlet id target;
@property (nonatomic, strong) NSColor *backgroundColor;

@end
