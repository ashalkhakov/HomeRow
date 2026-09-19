# Adding a keyboard layout

A layout pack tells HomeRow what is printed on the keys of a layout, so that
the on-screen keyboard can show it and light the key to press next. It is a
**description** of the layout your system is already set to — HomeRow never
remaps a key.

```
HomeRow/Resources/Layouts/<id>.plist
```

| Key | Meaning |
|---|---|
| `identifier` | same as the file name |
| `displayName` | what the Keyboard Layout menu shows |
| `geometry` | `ansi` or `iso` (tall Return, one more key left of Z) |
| `rows` | four arrays — number row, top, home, bottom — of keys, left to right, **character keys only** (no Tab, Shift, Return...) |

A key is the characters it gives: unshifted, shifted, then optionally
AltGr/Option and Shift+AltGr. Write it as one string (`qQ`, `2@`, `eE€`) when
each is a single code point, or as an array of strings when one is not.

Row lengths: ANSI 13 / 13 / 11 / 10, ISO 13 / 12 / 12 / 11. Fingers are
assigned by column, the standard touch-typing way; there is nothing to
configure.

Keep the file ASCII: write `&#x44F;` for `я`. gnustep-base reads raw UTF-8 in
an XML property list as Latin-1.

The packs that ship are MonkeyType's layouts, converted by
`Scripts/import-monkeytype-layouts.py` (GPL-3.0; `Layouts/LICENSE` names the
commit). Fix those upstream, or the next import undoes the fix. Matrix and
split boards are skipped — there is no drawing for them.

To make a course use a layout, name it in the course's entry in
`Resources/Lessons/gtypist/index.plist` (`layout`); `none` means no keyboard
is shown for that course, which is right for the numeric keypad and for
national layouts there is no pack for yet (Czech, Slovenian, Romanian).

`HRKeyboardLayoutTests` loads every bundled layout.
