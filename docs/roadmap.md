# Roadmap

What is outstanding and what could be done, as of 2026-09-19. The phases and
the reasoning behind them are in [feature-set.md](feature-set.md); this is
the working list. Tick things off here; move ideas up when they become
plans.

## Suggested order

1. Bug fixes (below)
2. Dead keys on macOS
3. Preferences window
4. Weak-spot practice
5. History list and export
6. Tag `v0.1`

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
- [ ] **Preferences window** — font and size for prose and for code, stop on
      error (off / letter / word), backspace policy, sounds, theme, where the
      data lives. Today the few settings there are sit in menus.
- [ ] **Statistics, further slices** — a history list of single results;
      progress charts per course and per file; *speed* per key (only error
      rate so far); personal bests; export and import (JSON/CSV).
- [ ] **Weak-spot practice** — drills generated from the keys (later: letter
      pairs) that are missed or slow. The reason the statistics are collected.
- [ ] **Generated courses** — lesson plan × layout × language, for everything
      GNU Typist has no course for. With it: layout packs for Czech, Slovenian
      and Romanian, and a numeric keypad drawing.
- [ ] **Code mode** — code metrics (keystroke overhead spent on errors, speed
      per symbol class); drag-and-drop; a folder as a personal library;
      optional typing of Tab; MonkeyType's `code_*` word lists; font choice.
- [ ] **Quote mode** — needs quotes that may be shipped: public-domain texts
      (Project Gutenberg), not MonkeyType's collection.
- [ ] **Polish for 1.0** — pace caret (race your average or best), replay of
      a test, sounds, more themes, a first-launch "teach me / test me" choice,
      signed and notarized macOS build, a tagged release with a Releases table
      in the README.

## Ideas beyond the plan

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
