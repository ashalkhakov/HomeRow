/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * HomeRow is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version.  It comes with ABSOLUTELY NO WARRANTY.  See COPYING.
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
/* Return or Space on a page of reading text (see pageText). */
- (void)testViewDidDismissPage:(HRTestView *)view;
@optional
/* A wrong key, as HRTestSession's lastWrongInput spells it -- for the
 * on-screen keyboard.  nil a moment later: stop showing it. */
- (void)testView:(HRTestView *)view didTypeWrongInput:(NSString *)input;
@end

/* The typing surface.  Draws the text itself instead of being an
 * NSTextView: every character needs its own state colour, the caret is
 * ours, and no key may do anything the session did not decide.
 *
 * Input arrives through -keyDown: -> -interpretKeyEvents: -> -insertText:,
 * so dead keys and whatever layout the system is set to simply work. */
/* On macOS the view is a text input client: that is what makes dead keys
 * and Option-composed accents arrive (the input context holds the accent as
 * "marked text" until the letter completes it).  gnustep-back composes
 * before the event is delivered, so GNUstep needs none of it. */
#if defined(GNUSTEP)
@interface HRTestView : NSView
#else
@interface HRTestView : NSView <NSTextInputClient>
#endif

@property (nonatomic, strong) HRTestSession *session;
@property (nonatomic, strong) HRTheme *theme;
@property (nonatomic, strong) NSFont *font;
/* One or two lines shown above the text: a lesson's instruction. */
@property (nonatomic, copy) NSString *caption;
/* When set, the view shows this instead of the session -- a lesson's
 * tutorial page, laid out for an 80-column terminal as GNU Typist's are --
 * and waits for Return or Space. */
@property (nonatomic, copy) NSString *pageText;
/* Code: the text keeps its own lines and indentation (HRWord's prefix and
 * suffix are drawn, untyped), scrolls to keep the caret's line in view,
 * and what is not typed yet is syntax-coloured. */
@property (nonatomic) BOOL codeLayout;
/* NSBeep() on every wrong key.  Off unless set. */
@property (nonatomic) BOOL beepsOnError;
/* IBOutlet-compatible; not retained. */
@property (nonatomic, assign) IBOutlet id delegate;

/* Call a few times a second: ends a timed test when its time is up.
 * (Shift+Return ends any test early, and is the only way out of zen.) */
- (void)tick;

/* Input with an explicit timestamp, as -keyDown: would deliver it.  For the
 * smoke test and future replay; the keyboard path does not come through
 * here. */
- (void)typeText:(NSString *)text atTime:(NSTimeInterval)time;

/* The accent waiting for its letter, shown at the caret; nil when there is
 * none.  Set by the input context on macOS; readable for tests. */
@property (nonatomic, readonly, copy) NSString *markedText;
/* What a dead key does, for tests: hold `text` as marked text / complete it. */
- (void)setMarkedTextForTesting:(NSString *)text;

@end
