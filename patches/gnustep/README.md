# gnustep-gui patches

These three patches are applied to gnustep-gui by
`.github/scripts/dependencies.sh` before it is built. They are copied
unchanged from [XFormsKit](https://github.com/ashalkhakov/XFormsKit/tree/master/patches/gnustep),
whose README explains each bug and carries a standalone reproduction:

| Patch | Bug |
|---|---|
| `gnustep-gui-gscstableau-removerow-use-after-free.patch` | Auto Layout: a row expression is used after its owner released it, on every window resize |
| `gnustep-gui-action-sender-lifetime.patch` | `NSMenu` / `NSTextField` keep using the sender after its action released it |
| `gnustep-gui-tracking-walk-retains-subviews.patch` | the tracking-rect walk visits views a `mouseExited:` handler has freed |

HomeRow does not knowingly depend on any of them (its window is laid out
with autoresizing masks, not constraints). They are carried so that the gui
inside HomeRow's AppImage is the same known-good build as XFormsKit's. Drop
a patch here once it is upstream; the CI cache key includes this folder, so
the stack rebuilds by itself.
