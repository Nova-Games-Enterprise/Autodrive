# Validation and release gates

## Evidence levels

1. **Implemented**: code exists and has been reviewed.
2. **Automated**: named tests ran, with command/version/commit recorded.
3. **Runtime verified**: exercised in an identified FiveM/GTA setup.

These levels are not interchangeable. No runtime result is recorded yet for the
recovery. The original prototype is not retrospectively certified by new tests.

## Automated baseline to establish

- Lua syntax and configuration/manifest consistency.
- Signed direction: rear detection cannot activate forward braking merely
  because an overlay or camera was requested.
- Pending/invalid/completed shape tests, stale samples and bounded handles.
- Cruise changes reach the active task; manual override never auto-resumes.
- Resource-owned braking releases on normal, fault, exit and resource-stop paths.
- Unknown NUI messages, non-finite values and unexpected types are rejected.
- No network installation handler is registered while installation is disabled.

## Required in-game acceptance matrix

Record FXServer artifact, GTA build/edition, client build, OneSync mode, operating
system, resource commit, vehicle model and framework/inventory versions, if any.

| Scenario | Required observation | Result |
| --- | --- | --- |
| Start/stop/restart resource | No stuck brakes, camera, tasks or overlay | Not run |
| Driver to passenger / exit / death | Assistance cancels and owned controls release | Not run |
| Vehicle replacement / ownership migration | No control of another player's vehicle | Not run |
| Forward / reverse / stopped | Only direction-appropriate obstacle decisions | Not run |
| World wall / vehicle / ped / object | Expected detection without entity-only assumptions | Not run |
| Slow / fast / uneven road | No false assurance from limited sensor range | Not run |
| Waypoint set/change/remove/arrival | Explicit transitions and cancellation | Not run |
| Keyboard / controller | Rebindable actions; predictable manual override | Not run |
| 16:9 / ultrawide / 4K | Readable, correctly hidden overlay | Not run |
| Audio unavailable | Silent fallback without errors or network requests | Not run |
| Multiple players / routing buckets | No cross-player or cross-bucket writes | Not run |
| Profiler idle / driving / obstacle | Record CPU, frame and network observations | Not run |

Mock tests cannot prove braking physics, GTA pathfinding, camera behavior,
collision completeness, network ownership behavior or framework compatibility.
