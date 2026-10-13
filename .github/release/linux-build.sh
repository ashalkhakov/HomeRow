#!/bin/bash
# FreeCoreData (beside this repository: the framework and momc) and HomeRow,
# on the stack in $PREFIX, passing its tests; first, that every import is one
# GNUstep can satisfy or is guarded, and that the stack has what HomeRow
# needs of it: ICU in gnustep-base, and gnustep-gui's sound plug-ins.
set -eo pipefail

bad=$(grep -rnE '^[[:space:]]*#[[:space:]]*(import|include)[[:space:]]*<[A-Za-z]+/' \
        HomeRow HomeRowTests --include='*.h' --include='*.m' --exclude='*-Apple.m' \
        --exclude-dir=ThirdParty --exclude-dir=Code --exclude-dir=Fixtures \
      | grep -vE '<(Foundation|AppKit|CoreData|XCTest|objc)/' || true)
unguarded=0
if [ -n "$bad" ]; then
  while IFS=: read -r file line rest; do
    prev=$(sed -n "$((line-1))p" "$file")
    case "$prev" in
      *__has_include*) ;;
      *) echo "::error file=$file,line=$line::import GNUstep cannot satisfy, and no __has_include guard above it"; unguarded=1 ;;
    esac
  done <<< "$bad"
fi
[ "$unguarded" = 0 ] || exit 1
echo "imports are portable"

# GNUstep.sh reads unset variables (ZSH_VERSION), so set -u comes after it.
. "$PREFIX/System/Library/Makefiles/GNUstep.sh"
set -u
base=$(find "$PREFIX" -name 'libgnustep-base.so' | head -1)
ldd "$base" | grep -q 'libicu' || { echo "::error::$base does not link ICU"; exit 1; }
find "$PREFIX" -maxdepth 5 -name '*.nssound' | grep -q . \
  || { echo "::error::the stack has no .nssound bundles: gnustep-gui was built without libsndfile and libao"; exit 1; }

(cd ../FreeCoreData
 make -j"$(nproc)" && make install
 make -C Tools/momc && make -C Tools/momc install)
make messages=yes
make check
