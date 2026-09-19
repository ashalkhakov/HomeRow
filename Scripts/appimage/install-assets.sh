#!/bin/bash
# Put the AppImage's own metadata into AppDir: the launcher, the desktop
# entry and the icon. linuxdeploy insists on all three.
set -euo pipefail
workspace_dir=${1:-$(pwd)}
appdir=${2:-AppDir}

mkdir -p "$appdir/usr/share/applications" "$appdir/usr/share/icons/hicolor/256x256/apps"
install -m 0755 "$workspace_dir/Scripts/appimage/AppRun" "$appdir/AppRun"
install -m 0644 "$workspace_dir/Scripts/appimage/HomeRow.desktop" "$appdir/homerow.desktop"
install -m 0644 "$workspace_dir/Scripts/appimage/HomeRow.desktop" "$appdir/usr/share/applications/homerow.desktop"
# one picture: the About panel, GNUstep's windows and the desktop launcher
install -m 0644 "$workspace_dir/HomeRow/Resources/HomeRow.png" "$appdir/homerow.png"
install -m 0644 "$workspace_dir/HomeRow/Resources/HomeRow.png" \
        "$appdir/usr/share/icons/hicolor/256x256/apps/homerow.png"
