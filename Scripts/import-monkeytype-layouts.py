#!/usr/bin/env python3
"""Import MonkeyType's keyboard layouts as HomeRow layout packs.

    Scripts/import-monkeytype-layouts.py /path/to/monkeytype [--out HomeRow/Resources/Layouts]

One plist per layout, named as MonkeyType names it (qwerty, dvorak, russian,
azerty, ...).  See docs/adding-a-layout.md for the format.  GPL-3.0, like the
word lists; Layouts/LICENSE names the commit.  Re-run to update -- nothing is
edited by hand afterwards.
"""
import argparse, json, os, plistlib, subprocess, sys


def dump_ascii_plist(obj, path):
    # gnustep-base reads raw UTF-8 in an XML plist as Latin-1; character
    # references survive on both platforms (see import-monkeytype.py)
    xml = plistlib.dumps(obj, sort_keys=True).decode("utf-8")
    xml = "".join(c if ord(c) < 128 else "&#x%X;" % ord(c) for c in xml)
    with open(path, "w", encoding="ascii") as f:
        f.write(xml)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("monkeytype")
    ap.add_argument("--out", default="HomeRow/Resources/Layouts")
    args = ap.parse_args()
    src = os.path.join(args.monkeytype, "frontend", "static", "layouts")
    commit = subprocess.check_output(["git", "-C", args.monkeytype, "rev-parse", "HEAD"], text=True).strip()
    os.makedirs(args.out, exist_ok=True)

    n = 0
    for fn in sorted(os.listdir(src)):
        if not fn.endswith(".json"):
            continue
        data = json.load(open(os.path.join(src, fn), encoding="utf-8"))
        geometry = data.get("type", "ansi")
        if geometry not in ("ansi", "iso"):
            continue   # matrix boards need a drawing HomeRow does not have
        rows = []
        for r in ("row1", "row2", "row3", "row4"):
            # each key: the characters it gives, unshifted first -- as one
            # string ("qQ") when every one is a single code point, which is
            # nearly always, and as an array of strings otherwise
            row = []
            for key in data["keys"][r]:
                chars = [str(c) for c in key]
                row.append("".join(chars) if all(len(c) == 1 for c in chars) else chars)
            rows.append(row)
        name = fn[:-5]
        dump_ascii_plist({"identifier": name,
                          "displayName": name.replace("_", " "),
                          "geometry": geometry,
                          "rows": rows}, os.path.join(args.out, name + ".plist"))
        n += 1

    open(os.path.join(args.out, "LICENSE"), "w", encoding="utf-8").write(
        "Imported by Scripts/import-monkeytype-layouts.py\n\n"
        "*.plist\n"
        "    From MonkeyType, https://github.com/monkeytypegame/monkeytype\n"
        "    commit %s, frontend/static/layouts/\n"
        "    GNU General Public License, version 3.  Copyright (C) the MonkeyType\n"
        "    contributors.  Converted from JSON to property lists; the space row is\n"
        "    dropped and nothing else is changed.\n" % commit)
    print("%d layouts, MonkeyType %s" % (n, commit[:12]))


if __name__ == "__main__":
    sys.exit(main())
