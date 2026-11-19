#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
mkdir -p output
xcrun swiftc Sources/ElapsedTime.swift Sources/ElapsedAnchor.swift Sources/ClockSnapshot.swift Sources/StopwatchSync.swift Sources/ClockLifecycle.swift Tests/main.swift -o output/ElapsedTimeTests
output/ElapsedTimeTests
