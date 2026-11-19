# Architecture

Clock Elapsed complements Apple's Clock with an elapsed-time readout. It owns no independent stopwatch controls and uses public macOS APIs.

## Components

| Component | Responsibility |
| --- | --- |
| `Watcher/main.m` | Objective-C/ARC process receiving Clock lifecycle notifications; opens or closes the main companion. |
| `Sources/ClockReader.swift` | Bounded, off-main-thread Accessibility discovery and sampling; navigation to Stopwatch on a user click. |
| `Sources/StopwatchSync.swift` | Establishes fresh running samples and distinguishes stale-source continuation. |
| `Sources/ElapsedAnchor.swift` | Continuous-time anchor used for local continuation. |
| `Sources/ClockSnapshot.swift` | Separates synchronized values from projected values. |
| `Sources/ElapsedTime.swift` | Parses localized duration labels and formats truncated whole seconds. |
| `Sources/NativeTitleRoller.swift` | One persistent horizontal symbol/text row, fixed digit columns and SwiftUI numeric transitions. |
| `Sources/main.swift` | Status item, lifecycle observations, boundary-aligned local updates and optional diagnostics. |

## Reading and continuation

The reader looks for Clock's `stopwatch-time` and `StartStopButton` Accessibility identifiers. It reads only Clock's interface. Clicking the companion may select the Stopwatch tab or its View menu command; it never invokes start, pause, reset or lap actions.

Reads occur on a utility queue once a second while Clock is active and every three seconds in the background. Cached elements are rediscovered periodically, invalid values trigger recovery, tree discovery has node/time bounds, and Accessibility messaging has a timeout. Repeated source strings reuse parsing results.

Fresh synchronized readings are not extrapolated between samples, preventing an ordinary pause from first showing a rounded-up second and then going backward. When Clock stops publishing advancing readings, an established running anchor can continue locally. Changes not yet exposed by Clock cannot be inferred. The next fresh source reading recalibrates the anchor.

## Rendering and lifecycle

`NSStatusBarButton` owns the click target and Accessibility label. A child hosting view fills the button bounds and draws one fixed horizontal row. Both the template symbol and text share neutral ink; the hosting view disables vibrant compositing. Digit identities are anchored from the right, preserving seconds columns as hours gain digits. Punctuation shares a text baseline with a small optical correction for the standalone SF colon.

Only consecutive one-second increments animate; jumps and reduced-motion updates settle immediately. Geometry changes only when the formatted length changes. Local continuation schedules a one-shot timer at the next elapsed-second boundary rather than a display loop.

The view is reused during display and released when the readout hides. Termination cancels timers, stops the reader and removes observers/status items. The watcher uses autorelease pools around events, owns no NSApplication or polling timer, and sleeps in its run loop between workspace notifications.

## Validation boundaries

`./test.sh` checks duration parsing, Unicode decimal digits, truncation, synchronization, frozen-source bootstrap, pause behavior, app lifecycle decisions and expanding hour boundaries. `./test-layout.sh` renders the production row in both color schemes at short, hour and three-digit-hour lengths for visual review.

These checks do not grant Accessibility access, start/stop Clock's timers, test a real sleep/wake cycle, prove cross-version compatibility, establish pixel identity with Apple's private implementation, or prove the absence of leaks. Resource measurements must include warm animation and extended operation, not just startup. AppKit/SwiftUI have a baseline memory cost.

## Assets and provenance

The app icon is drawn with AppKit paths by `Tools/make-icon.swift`; `docs/assets/app-icon.png` is an export of that source. The menu bar symbol is SF Symbols' `stopwatch`, supplied by macOS at runtime. No Apple Clock application artwork, third-party libraries or upstream Tock source is bundled. Build products, local diagnostics and signing materials are excluded from version control. `Installer/main.swift` provides a transient native setup dialog; it runs the bundled `install.sh` against the embedded app. `package.sh` creates universal signed DMG/ZIP distributions. The installer is separate from the windowless companion.

The legacy `local.clockelapsed.prototype` bundle identifier is retained so local updates preserve the existing installation's permissions and menu bar position.
