# Releasing

A release is a tag. `release.yml` builds both downloads from it, tests them,
signs and notarizes the macOS app if it has the means, and attaches the
files to a GitHub release with generated notes.

## Cutting one

1. `master` is green in CI, and the app has been *looked at* on both
   platforms — CI proves it starts and types, not that it looks right.
2. Bring [roadmap.md](roadmap.md) and the README's *Limitations* up to date.
3. Rehearse if anything about packaging changed: **Actions ▸ Release ▸ Run
   workflow** on the branch builds the same artifacts and publishes nothing.
4. Tag and push:

       git tag -a v0.1.0 -m "HomeRow 0.1.0"
       git push origin v0.1.0

   The tag is the version: `Scripts/stamp-version.sh` writes it into the
   Xcode project (numeric part only, as Apple requires), the GNUmakefile and
   `HomeRowInfo.plist`. `v0.1.0-rc1` works; GitHub marks nothing as a
   pre-release by itself, so tick that box on the release page for one.
5. When the workflow is done, the release has
   `HomeRow-Linux-<version>-x86_64.AppImage` and
   `HomeRow-macOS-<version>.zip` (or `…-unsigned.zip`, see below). Edit the
   generated notes into something a user wants to read.

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
4. **Repository secrets** (Settings ▸ Secrets and variables ▸ Actions):

   | Secret | Value |
   |---|---|
   | `MACOS_CERTIFICATE` | `base64 -i DeveloperID.p12 \| pbcopy` |
   | `MACOS_CERTIFICATE_PASSWORD` | the `.p12` password |
   | `MACOS_SIGN_IDENTITY` | the string from step 2 |
   | `NOTARY_APPLE_ID` | the Apple ID's e-mail address |
   | `NOTARY_TEAM_ID` | the ten-character team ID |
   | `NOTARY_PASSWORD` | the app-specific password |

   Then delete the `.p12` from wherever it was exported to.

With the certificate but without the `NOTARY_*` secrets the app is signed
and not notarized, and the job says so in a warning.

HomeRow needs no entitlements: it uses the hardened runtime as it is, opens
only files the user points it at, and is not sandboxed. If notarization is
rejected, the job prints Apple's log; the usual cause is a nested binary
that was not signed, and HomeRow has none.

To check a download by hand:

    spctl --assess --type execute --verbose=2 HomeRow.app
    codesign --verify --deep --strict --verbose=2 HomeRow.app
    xcrun stapler validate HomeRow.app

## Linux

The AppImage carries GNUstep, FreeCoreData, ICU and fonts. Two things come
from the host: a graphical session (X11, or XWayland), and — for key sounds
only — libao's output plug-ins, which libao looks for in the system's own
library directory (`libao4` on Debian and Ubuntu, `libao` on Fedora and
Arch). Without them HomeRow is silent and otherwise unchanged.

The GNUstep stack is cached in CI under a key that hashes
`.github/scripts/dependencies.sh` and the patches. A change to the *apt
package list* that GNUstep's configure scripts react to (as `libao-dev` was)
is not in that hash: bump the `gnustep-vN` prefix of the key in both
workflows.
