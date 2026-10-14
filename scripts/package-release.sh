#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
: "${SIGNING_IDENTITY:?Set your Developer ID Application signing identity}"
: "${NOTARY_PROFILE:?Set the name of your existing notarytool keychain profile}"
./scripts/build.sh
app="$PWD/dist/Portico.app"
# A public release must never contain a local library pointer.
if /usr/libexec/PlistBuddy -c 'Print :PorticoLibraryPath' "$app/Contents/Info.plist" >/dev/null 2>&1; then
    echo 'Refusing to package a local-library installation.' >&2
    exit 1
fi
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")
architecture=$(uname -m)
archive="$PWD/dist/Portico-$version-$architecture.zip"
submission="$PWD/dist/notarization-$version.zip"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$app" "$submission"
xcrun notarytool submit "$submission" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$app"
xcrun stapler validate "$app"
codesign --verify --deep --strict "$app"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$app" "$archive"
shasum -a 256 "$archive" > "$archive.sha256"
echo "Release archive: $archive"
