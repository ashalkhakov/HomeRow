#!/bin/bash
# The AppImage on a clean Ubuntu, as gnustep-release-actions' appimage-test
# runs it (.github/release/appimage.conf, SMOKE_SCRIPT): HomeRow starts,
# types and quits, in a fresh home.
#   Scripts/appimage-smoke.sh <HomeRow AppImage>
set -euo pipefail
export HOME=$(mktemp -d)
HR_SMOKE_TEST=1 timeout 120 xvfb-run -a "$1"
