#!/bin/zsh
set -euo pipefail
user_id="$(id -u)"
launchctl bootout "gui/$user_id/local.clockelapsed.watcher" 2>/dev/null || true
# Only remove this project's own startup registration; keep the app and its data.
rm -f "$HOME/Library/LaunchAgents/local.clockelapsed.watcher.plist"
pkill -x ClockElapsed 2>/dev/null || true
