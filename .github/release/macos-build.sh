#!/bin/bash
# HomeRow for gnustep-release-actions' macos-release.yml: first what CI ran,
# every source file in the Xcode project, the Debug build and the unit tests
# (the same XCTest sources the GNUstep build runs, here against Apple's Core
# Data); then the universal Release build into $RELEASE_DIR, which must run
# on macOS 11, Big Sur, the floor.
set -euo pipefail
xcodebuild -version

# A file with an -Apple.m beside it (HRUpdater.m) is that class's GNUstep
# half, and the Mac compiles the other.
missing=0
for f in HomeRow/*.m HomeRow/Engine/*.m HomeRowTests/*.m; do
  [ -e "${f%.m}-Apple.m" ] && continue
  name=$(basename "$f")
  grep -q "/\* $name in Sources \*/" HomeRow.xcodeproj/project.pbxproj \
    || { echo "::error file=$f::$name is not compiled by any target in HomeRow.xcodeproj"; missing=1; }
done
# Oniguruma: the C files the GNUmakefile names (the others are #included by
# unicode.c and must stay out of both builds).
for f in $(grep -o 'ThirdParty/oniguruma/src/[a-z0-9_]*\.c' HomeRow/GNUmakefile | sort -u); do
  name=$(basename "$f")
  grep -q "/\* $name in Sources \*/" HomeRow.xcodeproj/project.pbxproj \
    || { echo "::error file=HomeRow/$f::$name is not compiled by any target in HomeRow.xcodeproj"; missing=1; }
done
[ "$missing" -eq 0 ] || exit 1
echo "all listed"

# Built first and on its own, so a compile error is reported as that.
xcodebuild -project HomeRow.xcodeproj -scheme HomeRow \
  -destination 'platform=macOS' -configuration Debug build
xcodebuild -project HomeRow.xcodeproj -scheme HomeRow \
  -destination 'platform=macOS' -configuration Debug \
  -resultBundlePath "$RUNNER_TEMP/HomeRowTests.xcresult" test

xcodebuild -project HomeRow.xcodeproj -scheme HomeRow \
  -destination 'generic/platform=macOS' -configuration Release \
  -derivedDataPath "$RUNNER_TEMP/DerivedData" ONLY_ACTIVE_ARCH=NO build
ditto "$RUNNER_TEMP/DerivedData/Build/Products/Release/HomeRow.app" "$RELEASE_DIR/HomeRow.app"

# Big Sur is a promise that erodes silently: one target setting or one Xcode
# upgrade moves it. What the binary itself says, not the project file.
bin="$RELEASE_DIR/HomeRow.app/Contents/MacOS/HomeRow"
for arch in arm64 x86_64; do
  minos=$(vtool -arch "$arch" -show-build "$bin" | awk '/minos/{print $2; exit}')
  echo "$arch: minos $minos"
  [ "$minos" = "11.0" ] || { echo "::error::$arch slice needs macOS $minos, not 11.0"; exit 1; }
done
