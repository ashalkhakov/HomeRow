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

The stack is gnustep-patches': libobjc2, libdispatch, tools-make, libs-base,
libs-gui (with its patches), libs-back, the Eau theme and tools-xctest.
Either unpack the release CI builds on (`.github/pins.env`'s
`GNUSTEP_PATCHES_VERSION`: an archive for Ubuntu 22.04 that unpacks into
`/opt/gnustep`), or build the same stack on your own machine
with its `Scripts/build-gnustep.sh` (the apt packages it needs are in
`Scripts/packages-ubuntu.txt` beside it). On top of it,
[FreeCoreData](https://github.com/ashalkhakov/FreeCoreData) at the release
`.github/pins.env` names (`FREECOREDATA_VERSION`: its archive unpacks into
`/opt/gnustep`, or build it from source at that tag); `libsqlite3-dev` from apt.

```sh
# in gnustep-patches, once (about half an hour)
PREFIX=$HOME/gnustep Scripts/build-gnustep.sh

. $HOME/gnustep/System/Library/Makefiles/GNUstep.sh
(cd ../FreeCoreData && make && make install \
  && make -C Tools/momc && make -C Tools/momc install)
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
source added on Linux has to be added there too — `make check` (on
both, `Scripts/check-sources.sh`) first checks that every `.m` (and each of
Oniguruma's compiled `.c` files) is in the project. Resources that are whole folders (`Languages`, `Layouts`,
`Lessons`, `Code`, `Themes`) are folder references: new packs need no
project change.

## CI and packaging

One workflow, `.github/workflows/build.yml`, calls gnustep-release-actions'
`linux.yml` and `macos.yml`, the same as every repository's, on every push
and `v*` tag. They fetch what `.github/pins.env` names (the GNUstep stack,
FreeCoreData, Sparkle) and build HomeRow the familiar way: on Linux `make`,
`make check` and `make install`; on the Mac `Makefile.apple` (the universal
Release build and its macOS 12 floor, `check`, `install`, and `installcheck`,
the smoke test). Every run uploads the unsigned Mac zip and the AppImage as
artifacts, named for the app and version (`HomeRow-macOS-0.0.0-build57`,
`HomeRow-0.0.0-build57-x86_64`) and kept two weeks; the version is stamped
by gnustep-release-actions' `stamp-version.sh`. A tag is also released
([releasing.md](releasing.md)).

`HomeRow-<version>-x86_64.AppImage` is made by gnustep-release-actions'
`appimage`, the same as every app's image: the app (`make install`), the GNUstep libraries and bundles it needs,
DejaVu and Liberation fonts, the Eau theme, the shared launcher (`AppRun`)
and an opener, installed as `open` and `xdg-open` in the image's GNUstep
tools directory: `NSWorkspace` looks there before `$PATH`, and would
otherwise find nothing to open the project link in the Info panel with. Its
name has no "Linux" in it: AppImage asks names not to. The image is then run
on a clean Ubuntu 22.04 with no GNUstep and no fonts (`Scripts/appimage-smoke.sh`), so
an image that only works on the build machine fails there. The macOS app is
tested by `make -f Makefile.apple installcheck`; for a tag, again once signed.
