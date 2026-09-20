/*
 * This file is part of HomeRow, a typing tutor for GNUstep and Cocoa.
 * Copyright (C) 2026 Artyom Shalkhakov
 *
 * HomeRow is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version.  It comes with ABSOLUTELY NO WARRANTY.  See COPYING.
 */
#import "HRStage.h"
#import "HRResultsView.h"
#import "HRChartView.h"
#import "HRTheme.h"
#import "HRTestSession.h"
#import "HRClock.h"
#import "HRPace.h"
#import "HRReplay.h"
#import "HRSoundPlayer.h"
#import "HRPreferencesWindowController.h"   /* HRBeepOnErrorDefaultsKey */

#define HRLoc(key) NSLocalizedString(key, nil)

@implementation HRStageResult

+ (instancetype)resultWithSummary:(HRTestSummary *)summary
{
    HRStageResult *r = [[self alloc] init];
    r.wpm = summary.wpm;
    r.accuracy = summary.accuracy;
    r.samples = summary.rawWpmPerSecond;
    r.errors = summary.errorsPerSecond;
    r.average = summary.rawWpm;
    return r;
}

@end

@implementation HRStage
{
    NSTimer *_timer;
    HRSoundPlayer *_sounds;
    HRReplay *_lastReplay;           /* the test whose result is on screen */
    NSTimeInterval _replayBegan;
}

- (void)start
{
    _testView.delegate = self;
    _resultsView.target = self;
    _sounds = [[HRSoundPlayer alloc] init];
    _sounds.scheme = [[NSUserDefaults standardUserDefaults] stringForKey:HRSoundSchemeDefaultsKey];
    _timer = [NSTimer scheduledTimerWithTimeInterval:0.1
                                              target:self
                                            selector:@selector(timerFired:)
                                            userInfo:nil
                                             repeats:YES];
}

- (void)applyTheme:(HRTheme *)theme
{
    _testView.theme = theme;
    _testView.font = [HRTheme fixedPitchFontOfSize:[HRTheme proseFontSize]];
    _testView.beepsOnError = [[NSUserDefaults standardUserDefaults] boolForKey:HRBeepOnErrorDefaultsKey];
    _chartView.theme = theme;
    _resultsView.backgroundColor = theme.background;
    [_resultsView setNeedsDisplay:YES];
    /* one by one, not from an array literal: an unconnected outlet is the
     * smoke test's to report, not a nil-insertion exception's */
    [_wpmField setTextColor:theme.accent];
    [_accuracyField setTextColor:theme.accent];
    [_detailField setTextColor:theme.untyped];
    [_hintField setTextColor:theme.untyped];
    [_liveField setTextColor:theme.untyped];
}

#pragma mark - Putting something on

- (void)showTyping
{
    [_resultsView setHidden:YES];
    [_testView setHidden:NO];
    [_window makeFirstResponder:_testView];
}

- (void)presentSession:(HRTestSession *)session caption:(NSString *)caption
            codeLayout:(BOOL)codeLayout paceWpm:(double)paceWpm
{
    [self cancelReplay];
    _lastReplay = nil;
    _session = session;
    _showsPage = NO;
    _showsResult = NO;
    _testView.pageText = nil;
    _testView.caption = caption;
    _testView.codeLayout = codeLayout;
    _testView.session = session;
    _paceWpm = paceWpm;
    [self showTyping];
    [self updateLiveField];
    [self movePaceCaret];
    [_delegate stageDidChange:self];
}

- (void)presentPage:(NSString *)text
{
    [self cancelReplay];
    _lastReplay = nil;
    _session = nil;
    _showsPage = YES;
    _showsResult = NO;
    _paceWpm = 0.0;
    _testView.session = nil;
    _testView.caption = nil;
    _testView.codeLayout = NO;
    _testView.pageText = text;
    [self showTyping];
    [self updateLiveField];
    [self movePaceCaret];
    [_delegate stageDidChange:self];
}

