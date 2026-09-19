# Adding a language

A language is a folder of data. No code changes, no rebuild of anything but
the resources.

```
HomeRow/Resources/Languages/<id>/
    info.plist        required
    words-200.txt     at least one words-*.txt is required
    words-1k.txt
    LICENSE           required: where the words came from, and their licence
```

`<id>` is a short identifier (`en`, `de`, `pt-br`) and must equal the
`identifier` in `info.plist`.

To try a pack without rebuilding, put the folder in
`~/Library/Application Support/HomeRow/Languages/` on macOS, or
`~/GNUstep/Library/ApplicationSupport/HomeRow/Languages/` on GNUstep. A pack
there with the same identifier as a bundled one replaces it.

## info.plist

| Key | Required | Meaning |
|---|---|---|
| `identifier` | yes | same as the folder name |
| `displayName` | yes | the language's name in the language itself |
| `alphabet` | yes | every lowercase letter the word lists use, as one string |
| `defaultLayout` | no | layout pack to preselect; default `qwerty-us` |
| `script` | no | ISO 15924 code, e.g. `Latn`, `Cyrl` |
| `direction` | no | `ltr` (default). `rtl` is reserved and not supported yet |

See `en/info.plist` for a complete example.

## Word lists

UTF-8, one word per line, most frequent first. Blank lines and lines
starting with `#` are ignored. No duplicates. Every character must be in
`alphabet` (apostrophes are allowed). Name lists by size: `words-200`,
`words-1k`, `words-5k`, `words-10k`.

## Licensing

HomeRow is LGPL-2.1-or-later and everything it ships has to be compatible.
**Do not copy lists from MonkeyType (GPL-3.0) or from other typing sites.**
Good sources: frequency counts you compute yourself from public-domain
texts, or lists published under MIT/BSD/CC0/CC-BY. Say which in `LICENSE`.

## Checking your pack

`make check` (or the Xcode test action) runs `HRLanguageTests`, which loads
every bundled pack and fails on a missing key, an empty or duplicated list,
or a character outside the alphabet. CI runs the same test, so a broken
pack cannot be merged.

Keyboard layouts and the lesson course get their own pack formats in v0.2;
see `docs/feature-set.md`, section 7a.
