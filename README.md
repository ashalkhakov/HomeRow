# HomeRow

A native typing tutor for **GNUstep** and **Cocoa** — quick tests in the
spirit of MonkeyType, real source code in the spirit of Typing.io, and a
guided touch-typing course for people starting from zero. Offline, no
accounts, no telemetry, free software (GPL-3.0-or-later).

Objective-C 2.0 with ARC, XIB-based UI, one source tree for both platforms.

> **Status: v0.1 in progress.** What works today: time / words / zen /
> custom-text tests in 140 languages, punctuation and numbers, live WPM and
> accuracy, a results screen with a per-second chart, results saved through
> Core Data, and GNU Typist's 46 courses as courses you *follow*: HomeRow
> keeps your place, records every lesson, and shows a keyboard with the next
> key lit. And code: real source files in ten programming languages,
syntax-coloured by the same TextMate grammars VS Code uses. A Statistics
window charts what you have typed. What comes next is in
> [docs/feature-set.md](docs/feature-set.md) for the plan.

Known limitation: on macOS, dead keys and Option-composed accents do not
reach the typing view yet (fine for English; fixed before other languages
ship).

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
| Cmd/Ctrl+4 | the Code window |
| Cmd/Ctrl+L | the Courses window |
| Cmd/Ctrl+Shift+S | the Statistics window |
| Return or Space | next page, while a lesson is explaining something |

The **Language** menu picks the language, the word list and the keyboard
layout the on-screen keyboard draws.

### Following a course

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

The on-screen keyboard (Course ▸ Show Keyboard, Cmd/Ctrl+Shift+K) is on by
default in a course and off otherwise. It shows the course's layout with the
finger zones tinted, and lights the next key — plus the Shift of the other
hand, or Backspace when there is a mistake to take back first.

### Typing code

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
on-screen keyboard (when shown) marks the key you hit in red next to the one
that was wanted, and **Test ▸ Beep on a Wrong Key** adds a sound — in every
mode, not only this one.

The colours come from [TextMate grammars](docs/adding-a-code-language.md) —
the format VS Code uses too — so adding a language means adding a grammar
file and some source, not writing a lexer.

### Statistics

**Test ▸ Statistics…** (Cmd/Ctrl+Shift+S) shows what the saved results add up
to, for everything or for tests, courses or code alone, over the last 7, 30
or 90 days or all time: headline numbers (tests, time typing, average, recent
and best speed, accuracy); speed and accuracy test after test, each dot a
test and the line the average of the last ten; minutes of practice day by
day, gaps included; and the keyboard tinted by how often each key is missed
per press, with the worst keys named underneath. Move the mouse over a chart
to read a single test or day.

## Download

Releases carry an AppImage for Linux (x86_64) and a universal app for
macOS 11 Big Sur or later. Every CI run also uploads both as artifacts.

## Building

### macOS

Xcode 15 or later. Open `HomeRow.xcodeproj`, or:

```sh
xcodebuild -project HomeRow.xcodeproj -scheme HomeRow build
xcodebuild -project HomeRow.xcodeproj -scheme HomeRow test
```

### GNUstep

HomeRow targets one GNUstep: **clang, libobjc2, the gnustep-2.0 ABI, ARC**,
built from source. Distribution packages (gcc runtime, no ARC) are not
supported; on Linux, use the AppImage unless you are developing.

`.github/scripts/dependencies.sh` builds the whole stack into a prefix of
your choice — libobjc2, libdispatch, tools-make, libs-base, libs-gui,
libs-back, [FreeCoreData](https://github.com/ashalkhakov/FreeCoreData) at a
pinned commit, the Eau theme and tools-xctest. The package list it needs is
in `.github/workflows/ci.yml`.

```sh
export CC=clang CXX=clang++ LIBRARY_COMBO=ng-gnu-gnu RUNTIME_VERSION=gnustep-2.0
export DEPS_PATH=$HOME/gnustep-src INSTALL_PATH=$HOME/gnustep
export LD_LIBRARY_PATH=$INSTALL_PATH/lib
./.github/scripts/dependencies.sh          # about half an hour, once

. $INSTALL_PATH/System/Library/Makefiles/GNUstep.sh
make                                       # the app and the test bundle
make check                                 # run the tests
openapp ./HomeRow/HomeRow.app
```

`HR_SMOKE_TEST=1` makes the app check its own outlets, type a ten-word test,
save the result and exit 0 — CI runs the packaged AppImage and the macOS
app that way.

## Layout

```
HomeRow/                 the application
  Engine/                Foundation-only: sessions, scoring, text sources, packs
  Resources/             MainMenu.xib, CourseWindow.xib, CodeWindow.xib, StatsWindow.xib, Languages/, Layouts/,
                         Lessons/, Code/ (grammars and source files), Themes/
  ThirdParty/oniguruma/  the regex engine TextMate grammars need (BSD), compiled in
  HomeRow.xcdatamodeld   the Core Data model (Xcode compiles it; momc on GNUstep)
HomeRowTests/            XCTest sources, run on both platforms
HomeRow.xcodeproj        macOS build
GNUmakefile              GNUstep build
Scripts/                 AppImage packaging, version stamping
patches/gnustep/         gnustep-gui fixes applied by dependencies.sh
docs/                    feature set, metrics, how to add a language, a layout or a code language
```

Everything under `Engine/` must stay free of AppKit: the test bundle
compiles those sources directly and runs without a display.

## Contributing a language

No code needed: a folder with an `info.plist` and word lists. See
[docs/adding-a-language.md](docs/adding-a-language.md). Most of the bundled
packs are MonkeyType's word lists, brought in by
`Scripts/import-monkeytype.py`; run it against a newer MonkeyType checkout
to update them.

## Where the content comes from

HomeRow is GPL-3.0-or-later so that it can stand on two GPL projects:
the courses are [GNU Typist](https://www.gnu.org/software/gtypist/)'s lesson
files, unmodified (several of them converted by that project from KTouch),
and the word lists and keyboard layouts are [MonkeyType](https://github.com/monkeytypegame/monkeytype)'s.
The source files of code mode come from well-known projects under
permissive licences (MIT, BSD, Apache-2.0, PSF), each unmodified and listed
with its commit in [THIRD-PARTY](THIRD-PARTY); the grammars are the ones VS
Code bundles (MIT), run by a tokenizer written for HomeRow on top of
[Oniguruma](https://github.com/kkos/oniguruma) (BSD).
MonkeyType's quote collection is *not* used: its licence covers the
collection, not the books and films the quotes are from.

## Licence

GNU General Public License, version 3 or (at your option) any later version;
see [COPYING](COPYING). Third-party material is listed in
[THIRD-PARTY](THIRD-PARTY).
