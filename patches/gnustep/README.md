# gnustep-gui patches

They are not kept here any more.

Fixes to GNUstep itself live in the shared `gnustep-patches` repository,
because several projects on this machine build the same stack and each
carrying its own copies meant the same fix existed three times, drifted, and
outlived its merge upstream. The three this directory held — the tableau row
expression used after its owner released it, the `NSMenu` / `NSTextField`
sender used after its action released it, and the tracking-rect walk visiting
freed subviews — were byte-for-byte copies of XFormsKit's and are all there.

`.github/scripts/dependencies.sh` clones that repository and applies what it
carries for libs-gui, pinned by `GNUSTEP_PATCHES_REF` in the workflows, which
is part of the GNUstep cache key: moving the pin rebuilds the stack instead of
reusing a differently-patched prefix.

HomeRow does not knowingly depend on any of these fixes — its window is laid
out with autoresizing masks, not constraints, and it keeps its controls alive
across actions. They are applied so that the gui inside HomeRow's AppImage is
the same known-good build the other projects get.

To add a fix, or to check whether one is still needed, go to that repository:
its `STATUS.md` lists every patch, its pull request and which repositories
still carry a copy, and its `CLAUDE.md` describes how a patch is written,
tested against a docker-built GNUstep and sent upstream.
