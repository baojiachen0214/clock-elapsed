# Security policy

Clock Elapsed runs locally and requests Accessibility access. Treat that permission as sensitive even though this implementation limits its reads and navigation to Apple Clock. There is no network client, telemetry or update service in the app.

## Report privately

Please use [GitHub's private vulnerability reporting form](https://github.com/baojiachen0214/clock-elapsed/security/advisories/new) for security concerns. Include affected versions, impact and minimal reproduction steps. Do not publish credentials, personal diagnostics or an exploit in a public issue.

The latest default-branch source is the maintained version during this early preview. There is no response-time guarantee or security audit claim. Ordinary display and synchronization bugs belong in public issues.

## Distribution

The source and Developer ID signed preview installers are available. The current binary preview is not Apple-notarized. Local builds are ad-hoc signed unless you supply your own signing identity. Do not disable macOS security globally to run a build. See [setup](docs/SETUP.md) for the intended installation and signing flow.
