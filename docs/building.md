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
Either use the image it publishes, which CI builds on
(`ghcr.io/ashalkhakov/gnustep:latest`, or a dated tag such as
`v2026.10.13`; Ubuntu 22.04, the stack in `/opt/gnustep`), or build the same stack on your own machine
with its `Scripts/build-gnustep.sh` (the apt packages it needs are in
`Scripts/packages-ubuntu.txt` beside it). On top of it,
[FreeCoreData](https://github.com/ashalkhakov/FreeCoreData) at the commit
pinned in `.github/pins.env` (`FREECOREDATA_REF`), checked out beside this
repository; `libsqlite3-dev` from apt.

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
source added on Linux has to be added there too — the macOS build
(`.github/release/macos-build.sh`) first checks that every `.m` (and each of
Oniguruma's compiled `.c` files) is in the project. Resources that are whole folders (`Languages`, `Layouts`,
`Lessons`, `Code`, `Themes`) are folder references: new packs need no
project change.

## CI and packaging

One workflow, `.github/workflows/build.yml`, calls gnustep-release-actions'
`macos-release.yml` and `appimage-release.yml`, the same as every app's, on
every push, pull request and `v*` tag. What is HomeRow's own is in
`.github/release/`: `macos-build.sh` (every source in the project, the Debug
build and tests, the universal Release build, its macOS 11 floor),
`macos-test.sh` (the smoke test), `linux-build.sh` (the import guard, ICU and
the sound plug-ins in the stack, FreeCoreData, `make`, `make check`),
`linux-install.sh`, `linux-test.sh` and `appimage.conf`. Every run uploads
the unsigned Mac zip and the AppImage as artifacts, named for the app and
version (`HomeRow-macOS-0.0.0-build57`, `HomeRow-0.0.0-build57-x86_64`) and
kept two weeks; the version is stamped by gnustep-release-actions'
`stamp-version.sh`. A tag is also released ([releasing.md](releasing.md)).

`HomeRow-<version>-x86_64.AppImage` is made by gnustep-release-actions'
`appimage`, the same as every app's image: the app (installed into the
prefix by `linux-install.sh`), the GNUstep libraries and bundles it needs,
DejaVu and Liberation fonts, the Eau theme, the shared launcher (`AppRun`)
and an opener, installed as `open` and `xdg-open` in the image's GNUstep
tools directory: `NSWorkspace` looks there before `$PATH`, and would
otherwise find nothing to open the project link in the Info panel with. Its
name has no "Linux" in it: AppImage asks names not to. The image is then run
on a clean Ubuntu 22.04 with no GNUstep and no fonts (`linux-test.sh`), so
an image that only works on the build machine fails there. The macOS app is
tested by `macos-test.sh`; for a tag, again once signed.
