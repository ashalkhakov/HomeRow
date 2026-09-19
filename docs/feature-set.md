# HomeRow — Feature Set (draft 4)

A native typing tutor for GNUstep and Cocoa, in the spirit of MonkeyType (prose, quick tests, rich stats) and Typing.io (typing real source code), plus a guided touch-typing course for people starting from zero. Objective-C 2.0 with ARC, XIB-based UI, GPL-3.0-or-later, fully offline, no accounts, no telemetry.

## 0. Decisions so far

| Topic | Decision |
|---|---|
| Name / prefix | **HomeRow**, class prefix `HR` |
| Licence | **GPL-3.0-or-later** (`COPYING`). Relicensed from LGPL-2.1 on 2026-09-19 by the sole author, so that GNU Typist's lessons and MonkeyType's word lists can ship in the app |
| Content | Courses: GNU Typist's `.typ` lesson files, unmodified (46 courses, ~15 languages, incl. the KTouch-derived ones). Word lists: MonkeyType's (140 languages), via `Scripts/import-monkeytype.py`. The two are complementary, not alternatives: MonkeyType has no lessons, GNU Typist has no word lists. MonkeyType's quotes are not used |
| macOS target | macOS 11 Big Sur minimum, universal (arm64 + x86_64) |
| GNUstep target | From-source stack only (clang, libobjc2, `ng-gnu-gnu`, `gnustep-2.0`, ARC), as in XFormsKit; Linux distribution is an **AppImage**. Distro GNUstep packages are not supported. |
| Persistence | Core Data API — Apple's CoreData on macOS, **FreeCoreData** on GNUstep (dogfooding), SQLite store |
| Lessons/course | In scope — not for the author, but for everyone else who needs a free tutor |
| Code mode | In scope, but after the core, lessons and statistics |
| Languages / layouts | v0.2 ships English + QWERTY-US only, but languages and keyboard layouts are **data packs** from the start, so more can be added without code (section 7a) |
| FreeCoreData in CI | Checked out at a pinned tag/commit by `dependencies.sh`; bumping the pin is a deliberate commit |
| Hosting / CI | GitHub and GitHub Actions only; no Forgejo pipeline |

## 1. Design principles

1. **Keyboard-only flow.** Start typing to begin; Tab (or Esc) restarts; Enter on the results screen goes to the next test. The mouse is never required during practice.
2. **Nothing between you and the text.** The test view is one calm surface: text, caret, a small live counter. Settings and stats live elsewhere.
3. **Same app on both platforms.** One source tree, one set of XIBs, one `.xcdatamodeld`, GNUstep makefiles plus an Xcode project — the same arrangement as UDCalc and XFormsKit. Platform differences are isolated in `HRGNUstepCompat`.
4. **Engine separate from UI.** All test logic, scoring, text generation and lesson generation are Foundation-only classes covered by XCTest, so the GNUstep CI job can verify them without a display.
5. **Your data stays yours.** One local SQLite store, with CSV/JSON export and import.

## 2. Test modes

| Mode | Behaviour | Source |
|---|---|---|
| **Time** | 15 / 30 / 60 / 120 s or custom; words stream in endlessly | MonkeyType |
| **Words** | 10 / 25 / 50 / 100 or custom count | MonkeyType |
| **Quote** | A passage of short / medium / long length from a bundled public-domain collection | MonkeyType |
| **Lesson** | A step of the guided course (section 7) | — |
| **Custom** | Paste text or open any file; optionally saved to a personal library | both |
| **Zen** | No target text, no end; just measures free typing | MonkeyType |
| **Code** | Type a real source file or snippet, language-aware (section 4) — later phase | Typing.io |

Modifiers for Time and Words: **punctuation** on/off, **numbers** on/off, word list choice (English 200 / 1k / 5k / 10k, and additional languages as plain word-list files).

## 3. Typing behaviour

- Per-character feedback: untyped, correct, incorrect, and "extra" characters typed past a word's end, each with a distinct colour.
- Caret styles: line, block, underline, off; optional smooth caret animation (Cocoa; degrades to instant on GNUstep if animation is costly).
- Backspace rules: free backspace, word-local only, or none ("confidence mode").
- Option-/Ctrl-Backspace deletes the whole word.
- **Difficulty**: normal; *expert* (fail on submitting a wrong word); *master* (fail on any wrong key).
- **Stop on error**: off, per letter, per word. Lessons default to per letter; Code mode defaults to "must fix errors to proceed", as Typing.io does.
- **Blind mode**: no error highlighting during the test.
- Scrolling: three visible lines with the active line kept in the middle (prose); normal vertical scroll with the caret line kept in view (code).
- Pace caret (later): a ghost caret running at your personal best, your average, or a fixed WPM.
- Test is invalidated on long idle (AFK detection) and marked as such instead of polluting the stats.

