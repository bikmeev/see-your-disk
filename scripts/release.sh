#!/bin/zsh
# Build, sign (Developer ID), notarize and package See Your Disk as a DMG, then publish a GitHub release.
#
# One-time setup (see docs/RELEASING.md):
#   1. A "Developer ID Application" certificate in your keychain
#   2. xcrun notarytool store-credentials "seeyourdisk-notary" --apple-id <id> --team-id X6C6J5GZ75 --password <app-specific-password>
#   3. gh auth login
#
# Usage: scripts/release.sh 1.0.0
set -euo pipefail
setopt null_glob   # zsh: an unmatched pattern (no stale mounts) must not be an error

VERSION="${1:?usage: scripts/release.sh <version>}"
PROFILE="seeyourdisk-notary"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build"
APP="$BUILD/export/SeeYourDisk.app"
DMG="$BUILD/SeeYourDisk-$VERSION.dmg"

# a failed earlier run can leave the disk image mounted
for v in /Volumes/"See Your Disk"*; do [ -d "$v" ] && hdiutil detach "$v" -force >/dev/null 2>&1 || true; done
rm -rf "$BUILD"; mkdir -p "$BUILD"
cd "$ROOT"

echo "▶ Archive"
xcodebuild -project SeeYourDisk.xcodeproj -scheme SeeYourDisk -configuration Release \
  -destination 'generic/platform=macOS' -archivePath "$BUILD/SeeYourDisk.xcarchive" \
  MARKETING_VERSION="$VERSION" ENABLE_HARDENED_RUNTIME=YES archive

echo "▶ Export (Developer ID)"
xcodebuild -exportArchive -archivePath "$BUILD/SeeYourDisk.xcarchive" \
  -exportOptionsPlist scripts/ExportOptions.plist -exportPath "$BUILD/export"

echo "▶ Verify signature"
codesign --verify --deep --strict --verbose=2 "$APP"

echo "▶ Notarize app"
ditto -c -k --keepParent "$APP" "$BUILD/app.zip"
xcrun notarytool submit "$BUILD/app.zip" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$APP"

echo "▶ Make DMG (with background and arrow)"
VOL="See Your Disk"
RW="$BUILD/rw.dmg"
STAGE="$BUILD/dmg"; mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
hdiutil create -volname "$VOL" -srcfolder "$STAGE" -ov -format UDRW -fs HFS+ "$RW" >/dev/null
MOUNT="$(hdiutil attach "$RW" -readwrite -noverify -noautoopen | sed -n 's#.*\(/Volumes/.*\)$#\1#p' | head -1)"
trap 'hdiutil detach "$MOUNT" -force >/dev/null 2>&1 || true' EXIT
VOLNAME="$(basename "$MOUNT")"
mkdir "$MOUNT/.background"
cp "$ROOT/scripts/dmg-background.tiff" "$MOUNT/.background/background.tiff"
ln -s /Applications "$MOUNT/Applications"
# Finder lays out the window: needs "Automation" permission for your terminal the first time.
osascript <<OSA
tell application "Finder"
  tell disk "$VOLNAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 120, 860, 548}
    set opts to the icon view options of container window
    set arrangement of opts to not arranged
    set icon size of opts to 112
    delay 1
    try
      set background picture of opts to (POSIX file "$MOUNT/.background/background.tiff" as alias)
    on error
      set background picture of opts to file ".background:background.tiff"
    end try
    set position of item "SeeYourDisk.app" of container window to {170, 190}
    set position of item "Applications" of container window to {490, 190}
    close
    open
    update without registering applications
    delay 2
    close
  end tell
end tell
OSA
sync
hdiutil detach "$MOUNT" >/dev/null
trap - EXIT
hdiutil convert "$RW" -format UDZO -imagekey zlib-level=9 -o "$DMG" >/dev/null
codesign --force --sign "Developer ID Application" --timestamp "$DMG"

echo "▶ Notarize DMG"
xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$DMG"

echo "▶ Checksum"
( cd "$BUILD" && shasum -a 256 "$(basename "$DMG")" > "$(basename "$DMG").sha256" )

echo "▶ GitHub release v$VERSION"
gh release create "v$VERSION" "$DMG" "$DMG.sha256" \
  --title "See Your Disk $VERSION" \
  --notes "Open-source edition (no purchases, Full Disk Access). Signed with Developer ID and notarized by Apple. The Mac App Store edition: https://apps.apple.com/us/app/clean-systemdata-seeyourdisk/id6817565741"

echo "✔ Done: $DMG"
