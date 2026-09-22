# Contributing

Use an issue and short-lived branch for an independently reviewable change. Preserve the original
history and repository URL. Run `node scripts/verify.mjs` before a PR and record exact tools/results.

Distinguish static, unit, mocked-native, browser/CEF, actual FiveM and multiplayer tests. Do not call
mock success runtime compatibility, performance validation or stable readiness. Runtime changes need
relevant `docs/VALIDATION.md` cases exercised against a recorded artifact/game-build combination.

Do not commit credentials, server configuration, player data, databases, logs, binaries, third-party
vehicle assets, local backups or toolchains. Keep source, development runtime and production separate.
Avoid unrelated formatting and history rewrites.

Maintainers must resolve licensing before accepting contributions under an assumed license.
Security-sensitive reports belong in a private channel as described in `SECURITY.md`.
