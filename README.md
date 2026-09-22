# NGE Autodrive

**A vehicle-assistance project for FiveM, maintained by Nova Games Enterprise.**

> **Recovery preview: `2.0.0-dev.1`. Not a stable release.**
> This branch rebuilds the 2025 prototype around explicit safety boundaries and regression tests.
> Automated tests exercise policy and mocked native contracts. FiveM driving, braking, visuals,
> network behaviour and framework coexistence have **not yet passed in-game acceptance**.

## What is in this preview?

| Component | Implemented scope | Verification boundary |
| --- | --- | --- |
| Waypoint drive | GTA driving task, live set-speed updates, cancellation, arrival and stall handling | Lua tests and native-call mocks; in-game behaviour pending |
| Collision assistance | Direction-aware forward/reverse probes, warning/brake requests, stale-result handling | Policy and mocked lifecycle tests; calibration and stopping behaviour pending |
| Sensor lifecycle | One in-flight capsule query, bounded cadence, stale-context discard | Deterministic pending/invalid/timeout tests |
| Driver controls | Remappable keys; vehicle, seat, control-authority and lifecycle checks | Mocked runtime regression tests |
| HUD | Local responsive NUI, explicit units, preview label, stale-status indication | JavaScript DOM mocks; visual/CEF acceptance pending |
| Audio | Optional locally generated alerts; off by default | Audio API mocks; CEF behaviour pending |
| Server | Factory profiles only; no network installation or inventory mutation path | Server-surface regression checks |

**Not included yet:** paid module installation, persistent ownership, inventory/framework adapters,
state-bag replication, a real rear camera, ACC, blind-spot detection, cross-traffic alerts or recovery routing.
These are roadmap items, not compatibility or feature claims.

Waypoint drive uses GTA's built-in driving task. It is not an independent autonomous-driving stack.
Collision assistance uses fixed, experimental thresholds and a limited probe volume; it does not
guarantee detection or collision avoidance.

## Try it in an isolated development server

Use a disposable FiveM development environment, not a live server. No FiveM artifact/game-build
combination has been certified by this recovery work.

```sh
git clone --branch 1-recovery-foundation https://github.com/Nova-Games-Enterprise/Autodrive.git nge_autodrive
```

Place the folder under the development server's `resources` directory and add:

```cfg
ensure nge_autodrive
```

The preview has no ESX, QBCore, Qbox, inventory, database or InteractSound dependency. This means the core
is framework-independent, **not** that every framework integration has been tested. `Config.Vehicles` is
an explicit factory-profile allowlist. `sultan` provides a built-in vehicle profile; `tesla` and
`gbschwartzers` retain the old custom-model names and require your own corresponding assets.
No third-party vehicle assets are included.

Default controls: **K** for waypoint drive, **J** for collision assistance, **Page Up / Page Down** for set
speed. They are remappable in FiveM. Set a waypoint, enter an allowed vehicle as driver, release manual
driving input and let the sensor become ready before activation. Accelerator, brake or steering cancels
the driving task. A warning, brake condition or stale sensor also cancels it; no automatic resume occurs.

`Config.Units` is `kmh` or `mph`. Cruise configuration uses that unit; the native task receives metres per
second. Defaults are 50 km/h with a 20-80 km/h set-speed range. This is a configuration choice, not a
tested safe-speed envelope. Read [migration notes](docs/MIGRATION.md) before reusing old configuration.

## Verify the code

Developer checks require **Lua 5.4** and **Node.js 18 or later**. No npm packages are required.

```sh
node scripts/verify.mjs
```

On Linux the runner looks for `lua5.4`; on Windows it looks for `lua`. Select another path explicitly:

```powershell
$env:LUA_BIN = 'C:\path\to\lua.exe'
node scripts/verify.mjs
```

The suite covers configuration, conversion, directional policy, pending/stale probes, bounded query
allocation, controller transitions, runtime lifecycle, HUD rate limits, NUI/audio failures, manifest paths
and the deliberately closed network surface. GitHub Actions runs the same entrypoint with read-only
repository permissions and no persisted checkout credentials.

See [validation evidence and acceptance checklist](docs/VALIDATION.md). Automated tests do not replace
physical in-game verification. No frame-time, FPS or multiplayer load figures are claimed.

## Project map

```text
config.lua             Factory profiles and bounded settings
shared/core.lua        Pure policies, config checks, async-probe lifecycle
client/controller.lua  Injected driving controller and transitions
client/sensors.lua     Native adapter for directional capsule queries
client/hud.lua         Changed-state publishing and heartbeat
client/main.lua        Input, driver lifecycle and per-frame brake requests
server/main.lua        Restricted diagnostics; no installation endpoints
html/                  Local HUD with no remote scripts, fonts or requests
tests/                 Plain-Lua and Node.js regression tests
scripts/verify.mjs     Shared local/CI entrypoint
docs/                  Architecture, migration, roadmap and release gates
```

## Development and review

The repository URL and historical default-branch name are preserved. The documentation-only recovery notice from PR #2 is retained. Runtime recovery work is reviewed in a
separate branch and PR. The original implementation remains at commit
`681dff42c6915aba7edfcda414c211b78ac5cf47`.

Read [architecture](docs/ARCHITECTURE.md), [roadmap](docs/ROADMAP.md), [security policy](SECURITY.md)
and [contribution guidelines](CONTRIBUTING.md). This project currently targets FiveM only; no
other-platform compatibility or endorsement is claimed.

## Credits and licensing

Maintained by the **Nova Games Enterprise team**. Original 2025 implementation by **Bacasuoro**;
individual contributions remain attributable through Git history.

Licensing is pending an explicit rights-holder decision. This recovery increment does not introduce a
license grant or claim the repository is already licensed as open source.
