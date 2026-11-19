#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
mkdir -p output
xcrun swiftc -O -framework AppKit -framework SwiftUI \
  Sources/NativeTitleRoller.swift Tests/Layout/main.swift -o output/LayoutTests
output/LayoutTests
