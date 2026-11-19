#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
app_path="$PWD/output/ClockElapsed.app"
watcher_path="$app_path/Contents/Library/LoginItems/ClockElapsedWatcher.app"
signing_identity="${CLOCKELAPSED_SIGNING_IDENTITY:--}"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
architecture_list="${CLOCKELAPSED_ARCHS:-$(uname -m)}"
architectures=(${=architecture_list})
main_binaries=()
watcher_binaries=()
mkdir -p output/bin
for architecture in $architectures; do
  xcrun swiftc -O -whole-module-optimization -target "$architecture-apple-macos14.0" \
    -framework AppKit -framework ApplicationServices -framework SwiftUI Sources/*.swift \
    -o "output/bin/ClockElapsed-$architecture"
  main_binaries+=("output/bin/ClockElapsed-$architecture")
done
xcrun lipo -create $main_binaries -output "$app_path/Contents/MacOS/ClockElapsed"
mkdir -p "$watcher_path/Contents/MacOS"
for architecture in $architectures; do
  xcrun clang -O2 -fobjc-arc -target "$architecture-apple-macos14.0" \
    -framework AppKit -framework Foundation Watcher/main.m \
    -o "output/bin/ClockElapsedWatcher-$architecture"
  watcher_binaries+=("output/bin/ClockElapsedWatcher-$architecture")
done
xcrun lipo -create $watcher_binaries -output "$watcher_path/Contents/MacOS/ClockElapsedWatcher"
cp Resources/Watcher-Info.plist "$watcher_path/Contents/Info.plist"
cp Resources/Info.plist "$app_path/Contents/Info.plist"
cp -R Resources/en.lproj Resources/zh-Hans.lproj "$app_path/Contents/Resources/"
if [[ ! -f Resources/AppIcon.icns || Tools/make-icon.swift -nt Resources/AppIcon.icns ]]; then
  xcrun swift Tools/make-icon.swift output/AppIcon.iconset
  iconutil -c icns output/AppIcon.iconset -o Resources/AppIcon.icns
fi
cp Resources/AppIcon.icns "$app_path/Contents/Resources/"
codesign --force --options runtime --sign "$signing_identity" --identifier local.clockelapsed.watcher "$watcher_path"
codesign --force --options runtime --sign "$signing_identity" --identifier local.clockelapsed.prototype "$app_path"
echo "$app_path"
