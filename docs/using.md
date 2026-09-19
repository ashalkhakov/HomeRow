# Using HomeRow

## Keys

| Key | Does |
|---|---|
| just type | starts the test |
| Tab or Esc | new test |
| Shift+Return | end the test now (the only way out of zen) |
| Alt/Option+Backspace, Ctrl+Backspace | delete the word |
| Return, Tab or Esc on the results | next test |
| Cmd/Ctrl+O | open a text file as a custom test |
| Cmd/Ctrl+1, 2, 3 | time test, words test, zen — also the way out of a course |
| Cmd/Ctrl+5 | practise the keys you miss most |
| Cmd/Ctrl+4 | the Code window |
| Cmd/Ctrl+L | the Courses window |
| Cmd/Ctrl+Shift+S | the Statistics window |
| Cmd/Ctrl+, | Preferences |
| Return or Space | next page, while a lesson is explaining something |

The **Language** menu picks the language, the word list and the keyboard
layout the on-screen keyboard draws.

Accents: dead keys and, on macOS, Option combinations (Option+E then E for é)
work as they do everywhere; the accent shows underlined at the caret until the
letter arrives, and only the finished character counts as a keystroke. On
macOS a held key repeats; the press-and-hold accent pop-up is off in HomeRow.

## Following a course

**Course ▸ Courses…** (Cmd/Ctrl+L) lists the courses by language. Pick one and
press *Start Course*: from then on the *course* entry of the mode pop-up, the
course's own entry in the Course menu, and simply starting HomeRow again all
take you to where you left off — in the middle of a lesson, if that is where it
was. The window shows each lesson's best speed and accuracy, how often and
when it was done; any lesson can be started again from there, and *Reset
Progress…* forgets a course's position and records (the exercises stay in
your history).

Several courses can be on the go at once: each keeps its own place. The
Course menu lists the ones you have started — the current one ticked, with
the lesson each is at — and choosing another switches to it and carries on
from there; in the Courses window they carry a bullet.

In a lesson, an exercise with more than 3% wrong keystrokes (or whatever the
course says) comes round again, as it does in GNU Typist. After a lesson,
Return goes on to the next one.

The on-screen keyboard (Show Keyboard in the Course and Test menus,
Cmd/Ctrl+Shift+K) is on by default in a course and in code mode, and off in
the free tests; each of the three remembers its own setting. It shows the course's layout with the
finger zones tinted, and lights the next key — plus the Shift of the other
hand, or Backspace when there is a mistake to take back first.

## Typing code

**Test ▸ Code…** (Cmd/Ctrl+4) lists source files by programming language —
C, Objective-C, C#, Python, JavaScript, TypeScript, Go, Rust, SQL and shell —
each cut into parts of about fifty lines at blank lines. Pick a part and
press *Type Section*, or *Open File…* to type one of your own files (its
language goes by the extension). As with a course, HomeRow keeps your place
in every file, shows each part's best speed and accuracy, and Return after a
part goes on to the next.

Code is typed the way an editor with auto-indent has you type it:
indentation is filled in, Return ends a line, blank lines are skipped, and
comments are shown but not typed (unless *Type the comments too* is on). A
wrong key does not go in — the caret waits for the right one, and the miss
counts against accuracy. The place where it should have gone flashes red, the
on-screen keyboard marks the key you hit in red next to the one
that was wanted, and **Test ▸ Beep on a Wrong Key** adds a sound — in every
mode, not only this one.

The colours come from [TextMate grammars](adding-a-code-language.md) —
the format VS Code uses too — so adding a language means adding a grammar
file and some source, not writing a lexer.

## Statistics

**Test ▸ Statistics…** (Cmd/Ctrl+Shift+S) has three panes. *Overview* and
*History* can be narrowed to tests, courses or code, and to the last 7, 30 or
90 days.

**Overview** — headline numbers (tests, time typing, average, recent and best
speed, accuracy); speed and accuracy test after test, each dot a test and the
line the average of the last ten; minutes of practice day by day, gaps
included; and the keyboard as a heatmap, with the worst keys named underneath.
*Keys by mistakes* tints a key by how often it is missed per press (the worst
of its characters); *Keys by speed* by how long it takes, from the fastest key
(plain) to the slowest. Move the mouse over a chart to read a single test or
day.

**History** — every saved result, newest first, personal bests starred.
Select one for its per-second chart and character counts. *Delete…* removes the selected results — several
can be selected — from the history and the statistics. *Export…* writes everything
to a file: name it `.json` to keep all of it, or `.csv` for a spreadsheet —
the CSV has MonkeyType's columns, so tools written for MonkeyType exports read
it. *Import…* reads a HomeRow file of either kind, or a `results.csv` exported
from MonkeyType; nothing is ever added twice. That is also how a history moves
from one machine to another. The formats: [results-format.md](results-format.md).

**Progress** — one course or code file at a time: best speed lesson by lesson,
and the mistakes in the best run, with how much of it is done.

## Practising weak keys

**Test ▸ Practise Weak Keys** (Cmd/Ctrl+5), the *weak keys* entry of the mode
pop-up, or the button in the Statistics window. HomeRow looks at the hits and
misses of the last thirty days (of everything, if that is too little) and
takes up to six keys: first those you *miss* clearly more often than you miss
keys on the whole — half again your overall error rate, at least one miss in a
hundred — then those that are clearly *slow*, a third slower than your keys
are on average; in both cases only keys pressed often enough to judge. The round is forty words
from the current word list, named in the caption above the text:

- words containing the weak letters come up much more often, though not
  exclusively, so it still reads like text;
- a weak capital brings words beginning with that letter, capitalised;
- what no word contains — digits, brackets, the symbols of code — is attached
  to words: wrapped around them when it is one of a pair, otherwise put before
  or after.

Only keys that can come up count: those on the keyboard layout in use and in
the current word list. What a German course left on record does not turn up
in an English round on a US keyboard — switch the language and the layout,
and it does.

The words come from the language chosen in the **Language** menu, which the
caption names. Following a course in another language does not change it.

Return after a round starts the next, worked out afresh. With too little on
record, or no key standing out, it says so instead. Rounds are saved like
tests (as *practice*) and count in the statistics.

## Preferences

**HomeRow ▸ Preferences…** (Cmd/Ctrl+,). Every control applies at once.

- **Appearance** — theme (follow the system, light, dark); the font, from the
  fixed-pitch families on this machine, or *Automatic*; text size for prose
  and, separately, for code.
- **Typing** — *Stop on a mistake*: never (mistakes go in and can be left
  behind), on every letter (a wrong key does not go in; code mode always works
  this way), or on every word (mistakes go in, but the word must be right
  before it can be left). *Backspace*: anywhere, only in the word being typed,
  or off — except that a word held by "stop on every word" can always be
  corrected. *Beep on a wrong key.* Changing a rule starts the test under way
  over.
- **On-screen keyboard** — the layout it draws (*Choose…* opens a list that
  can be searched — type "col" for Colemak and its variants — with the
  well-known layouts first and a preview of the selected one; the same list
  is under **Language ▸ Keyboard Layout…**), and whether the keyboard shows
  in courses, in code and in the free tests.
- **Code** — whether comments are typed too.
- **Your data** — where the results are kept, with a button to show the file.