- (void)presentResult:(HRStageResult *)result
{
    [self cancelReplay];
    _lastReplay = (result.replayable && _session.state == HRSessionFinished)
        ? [[HRReplay alloc] initWithSession:_session] : nil;
    _showsPage = NO;
    _showsResult = YES;
    _testView.pageText = nil;
    _testView.paceCharacters = -1.0;

    [_wpmField setStringValue:[NSString stringWithFormat:@"%.0f %@", result.wpm, HRLoc(@"wpm")]];
    [_accuracyField setStringValue:[NSString stringWithFormat:@"%.0f%% %@", result.accuracy, HRLoc(@"acc")]];
    [_detailField setStringValue:result.detail ?: @""];
    /* "r" where a result can be played back; the hint under it says so */
    NSString *hint = result.hint ?: @"";
    if (_lastReplay) hint = [hint stringByAppendingString:HRLoc(@"      r \u2014 replay")];
    [_hintField setStringValue:hint];
    _chartView.errors = result.errors;
    _chartView.average = result.average;
    _chartView.samples = result.samples ?: @[];

    [_testView setHidden:YES];
    [_resultsView setHidden:NO];
    [_window makeFirstResponder:_resultsView];
    [_liveField setStringValue:@""];
    [_delegate stageDidChange:self];
}

- (NSString *)expectedInput
{
    if (_showsPage || _showsResult || !_session) return nil;
    return [_session expectedInput];
}

#pragma mark - The line of live numbers

- (void)updateLiveField
{
    if (_showsResult) return;
    NSString *prefix = [_delegate statusPrefixForStage:self];
    if (prefix) {
        if (_session && _session.state != HRSessionIdle) {
            prefix = [prefix stringByAppendingFormat:@"   %.0f wpm   %.0f%%",
                      [_session liveWpmAtTime:HRMonotonicNow()], [_session liveAccuracy]];
        }
        [_liveField setStringValue:prefix];
        return;
    }
    if (!_session) {
        [_liveField setStringValue:@""];
        return;
    }
    if (_session.state == HRSessionIdle) {
        NSString *idle = (_session.configuration.mode == HRTestModeZen
                          ? HRLoc(@"type anything — shift+return to finish")
                          : HRLoc(@"start typing"));
        if (_paceWpm > 0.0) idle = [idle stringByAppendingFormat:HRLoc(@"   \u2014   pace caret at %.0f wpm"), _paceWpm];
        [_liveField setStringValue:idle];
        return;
    }
    NSTimeInterval now = HRMonotonicNow();
    NSInteger remaining = [_session remainingAtTime:now];
    NSString *left = remaining >= 0 ? [NSString stringWithFormat:@"%ld   ", (long)remaining] : @"";
    [_liveField setStringValue:[NSString stringWithFormat:@"%@%.0f wpm   %.0f%%",
                                left, [_session liveWpmAtTime:now], [_session liveAccuracy]]];
}

- (void)timerFired:(NSTimer *)timer
{
    if (_replay) {
        [self advanceReplayToElapsed:HRMonotonicNow() - _replayBegan];
        return;
    }
    [_testView tick];
    [self movePaceCaret];
}

#pragma mark - The pace caret

- (void)setPaceWpm:(double)paceWpm
{
    _paceWpm = paceWpm;
    [self movePaceCaret];
    [self updateLiveField];
}

- (void)movePaceCaret
{
    HRTestSession *session = _replay ? _replaySession : _session;
    if (_paceWpm <= 0.0 || !session || session.state == HRSessionFinished || _showsResult) {
        _testView.paceCharacters = -1.0;
        return;
    }
    NSTimeInterval now = _replay ? [_replay timeAtElapsed:(HRMonotonicNow() - _replayBegan)] : HRMonotonicNow();
    NSTimeInterval elapsed = session.state == HRSessionRunning ? [session elapsedAtTime:now] : 0.0;
    _testView.paceCharacters = [HRPace charactersAtWpm:_paceWpm elapsed:elapsed];
}

#pragma mark - Replay

- (BOOL)canReplay
{
    return _lastReplay != nil && !_replay && _showsResult;
}

- (BOOL)isReplaying
{
    return _replay != nil;
}

/* The test whose result is on screen, typed again by nobody, at the speed
 * it was typed at.  Nothing is recorded; Tab, Esc or Return go back to the
 * result. */
