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
> key lit. Statistics and code mode are next — see
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
| Cmd/Ctrl+L | the Courses window |
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
  Resources/             MainMenu.xib, CourseWindow.xib, Languages/, Layouts/, Lessons/, Themes/
  HomeRow.xcdatamodeld   the Core Data model (Xcode compiles it; momc on GNUstep)
HomeRowTests/            XCTest sources, run on both platforms
HomeRow.xcodeproj        macOS build
GNUmakefile              GNUstep build
Scripts/                 AppImage packaging, version stamping
patches/gnustep/         gnustep-gui fixes applied by dependencies.sh
docs/                    feature set, metrics, how to add a language or a layout
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
MonkeyType's quote collection is *not* used: its licence covers the
collection, not the books and films the quotes are from.

## Licence

GNU General Public License, version 3 or (at your option) any later version;
see [COPYING](COPYING). Third-party material is listed in
[THIRD-PARTY](THIRD-PARTY).
