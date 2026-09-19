#!/usr/bin/env python3
"""Assemble HomeRow's code packs: TextMate grammars and source files to type.

    Scripts/import-code.py /path/to/vscode [--work /tmp/homerow-code] [--out HomeRow/Resources/Code]

Grammars come from VS Code's bundled language extensions (a checkout of
https://github.com/microsoft/vscode; only extensions/ is needed).  VS Code
does not write them: each is taken from an upstream project, recorded in the
extension's cgmanifest.json, and all of the ones used here are MIT.

Source files come from well-known projects under licences compatible with
the GPL-3.0 (MIT, BSD, Apache-2.0, PSF, Unlicense), fetched at HEAD with
sparse clones.  Every file is copied unmodified; index.plist records the
repository, path, commit and licence, and each project's licence text is
kept in Code/LICENSES/.

Re-run to update.  Nothing is edited by hand afterwards.
"""
import argparse, glob, json, os, plistlib, shutil, subprocess, sys

LANGUAGES = [
    # id, display name, scope, grammar file(s) in vscode/extensions, file extensions
    ("c", "C", "source.c", ["cpp/syntaxes/c.tmLanguage.json"], ["c", "h"]),
    ("objective-c", "Objective-C", "source.objc", ["objective-c/syntaxes/objective-c.tmLanguage.json"], ["m"]),
    ("csharp", "C#", "source.cs", ["csharp/syntaxes/csharp.tmLanguage.json"], ["cs"]),
    ("python", "Python", "source.python", ["python/syntaxes/MagicPython.tmLanguage.json",
                                          "python/syntaxes/MagicRegExp.tmLanguage.json"], ["py"]),
    ("javascript", "JavaScript", "source.js", ["javascript/syntaxes/JavaScript.tmLanguage.json"], ["js", "mjs", "cjs"]),
    ("typescript", "TypeScript", "source.ts", ["typescript-basics/syntaxes/TypeScript.tmLanguage.json"], ["ts"]),
    ("go", "Go", "source.go", ["go/syntaxes/go.tmLanguage.json"], ["go"]),
    ("rust", "Rust", "source.rust", ["rust/syntaxes/rust.tmLanguage.json"], ["rs"]),
    ("sql", "SQL", "source.sql", ["sql/syntaxes/sql.tmLanguage.json"], ["sql"]),
    ("shell", "Shell", "source.shell", ["shellscript/syntaxes/shell-unix-bash.tmLanguage.json"], ["sh", "bash", "zsh"]),
]

FILES = [
    # language, repository, path, SPDX licence
    ("c", "valkey-io/valkey", "src/adlist.c", "BSD-3-Clause"),
    ("c", "lua/lua", "lstring.c", "MIT"),
    ("objective-c", "AFNetworking/AFNetworking", "AFNetworking/AFNetworkReachabilityManager.m", "MIT"),
    ("objective-c", "Mantle/Mantle", "Mantle/MTLValueTransformer.m", "MIT"),
    ("objective-c", "SDWebImage/SDWebImage", "SDWebImage/Core/SDImageCacheConfig.m", "MIT"),
    ("csharp", "dotnet/runtime", "src/libraries/System.Private.CoreLib/src/System/Collections/Generic/Queue.cs", "MIT"),
    ("csharp", "JamesNK/Newtonsoft.Json", "Src/Newtonsoft.Json/Utilities/StringUtils.cs", "MIT"),
    ("python", "python/cpython", "Lib/bisect.py", "PSF-2.0"),
    ("python", "python/cpython", "Lib/heapq.py", "PSF-2.0"),
    ("python", "psf/requests", "src/requests/structures.py", "Apache-2.0"),
    ("javascript", "expressjs/express", "lib/utils.js", "MIT"),
    ("javascript", "jashkenas/underscore", "modules/debounce.js", "MIT"),
    ("typescript", "microsoft/vscode-textmate", "src/matcher.ts", "MIT"),
    ("typescript", "microsoft/vscode-textmate", "src/utils.ts", "MIT"),
    ("go", "golang/go", "src/container/list/list.go", "BSD-3-Clause"),
    ("go", "golang/go", "src/strings/builder.go", "BSD-3-Clause"),
    ("go", "spf13/cobra", "args.go", "Apache-2.0"),
    ("rust", "rust-lang/rust", "library/core/src/bool.rs", "MIT OR Apache-2.0"),
    ("rust", "BurntSushi/ripgrep", "crates/matcher/src/interpolate.rs", "MIT OR Unlicense"),
    ("sql", "jOOQ/sakila", "sqlite-sakila-db/sqlite-sakila-schema.sql", "BSD-2-Clause"),
    ("shell", "rbenv/rbenv", "libexec/rbenv-init", "MIT"),
    ("shell", "ohmyzsh/ohmyzsh", "tools/upgrade.sh", "MIT"),
    ("shell", "nvm-sh/nvm", "install.sh", "MIT"),
]
# where a project keeps its licence when it is not LICENSE*/COPYING* at the top
LICENCE_FILES = {"lua/lua": "lua.h"}


