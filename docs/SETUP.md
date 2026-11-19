# Setup and troubleshooting

[English overview](../README.md) · [中文概览](../README.zh-CN.md)

## Requirements and installation

The deployment target is macOS 14.0. Current integration checks were performed on macOS 27.2.1, Apple silicon. Intel builds and other macOS releases need real-device verification, particularly Clock's Accessibility identifiers and navigation.

Install Xcode Command Line Tools if needed with `xcode-select --install`. Then run:

```sh
./test.sh
./build.sh
./install.sh
```

The compiler targets the current machine's architecture. The scripts do not build a universal binary. Build output is in `output/ClockElapsed.app`.

Installation copies the app to `~/Applications/ClockElapsed.app`, registers it with Launch Services, and creates `~/Library/LaunchAgents/local.clockelapsed.watcher.plist` for the current user. The nested Objective-C watcher receives Clock launch/quit notifications. It stays resident even when Clock is closed; the main companion does not.

## Accessibility permission

Allow the **installed** copy of Clock Elapsed in System Settings → Privacy & Security → Accessibility. Depending on macOS version/localization, that permission section may be named differently; the tested Chinese macOS 27 system calls it 设备控制和数据访问.

Use `open -g ~/Applications/ClockElapsed.app --args --setup` to explicitly request the system prompt. Automatic launches do not prompt. The app does not modify macOS's permission database.

If access remains unavailable after replacing a differently signed build, remove the old permission entry and add the installed app again. Rebuilding with ad-hoc signatures can change code identity. To keep a stable identity across your own builds, use a signing identity available in your keychain:

```sh
CLOCKELAPSED_SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)' ./build.sh
./install.sh
```

No signing identity, certificate or private key is included in the repository. Changing from ad-hoc signing to a stable identity may require granting access once more. These builds are not notarized.

## No readout

1. Confirm Clock is running and permission is granted to the installed app.
2. Open Clock's Stopwatch page and start or resume the stopwatch. A paused stopwatch at zero intentionally has no readout.
3. Leave Stopwatch visible briefly so the reader can establish fresh advancing samples. A fresh companion launch cannot reconstruct a running stopwatch from a frozen Accessibility value.
4. If permissions are correct but the source stays unavailable, include your macOS version and system language in a bug report. Clock may have changed its exposed interface.

## Position, appearance and synchronization

Hold Command and drag the menu bar item to place it next to Clock's countdown. Their spacing remains controlled by macOS. The companion preserves its status-item autosave name across launches.

The readout uses whole seconds, system typography, separate fixed-width digit columns and the system numeric transition. A standalone colon has a small optical adjustment to match Clock's numerical punctuation. Reduced Motion disables transitions. Menu bar background appearance determines light/dark ink.

Closing Clock's window keeps the app running. Quitting Clock stops the main companion. Switching away from Stopwatch can freeze the source value; the companion continues locally only after synchronization and recalibrates when fresh readings return. Changes through Siri or other paths cannot be detected while the source is stale.

A continuous-time anchor is designed to account for sleep. Real sleep/wake integration testing remains outstanding; elapsed-time unit tests alone do not establish that behavior end to end.

## Optional diagnostics

Diagnostics are off by default. Quit the main companion only (leave Clock running), then launch a diagnostic instance directly:

```sh
pkill -x ClockElapsed
~/Applications/ClockElapsed.app/Contents/MacOS/ClockElapsed --diagnostics /tmp/clockelapsed-samples.jsonl
```

The file contains source time/state, readout, width and appearance metadata. Review and trim it before sharing. Do not start multiple diagnostic instances. Stop the diagnostic instance and open the installed app normally when finished.

## Remove

Run `./uninstall.sh` to stop the companion and remove its LaunchAgent registration. It keeps the installed app. To remove the app as well, delete `~/Applications/ClockElapsed.app` in Finder. Accessibility permission entries can be removed separately in System Settings. No system Clock data is changed.
