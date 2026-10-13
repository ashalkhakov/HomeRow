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

/* The app's updates.  On macOS, Sparkle (HRUpdater-Apple.m): the newest
 * release's appcast (SUFeedURL in HomeRow-Info.plist, its updates signed
 * with the key SUPublicEDKey names) is checked once a day if the user
 * allows it, and HomeRow > Check for Updates... checks now.  On GNUstep
 * (HRUpdater.m), nothing: the AppImage carries its own update information,
 * for AppImageUpdate, Gear Lever and the like. */
@interface HRUpdater : NSObject

/* Started at once unless told not to: the smoke test reaches no network. */
- (instancetype)initStarting:(BOOL)start;
/* Whether this system has an updater at all (Check for Updates... shown). */
@property (nonatomic, readonly) BOOL available;
@property (nonatomic, readonly) BOOL canCheckForUpdates;
- (IBAction)checkForUpdates:(id)sender;

@end