## 4. Code mode (the Typing.io half) — later phase

- Monospaced rendering, original indentation and line structure preserved.
- **Auto-indent**: after Enter, leading whitespace is filled in for you; you type only the meaningful characters. Tab key can be required or skipped — a setting.
- Comments and blank lines can be skipped automatically (setting), since they train prose, not code.
- Lightweight syntax colouring of the *untyped* text only (keywords, strings, comments, numbers) via a small table-driven tokenizer per language — no external dependencies. Typed text uses the correct/incorrect colours so feedback stays unambiguous.
- Long files are split into sections of roughly 40–80 lines; progress through a file is remembered.
- Bundled starter library: short snippets in C, Objective-C, C#, Python, JavaScript, Go, Rust, SQL, shell. **Licensing constraint:** everything bundled must be GPL-3.0-compatible, with attribution kept in `THIRD-PARTY`.
- "Open file…" and drag-and-drop to practise on your own code; a folder can be added as a personal library.
- Code-specific metrics: **unproductive keystroke overhead** (keystrokes spent on errors and fixes ÷ total), and a **symbol breakdown** showing speed and error rate per character class (letters, digits, brackets, operators, punctuation).

The engine is designed for this from v0.1 (newlines and tabs as typeable characters, a text source that can mark spans as "auto-filled" or "skipped"), so Code mode is an addition later rather than a rewrite.

## 5. Metrics and results

Live during a test (each individually hideable): WPM, accuracy, time or words remaining.

Results screen:

- **WPM** (correct characters ÷ 5 per minute), **raw WPM**, **accuracy**, **consistency** (derived from the coefficient of variation of per-second raw WPM), character counts as correct / incorrect / extra / missed, elapsed time.
- A chart of WPM and raw WPM per second, with error markers — drawn by a custom `NSView` with `NSBezierPath`, no chart library.
- Missed-words list and the slowest words, with "practise these" to generate a test from them.
- Personal-best indicator per mode + setting combination.
- Replay of the test keystroke by keystroke (later).

All formulas are documented in `docs/metrics.md` and pinned by unit tests, so numbers stay comparable with MonkeyType's.

## 6. History and progress

- Every completed test is stored: timestamp, mode, settings, all metrics, per-second series, per-key timing and error counts.
- **History window**: sortable/filterable table of past tests (`NSTableView` fed by `NSFetchedResultsController` or plain fetch requests); WPM-over-time chart with a moving average; activity calendar; totals (tests, time typed, characters).
- **Keyboard heatmap**: per-key error rate and per-key speed over a chosen period, drawn on the same keyboard view the lessons use.
- **Weak-spot practice**: generate a test weighted towards your slowest/most error-prone letters, bigrams, and words.
- Export to CSV and JSON; import of the same JSON for moving between machines.

### Storage: Core Data

- One `HomeRow.xcdatamodeld`, edited in Xcode, compiled by Xcode on macOS and by FreeCoreData's `momc` via `coredata-model.make` on GNUstep.
- SQLite store at `~/Library/Application Support/HomeRow/HomeRow.sqlite` on macOS and the GNUstep equivalent from `NSSearchPathForDirectoriesInDomains`.
- Draft entities:
  - `HRTestResult` — date, mode, mode parameters, language/source, wpm, rawWpm, accuracy, consistency, character counts, duration, flags (afk, failed, personalBest); `series` (per-second samples) and `keystrokes` (compact log, for replay) as Binary Data attributes holding an encoded blob, so the schema stays flat.
  - `HRKeyStat` — one row per character per test (hits, misses, total latency); to-one to `HRTestResult`. Feeds heatmap and weak-spot practice with simple aggregate fetches.
  - `HRLessonProgress` — course id, lesson id, best wpm/accuracy, stars, unlocked, attempts, last attempt.
  - `HRCustomText` — title, body or file bookmark/path, kind (prose/code), language, last position.
- Settings remain in `NSUserDefaults`; themes and word lists remain files.
- Anything the app needs that FreeCoreData lacks (aggregate fetches, lightweight migration between model versions, etc.) becomes an upstream FreeCoreData issue rather than a workaround here — that is the point of dogfooding. The store is behind a small `HRResultStore` façade, so the engine tests do not depend on it.
- Licence check: FreeCoreData is MIT (Cocotron heritage), compatible with the GPL; its notices go into `THIRD-PARTY`.

## 7. Lessons — the touch-typing course

