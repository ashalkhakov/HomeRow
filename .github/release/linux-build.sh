#!/bin/bash
# FreeCoreData (beside this repository: the framework and momc) and HomeRow,
# on the stack in $PREFIX, stamped and passing its tests.
set -euo pipefail
# The packages are not in the stack's cache key: a stack built without
# libsndfile and libao would be restored without its sound plug-ins.
find "$PREFIX" -maxdepth 5 -name '*.nssound' | grep -q . \
  || { echo "::error::no .nssound bundles: were libsndfile1-dev and libao-dev installed before the stack was built?"; exit 1; }
. "$PREFIX/System/Library/Makefiles/GNUstep.sh"
(cd ../FreeCoreData
 make -j"$(nproc)" && make install
 make -C Tools/momc && make -C Tools/momc install)
./Scripts/stamp-version.sh "$APP_VERSION"
make check
