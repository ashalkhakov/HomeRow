#!/usr/bin/env python3
"""Import MonkeyType's word lists as HomeRow language packs.

    Scripts/import-monkeytype.py /path/to/monkeytype [--out HomeRow/Resources/Languages]

MonkeyType (https://github.com/monkeytypegame/monkeytype) is GPL-3.0, which is
why HomeRow is GPL-3.0-or-later.  This script is the whole import: nothing is
edited by hand afterwards, so re-running it against a newer checkout is how
the lists are updated.  Each pack gets a LICENSE naming the commit it came
from.

What is left out, and why:
  code_*                      keyword lists, for Code mode later
  rightToLeft                 HomeRow has no RTL layout yet
  chinese_*, japanese_hiragana, japanese_katakana, korean
                              need an input method; out of scope for now
  lists over 10 000 words     megabytes each, little practice value
  SKIP below                  brand names and jokes rather than languages

The pack "english" also keeps HomeRow's own words-200.txt; MonkeyType's base
English list is not imported over it.
"""
import argparse, json, os, plistlib, re, subprocess, sys, unicodedata

SKIP = {"docker_file", "git", "league_of_legends", "lorem_ipsum", "pokemon",
        "twitch_emotes", "wordle"}
NEEDS_IME = re.compile(r"^(chinese_|japanese_hiragana|japanese_katakana|korean)")
MAX_WORDS = 10000
MARK = "Imported by Scripts/import-monkeytype.py"


def dump_ascii_plist(obj, path):
    """XML plist with every non-ASCII character as a numeric reference.

    gnustep-base (as of 2026-09) reads raw UTF-8 in an XML plist as Latin-1,
    so "e-circumflex" arrives as two characters; character references come
    through intact on GNUstep and macOS alike."""
    xml = plistlib.dumps(obj, sort_keys=True).decode("utf-8")
    xml = "".join(c if ord(c) < 128 else "&#x%X;" % ord(c) for c in xml)
    with open(path, "w", encoding="ascii") as f:
        f.write(xml)


def list_name(count, taken):
    name = "words-200" if count <= 400 else "words-%dk" % max(1, round(count / 1000))
    while name in taken:
        name += "b"
    return name


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("monkeytype")
    ap.add_argument("--out", default="HomeRow/Resources/Languages")
    args = ap.parse_args()

    src = os.path.join(args.monkeytype, "frontend", "static", "languages")
    commit = subprocess.check_output(["git", "-C", args.monkeytype, "rev-parse", "HEAD"], text=True).strip()

    packs = {}
    for fn in sorted(os.listdir(src)):
        if not fn.endswith(".json"):
            continue
        data = json.load(open(os.path.join(src, fn), encoding="utf-8"))
        name = data["name"]
        m = re.match(r"^(.*?)_(\d+k)$", name)
        base, sized = (m.group(1), m.group(2)) if m else (name, None)
        if (name.startswith("code_") or data.get("rightToLeft") or NEEDS_IME.match(name)
                or base in SKIP or len(data["words"]) > MAX_WORDS):
            continue
        words, seen = [], set()
        for w in data["words"]:
            w = unicodedata.normalize("NFC", str(w)).strip()
            # a "word" with a blank in it cannot be typed as one word
            if not w or w.startswith("#") or any(c.isspace() for c in w) or w in seen:
                continue
            seen.add(w)
            words.append(w)
        if len(words) < 20:
            continue
        pack = packs.setdefault(base, {"lists": [], "bcp47": None, "sources": []})
        pack["lists"].append((sized, words))
        if not (base == "english" and sized is None):
            pack["sources"].append(fn)
        if data.get("bcp47") and not pack["bcp47"]:
            pack["bcp47"] = str(data["bcp47"]).replace("_", "-")

    total = 0
    for base, pack in sorted(packs.items()):
        d = os.path.join(args.out, base)
        os.makedirs(d, exist_ok=True)
        ours = base == "english"
        taken = {"words-200"} if ours else set()
        letters = set()
        for sized, words in sorted(pack["lists"], key=lambda l: len(l[1])):
            if ours and sized is None:
                continue
            name = list_name(len(words), taken) if sized is None else "words-" + sized
            while name in taken:
                name += "b"
            taken.add(name)
            with open(os.path.join(d, name + ".txt"), "w", encoding="utf-8") as f:
                f.write("\n".join(words) + "\n")
            total += 1
            # as written and lowercased: Unicode lowercasing differs between
            # libraries at the edges (dotted I, final sigma), and the pack
            # must validate under all of them
            for w in words:
                letters.update(c for c in w + w.lower() if c != "'")
        info_path = os.path.join(d, "info.plist")
        if ours and os.path.exists(info_path):
            info = plistlib.load(open(info_path, "rb"))
            letters.update(info.get("alphabet", ""))
        else:
            info = {"identifier": base,
                    "displayName": base.replace("_", " ").title(),
                    "direction": "ltr"}
        if pack["bcp47"]:
            info["bcp47"] = pack["bcp47"]
        # a set of code points, combining marks included; see adding-a-language.md
        info["alphabet"] = "".join(sorted(letters))
        dump_ascii_plist(info, info_path)

        notice = ("%s\n\n%s\n    From MonkeyType, https://github.com/monkeytypegame/monkeytype\n"
                  "    commit %s, frontend/static/languages/\n"
                  "    GNU General Public License, version 3.  Copyright (C) the MonkeyType\n"
                  "    contributors.  De-duplicated and NFC-normalized; otherwise unchanged.\n"
                  % (MARK, "\n".join(sorted(pack["sources"])), commit))
        lic = os.path.join(d, "LICENSE")
        if ours and os.path.exists(lic):
            own = open(lic, encoding="utf-8").read().split(MARK)[0].rstrip()
            notice = own + "\n\n" + notice
        open(lic, "w", encoding="utf-8").write(notice)

    print("%d packs, %d word lists, MonkeyType %s" % (len(packs), total, commit[:12]))


if __name__ == "__main__":
    sys.exit(main())