MonkeyType and Typing.io both assume you can already touch-type. HomeRow does not.

- **Course structure**: home row (index fingers first: `f j`, then `d k`, `s l`, `a ;`, then `g h`) → top row → bottom row → Shift and capitals → basic punctuation → digits → symbols. Each stage introduces two keys, drills them alone, then mixes them with everything learned so far, then a review lesson using real words that are typeable with the known key set.
- **Lesson generator**: given the set of unlocked keys and the newly introduced keys, produce (a) pattern drills, (b) pseudo-words with natural letter frequencies, (c) real words filtered from the word list. Deterministic from a seed so tests can pin it. Foundation-only.
- **Courses are derived, not hand-written per layout**: a course is a generic stage plan (home row → top row → …, expressed in *physical key positions*) applied to a layout pack and a language pack (section 7a). Only English + QWERTY-US ships in v0.2.
- **Passing**: accuracy and speed thresholds per lesson (default ≥ 95 % accuracy, a modest WPM target that rises through the course), 1–3 stars, next lesson unlocks on pass; thresholds adjustable and "unlock everything" available in Preferences.
- **On-screen keyboard**: a custom view showing the layout, the next key highlighted, and colour-coded finger zones; optional hand/finger hint. ANSI and ISO outlines. Can be shown in any mode, off by default outside lessons.
- **Guidance text**: short intro per lesson (posture, which finger, what to watch for), localizable.
- **Adaptive review**: after each stage, an automatically generated lesson built from that learner's weakest keys (same generator as weak-spot practice).
- **Course window**: the lesson list with stars, lock state and best results; "continue" goes to the first unpassed lesson.

## 7a. Languages and layouts as data packs

Nothing in the engine or UI may assume English or QWERTY. v0.2 ships exactly one language (English) and one layout (QWERTY-US), but both go through the same loading path a contributed pack would.

**Layout pack** — `Layouts/<id>.plist` (e.g. `qwerty-us`, later `dvorak`, `colemak`, `jcuken-ru`, `qwertz-de`):

- id, display name, geometry (`ansi` / `iso`), and for each **physical key position** (row + column, independent of what is printed on it): the base character, the shifted character, optionally the AltGr/Option characters, and the finger assigned to it.
- Dead-key sequences where a layout needs them (e.g. `´` + `e` → `é`), so the keyboard view can hint two-step input.
- From this one file come: the on-screen keyboard labels, the finger zones, the heatmap, and the mapping "which characters has the learner unlocked so far".

**Language pack** — `Languages/<id>/` (e.g. `english`, `russian`, `german`):

- `info.plist`: id, display name, script, writing direction, default layout id, the alphabet, and language-specific punctuation rules (quote marks, spacing before `?`/`:` in French, etc.) used by the punctuation modifier.
- `words-*.txt`: frequency-ordered word lists, one word per line, UTF-8 (`words-200`, `words-1k`, …).
- `quotes.json` (optional) and `lessons.strings` (optional, course guidance text; falls back to English).
- `LICENSE`/source note — mandatory, because of the content-licensing rule in section 11.

**Course plan** — `Courses/standard.plist`: the ordered stages in physical positions (index-finger home keys, then middle, ring, little finger, inner columns, top row, …), plus thresholds. The lesson generator combines *plan × layout × language*: positions → characters via the layout; pseudo-words and real words via the language's alphabet, letter-pair frequencies (computed from its word list at load time) and word list filtered to unlocked characters. A language/layout combination with no typeable real words for an early stage simply gets pattern drills and pseudo-words there.

**Where packs live and how they are picked up**

- Bundled packs sit in the app's `Resources/`; user packs in `Application Support/HomeRow/Layouts` and `/Languages` are discovered at launch and listed alongside the bundled ones. Adding a language or layout is therefore "drop files in a folder" for a user and "add files + a line in the makefile/Xcode resources" for a contributor.
- Packs are validated on load (`HRPackValidator`): required keys, every alphabet character reachable on the chosen layout, UTF-8 cleanliness. Invalid packs are reported in the Library window, never crash the app.
- CI runs the validator over every bundled pack, and a test builds the full course for each bundled language × layout pair, so a contributed pack cannot land broken.
- `docs/adding-a-language.md` and `docs/adding-a-layout.md` describe the formats with a worked example; these are the main contribution path for non-programmers.

**Engine consequences (apply from v0.1)**

