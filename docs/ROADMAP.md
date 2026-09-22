# Recovery roadmap

Status: active development. Delivery is gated by evidence, not dates.

## M0/M1: recovery and testable foundation

Tracking: [#1](https://github.com/Nova-Games-Enterprise/Autodrive/issues/1).

- Preserve the existing repository, original commit and historical branch names.
- Retire unsafe plate-only installation and global module-table broadcasts.
- Extract driving policy, sensor scheduling and control ownership from native glue.
- Fix directional rear checks, stale sensor handling and cruise-speed updates.
- Bound NUI/audio work and add user-rebindable input.
- Add Lua/JavaScript tests and manifest validation.
- Publish runtime acceptance criteria and a reviewed CI workflow.

Paid installation stays disabled in this increment. No persistent module data
is created, consumed or silently migrated.

## M2: authoritative installation and persistence

Before accepting any client installation request:

- Resolve the player and networked vehicle on the server: distance, routing
  bucket, allowed model, role and resource state must be checked there.
- Use a stable owned-vehicle identifier; treat the plate as display metadata.
- Validate input type/size and rate-limit requests.
- Make item consumption and installation idempotent; define recovery for
  inventory/database failures, retries and duplicate requests.
- Treat entity state bags as replicated projections, not proof of authorization
  or durable storage. The authoritative record remains on the server.
- Test each adapter against identified framework and inventory versions.

## M3: assistance behavior

Calibrated obstacle envelopes, multi-probe sensing, warning/AEB, parking sensors
and then adaptive cruise. Add road-speed, geometry and moving-obstacle scenarios
before calling any feature complete. Blind-spot/cross-traffic behavior is
exploratory, not part of the first release promise.

## M4: real rear camera

Vehicle-relative scripted camera, correct restoration, aspect-ratio tests and
geometry-aware guides. An overlay alone must never be marketed as a camera.

## M5: waypoint-driving lifecycle

Destination changes, arrival, manual intervention, blocked routes, interrupted
tasks and bounded recovery. Never silently resume after a manual cancel.

## M6: public alpha

Close applicable [validation gates](VALIDATION.md), record exact runtime and
framework versions, publish a real gameplay demonstration and resolve licensing.
Performance claims require profiler measurements. Stable release remains separate.
