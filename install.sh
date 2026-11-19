#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
app_path="$HOME/Applications/ClockElapsed.app"
agent_path="$HOME/Library/LaunchAgents/local.clockelapsed.watcher.plist"
user_id="$(id -u)"
[[ -x output/ClockElapsed.app/Contents/MacOS/ClockElapsed ]] || { echo 'Build the app first.' >&2; exit 1; }
launchctl bootout "gui/$user_id/local.clockelapsed.watcher" 2>/dev/null || true
pkill -x ClockElapsed 2>/dev/null || true
mkdir -p "$HOME/Applications" "$HOME/Library/LaunchAgents"
ditto output/ClockElapsed.app "$app_path"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$app_path"
python3 - "$app_path" "$agent_path" <<'PY'
import plistlib, sys
from pathlib import Path
app, destination = sys.argv[1:]
with open(destination, 'wb') as output:
    plistlib.dump({
        'Label': 'local.clockelapsed.watcher',
        'ProgramArguments': [str(Path(app) / 'Contents/Library/LoginItems/ClockElapsedWatcher.app/Contents/MacOS/ClockElapsedWatcher')],
        'RunAtLoad': True,
        'KeepAlive': True,
        'ProcessType': 'Background',
        'ThrottleInterval': 10,
    }, output)
PY
launchctl enable "gui/$user_id/local.clockelapsed.watcher"
launchctl bootstrap "gui/$user_id" "$agent_path"
echo "$app_path"