- All text handling is by composed character sequence, not `unichar`, so accented letters and non-BMP characters count as one keystroke target.
- WPM stays "characters ÷ 5" for every language, for comparability; this is stated on the results screen's help.
- Results and key stats record the language id and layout id, so statistics and heatmaps are kept per layout.
- The selected layout in HomeRow is a *description* of the user's system layout, not a remapping: the app never translates key codes. Preferences offer the list of packs, preselecting by the system's current input source where that can be detected (macOS), otherwise by language default.
- On macOS the typing view must adopt `NSTextInputClient` before any non-English pack ships: a plain `NSView` gets `insertText:` for ordinary keys but has no input context, so dead keys and Option-composed accents never arrive. (GNUstep delivers composed input without it.) This is the first v0.2 task.
- UI localization (`*.lproj`) is independent of the practice language.
- Right-to-left scripts and IME-composed scripts (CJK) are out of scope for now; the pack format reserves `direction` so RTL can be added later without a format break.

## 8. Appearance and sound

- Themes as plist files (background, text, caret, correct, error, extra, accent). Bundled: a light, a dark, and a few popular palettes; user themes are picked up from the Application Support folder. Follows system dark mode on macOS by default.
- Font family and size for prose and for code, chosen separately.
- Optional key-click and error sounds (`NSSound`), off by default.

## 9. Application shell

- **Main window**: mode bar on top (mode, length, punctuation/numbers toggles), test view in the centre, optional keyboard view below it, results replacing the test view in place when a test ends.
- **Course window**, **History/Statistics window**, **Library window** (word lists, quotes, code, custom texts).
- **Preferences window**: Behaviour, Lessons, Appearance, Code, Sound, Data.
- Full menu bar with key equivalents for every action; this doubles as the GNUstep-friendly substitute for MonkeyType's command palette. A real command palette (Cmd/Ctrl-Shift-P) comes later.
- First launch asks one question: "learn touch typing" (opens the course) or "just test me" (opens a 30-second test).
- Localizable from the start (`Localizable.strings`, `en.lproj`), as in UDCalc.
- Accessibility: all colours come from the theme, error state is also conveyed by underline (not colour alone), respects reduced-motion for the caret.

## 10. Explicit non-goals

Accounts, cloud sync, leaderboards, multiplayer/races, ads, telemetry, network access of any kind. No web view, no embedded scripting.

## 11. Content and licensing

HomeRow is GPL-3.0-or-later, which is what lets it build on the two largest free bodies of typing content:

