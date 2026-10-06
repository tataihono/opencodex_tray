<p align="center">
  <img src="assets/app-icon.png" width="160" alt="OpenCodex Quota Tray icon">
</p>

# OpenCodex Quota Tray

Native macOS 14+ menu-bar app. Polls a local OpenCodex instance and shows
Codex and Claude pool allowances. It also includes a native macOS desktop and
Notification Center widget. This fork is deliberately read-only: it does not
switch, pause, add, or remove accounts.

[OpenCodex](https://github.com/lidge-jun/opencodex) is a local proxy that
multiplexes several Codex and Claude accounts behind one endpoint and tracks
their quota usage. This app sits in the macOS menu bar, polls that proxy, and
turns its per-account quota data into at-a-glance pool totals.

![Menu-bar dropdown showing Codex and Claude pool percentages with per-account rows](assets/tray-screenshot.png)

## Quota math

Every account has `100` native allowance. Display converts all values to
Pro-equivalent units: `pro = 1`, `prolite = 0.25` because one Pro percentage
point equals four ProLite percentage points.

```text
native remaining = max(native allowance - weekly usage, 0)
Pro-equivalent value = native value * plan factor
tray = floor(sum(Pro-equivalent remaining))
```

Example:

```text
main (Pro): 92%/100%
backup (Pro): 100%/100%
tray: floor(92 + 100) = 192%
```

Tray total represents absolute Pro-equivalent allowance, not ratio. Multiple
accounts can therefore produce values above `100%`.

Missing weekly quota or unknown plan displays `—` and makes tray total `—`
rather than inventing capacity.

Claude converts OpenCodex's raw per-account Anthropic utilization to remaining
allowance. No plan conversion is applied:

```text
Claude remaining = max(100 - usage, 0)
Claude row = 5-hour remaining / 1-week remaining
Claude tray = floor(sum(5-hour remaining)) / floor(sum(1-week remaining))
```

For example, `3%` 5-hour utilization and `12%` weekly utilization displays as
`97%/88%`. Like Codex, each Claude pool total is absolute across accounts and
can exceed `100%`. A missing window displays `—` in only that slot.

## Configure

Finder-launched apps do not reliably inherit shell environment. Create:

```text
~/.config/opencodex-quota-tray/config.json
```

No configuration file is required for a standard local OpenCodex installation.
To change the refresh interval, for example:

```json
{ "pollIntervalMS": 60000 }
```

Environment variables remain supported and override config-file values.

Optional env:

| Variable | Default |
| --- | --- |
| `POLL_INTERVAL_MS` | `60000` |
| `REQUEST_TIMEOUT_MS` | `30000` |
| `OPENCODEX_BASE_URL` | `http://127.0.0.1:10100` |
| `OPENCODEX_HOME` | `$HOME/.opencodex` |

The admin token is read once from
`${OPENCODEX_HOME:-$HOME/.opencodex}/admin-api-token`.

The widget supports the standard local installation only:
`http://127.0.0.1:10100` with the token at
`~/.opencodex/admin-api-token`. The tray app continues to support the optional
configuration above.

## Add the widget

Launch `OpenCodexTray.app` once, then right-click the desktop or an existing
widget and choose **Edit Widgets**. Search for **OpenCodex** and add either the
small overview or medium per-account widget. WidgetKit refreshes on its own
timeline, and the running tray app requests a refresh whenever displayed Codex
quota changes.

## Security boundary

- OpenCodex must be on a loopback host (`localhost`, `127.0.0.0/8`, or `::1`).
- HTTP redirects are rejected, so the bearer token cannot follow a redirect to
  another origin.
- The URL session is ephemeral with cookies, credential storage, and caching
  disabled.
- Runtime requests are limited to read-only account/quota endpoints.
- The widget extension is sandboxed. It has outbound network access and a
  read-only exception limited to `~/.opencodex/admin-api-token`; the same
  loopback-only client and GET-only quota endpoint are used.
- There are no analytics, telemetry, update checks, or third-party Swift
  package dependencies.
- `NOTARIZE=1` is the only build mode that contacts an external service; it
  submits the built archive to Apple's notarization service. Normal local builds
  do not do this.

## Develop

```bash
swift test
swift run OpenCodexTray
```

Headless single check:

```bash
swift run pause-worker-once
```

GitHub CI runs `swift test`, the offline build-script regression suite and
`tests/release-artifact-tests.sh` on pull requests and pushes to `main`, using
the macOS 26 runner and its Xcode toolchain (Swift 6.2 or newer is required by
`Package.swift`). Artifact checks compile the tray and widget, verify embedded
resources and validate the ad-hoc widget signature. The resource-only launch
exits before configuration, token loading or polling.

CI uses no live OpenCodex instance, account token, signing identity or Apple
notarization profile. Signing/notarization branches in the shell regression
suite use fake tools; the real artifact build uses `NOTARIZE=0`. Widget gallery
installation and live quota refresh remain manual acceptance checks.

## Build app

Local builds use an ad-hoc signature and do not contact Apple:

```bash
./scripts/build-app.sh
open dist/OpenCodexTray.app
```

Trusted direct distribution requires the local Developer ID identity and a
one-time Notary service Keychain profile:

```bash
xcrun notarytool store-credentials "YOUR_NOTARY_PROFILE" \
  --apple-id "YOUR_APPLE_ACCOUNT" \
  --team-id "YOUR_TEAM_ID"
```

Enter an app-specific password when prompted. Copy `.env.example` to `.env`
and replace its placeholders with your local signing identity and Keychain
profile. `.env` is ignored by Git.

The build reads only `SIGNING_IDENTITY` and `NOTARY_PROFILE` from `.env` as
literal values; it does not execute the file as shell code.

```bash
cp .env.example .env
NOTARIZE=1 ./scripts/build-app.sh
```

This signs, notarizes, staples, and verifies the release. The distributable
artifact is `dist/OpenCodexTray.zip`. Environment variables override values
loaded from `.env`.

Tray title shows Claude icon + remaining Claude pool `5h/1w` allowance, then
Codex icon + Pro-equivalent Codex pool percentage and nearest reset. Click it for separate
`Codex Pool` and `Claude Pool (5h/1w)` sections with per-account rows,
`Refresh Now`, errors, and `Quit`. `Launch at Login` registers the app through
macOS Service Management. If macOS requires approval, use
`Open Login Items Settings` from the tray menu. App has no Dock icon.

## License

MIT, see [LICENSE](LICENSE).

Bundled CodexBar provider icons are MIT-licensed by Peter Steinberger, see
[Sources/OpenCodexTray/Resources/CodexBar-LICENSE.txt](Sources/OpenCodexTray/Resources/CodexBar-LICENSE.txt).
