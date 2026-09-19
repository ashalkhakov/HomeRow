#!/bin/bash
# Assemble AppDir. Ported from XFormsKit's Scripts/prepare-appdir.sh (which
# came from RDLKit and UDQuakeTools); one application here instead of three.
#
#   GNUSTEP_PREFIX=/path/to/gnustep ./Scripts/prepare-appdir.sh
set -e

WORKSPACE_DIR=$(pwd)
LOCAL_PREFIX="${GNUSTEP_PREFIX:-/opt/gnustep-prefix}"

# 1. Recreate clean AppDir structural root
rm -rf AppDir
mkdir -p AppDir/usr/bin AppDir/usr/lib AppDir/usr/etc AppDir/usr/local/bin

# 2. Source GNUstep environment once
. "${LOCAL_PREFIX}/System/Library/Makefiles/GNUstep.sh"

# 3. Install the app into the prefix. Only the app: the test bundle has no
# business in the image.
make -C HomeRow
make -C HomeRow install GNUSTEP_INSTALLATION_DOMAIN=SYSTEM

# 4. The background tools gnustep-gui starts on demand
for tool in gdnc gpbs make_services; do
    FOUND_TOOL=$(find "${LOCAL_PREFIX}" -type f -name "$tool" 2>/dev/null | head -n 1 || true)
    if [ -n "$FOUND_TOOL" ]; then
        cp -p "$FOUND_TOOL" AppDir/usr/lib/
        cp -p "$FOUND_TOOL" AppDir/usr/local/bin/
    fi
done

# 5. Pull BOTH System and Local hierarchies into AppDir/usr/ -- themes,
# backend bundle, FreeCoreData's framework and the app itself all live there.
for domain in System Local; do
    if [ -d "${LOCAL_PREFIX}/${domain}" ]; then
        mkdir -p "AppDir/usr/${domain}"
        cp -Rp "${LOCAL_PREFIX}/${domain}/"* "AppDir/usr/${domain}/"
    fi
done
# nobody compiles inside the image
rm -rf AppDir/usr/System/Library/Headers AppDir/usr/Local/Library/Headers \
       AppDir/usr/System/Library/Makefiles AppDir/usr/System/Library/Documentation

# libobjc, from the prefix's plain lib directory
for libobjc in "${LOCAL_PREFIX}"/lib/libobjc.so.*.*; do
    if [ -f "$libobjc" ]; then
        soname=$(basename "$libobjc")
        cp -p "$libobjc" AppDir/usr/lib/
        ln -sf "$soname" "AppDir/usr/lib/${soname%.*}"
        ln -sf "$soname" AppDir/usr/lib/libobjc.so
    fi
done

# libdispatch and, when it built its own, BlocksRuntime
for libdir in "${LOCAL_PREFIX}/lib" "${LOCAL_PREFIX}/lib64"; do
    if ls "$libdir"/libdispatch.so* 1> /dev/null 2>&1; then
        cp -p "$libdir"/libdispatch.so* AppDir/usr/lib/
        cp -p "$libdir"/libBlocksRuntime.so* AppDir/usr/lib/ 2>/dev/null || true
        break
    fi
done

# 6. Versioned and unversioned names for the backend bundle
BACKEND_BUNDLE=$(find AppDir/usr -name "libgnustep-back-*.bundle" 2>/dev/null | head -n 1 || true)
if [ -n "$BACKEND_BUNDLE" ]; then
    BUNDLE_DIR=$(dirname "$BACKEND_BUNDLE")
    BACKEND_NAME=$(basename "$BACKEND_BUNDLE")
    ln -sfv "$BACKEND_NAME" "$BUNDLE_DIR/libgnustep-back.bundle" || true
    ln -sfv "$BACKEND_NAME" "$BUNDLE_DIR/back.bundle" || true
fi

# 7. Fonts. The typing surface wants a fixed-pitch font, and a machine with
# none installed would otherwise fall back to something proportional.
mkdir -p AppDir/usr/etc/fonts
cp Scripts/appimage/fonts.conf AppDir/usr/etc/fonts/fonts.conf
for dir in /usr/share/fonts/truetype/dejavu /usr/share/fonts/truetype/liberation; do
    if [ -d "$dir" ]; then
        mkdir -p "AppDir/usr/share/fonts/truetype/$(basename "$dir")"
        cp -Rp "$dir"/* "AppDir/usr/share/fonts/truetype/$(basename "$dir")/"
    fi
done

find AppDir -maxdepth 1 -type d ! -name "AppDir" ! -name "usr" -exec rm -rf {} + 2>/dev/null || true

echo "AppDir assembled:"
du -sh AppDir
found=$(find AppDir/usr -maxdepth 5 -name "HomeRow.app" | head -n 1)
if [ -z "$found" ]; then
    echo "  MISSING: HomeRow.app" >&2
    exit 1
fi
echo "  $found"
test -d "$found/Resources/HomeRow.momd"  || { echo "  MISSING: HomeRow.momd" >&2; exit 1; }
test -f "$found/Resources/Layouts/qwerty.plist" || { echo "  MISSING: the keyboard layouts" >&2; exit 1; }
test -f "$found/Resources/Lessons/gtypist/index.plist" || { echo "  MISSING: the GNU Typist lessons" >&2; exit 1; }
test -f "$found/Resources/Code/index.plist" || { echo "  MISSING: the code samples and grammars" >&2; exit 1; }
test -f "$found/Resources/CodeWindow.xib" || { echo "  MISSING: CodeWindow.xib" >&2; exit 1; }
test -f "$found/Resources/StatsWindow.xib" || { echo "  MISSING: StatsWindow.xib" >&2; exit 1; }
test -d "$found/Resources/Languages/english"  || { echo "  MISSING: the English language pack" >&2; exit 1; }
