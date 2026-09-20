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
#import "HRTestConfiguration.h"

@class HRControlBar;
@class HRAppModel;

@protocol HRControlBarDelegate <NSObject>
/* A mode was picked: also a course's or code's, which are not the
 * configuration's to keep until something of theirs is on. */
- (void)controlBar:(HRControlBar *)bar didChooseMode:(HRTestMode)mode;
/* The amount or an option changed; the configuration has it already. */
- (void)controlBarDidChangeTest:(HRControlBar *)bar;
@end

/* The strip over the text: mode, amount, punctuation, numbers.  It shows
 * the configuration and edits it; what follows from a change is its
 * delegate's business. */
@interface HRControlBar : NSObject

@property (nonatomic, strong) NSPopUpButton *modePopUp;
@property (nonatomic, strong) NSPopUpButton *amountPopUp;
@property (nonatomic, strong) NSButton *punctuationCheck;
@property (nonatomic, strong) NSButton *numbersCheck;

- (instancetype)initWithModel:(HRAppModel *)model delegate:(id<HRControlBarDelegate>)delegate;

/* Shows the configuration as it is now.  In a course or in code the bar is
 * empty: the lesson or the file decides the text, and the way out is the
 * Test menu, not a control sitting over the lesson. */
- (void)sync;

- (IBAction)modeChanged:(id)sender;
- (IBAction)amountChanged:(id)sender;
- (IBAction)optionChanged:(id)sender;

@end
