# Adding a programming language (or more code) to code mode

Code mode needs two things per language: a **TextMate grammar** to colour
the text and tell comments from code, and **source files** to type. Neither
involves writing Objective-C.

## How it fits together

```
HomeRow/Resources/Code/
  index.plist              languages, their grammar, extensions and files
  Grammars/*.tmLanguage.json   TextMate grammars (JSON or plist both load)
  Grammars/NOTICE          where each grammar came from
  Files/<language>/*       the source files, unmodified
  LICENSES/*.txt           one licence text per project the files come from
```

`HRCodeLibrary` reads `index.plist`. `HRTextMateGrammar` tokenizes a file
with its grammar — the same begin/end/while, captures and `include` rules
VS Code's `vscode-textmate` implements, on the same regular expression
engine (Oniguruma, in `HomeRow/ThirdParty`). `HRCodeDocument` turns the
scopes into a handful of styles (comment, string, keyword, number, type,
function), cuts the file into parts of about fifty lines at blank lines,
and decides what is typed: indentation, blank lines and — by default —
comments are filled in, everything else is yours.

TextMate grammars were chosen because they are the most widely shared
description of syntax there is: TextMate, Sublime Text, Atom and VS Code all
read them, and a grammar exists for practically every language.

## The supported way: Scripts/import-code.py

Everything under `Resources/Code` is generated. To add a language or files,
edit the two tables at the top of `Scripts/import-code.py` and re-run it:

```sh
git clone --depth 1 --filter=blob:none --sparse https://github.com/microsoft/vscode /tmp/vscode
git -C /tmp/vscode sparse-checkout set extensions
Scripts/import-code.py /tmp/vscode
```

`LANGUAGES` — identifier, display name, the grammar's `scopeName`, the
grammar file(s) inside `vscode/extensions`, and the file extensions that
mean this language when someone opens a file of their own. List a second
grammar when the first one `include`s it (Python's includes its regex
grammar).

`FILES` — language, GitHub repository, path, SPDX licence.

Rules for files:

- **The licence must be compatible with GPL-3.0-or-later** — MIT, BSD,
  Apache-2.0, PSF, Unlicense, (L)GPL. No licence, "source available", and
  anything with a field-of-use restriction are out. The script copies the
  project's licence text into `LICENSES/`; check that it found one (a
  project that keeps it somewhere unusual goes into `LICENCE_FILES`).
- Files are copied **unmodified**, copyright header included.
- Pick files that read like everyday code: 100–500 lines, no generated
  code, no giant tables, mostly ASCII. Tabs are fine (shown as four
  columns; never typed).

Then add the new rows to the table in `THIRD-PARTY`.

## Checking it

```sh
cd HomeRowTests && make check
```

`HRCodeTests` loads every language in `index.plist`, requires its grammar to
compile without a single rejected pattern, tokenizes every bundled file,
and checks that each has its origin on record, leaves something to type, and
that no comment text ends up among the typed words. The app's smoke
test (`HR_SMOKE_TEST=1`) does the same from inside the packaged app.

A grammar that uses **injections** will load, but the injected rules are
ignored — none of the bundled grammars depends on them for its own
language.

## Your own files, without any of the above

*Open File…* in the Code window types any UTF-8 text file. Its language goes
by the extension; a file HomeRow has no grammar for is typed as plain text.
HomeRow remembers the last thirty such files and your place in each.