- (IBAction)replayLastTest:(id)sender
{
    if (![self canReplay]) return;
    _replay = _lastReplay;
    _replaySession = [_replay begin];
    _replayBegan = HRMonotonicNow();
    _testView.session = _replaySession;
    _testView.replaying = YES;
    [_resultsView setHidden:YES];
    [_testView setHidden:NO];
    [_window makeFirstResponder:_testView];
    [self movePaceCaret];
    [self advanceReplayToElapsed:0.0];
}

- (void)advanceReplayToElapsed:(NSTimeInterval)elapsed
{
    if (!_replay) return;
    NSUInteger wrongBefore = _replaySession.wrongInputCount;
    NSUInteger wordBefore = _replaySession.currentWordIndex, caretBefore = [_replaySession caretIndexInCurrentWord];
    BOOL more = [_replay advanceToElapsed:elapsed];
    /* the sounds of it too, a tick's worth at a time */
    if (_replaySession.wrongInputCount != wrongBefore) [_sounds playError];
    else if (_replaySession.currentWordIndex != wordBefore || [_replaySession caretIndexInCurrentWord] != caretBefore) [_sounds playKey:@"a"];
    [_testView setNeedsDisplay:YES];
    [self movePaceCaret];
    NSTimeInterval now = [_replay timeAtElapsed:elapsed];
    [_liveField setStringValue:[NSString stringWithFormat:HRLoc(@"replay   %.0f wpm   %.0f%%   %.0fs   \u2014   esc \u2014 back to the result"),
                                [_replaySession liveWpmAtTime:now], [_replaySession liveAccuracy],
                                MIN(elapsed, _replay.duration)]];
    if (!more) [self endReplay];
}

/* Stops the show and leaves the stage as it is: for whoever is about to
 * put something else on it. */
- (void)cancelReplay
{
    if (!_replay) return;
    _replay = nil;
    _replaySession = nil;
    _testView.replaying = NO;
    _testView.session = _session;
    _testView.paceCharacters = -1.0;
}

/* ...and back to the result it came from. */
- (void)endReplay
{
    if (!_replay) return;
    [self cancelReplay];
    [_testView setHidden:YES];
    [_resultsView setHidden:NO];
    [_window makeFirstResponder:_resultsView];
    [_liveField setStringValue:@""];
}

#pragma mark - Sounds

- (BOOL)beepsOnError { return _testView.beepsOnError; }

- (void)setBeepsOnError:(BOOL)beeps
{
    _testView.beepsOnError = beeps;
    [[NSUserDefaults standardUserDefaults] setBool:beeps forKey:HRBeepOnErrorDefaultsKey];
}

- (NSString *)soundScheme { return _sounds.scheme; }
- (void)setSoundScheme:(NSString *)scheme { _sounds.scheme = scheme; }
- (NSUInteger)loadedSounds { return _sounds.loadedSounds; }
- (void)playSampleSound { [_sounds playKey:@"a"]; }

#pragma mark - The results panel's keys

/* Tab, Esc or Return on a result (HRResultsView). */
- (IBAction)restartTest:(id)sender
{
    [_delegate stageDidRequestNext:self];
}

#pragma mark - HRTestViewDelegate

- (void)testViewDidRequestRestart:(HRTestView *)view
{
    if (_replay) {
        /* Tab, Esc or Return while a replay runs: back to its result */
        [self endReplay];
        return;
    }
    [_delegate stageDidRequestNext:self];
}

- (void)testViewDidDismissPage:(HRTestView *)view
{
    [_delegate stageDidDismissPage:self];
}

- (void)testViewDidChange:(HRTestView *)view
{
    [self updateLiveField];
    [_delegate stageDidChange:self];
}

- (void)testView:(HRTestView *)view didTypeWrongInput:(NSString *)input
{
    [_delegate stage:self didTypeWrongInput:input];
}

- (void)testView:(HRTestView *)view didTypeInput:(NSString *)input correctly:(BOOL)correct
{
    if (correct) [_sounds playKey:input];
    else [_sounds playError];
}

- (void)testViewDidFinish:(HRTestView *)view
{
    _testView.paceCharacters = -1.0;
    [_delegate stage:self didFinishSession:_session];
}

@end
