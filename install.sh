#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
validate_only=false
if [[ "${1:-}" == --validate ]]; then validate_only=true; shift; fi
source_app="${1:-$PWD/output/ClockElapsed.app}"
app_path="$HOME/Applications/ClockElapsed.app"
agent_path="$HOME/Library/LaunchAgents/local.clockelapsed.watcher.plist"
user_id="$(id -u)"
[[ -x "$source_app/Contents/MacOS/ClockElapsed" && -x "$source_app/Contents/Library/LoginItems/ClockElapsedWatcher.app/Contents/MacOS/ClockElapsedWatcher" ]] || { echo 'The app bundle is incomplete.' >&2; exit 1; }
codesign --verify --deep --strict "$source_app"
temporary_plist="$(mktemp -t clockelapsed-launchagent)"
trap 'rm -f "$temporary_plist"' EXIT
/usr/bin/plutil -create xml1 "$temporary_plist"
/usr/bin/plutil -insert Label -string local.clockelapsed.watcher "$temporary_plist"
/usr/bin/plutil -insert ProgramArguments -array "$temporary_plist"
/usr/bin/plutil -insert ProgramArguments.0 -string "$app_path/Contents/Library/LoginItems/ClockElapsedWatcher.app/Contents/MacOS/ClockElapsedWatcher" "$temporary_plist"
/usr/bin/plutil -insert RunAtLoad -bool YES "$temporary_plist"
/usr/bin/plutil -insert KeepAlive -bool YES "$temporary_plist"
/usr/bin/plutil -insert ProcessType -string Background "$temporary_plist"
/usr/bin/plutil -insert ThrottleInterval -integer 10 "$temporary_plist"
/usr/bin/plutil -lint "$temporary_plist"
if $validate_only; then echo 'Installer validation passed; no installation changed.'; exit 0; fi
launchctl bootout "gui/$user_id/local.clockelapsed.watcher" 2>/dev/null || true
pkill -x ClockElapsed 2>/dev/null || true
mkdir -p "$HOME/Applications" "$HOME/Library/LaunchAgents"
# ditto preserves code signatures and replaces the existing installation.
ditto "$source_app" "$app_path"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$app_path"
chmod 644 "$temporary_plist"
mv "$temporary_plist" "$agent_path"
launchctl enable "gui/$user_id/local.clockelapsed.watcher"
launchctl bootstrap "gui/$user_id" "$agent_path"
echo "$app_path"
