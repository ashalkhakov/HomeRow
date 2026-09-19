# Building HomeRow

## macOS

Xcode 15 or later. Open `HomeRow.xcodeproj`, or:

```sh
xcodebuild -project HomeRow.xcodeproj -scheme HomeRow build
xcodebuild -project HomeRow.xcodeproj -scheme HomeRow test
```

## GNUstep

HomeRow targets one GNUstep: **clang, libobjc2, the gnustep-2.0 ABI, ARC**,
built from source. Distribution packages (gcc runtime, no ARC) are not
supported; on Linux, use the AppImage unless you are developing.

`.github/scripts/dependencies.sh` builds the whole stack into a prefix of
your choice — libobjc2, libdispatch, tools-make, libs-base, libs-gui,
libs-back, [FreeCoreData](https://github.com/ashalkhakov/FreeCoreData) at a
pinned commit, the Eau theme and tools-xctest. The package list it needs is
in `.github/workflows/ci.yml`.

```sh
export CC=clang CXX=clang++ LIBRARY_COMBO=ng-gnu-gnu RUNTIME_VERSION=gnustep-2.0
export DEPS_PATH=$HOME/gnustep-src INSTALL_PATH=$HOME/gnustep
export LD_LIBRARY_PATH=$INSTALL_PATH/lib
./.github/scripts/dependencies.sh          # about half an hour, once

. $INSTALL_PATH/System/Library/Makefiles/GNUstep.sh
make                                       # the app and the test bundle
make check                                 # run the tests
openapp ./HomeRow/HomeRow.app
```

`HR_SMOKE_TEST=1` makes the app check its own outlets, type a ten-word test,
save the result and exit 0 — CI runs the packaged AppImage and the macOS
app that way.


## The Xcode project and the GNUmakefiles

Both build the same sources. The GNUmakefiles pick `Engine/*.m` and the
tests up with wildcards; `HomeRow.xcodeproj` lists files one by one, so a
source added on Linux has to be added there too — CI's first step checks
that every `.m` (and each of Oniguruma's compiled `.c` files) is in the
project. Resources that are whole folders (`Languages`, `Layouts`,
`Lessons`, `Code`, `Themes`) are folder references: new packs need no
project change.

## Packaging

`Scripts/prepare-appdir.sh` assembles an AppDir from a GNUstep prefix (the
app, the GNUstep libraries and bundles it needs, a fontconfig setup with
DejaVu and Liberation fonts) and `Scripts/package-appimage.sh` turns it into
`HomeRow-Linux-*.AppImage` with linuxdeploy. CI then runs the image with the
build prefix moved away, so an image that only works on the build machine
fails there. `release.yml` does the same for a tag and, given signing
secrets, signs and notarizes the macOS app; without them the zip is ad-hoc
signed.
