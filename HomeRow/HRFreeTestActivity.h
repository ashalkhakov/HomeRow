/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * HomeRow is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version.  It comes with ABSOLUTELY NO WARRANTY.  See COPYING.
 */
#import "HRActivity.h"

@class HRWeakSpots;

/* The tests that are nobody's lesson: time, words, zen, a text of one's own,
 * and rounds of practice on the weak keys.  The mode and its amount are the
 * configuration's; this makes the words, sets the pace caret, records the
 * result and says whether it was a personal best. */
@interface HRFreeTestActivity : HRActivity

/* The text of custom mode; does not outlive the launch. */
@property (nonatomic, copy) NSString *customText;

/* The keys a round of practice would be about now; nil when there is not
 * enough on record, or nothing stands out. */
- (HRWeakSpots *)currentWeakSpots;
/* What the round on stage is for. */
@property (nonatomic, readonly) HRWeakSpots *weakSpots;
/* The smoke test's: its store is too young to have weak keys. */
@property (nonatomic, strong) HRWeakSpots *weakSpotsForTesting;

/* The pace caret's speed for a test with the present settings; 0 for none. */
- (double)paceWpm;
/* The preference changed: the test on stage takes the new speed. */
- (void)paceDidChange;

@end

/* how many words a round of weak-spot practice has */
extern const NSUInteger HRPracticeWords;
