# Validation evidence and release gates

## Recorded local run: 2026-09-22

- Lua **5.4.9**, locally compiled from the upstream source release.
- Source SHA-256: `2335b6c582a52654f94612bf10d2f4672805d05329aa6568b1d8cd9e5c6fb8e6`, matched against https://www.lua.org/ftp/.
- Node.js **v24.15.0**, Windows x64.
- Command: `node scripts/verify.mjs`, with `LUA_BIN` selecting that interpreter.
- **83 Lua tests passed; 0 failed.** Includes manifest/syntax and mocked client/server lifecycle checks.
- **32 JavaScript tests passed; 0 failed.** Includes DOM-message validation, stale-state recovery and audio failures.
- One policy test sweeps 2,501 deterministic speed/distance pairs, not 2,501 in-game tests.
- One pending-query test attempts 10,000 starts and verifies just one handle allocation.

Three regressions found in the first local run were fixed before publication and retained as tests:
invalid data at standstill, speed updates after switching vehicles, and sensor work after disabling assistance.

Additional review added tests for stationary obstructions, interrupted tasks, pause/focus transitions,
native failures, ped changes, non-finite values, heartbeat bounds and a suspended audio context.

GitHub Actions runs the same command on Ubuntu 24.04 with distribution Lua 5.4 and runner-provided Node.
Concrete CI versions/results belong to the workflow run. Local success does not imply remote CI success.

## Native FXServer lifecycle run: 2026-09-22

- Windows 10.0.26100.33158.
- FXServer Windows artifact **35245**.
- cfx-server-data commit 32d98e7524b952faf8b220d719615b0346b0a6cc.
- Resource archive from PR #3 commit 7cc422ad5d4d35ef6db32b7245adc4f2e773708e.
- Loopback-only test endpoint: 127.0.0.1:30129.
- Cfx license authentication succeeded.
- Clean server bootstrap created the nge_autodrive script environment and started 2.0.0-dev.1.
- Restricted console status command returned the expected factory-only state.
- Explicit restart nge_autodrive passed three consecutive clean cycles after configuration cleanup.
- Explicit stop/start passed; info.json reported the resource absent while stopped and present after start.
- The obsolete set onesync off test-config line was removed after artifact 35245 warned that onesync is an internal ConVar; the subsequent clean bootstrap had no Autodrive or configuration warning.
- No Autodrive stderr output or server-side resource error was observed in the recorded lifecycle checks.

This validates the server/resource lifecycle only. It does **not** validate a connected FiveM client, NUI/CEF,
vehicle natives, physical braking, routing, game input, network ownership migration or frame-time behaviour.
## What these results do not demonstrate

Mocks validate code decisions/expected calls, not the game engine. No live FiveM client session, actual
stopping distance, CEF visuals/audio, controller-device behaviour, multiplayer ownership migration,
artifact/game-build matrix or profiler baseline has been verified here. This preview is not approved
for production, stable release or compatibility certification.

## Required in-game acceptance

Record artifact version, game build, OneSync mode, operating systems, resource commit, model, input
device, commands, outcome and evidence. Do not mark a case passed without evidence.

| Gate | Expected outcome | Result |
| --- | --- | --- |
| FXServer resource lifecycle | Start/restart/stop without resource errors; endpoint state matches lifecycle | **Passed 2026-09-22** |
| Client lifecycle | HUD initializes/disappears; no stuck controls across restart/stop | Pending |
| Stock/custom models | Correct allowlist and bounds; unsupported models cannot engage | Pending |
| Remappable keyboard/controller | No chat/menu conflict; prompt manual takeover | Pending |
| Forward obstacle/vehicle | Correct warning/braking; no inadvertent reverse movement | Pending |
| Reverse obstacle/standstill | Correct reverse braking; no acceleration at standstill | Pending |
| Clear path after braking | Input releases; manual driving resumes normally | Pending |
| Slopes/curbs/walls/peds/clutter | Record misses/false positives and calibrate thresholds | Pending |
| Set-speed change | Actual task follows new speed | Pending |
| Traffic/detour/changed waypoint | Predictable interruption/arrival, no silent restart | Pending |
| Exit/seat swap/death/respawn/deletion | No leaked task, stale input or HUD | Pending |
| Control migration/other driving resource | No takeover, unrelated cancellation or contamination | Pending |
| Missing/stale sensor | Drive cancels; unavailable, never fabricated clear road | Pending |
| 720p/1080p/1440p/ultrawide CEF | Readable, unclipped HUD; no false camera claims | Pending |
| Optional audio | No event traffic, spam or autoplay runtime error | Pending |
| Idle/driving profiling | Actual CPU/frame cost recorded; no invented performance figures | Pending |

## Promotion

Keep the PR in draft until connected-client and gameplay smoke/lifecycle gates have evidence. Review the network surface,
task/control coexistence, UI and deliberate removals. Stable promotion additionally requires a licensing
decision, supported-runtime matrix and reproducible packaging.
