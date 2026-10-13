# Releasing

A release is a tag. `build.yml`, the workflow every push runs, builds both
downloads from it, tests them, signs and notarizes the macOS app if it has
the means, and attaches the files to the tag's GitHub release.

## Cutting one

1. `master` is green in CI, and the app has been *looked at* on both
   platforms — CI proves it starts and types, not that it looks right.
2. Bring [roadmap.md](roadmap.md) and the README's *Limitations* up to date.
3. Rehearse if anything about packaging changed: every push to a branch
   builds the same downloads, unsigned, as artifacts of its run, and
   publishes nothing. (**Actions ▸ Build ▸ Run workflow** with a tag
   releases that tag.)
4. Tag and push:

       git tag -a v0.1.0 -m "HomeRow 0.1.0"
       git push origin v0.1.0

   The tag is the version: the release workflows (gnustep-release-actions'
   `stamp-version.sh`) write it into the Xcode project (numeric part only,
   as Apple requires; the build number is the run's), the GNUmakefile and
   `HomeRowInfo.plist`. `v0.1.0-rc1` works, and makes a pre-release: one
   that installed copies are not offered (below).
5. When the workflow is done, the release has
   `HomeRow-<version>-x86_64.AppImage` and
   `HomeRow-macOS-<version>.zip` (or `…-unsigned.zip`, see below), and for
   a release (not a pre-release) `appcast.xml` and the AppImage's `.zsync`
   (see *Updates*). Edit the generated notes into something a user wants
   to read.

A tag that fails its tests publishes nothing for that platform; fix, delete
the tag (`git push origin :v0.1.0`), and tag again.

## Signing and notarizing the macOS app

Without secrets the job still succeeds: the zip is named `-unsigned`, the
app is ad-hoc signed, and Gatekeeper makes people right-click ▸ Open. With
them, it is signed with a Developer ID, notarized, stapled, and checked
with `spctl` the way a downloader's Mac will check it.

This needs a paid Apple Developer Program membership. Once:

1. **Certificate.** Xcode ▸ Settings ▸ Accounts ▸ Manage Certificates ▸ **+**
   ▸ *Developer ID Application*. In Keychain Access, find it under *My
   Certificates*, select the certificate *with its private key*, File ▸
   Export Items… as `.p12`, with a password.
2. **Its identity string**, for `MACOS_SIGN_IDENTITY`:

       security find-identity -v -p codesigning
       # "Developer ID Application: Your Name (TEAMID)"

3. **An app-specific password** for notarization: account.apple.com ▸
   Sign-In and Security ▸ App-Specific Passwords.
4. **Secrets of the `production` environment** (Settings ▸ Environments ▸
   production ▸ Environment secrets) — the macOS job (gnustep-release-actions'
   `macos.yml`) names that environment, and only a job that does can
   read them. Repository-level secrets of the same names work too, but keep
   them in one place:

   | Secret | Value |
   |---|---|
   | `MACOS_CERTIFICATE` | `base64 -i DeveloperID.p12 \| pbcopy` |
   | `MACOS_CERTIFICATE_PASSWORD` | the `.p12` password |
   | `MACOS_SIGN_IDENTITY` | the string from step 2 |
   | `NOTARY_APPLE_ID` | the Apple ID's e-mail address |
   | `NOTARY_TEAM_ID` | the ten-character team ID |
   | `NOTARY_PASSWORD` | the app-specific password |
   | `SPARKLE_PRIVATE_KEY` | the EdDSA key Sparkle's `generate_keys -x` exports (*Updates*) |

   Then delete the `.p12` from wherever it was exported to.

If the job warns that `MACOS_CERTIFICATE` is not set although it is, the log
shows `CERTIFICATE:` empty in the step's `env:` — the secrets are in an
environment the job does not name, or the environment restricts which
branches and tags may use it (Deployment branches and tags: a `v*` tag must
be allowed).

With the certificate but without the `NOTARY_*` secrets the app is signed
and not notarized, and the job says so in a warning.

HomeRow needs no entitlements: it uses the hardened runtime as it is, opens
only files the user points it at, and is not sandboxed. The hardened runtime
is switched on when the app is signed (gnustep-release-actions'
`macos-sign`), not in the Xcode project: an ad-hoc signed build with it
would refuse to load the Sparkle.framework embedded in it. Signing goes
inside out -- Sparkle's helpers, the framework, then the app -- rather than
with `--deep`. If notarization is rejected, the job prints Apple's log; the
usual cause is a nested binary that was not signed.

To check a download by hand:

    spctl --assess --type execute --verbose=2 HomeRow.app
    codesign --verify --deep --strict --verbose=2 HomeRow.app
    xcrun stapler validate HomeRow.app

## Updates

The Mac app updates itself with Sparkle: it checks the newest release's
`appcast.xml` (`SUFeedURL` in `HomeRow/HomeRow-Info.plist`) once a day if
the user allows it, and HomeRow ▸ Check for Updates… checks at once. A
release's appcast is written by the macOS job and signed with the
`SPARKLE_PRIVATE_KEY` secret, whose public half is `SUPublicEDKey` in the
same plist; without the secret there is no appcast, and installed copies
are not offered the release.

A release's AppImage carries update information (`gh-releases-zsync`, the
newest release), and its `.zsync` is attached beside it, so AppImageUpdate,
Gear Lever and the like update it by the blocks that changed. A
pre-release's carries none: "latest" would offer it the release before it.
Up to 0.1.1 the image was named `HomeRow-Linux-<version>-x86_64.AppImage`,
and 0.1.1's update information looks for that name: its users download the
next release by hand once.

## Linux

The AppImage carries GNUstep, FreeCoreData, ICU and fonts. Two things come
from the host: a graphical session (X11, or XWayland), and — for key sounds
only — libao's output plug-ins, which libao looks for in the system's own
library directory (`libao4` on Debian and Ubuntu, `libao` on Fedora and
Arch). Without them HomeRow is silent and otherwise unchanged.

The AppImage is built on Ubuntu 22.04, so that it runs there and on
anything newer, on the stack gnustep-patches publishes as an image
(`ghcr.io/ashalkhakov/gnustep:latest`), with FreeCoreData at its pin in
`.github/pins.env`. HomeRow builds no GNUstep of its own: a change to the
stack (a patch, a component, an apt package its configure scripts react to,
as `libao-dev` was) is made in gnustep-patches and reaches HomeRow with its
next image.
