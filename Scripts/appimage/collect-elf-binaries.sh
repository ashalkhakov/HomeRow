#!/bin/bash
# The executables linuxdeploy should trace for dependencies. Found rather
# than named by path, because gnustep-make decides where they land. The
# backend bundle and FreeCoreData are dlopened or linked from inside the
# GNUstep tree, which linuxdeploy does not walk by itself, so they are named
# too: that is what brings cairo, fontconfig and sqlite3 into the image.
set -euo pipefail
appdir=${1:-AppDir}
find "$appdir" -type f -name "HomeRow" -perm -111 -exec file {} \; 2>/dev/null \
  | awk -F: '/ELF/{print $1; exit}'
find "$appdir" -type f \( -path '*libgnustep-back-*.bundle/*' -o -name 'libCoreData.so.*' \
                          -o -name 'libgnustep-gui.so.*.*' -o -name 'libgnustep-base.so.*.*' \) \
     -exec file {} \; 2>/dev/null | awk -F: '/ELF/{print $1}'
