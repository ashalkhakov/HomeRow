# HomeRow

A native typing tutor for macOS and Linux (GNUstep): a touch-typing
course from zero, quick tests, and real-text practice.

## GNUstep patches live elsewhere

Fixes to GNUstep itself are not kept here. They live in `../gnustep-patches`,
which this machine's GNUstep projects share. It builds the patched stack
(`Scripts/build-gnustep.sh`) and publishes it as an image,
`ghcr.io/ashalkhakov/gnustep:latest`, which CI builds on; this repository
builds no GNUstep. The one pin left, FreeCoreData's, is in
`.github/pins.env`: to move it, edit it there.

If a bug here turns out to be GNUstep's, work in that repository and read its
`CLAUDE.md` first: reproduce in the docker container, fix, turn the
reproduction into a test in GNUstep's own suite, and push it there — that is
where patches are kept and where they are sent upstream from.

## Testing

GNUstep builds and tests run in docker, and anything that opens a window
needs `xvfb-run -a`. The patches this repository applies are insurance for
the gui it ships in the AppImage rather than fixes it is known to depend on —
`patches/gnustep/README.md` explains which.
