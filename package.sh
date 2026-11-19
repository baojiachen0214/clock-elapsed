#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
signing_identity="${CLOCKELAPSED_SIGNING_IDENTITY:--}"
export CLOCKELAPSED_ARCHS="${CLOCKELAPSED_ARCHS:-arm64 x86_64}"
./build.sh
version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist)
stage="$PWD/output/release-stage"
installer="$stage/Install Clock Elapsed.app"
rm -rf "$stage"
mkdir -p "$installer/Contents/MacOS" "$installer/Contents/Resources" output/releases
installer_binaries=()
for architecture in ${=CLOCKELAPSED_ARCHS}; do
  xcrun swiftc -O -whole-module-optimization -target "$architecture-apple-macos14.0" \
    -framework AppKit Installer/main.swift -o "output/bin/ClockElapsedInstaller-$architecture"
  installer_binaries+=("output/bin/ClockElapsedInstaller-$architecture")
done
xcrun lipo -create $installer_binaries -output "$installer/Contents/MacOS/ClockElapsedInstaller"
cp Installer/Info.plist "$installer/Contents/Info.plist"
cp Resources/AppIcon.icns "$installer/Contents/Resources/"
cp install.sh "$installer/Contents/Resources/"
cp -R Installer/en.lproj Installer/zh-Hans.lproj "$installer/Contents/Resources/"
ditto output/ClockElapsed.app "$installer/Contents/Resources/ClockElapsed.app"
codesign --force --options runtime --sign "$signing_identity" --identifier local.clockelapsed.installer "$installer"
codesign --verify --deep --strict "$installer"
cp LICENSE "$stage/License.txt"
cp Installer/Read-me.txt "$stage/Read me first.txt"
cp Installer/请先阅读.txt "$stage/请先阅读.txt"
archive="$PWD/output/releases/ClockElapsed-$version-universal.zip"
dmg="$PWD/output/releases/ClockElapsed-$version-universal.dmg"
rm -f "$archive" "$dmg"
hdiutil create -quiet -volname 'Clock Elapsed' -srcfolder "$stage" -format UDZO "$dmg"
if [[ "$signing_identity" != - ]]; then codesign --force --sign "$signing_identity" "$dmg"; fi
# A configured profile enables notarization without embedding credentials.
if [[ -n "${CLOCKELAPSED_NOTARY_PROFILE:-}" ]]; then
  xcrun notarytool submit "$dmg" --keychain-profile "$CLOCKELAPSED_NOTARY_PROFILE" --wait
  xcrun stapler staple "$installer"
  xcrun stapler staple "$dmg"
fi
ditto -c -k --sequesterRsrc --keepParent "$stage" "$archive"
(cd output/releases && shasum -a 256 "${dmg:t}" "${archive:t}" > SHA256SUMS.txt)
echo "$dmg"
echo "$archive"
