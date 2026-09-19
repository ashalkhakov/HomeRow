# The results file

HomeRow exports its history in two formats (Statistics ▸ History ▸ Export…)
and reads both back, plus MonkeyType's (▸ Import…).

There is no standard for typing results. The nearest thing to one is the
`results.csv` that [MonkeyType](https://github.com/monkeytypegame/monkeytype)
exports, which people have already written analysis tools for — so
HomeRow's CSV *is* that format, with columns of its own added after it, and
a MonkeyType export can be imported as it is. JSON is HomeRow's own, and the
only one of the two that loses nothing.

| | CSV | JSON |
|---|---|---|
| For | spreadsheets, other people's scripts | moving a history between machines, backups |
| One result is | one line | one object |
| Per-key hits, misses and times | no | yes |
| Per-second speed and errors | no | yes |
| Read back by HomeRow | yes (what it has) | yes (everything) |

Importing never duplicates: a result whose `uuid` is already in the store is
skipped, and for files without usable ids, so is one with the same second,
mode and speed. Importing the same file twice adds nothing the second time.

## JSON

```json
{
  "format": "homerow-results",
  "version": 1,
  "results": [
    {
      "uuid": "0B5F0C0E-6B1D-4D0B-9F43-1C0E2F8E7A11",
      "timestamp": 1789000000500,
      "mode": "time",
      "amount": 30,
      "settingsKey": "time:30:english/words-200:p",
      "languageID": "english",
      "layoutID": "qwerty",
      "wpm": 71.25, "rawWpm": 74.5, "accuracy": 97.1, "consistency": 81.0,
      "duration": 30.0,
      "correctCharacters": 178, "incorrectCharacters": 3,
      "extraCharacters": 1, "missedCharacters": 0,
      "punctuation": true, "numbers": false, "isBest": true,
      "keys": { "a": { "hits": 12, "misses": 1, "timed": 10, "time": 1.75 } },
      "series": { "raw": [60, 75.5, 72], "errors": [0, 1, 0] }
    }
  ]
}
```

- `timestamp` — milliseconds since 1970-01-01 UTC, as in MonkeyType: no time
  zones, no date formats.
- `mode` — `time`, `words`, `zen`, `custom`, `lesson` (an exercise of a
  course), `code` (a part of a source file), `practice` (weak keys).
- `amount` — seconds for `time`, words for `words` and `practice`.
- `settingsKey` — what personal bests are compared within.
- `courseFile`, `lessonIndex`, `stepIndex` — for `lesson` and `code` only:
  the course file (`q.typ`) or code file (`code:c/valkey--adlist.c`), the
  lesson or part (from 0), and the exercise within the lesson.
- `keys` — by the character that was *wanted*: `hits`, `misses`, and how
  many of the hits were `timed` and what those took together, `time`, in
  seconds (see [metrics.md](metrics.md)). Results from before HomeRow
  recorded times have `timed: 0`.
- `series` — raw WPM and wrong keystrokes, one entry per second.
- `isBest` — informational; it is worked out again on import.
- Everything except `timestamp`, `mode` and `wpm` may be missing. A reader
  must ignore members it does not know; a writer that adds any raises
  `version` only when old readers would get the *meaning* wrong. HomeRow
  refuses a `version` higher than it knows.

## CSV

The first 24 columns are MonkeyType's, in MonkeyType's order and units:

`_id, isPb, wpm, acc, rawWpm, consistency, charStats, mode, mode2,
quoteLength, restartCount, testDuration, afkDuration, incompleteTestSeconds,
punctuation, numbers, language, funbox, difficulty, lazyMode, blindMode,
bailedOut, tags, timestamp`

- `charStats` is `correct;incorrect;extra;missed`.
- `mode` is `time`, `words`, `zen` or `custom`: lessons, code and practice
  are, to MonkeyType's tools, custom texts. `mode2` is the amount for `time`
  and `words`.
- Columns HomeRow has nothing for carry MonkeyType's neutral value
  (`funbox` is `none`, `difficulty` is `normal`, the counters are `0`).

Then HomeRow's own: `homerowMode, layout, courseFile, lessonIndex,
stepIndex`. `homerowMode` is the real mode; on import it wins over `mode`.

Fields with a comma, a quote or a line break are quoted, quotes doubled
(RFC 4180). UTF-8, `\n` line ends.

### Importing from MonkeyType

Account ▸ *Export CSV* on monkeytype.com, then Import… in HomeRow. Ids are
kept apart as `monkeytype:<_id>`; `quote` results come in as `custom`;
bests are compared under a key of their own (`time:30:english/imported`),
since MonkeyType's word lists and HomeRow's are not the same test.

## Towards sync

Every result has had a `uuid` since data model 3; that, and results never
being edited after they are saved, is what any sync needs — two stores can
be merged by taking the union. Sync itself would belong in
[FreeCoreData](https://github.com/ashalkhakov/FreeCoreData) rather than in
HomeRow; until then, export on one machine and import on the other does the
same by hand. Progress through courses (`CourseProgress`, `LessonRecord`) is
not in the results file: it *is* edited in place, and needs a merge rule
(furthest lesson wins, best speed wins) before it can travel.
