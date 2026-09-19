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

@class HRTestSession;
@class HRTheme;
@class HRTestView;

@protocol HRTestViewDelegate <NSObject>
/* Tab or Esc: throw this test away and start another. */
- (void)testViewDidRequestRestart:(HRTestView *)view;
/* Something was typed; live counters may want refreshing. */
- (void)testViewDidChange:(HRTestView *)view;
/* The session reached HRSessionFinished. */
- (void)testViewDidFinish:(HRTestView *)view;
@end

/* The typing surface.  Draws the text itself instead of being an
 * NSTextView: every character needs its own state colour, the caret is
 * ours, and no key may do anything the session did not decide.
 *
 * Input arrives through -keyDown: -> -interpretKeyEvents: -> -insertText:,
 * so dead keys and whatever layout the system is set to simply work. */
@interface HRTestView : NSView

@property (nonatomic, strong) HRTestSession *session;
@property (nonatomic, strong) HRTheme *theme;
@property (nonatomic, strong) NSFont *font;
/* IBOutlet-compatible; not retained. */
@property (nonatomic, assign) IBOutlet id delegate;

/* Call a few times a second: ends a timed test when its time is up.
 * (Shift+Return ends any test early, and is the only way out of zen.) */
- (void)tick;

/* Input with an explicit timestamp, as -keyDown: would deliver it.  For the
 * smoke test and future replay; the keyboard path does not come through
 * here. */
- (void)typeText:(NSString *)text atTime:(NSTimeInterval)time;

@end
