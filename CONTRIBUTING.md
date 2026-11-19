# Contributing

Thanks for helping make Clock's stopwatch easier to glance at. Keep changes focused on its role as a companion to Apple Clock.

## Before a pull request

1. Describe the user-visible problem. Include your macOS version, processor, system language and display scale for compatibility or rendering reports.
2. Keep Stopwatch as the source of truth. Never add automatic start, pause or reset actions to Clock.
3. Run `./test.sh` and `./build.sh`. For rendering changes, also run `./test-layout.sh` and inspect the light/dark images in `output/`.
4. Explain the resulting behavior and validation. Include before/after captures for UI changes, with personal information removed.

## Project conventions

- Use public macOS APIs, with bounded Accessibility reads off the main thread.
- Preserve the quiet menu bar experience: no unsolicited windows, menus or permission prompts.
- Keep user-facing strings in `Resources/en.lproj/Localizable.strings` and `Resources/zh-Hans.lproj/Localizable.strings`; update both when adding a key. Keep `README.md` and `README.zh-CN.md` aligned for user-visible changes.
- Test parsing, pause/resume, stale-source recovery and hour boundaries when changing synchronization.
- For performance claims, describe the state measured, duration, tool and hardware. Compare steady operation and animation after warmup, including the watcher; a startup memory snapshot is not a running peak or evidence of no leaks.
- Do not commit builds, diagnostics, signing material, credentials or personal screenshots. Never exercise sleep, reset timers or change a contributor's Clock state without their agreement.

The app uses Swift with AppKit/SwiftUI; the event-driven watcher uses Objective-C with ARC. No third-party runtime dependencies are required.

## Reporting issues

Use a bug report for reproducible issues or a feature request for proposals. English and Simplified Chinese are welcome. Share only the smallest relevant diagnostic excerpt. Report security concerns privately as described in [SECURITY.md](SECURITY.md).

Contributions are provided under the project's [MIT license](LICENSE).
