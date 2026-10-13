#!/bin/bash
# HomeRow for gnustep-release-actions' macos-release.yml: stamped, its unit
# tests passed, and the universal Release build into $RELEASE_DIR.
set -euo pipefail
xcodebuild -project HomeRow.xcodeproj -scheme HomeRow \
  -destination 'platform=macOS' -configuration Debug test
xcodebuild -project HomeRow.xcodeproj -scheme HomeRow \
  -destination 'generic/platform=macOS' -configuration Release \
  -derivedDataPath "$RUNNER_TEMP/DerivedData" ONLY_ACTIVE_ARCH=NO build
ditto "$RUNNER_TEMP/DerivedData/Build/Products/Release/HomeRow.app" "$RELEASE_DIR/HomeRow.app"
