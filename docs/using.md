# Using HomeRow

The first time it starts, HomeRow asks where you want to begin. *Teach me to
touch-type* starts the first course for your keyboard layout (GNU Typist's
quick QWERTY course, or the Dvorak or Colemak one), with the keyboard on
screen; *Test my typing* leaves you at a 30-second test. It is asked once,
and only of someone with nothing on record; everything stays a menu away
whichever you pick.

## Keys

| Key | Does |
|---|---|
| just type | starts the test |
| Tab or Esc | new test |
| Shift+Return | end the test now (the only way out of zen) |
| Alt/Option+Backspace, Ctrl+Backspace | delete the word |
| Return, Tab or Esc on the results | next test |
| R on the results (Cmd/Ctrl+Shift+R anywhere) | replay the test just typed |
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

## Pace caret, replay, sounds

**A pace caret** (Preferences ▸ Typing) is a second, paler caret that goes
through the text at a steady speed: your *average* — of the last ten tests
with the same settings — your *best* with these settings, or a speed you
choose. Keep up with it, or beat it. It shows in time, words, custom-text
and weak-key tests; the line under the text says what speed it is set to
before you start. With nothing on record for the settings yet, *average* and
*best* have nothing to show, and there is no pace caret until there is.
The speed is settled when a test starts, and counts characters the way WPM
does: five to a word, spaces included.

**Replay.** Press **R** on a result (or Test ▸ Replay the Last Test) and the
test types itself again exactly as you did — hesitations, mistakes,
Backspace and all — with the pace caret if there was one. Tab, Esc or Return
go back to the result. Sections of code replay too; exercises of a lesson do
not, since a lesson goes straight on. A replay is kept for the result on
screen only: it is not saved, and neither it nor watching it counts for
anything.

**Sounds** (Preferences ▸ Typing): *Click*, a dry soft key, or *Typewriter*,
with a thud for the space bar and a bell for Return; a wrong key has a sound
of its own. *Beep on a wrong key* is the system's alert sound and is
separate. The sounds are synthesized by `Scripts/make-sounds.py`. On Linux
they need the system's libao; without it HomeRow is simply silent.

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
press *Type Section*. As with a course, HomeRow keeps your place
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

**Your own code.** *Open File…* takes one or more files; *Add Folder…* takes
a whole project, and so does dropping files or folders on the list. A file's
language goes by its extension, and a folder's files turn up under their
languages as `folder/path/to/file`. HomeRow reads a folder again at every
launch, so new files appear by themselves; it leaves out hidden folders,
dependencies and build output (`node_modules`, `vendor`, `Pods`, `build`,
`target`…), generated and minified files, anything over 200 KB, and stops at
300 files a folder. *Remove* forgets the selected file, or the folder it came
with; nothing on disk is touched and your progress in the files is kept.

**Tab.** With *Type Tab where the code indents deeper* on (Preferences ▸
Code), indentation is no longer all free: where a line starts deeper than the
line before it, the step is yours to type — one Tab per level, shown as `→`.
Lines that stay level or come back out are still filled in, as an editor
would. (While a Tab is wanted, Tab does not start the test over; Esc does.)

**What a section tells you.** Besides speed and accuracy, the result of a
section gives the *keystroke overhead* — the share of your keystrokes that
left nothing behind: wrong keys, and Backspace with what it took away — and
error rate and time per key by *kind of key*: letters, capitals, digits,
brackets, operators, punctuation, and space/return/tab. Code is mostly
decided on the brackets and operators line. The
[definitions](metrics.md#keystroke-overhead).

**Keywords as a word list.** **Language ▸ Programming** has MonkeyType's
keyword lists for some sixty programming languages. They are word lists like
any other — time and words tests, weak-spot practice — typed as they stand,
without punctuation or numbers worked in. Good for the vocabulary of a
language; the files above are for its punctuation.

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
Among the headline numbers is the average *keystroke overhead*.
*Keys by mistakes* tints a key by how often it is missed per press (the worst
of its characters); *Keys by speed* by how long it takes, from the fastest key
(plain) to the slowest; *Kinds of key* keeps the tint of mistakes and names,
underneath, the error rate and time per key of letters, capitals, digits,
brackets, operators, punctuation and white space. Move the mouse over a chart to read a single test or
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
  corrected. *Pace caret* and *Sounds*, [as above](#pace-caret-replay-sounds).
  *Beep on a wrong key.* Changing a rule starts the test under way
  over.
- **On-screen keyboard** — the layout it draws (*Choose…* opens a list that
  can be searched — type "col" for Colemak and its variants — with the
  well-known layouts first and a preview of the selected one; the same list
  is under **Language ▸ Keyboard Layout…**), and whether the keyboard shows
  in courses, in code and in the free tests.
- **Code** — a font of its own for code (or the same as the text), whether
  comments are typed too, and whether Tab is typed where the code indents
  deeper.
- **Your data** — where the results are kept, with a button to show the file.