def run(*cmd):
    return subprocess.run(cmd, capture_output=True, text=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("vscode")
    ap.add_argument("--work", default="/tmp/homerow-code")
    ap.add_argument("--out", default="HomeRow/Resources/Code")
    args = ap.parse_args()

    for sub in ("Grammars", "Files", "LICENSES"):
        shutil.rmtree(os.path.join(args.out, sub), ignore_errors=True)
        os.makedirs(os.path.join(args.out, sub))
    vscode_commit = run("git", "-C", args.vscode, "rev-parse", "HEAD").stdout.strip()

    # --- grammars -------------------------------------------------------
    notices = ["TextMate grammars, copied unmodified from VS Code's bundled extensions",
               "(https://github.com/microsoft/vscode, commit %s).  VS Code takes each" % vscode_commit,
               "from the upstream project named below; all are under the MIT licence.", ""]
    languages = []
    for ident, name, scope, grammars, extensions in LANGUAGES:
        for g in grammars:
            shutil.copy(os.path.join(args.vscode, "extensions", g), os.path.join(args.out, "Grammars"))
        manifest = json.load(open(os.path.join(args.vscode, "extensions", grammars[0].split("/")[0], "cgmanifest.json")))
        for reg in manifest["registrations"]:
            git = reg["component"].get("git", {})
            lic = reg.get("license", "")
            if "MIT" not in lic:
                continue   # the TextMate-bundle-licensed parts belong to grammars HomeRow does not take
            notices.append("%-12s %s  @ %s  (%s)" % (ident, git.get("repositoryUrl"), git.get("commitHash", "")[:12], lic))
        languages.append({"identifier": ident, "displayName": name, "scopeName": scope,
                          "grammar": os.path.basename(grammars[0]), "extensions": extensions, "files": []})
    open(os.path.join(args.out, "Grammars", "NOTICE"), "w").write("\n".join(notices) + "\n")

    # --- source files ---------------------------------------------------
    by_id = {l["identifier"]: l for l in languages}
    for lang, repo, path, licence in FILES:
        d = os.path.join(args.work, repo.replace("/", "_"))
        if not os.path.isdir(d):
            r = run("git", "clone", "-q", "--depth", "1", "--filter=blob:none", "--sparse",
                    "https://github.com/%s.git" % repo, d)
            if r.returncode:
                sys.exit("could not clone %s: %s" % (repo, r.stderr.strip()[-200:]))
        wanted = ["/" + p for l, rp, p, _ in FILES if rp == repo]
        wanted += ["/LICENSE*", "/LICENCE*", "/COPYING*", "/License*"]
        if repo in LICENCE_FILES:
            wanted.append("/" + LICENCE_FILES[repo])
        run("git", "-C", d, "sparse-checkout", "set", "--no-cone", *wanted)
        commit = run("git", "-C", d, "rev-parse", "HEAD").stdout.strip()
        src = os.path.join(d, path)
        if not os.path.isfile(src):
            sys.exit("%s no longer has %s" % (repo, path))
        text = open(src, encoding="utf-8").read()     # must be UTF-8: fail here, not in the app
        dest_name = "%s--%s" % (repo.split("/")[1], os.path.basename(path))
        os.makedirs(os.path.join(args.out, "Files", lang), exist_ok=True)
        shutil.copy(src, os.path.join(args.out, "Files", lang, dest_name))
        by_id[lang]["files"].append({"file": "%s/%s" % (lang, dest_name),
                                     "title": "%s — %s" % (repo.split("/")[1], os.path.basename(path)),
                                     "repository": "https://github.com/" + repo, "path": path,
                                     "commit": commit, "licence": licence,
                                     "lines": text.count("\n")})
        lic_dest = os.path.join(args.out, "LICENSES", repo.replace("/", "--") + ".txt")
        if not os.path.exists(lic_dest):
            found = sorted(glob.glob(os.path.join(d, "LICEN[SC]E*")) + glob.glob(os.path.join(d, "License*"))
                           + glob.glob(os.path.join(d, "COPYING*")))
            if repo in LICENCE_FILES:
                found = [os.path.join(d, LICENCE_FILES[repo])]
            found = [f for f in found if os.path.isfile(f)]
            with open(lic_dest, "w", encoding="utf-8") as out:
                out.write("%s (%s), https://github.com/%s @ %s\n\n" % (repo, licence, repo, commit))
                if not found:
                    out.write("(the project keeps no licence file at its top level; see the file headers)\n")
                for f in found:
                    out.write("---- %s ----\n%s\n" % (os.path.basename(f), open(f, encoding="utf-8", errors="replace").read()))

    xml = plistlib.dumps({"vscodeCommit": vscode_commit, "languages": languages}, sort_keys=False).decode("utf-8")
    xml = "".join(c if ord(c) < 128 else "&#x%X;" % ord(c) for c in xml)   # see import-monkeytype.py
    open(os.path.join(args.out, "index.plist"), "w", encoding="ascii").write(xml)
    print("%d languages, %d files" % (len(languages), sum(len(l["files"]) for l in languages)))


if __name__ == "__main__":
    main()
