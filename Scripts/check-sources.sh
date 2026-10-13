#!/bin/bash
# HomeRow's sources, checked before its tests (make check, on GNUstep and
# on the Mac):
#   * every import is one GNUstep can satisfy, or is guarded by
#     __has_include on the line above it;
#   * every source file is compiled by a target of HomeRow.xcodeproj (a
#     file with an -Apple.m beside it is that class's GNUstep half: the Mac
#     compiles the other), and so is every Oniguruma file HomeRow's
#     GNUmakefile names (the others are #included by unicode.c and must
#     stay out of both builds).
# Run from the repository's root.
set -euo pipefail
failed=0

bad=$(grep -rnE '^[[:space:]]*#[[:space:]]*(import|include)[[:space:]]*<[A-Za-z]+/' \
        HomeRow HomeRowTests --include='*.h' --include='*.m' --exclude='*-Apple.m' \
        --exclude-dir=ThirdParty --exclude-dir=Code --exclude-dir=Fixtures \
      | grep -vE '<(Foundation|AppKit|CoreData|XCTest|objc)/' || true)
if [ -n "$bad" ]; then
  while IFS=: read -r file line rest; do
    case "$(sed -n "$((line-1))p" "$file")" in
      *__has_include*) ;;
      *) echo "$file:$line: an import GNUstep cannot satisfy, and no __has_include guard above it"; failed=1 ;;
    esac
  done <<< "$bad"
fi

project=HomeRow.xcodeproj/project.pbxproj
for f in HomeRow/*.m HomeRow/Engine/*.m HomeRowTests/*.m; do
  [ -e "${f%.m}-Apple.m" ] && continue
  grep -q "/\* $(basename "$f") in Sources \*/" "$project" \
    || { echo "$f: not compiled by any target in HomeRow.xcodeproj"; failed=1; }
done
for f in $(grep -o 'ThirdParty/oniguruma/src/[a-z0-9_]*\.c' HomeRow/GNUmakefile | sort -u); do
  grep -q "/\* $(basename "$f") in Sources \*/" "$project" \
    || { echo "HomeRow/$f: not compiled by any target in HomeRow.xcodeproj"; failed=1; }
done

[ "$failed" = 0 ] && echo "check-sources: imports portable, every source in the Xcode project"
exit "$failed"
