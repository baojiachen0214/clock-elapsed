#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
app_path="$PWD/output/ClockElapsed.app"
watcher_path="$app_path/Contents/Library/LoginItems/ClockElapsedWatcher.app"
signing_identity="${CLOCKELAPSED_SIGNING_IDENTITY:--}"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
xcrun swiftc -O -whole-module-optimization -target "$(uname -m)-apple-macos14.0" \
  -framework AppKit -framework ApplicationServices -framework SwiftUI Sources/*.swift \
  -o "$app_path/Contents/MacOS/ClockElapsed"
mkdir -p "$watcher_path/Contents/MacOS"
xcrun clang -O2 -fobjc-arc -target "$(uname -m)-apple-macos14.0" \
  -framework AppKit -framework Foundation Watcher/main.m \
  -o "$watcher_path/Contents/MacOS/ClockElapsedWatcher"
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
