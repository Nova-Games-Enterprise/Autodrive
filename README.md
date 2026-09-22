# NGE Autodrive

Vehicle-assistance experiments for FiveM, maintained by **Nova Games Enterprise**.
Original implementation by **Bacasuoro**.

> **Recovery in progress, September 2026.** This is the original Autodrive
> repository, not a replacement or a fork. The historical prototype is being
> rebuilt in small, reviewable increments. It is **not a production-ready release**.

## Current status

The 2025 prototype contains waypoint driving, forward/rear obstacle checks,
a small NUI overlay and an experimental mechanic-installable module.
The old "rear camera" is a guide-line overlay, not an implemented camera.

The recovery starts with [issue #1](https://github.com/Nova-Games-Enterprise/Autodrive/issues/1):
security boundaries, lifecycle handling, testable driving policies and regression tests.
Work stays in this repository and preserves its original history and links.

**Do not deploy the historical module-installation events on a public server.**
They do not establish a trustworthy vehicle identity or persist installations.
The first recovery increment retires that path until a server-validated,
persistent workflow is implemented and tested.

## Direction

| Area | Recovery target |
| --- | --- |
| Driving core | Framework-independent policies with explicit activation and cancellation |
| Sensors | Bounded asynchronous queries, direction-aware decisions, stale-data handling |
| Vehicle lifecycle | Release only controls owned by this resource; clean up on exit and stop |
| UI and sound | Local-only feedback, bounded updates, no external assets or sensor network traffic |
| Installation | Server authority, stable identity, inventory transactions and persistence before re-enabling |
| Integrations | Separately tested adapters rather than assumed ESX/QB/Qbox compatibility |
| Public releases | Reproducible checks, recorded in-game results, documented limitations |

See the [roadmap](docs/ROADMAP.md), [validation gates](docs/VALIDATION.md) and
[security model](SECURITY.md). A checked-in feature or a passing mock test is
not evidence that the feature works in the game runtime.

## Scope and claims

Autodrive is a **game resource**, not automotive safety software or a replacement
for FiveM anti-cheat. Its waypoint driving relies on GTA/FiveM driving tasks.
No HELIX runtime integration or compatibility is currently claimed.

The historical `README_ADAS.txt` describes the prototype; it is not a current
installation or compatibility guarantee. There is no stable 2.x release yet.

## Contributing

Please start with an issue describing the expected behavior and a reproducible
test. Keep changes focused, include regression coverage and distinguish native
runtime observations from mock results. Avoid publishing exploit payloads or
server credentials. See [SECURITY.md](SECURITY.md).

## Licensing

A project license has not yet been selected by the NGE maintainers.
This recovery does not add a license or change existing authorship.
