# Security review

Review date: 2026-08-27

Upstream reviewed: `alexalok/opencodex_tray` at
`0e822ca92ecf908b2881c42b5f42a3124e44dc01`.

## Scope

The review covered every tracked source and build file, Swift package metadata,
bundled resources, commit history, runtime-linked libraries, code-signing
metadata, and observed network connections from a local build.

## Upstream findings

- No analytics, telemetry, crash reporter, updater, advertising SDK, or
  third-party Swift package dependency was present.
- The normal local build was offline. `NOTARIZE=1` explicitly submits the
  archive to Apple's notarization service.
- Launch at login used `SMAppService.mainApp` and was opt-in through the UI.
- Runtime networking used the configured OpenCodex management API only.
- Upstream allowed an arbitrary remote HTTPS management URL, which could send
  the OpenCodex admin bearer token off-machine when configured that way.
- Upstream was not read-only: a refresh could send `PUT
  /api/codex-auth/accounts/pause` after an account crossed a configured
  threshold.

## Hardening in this fork

- Management URLs are restricted to loopback hosts.
- HTTP redirects are rejected.
- URL sessions are ephemeral with cookies, credential storage, and caching
  disabled.
- All account mutation code was removed. Runtime API calls are GET-only.
- The required target-account alias was removed so all pooled accounts can be
  displayed without introducing a mutation selector.

## Verification

- Swift unit tests, build-script tests, and release-artifact tests pass.
- The built app is ad-hoc signed with no custom entitlements.
- The binary links only Apple system frameworks and Swift runtime libraries.
- Runtime observation showed connections only to `127.0.0.1:10100`, the local
  OpenCodex proxy.

## Residual trust boundary

The app reads the local OpenCodex admin token into process memory and trusts
responses from the loopback OpenCodex proxy. A malicious process already
running as the same macOS user can ordinarily read the token file directly and
is outside this app's protection boundary. Local builds are ad-hoc signed; use
the documented Developer ID/notarization path before distributing binaries to
other users.

This is a focused source and runtime review, not a formal penetration test or a
guarantee that the software is vulnerability-free.
