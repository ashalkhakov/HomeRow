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
