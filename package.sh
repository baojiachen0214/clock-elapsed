#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
signing_identity="${CLOCKELAPSED_SIGNING_IDENTITY:--}"
export CLOCKELAPSED_ARCHS="${CLOCKELAPSED_ARCHS:-arm64 x86_64}"
notarize=false
if [[ -n "${CLOCKELAPSED_NOTARY_PROFILE:-}${CLOCKELAPSED_NOTARY_KEY:-}" ]]; then notarize=true; fi
if [[ "${CLOCKELAPSED_RELEASE:-0}" == 1 ]] && { ! $notarize || [[ "$signing_identity" == - ]]; }; then
  echo 'Official releases require Developer ID signing and notarization credentials.' >&2
  exit 1
fi
./build.sh
if $notarize; then
  mkdir -p output/notary
  ditto -c -k --sequesterRsrc --keepParent output/ClockElapsed.app output/notary/payload.zip
  ./Tools/notarize.sh output/notary/payload.zip output/notary/payload
  watcher="$PWD/output/ClockElapsed.app/Contents/Library/LoginItems/ClockElapsedWatcher.app"
  xcrun stapler staple "$watcher"
  xcrun stapler validate "$watcher"
  xcrun stapler staple output/ClockElapsed.app
  xcrun stapler validate output/ClockElapsed.app
  spctl --assess --type execute --verbose=2 output/ClockElapsed.app
fi
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
if $notarize; then
  ditto -c -k --sequesterRsrc --keepParent "$installer" output/notary/installer.zip
  ./Tools/notarize.sh output/notary/installer.zip output/notary/installer
  xcrun stapler staple "$installer"
  xcrun stapler validate "$installer"
  spctl --assess --type execute --verbose=2 "$installer"
fi
cp LICENSE "$stage/License.txt"
cp Installer/Read-me.txt "$stage/Read me first.txt"
cp Installer/请先阅读.txt "$stage/请先阅读.txt"
archive="$PWD/output/releases/ClockElapsed-$version-universal.zip"
dmg="$PWD/output/releases/ClockElapsed-$version-universal.dmg"
rm -f "$archive" "$dmg"
hdiutil create -quiet -volname 'Clock Elapsed' -srcfolder "$stage" -format UDZO "$dmg"
if [[ "$signing_identity" != - ]]; then codesign --force --sign "$signing_identity" "$dmg"; fi
# Validate every layer, including the final distribution container.
if $notarize; then
  ./Tools/notarize.sh "$dmg" output/notary/dmg
  xcrun stapler staple "$dmg"
  xcrun stapler validate "$dmg"
  spctl --assess --type open --context context:primary-signature --verbose=2 "$dmg"
fi
ditto -c -k --sequesterRsrc --keepParent "$stage" "$archive"
(cd output/releases && shasum -a 256 "${dmg:t}" "${archive:t}" > SHA256SUMS.txt)
echo "$dmg"
echo "$archive"
