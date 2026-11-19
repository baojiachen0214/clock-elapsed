# Setup and troubleshooting

[English overview](../README.md) · [中文概览](../README.zh-CN.md)

## Download the installer

The [latest Release](https://github.com/baojiachen0214/clock-elapsed/releases) provides a universal `.dmg` and a ZIP alternative. Open the disk image (or unzip), double-click **Install Clock Elapsed.app**, and click Install. The native installer uses the same per-user setup as `install.sh`, with no Xcode, Python, terminal commands or administrator password required. It does not change Clock's timers. Download checksums are published alongside the assets.

Official v0.2.2 downloads are Developer ID signed and Apple-notarized. The payload, installer and disk image are notarized in sequence, with tickets attached and Gatekeeper assessments checked. macOS can still ask you to confirm opening an Internet download; Accessibility access requires a separate one-time user grant. The old v0.2.1 preview was not notarized.

## Requirements and source installation

The deployment target is macOS 14.0. Current integration checks were performed on macOS 27.2.1, Apple silicon. Intel builds and other macOS releases need real-device verification, particularly Clock's Accessibility identifiers and navigation.

Install Xcode Command Line Tools if needed with `xcode-select --install`. Then run:

```sh
./test.sh
./build.sh
./install.sh
```

The compiler targets the current machine's architecture by default. `CLOCKELAPSED_ARCHS='arm64 x86_64' ./build.sh` builds a universal binary. Build output is in `output/ClockElapsed.app`.

Installation copies the app to `~/Applications/ClockElapsed.app`, registers it with Launch Services, and creates `~/Library/LaunchAgents/local.clockelapsed.watcher.plist` for the current user. The nested Objective-C watcher receives Clock launch/quit notifications. It stays resident even when Clock is closed; the main companion does not.

## Accessibility permission

Allow the **installed** copy of Clock Elapsed in System Settings → Privacy & Security → Accessibility. Depending on macOS version/localization, that permission section may be named differently; the tested Chinese macOS 27 system calls it 设备控制和数据访问.

Use `open -g ~/Applications/ClockElapsed.app --args --setup` to explicitly request the system prompt. Automatic launches do not prompt. The app does not modify macOS's permission database.

If access remains unavailable after replacing a differently signed build, remove the old permission entry and add the installed app again. Rebuilding with ad-hoc signatures can change code identity. To keep a stable identity across your own builds, use a signing identity available in your keychain:

```sh
CLOCKELAPSED_SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)' ./build.sh
./install.sh
```

No signing identity, certificate or private key is included in the repository. Changing from ad-hoc signing to a stable identity may require granting access once more. Local builds are not notarized unless you configure the notarization workflow below.

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

## Build a release

`./package.sh` builds universal main, watcher and native installer binaries, then creates DMG/ZIP assets and `SHA256SUMS.txt` in `output/releases`. Use your own Developer ID Application signing identity and notarytool credentials for distribution. Credentials are never bundled or stored in source.

```sh
CLOCKELAPSED_SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)' \
CLOCKELAPSED_NOTARY_PROFILE='your-keychain-profile' \
CLOCKELAPSED_RELEASE=1 ./package.sh
```

Alternatively, supply `CLOCKELAPSED_NOTARY_KEY` (a local API key path), `CLOCKELAPSED_NOTARY_KEY_ID`, and `CLOCKELAPSED_NOTARY_ISSUER` for a team key. Individual API keys omit the issuer. Keep the private key outside the repository.

Official release mode refuses to run without both a signing identity and notarization credentials. `Tools/notarize.sh` requires Apple's `Accepted` verdict and saves receipts/logs only in ignored `output/notary/`. The pipeline notarizes and staples the payload first, then the installer, then the final DMG; each stage validates tickets and Gatekeeper acceptance. Without credentials, packaging creates a development archive, not an official notarized release.

`./install.sh --validate output/ClockElapsed.app` checks the signature and generated LaunchAgent plist without changing the installation.