- **Courses — GNU Typist** (GPL-3.0-or-later). All of its lesson files ship unmodified in `Resources/Lessons/gtypist/`: the English QWERTY series (Q, R, T, V, U), drills (M, S), numeric keypad (N), programmers' symbols (P), Dvorak, Colemak, Czech, Spanish, Russian, Romanian, and the KTouch-derived courses for Bulgarian, German (incl. NEO), Danish, Finnish, French, Hungarian, Italian, Dutch, Norwegian, Polish, Slovenian, Turkish, Catalan. `index.plist` maps each course to a language pack and a layout. `HRTypScript` (Foundation-only) parses the format; the app runs a lesson as tutorial pages and exercises, repeating an exercise that exceeds the allowed error rate, as gtypist does.
- **Word lists — MonkeyType** (GPL-3.0). 140 languages / 283 lists up to 10k words, imported reproducibly by `Scripts/import-monkeytype.py` (each pack's `LICENSE` names the upstream commit). Left out: `code_*` lists (for Code mode later), right-to-left languages, languages needing an input method (Chinese, Japanese kana, Korean), lists over 10k words, and brand/joke lists.
- **MonkeyType's keyboard layouts** (239 JSON files) are the intended source for v0.2's layout packs.
- **Not used:** MonkeyType's quotes — the GPL covers the collection, not the third-party books and films quoted. Quote mode stays on public-domain texts. Typing.io content is proprietary.
- The generated course (plan × layout × language, section 7) is still wanted: it is the only thing that gives *every* language/layout pair a course, and the only adaptive one. The GNU Typist courses are the hand-written complement.
- Fonts: rely on system fonts; bundle none, or only OFL-licensed ones.

## 12. Technical notes that shape the features

- The test view is a custom `NSView` that draws the text itself (attributed strings / `NSLayoutManager`) rather than an editable `NSTextView`: it needs per-glyph state colouring, a custom caret, and full control over key handling. Input arrives via `keyDown:` → `interpretKeyEvents:` → `insertText:` so dead keys and non-US layouts work on both platforms.
- Timing uses a monotonic clock, captured at the key event, not at redraw.
- Big Sur floor: deployment target 11.0; no API newer than macOS 11 without an `@available` guard; XIBs kept to features GNUstep's XIB loader handles (as already practised in UDCalc) — no storyboards, no Auto Layout-only constructs that GNUstep ignores unless verified there.
- Engine classes (Foundation only): `HRTestSession`, `HRTextSource` (+ word, quote, lesson, custom, later code subclasses), `HRKeystrokeLog`, `HRScorer`, `HRLessonGenerator`, `HRCoursePlan`, `HRKeyboardLayout`, `HRLanguage`, `HRPackValidator`.
- App classes: `HRAppDelegate`, `HRTestView`, `HRKeyboardView`, `HRChartView`, `HRResultStore` (Core Data façade), window controllers per window.

## 13. Project setup and CI/CD (mirroring your existing repos)

Taken from **UDCalc** (app layout: Xcode project + `GNUmakefile` side by side, `Resources/*.xib`, `en.lproj`, a GNUstep compat file, separate tests directory with its own makefile), **XFormsKit** (GitHub Actions, from-source GNUstep, AppImage, release flow) and **FreeCoreData** (`coredata-model.make`, `momc`):

```
HomeRow/
  HomeRow.xcodeproj
  GNUmakefile                 aggregate: HomeRow, HomeRowTests
  HomeRow/                    app sources, GNUmakefile, HomeRow-Info.plist
    Engine/                   Foundation-only classes
    Resources/                *.xib, Themes/, Layouts/, Languages/, Courses/
    HomeRow.xcdatamodeld
    en.lproj/
  HomeRowTests/               XCTest bundle, own GNUmakefile
  Scripts/                    install-linuxdeploy.sh, AppDir assembly
  .github/workflows/ci.yml, release.yml
  .github/scripts/apt-update.sh, dependencies.sh
  docs/  COPYING  THIRD-PARTY  README.md
```

- `ci.yml`, on push / PR / manual, with branch-name concurrency groups:
  - **macOS job** (`macos-15`): `xcodebuild` build with `MACOSX_DEPLOYMENT_TARGET=11.0`, XCTest run, unsigned universal `.app` zipped and uploaded as a 14-day artifact, `.xcresult` uploaded on failure. A step asserts the built binary's minimum OS (`vtool -show-build`) is 11.0 and that both architectures are present.
  - **GNUstep job** (`ubuntu-latest`, clang, `ng-gnu-gnu`, `gnustep-2.0`): early grep guard against imports GNUstep cannot satisfy; stack built from source by `.github/scripts/dependencies.sh` with `--with-layout=gnustep` and `--enable-objc-arc`, cached on the script's hash; `make`, tests via tools-xctest, AppImage packaged with linuxdeploy and smoke-tested, uploaded as artifact.
- Stack built by `dependencies.sh`: libobjc2, libdispatch, tools-make, libs-base, libs-gui, libs-back, tools-xctest, the Eau theme for the AppImage, and **FreeCoreData checked out at a pinned ref** (`FREECOREDATA_REF=<tag or full SHA>` at the top of the script; `git fetch --depth 1 origin $FREECOREDATA_REF`; installs the framework, `momc` and `coredata-model.make`). Because the cache key is the script's hash, changing the pin rebuilds the stack automatically. No Opal/corebase. `libsqlite3` comes from apt and is bundled into the AppImage.
- `release.yml`, on `v*` tags: version stamped from the tag; Linux AppImage and macOS app (signed and notarized when the secrets exist, with a warning otherwise) attached to the GitHub release.

## 14. Phasing

- **v0.1 — usable daily**: Time, Words, Custom, Zen modes; punctuation/numbers; core typing behaviour; live WPM/accuracy; results screen with chart; results saved through Core Data/FreeCoreData; light and dark themes; CI on both platforms producing an AppImage and a macOS zip from the first commit.
- **Done ahead of plan (with the relicensing)**: GNU Typist courses with a basic lesson runner (Lessons menu), 140 language packs with a Language / Word List menu.
- **v0.2 — tutor**: a course window with per-lesson progress and stars (`HRLessonProgress`), `NSTextInputClient` on macOS (dead keys — needed by every non-English course), layout/language pack loading and validation, lesson generator, English + QWERTY-US course, keyboard view with finger hints, course window, lesson progress, first-launch choice.
- **v0.3 — insight**: History window, charts, heatmap on the keyboard view, weak-spot practice and adaptive review, personal bests, export/import; Quote mode.
- **v0.4 — code**: Code mode with auto-indent, tokenizer colouring, file/folder import, overhead and symbol metrics.
- **v1.0 — polish**: pace caret, replay, command palette, sounds, more themes; additional layout and language packs as they are contributed; signed/notarized macOS build.

## 15. Open questions

None at the moment. Next step: scaffold the repository (Xcode project, GNUmakefiles, first XIB, data model, `dependencies.sh`, `ci.yml`, `release.yml`).
