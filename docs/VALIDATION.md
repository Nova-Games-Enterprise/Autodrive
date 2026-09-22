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

## What these results do not demonstrate

Mocks validate code decisions/expected calls, not the game engine. No live FiveM/FXServer session, actual
stopping distance, CEF visuals/audio, controller-device behaviour, multiplayer ownership migration,
artifact/game-build matrix or profiler baseline has been verified here. This preview is not approved
for production, stable release or compatibility certification.

## Required in-game acceptance: all pending

Record artifact version, game build, OneSync mode, operating systems, resource commit, model, input
device, commands, outcome and evidence. Do not mark a case passed without evidence.

| Gate | Expected outcome | Result |
| --- | --- | --- |
| Start/restart/stop | No console errors; HUD initializes/disappears; no stuck controls | Pending |
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

Keep the PR in draft until native smoke/lifecycle gates have evidence. Review the network surface,
task/control coexistence, UI and deliberate removals. Stable promotion additionally requires a licensing
decision, supported-runtime matrix and reproducible packaging.
