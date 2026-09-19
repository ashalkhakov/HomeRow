# Metrics

How HomeRow computes what it shows. The definitions follow MonkeyType so
that numbers are comparable; each is pinned by a test in
`HomeRowTests/HRScorerTests.m` or `HRSessionTests.m`. Change a definition
here, in the code and in the test together, or not at all.

## Units

A *character* is a composed character sequence: `é` typed through a dead
key is one, and so is an emoji outside the BMP. A *word* is what stands
between two separators. A *separator* is a space, or Return where the text
has a line break.

Time comes from a monotonic clock, stamped on the key event. The clock
starts with the first keystroke and stops with the last one (finite tests)
or exactly when the time is up (timed tests) — not when the app notices.

## WPM

    wpm = (characters that count / 5) / minutes

Characters that count: every character of each **completely correct** word,
plus one for the separator after it. A word with any mistake left in it
contributes nothing. The word the test ended in counts as far as it was
typed, if what is there is right.

## Raw WPM

The same formula over everything typed — right or wrong, plus one per
separator pressed.

## Accuracy

    accuracy = correct keystrokes / all keystrokes × 100

Counted per key press, so a mistake that was corrected still lowers it. A
separator pressed to leave a wrong or unfinished word is a wrong keystroke,
and so is Return where a space belongs (or the reverse). Backspace is not a
keystroke for this purpose. A miss is charged to the character that was
*expected*: that is the key to practise.

## Character counts

`correct / incorrect / extra / missed`, from the final state of the text:
*extra* were typed past a word's end, *missed* were left untyped in a word
that was moved on from.

## Consistency

From raw WPM sampled once per second (a last partial second is scaled up if
it is at least half a second long, dropped otherwise):

    cv          = standard deviation / mean
    consistency = 100 × (1 − tanh(cv + cv³/3 + cv⁵/5))

100 is a perfectly even pace.

## What is saved

A result is stored when the test lasted at least one second and had at
least one keystroke. The personal best is the highest WPM among results
with the same *settings key* — mode, amount, language and word list,
punctuation, numbers (e.g. `time:30:en/words-200:p`). Custom and zen tests
have no personal best.

## Time per key

A key's time is the interval since the keystroke before it, counted only when
both were right and no more than two seconds apart. The key after a mistake,
after Backspace or after a pause is not timed — the hand, or the mind, was
somewhere else — and neither is the first key of a test. A key's speed is
the total of its timed hits over their number; a key's times are attributed to
the character that was wanted, as hits and misses are.

This is recorded from data model 3 on. Earlier results have hits and misses
only, so *Keys by speed* and the slow keys of weak-spot practice fill in as
new results come.
