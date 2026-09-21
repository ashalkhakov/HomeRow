# Roadmap

What is outstanding and what could be done, as of 2026-09-19. The phases and
the reasoning behind them are in [feature-set.md](feature-set.md); this is
the working list. Tick things off here; move ideas up when they become
plans.

## Suggested order

1. Bug fixes (below)
2. Dead keys on macOS (fixed)
3. Preferences window (done)
4. Weak-spot practice (done)
5. History list and export (done)
6. Code mode (done)
7. Polish for 1.0 (done, but for themes and the signing secrets)
8. Tag `v0.1` — see [releasing.md](releasing.md)

## Known bugs

- [x] "Last done" dates in the Courses and Code windows come from
      `NSDateFormatter`, which gives nothing on a gnustep-base built without
      ICU. (The AppImage has ICU; a developer's own GNUstep may not.)
- [x] Statistics: the list under the keyboard goes by character ("# 31%")
      while the tint goes by key, both characters together ("deepest tint
      15%") — the two disagree.
- [x] A lesson resumed mid-way after a relaunch reports totals for the
      resumed part only. *(Fixed: the run takes in the exercises saved since
      the lesson was started.)*

## Planned and outstanding

- [x] **Dead keys on macOS** — `HRTestView` is an `NSTextInputClient`: the
      accent waits as marked text, shown at the caret, until its letter
      arrives. Press-and-hold accents are switched off for HomeRow (a held key
      repeats). Confirmed on macOS with Option+E, E (`-HRLogInput YES` traces
      the exchange); still to try: a layout with real dead keys.
- [x] **Preferences window** — theme, font family, size for prose and for
      code, stop on a mistake (never / letter / word), backspace policy, beep,
      keyboard layout and when the keyboard shows, comments in code, where the
      data lives. *Not seen on a display yet.* Later: sounds beyond the beep,
      a tab width for code, moving the data.
- [x] **Statistics, further slices** — History pane (every result, its
      per-second chart, delete), personal bests, export to JSON and to a
      MonkeyType-compatible CSV, import of both and of MonkeyType's own
      export, time per key (data model 3) with a speed heatmap, Progress pane
      per course and code file. Still open: charts of a single setting over
      time; bigrams.
- [x] **Weak-spot practice** — rounds of words weighted towards the keys
      that are *missed* clearly more often than the typist's average; weak
      capitals and symbols are worked into the words; *slow* keys follow the
      missed ones. Still to come: letter pairs.
- [ ] **Generated courses** — lesson plan × layout × language, for everything
      GNU Typist has no course for. With it: layout packs for Czech, Slovenian
      and Romanian, and a numeric keypad drawing.
- [x] **Code mode** — keystroke overhead and error rate and speed per kind of
      key (for a section, and in Statistics); files and folders by
      drag-and-drop; folders as a personal library, read again at every
      launch; Tab typed where the code indents deeper (a preference);
      MonkeyType's `code_*` keyword lists under Language ▸ Programming; a font
      for code. *Not seen on a display yet.* Still open: a tab width, overhead
      over time as a chart, kinds of key narrowed to one programming language.
- [ ] **Quote mode** — needs quotes that may be shipped: public-domain texts
      (Project Gutenberg), not MonkeyType's collection.
- [x] **Polish for 1.0** — pace caret (average, best, or a chosen speed);
      replay of the test just typed (R on the result), from an input log the
      session keeps; key sounds, synthesized (click, typewriter); a
      welcome at every launch (carry on / teach me / test me); the release workflow
      smoke-tests, signs, notarizes and checks with `spctl`, and
      [releasing.md](releasing.md) says how to give it the secrets; a Releases
      table in the README. *Not seen on a display or heard yet.* More themes
      were dropped as not needed. Still to do by hand: set the signing
      secrets, tag. Still open: replay speed (2×, step), replays of saved
      results (needs the input log stored), a volume setting, sounds on Linux
      without the host's libao.

## Ideas beyond the plan

- **Sync** — every result has a uuid and is never edited once saved, so two
  stores merge by union; the machinery belongs in FreeCoreData, not here
  (change tracking, a transport), and course progress needs a merge rule
  first. Until then: export on one machine, import on the other. See
  [results-format.md](results-format.md).
- **Bigram and word statistics** — slow pairs ("th", "br") explain speed
  better than single keys; needs the per-keystroke log the feature set
  describes.
- **Daily goal and streak** — the practice-per-day chart is most of it; add a
  goal line and a gentle reminder.
- **Two-step hints on the keyboard** — dead key, then letter; light AltGr. The
  layout packs already carry that level.
- **Hands overlay** — which finger goes where, for real beginners.
- **Git repositories as code libraries** — practise on your own project,
  skipping generated and vendored files.
- **Grammars by drop-in** — a user folder of `.tmLanguage` files; the
  tokenizer can already do it, only discovery is missing.
- **User packs folder** under Application Support for languages, layouts,
  courses and themes (the feature set describes it; packs load from the app
  bundle only today).
- **Localized interface** — Russian and German first, given the courses.
- **Right-to-left and input-method languages** — RTL needs a second layout
  path in the typing view; IME needs the `NSTextInputClient` work first.
- **Flatpak** next to the AppImage; a Homebrew cask once the Mac build is
  signed.
- **Upstream to GNUstep** — the fixed-pitch font fallback, and the patches in
  `patches/gnustep`.
