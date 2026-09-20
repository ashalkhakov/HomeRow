/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * HomeRow is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version.  It comes with ABSOLUTELY NO WARRANTY.  See COPYING.
 */
#import "HRControlBar.h"
#import "HRAppModel.h"
#import "HRLanguage.h"

#define HRLoc(key) NSLocalizedString(key, nil)

@implementation HRControlBar
{
    HRAppModel *_model;
    __weak id<HRControlBarDelegate> _delegate;
}

- (instancetype)initWithModel:(HRAppModel *)model delegate:(id<HRControlBarDelegate>)delegate
{
    if ((self = [super init])) {
        _model = model;
        _delegate = delegate;
    }
    return self;
}

+ (NSArray *)amountsForMode:(HRTestMode)mode
{
    if (mode == HRTestModeTime)  return @[@15, @30, @60, @120];
    if (mode == HRTestModeWords) return @[@10, @25, @50, @100];
    return @[];
}

- (void)sync
{
    HRTestConfiguration *configuration = _model.configuration;
    [_modePopUp removeAllItems];
    [_modePopUp addItemsWithTitles:@[HRLoc(@"time"), HRLoc(@"words"), HRLoc(@"zen")]];
    [[_modePopUp itemAtIndex:0] setTag:HRTestModeTime];
    [[_modePopUp itemAtIndex:1] setTag:HRTestModeWords];
    [[_modePopUp itemAtIndex:2] setTag:HRTestModeZen];
    [_modePopUp addItemWithTitle:HRLoc(@"course")];
    [[_modePopUp lastItem] setTag:HRTestModeLesson];
    [_modePopUp addItemWithTitle:HRLoc(@"code")];
    [[_modePopUp lastItem] setTag:HRTestModeCode];
    [_modePopUp addItemWithTitle:HRLoc(@"weak keys")];
    [[_modePopUp lastItem] setTag:HRTestModePractice];
    if (configuration.mode == HRTestModeCustom) {
        [_modePopUp addItemWithTitle:HRLoc(@"custom")];
        [[_modePopUp lastItem] setTag:HRTestModeCustom];
    }
    [_modePopUp selectItemWithTag:configuration.mode];

    NSArray *amounts = [[self class] amountsForMode:configuration.mode];
    [_amountPopUp removeAllItems];
    for (NSNumber *a in amounts) {
        [_amountPopUp addItemWithTitle:[a stringValue]];
        [[_amountPopUp lastItem] setTag:[a integerValue]];
    }
    if ([amounts count] > 0 && ![amounts containsObject:@(configuration.amount)]) {
        configuration.amount = [amounts[1] integerValue];
    }
    [_amountPopUp selectItemWithTag:configuration.amount];
    [_amountPopUp setEnabled:[amounts count] > 0];

    BOOL generated = (configuration.mode == HRTestModeTime || configuration.mode == HRTestModeWords);
    /* keywords are typed as they stand: "printf," teaches nothing */
    BOOL prose = ![_model currentLanguage].isCode;
    [_punctuationCheck setEnabled:generated && prose];
    [_numbersCheck setEnabled:generated && prose];
    /* following a course, none of the three means anything: the lesson
     * decides the text.  Greyed-out is for "not now"; this is "not here".
     * The same goes for code: the file decides. */
    BOOL inCourse = (configuration.mode == HRTestModeLesson || configuration.mode == HRTestModeCode);
    /* ...and so is the mode pop-up: a course is left through the Test menu
     * (Cmd-1/2/3), not by a control sitting over the lesson */
    [_modePopUp setHidden:inCourse];
    [_amountPopUp setHidden:inCourse];
    [_punctuationCheck setHidden:inCourse];
    [_numbersCheck setHidden:inCourse];
    [_punctuationCheck setState:(configuration.punctuation ? NSControlStateValueOn : NSControlStateValueOff)];
    [_numbersCheck setState:(configuration.numbers ? NSControlStateValueOn : NSControlStateValueOff)];
}

- (IBAction)modeChanged:(id)sender
{
    [_delegate controlBar:self didChooseMode:(HRTestMode)[[_modePopUp selectedItem] tag]];
}

- (IBAction)amountChanged:(id)sender
{
    _model.configuration.amount = [[_amountPopUp selectedItem] tag];
    [_model saveConfiguration];
    [_delegate controlBarDidChangeTest:self];
}

- (IBAction)optionChanged:(id)sender
{
    _model.configuration.punctuation = ([_punctuationCheck state] == NSControlStateValueOn);
    _model.configuration.numbers = ([_numbersCheck state] == NSControlStateValueOn);
    [_model saveConfiguration];
    [_delegate controlBarDidChangeTest:self];
}

@end
