#!/bin/bash
# HomeRow-Linux-<version>-x86_64.AppImage: HomeRow, FreeCoreData and the
# GNUstep runtime in one file.
set -euo pipefail
. "$PREFIX/System/Library/Makefiles/GNUstep.sh"
GNUSTEP_PREFIX="$PREFIX" ./Scripts/prepare-appdir.sh
GNUSTEP_PREFIX="$PREFIX" ./Scripts/package-appimage.sh
