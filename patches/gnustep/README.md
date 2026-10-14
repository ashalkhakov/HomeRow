# gnustep-gui patches

They are not kept here any more.

Fixes to GNUstep itself live in the shared `gnustep-patches` repository,
because several projects on this machine build the same stack and each
carrying its own copies meant the same fix existed three times, drifted, and
outlived its merge upstream. The three this directory held — the tableau row
expression used after its owner released it, the `NSMenu` / `NSTextField`
sender used after its action released it, and the tracking-rect walk visiting
freed subviews — were byte-for-byte copies of XFormsKit's and are all there.

That repository builds the stack with its patches applied and publishes it
as an image, `ghcr.io/ashalkhakov/gnustep:latest` (and a dated tag per
build), which HomeRow's CI builds on; HomeRow builds no GNUstep and pins
none. A patch reaches HomeRow with the next image.

HomeRow does not knowingly depend on any of these fixes — its window is laid
out with autoresizing masks, not constraints, and it keeps its controls alive
across actions. They are applied so that the gui inside HomeRow's AppImage is
the same known-good build the other projects get.

To add a fix, or to check whether one is still needed, go to that repository:
its `STATUS.md` lists every patch, its pull request and which repositories
still carry a copy, and its `CLAUDE.md` describes how a patch is written,
tested against a docker-built GNUstep and sent upstream.
