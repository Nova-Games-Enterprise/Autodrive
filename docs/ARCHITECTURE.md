# Architecture and trust boundaries

## Recovery increment

The core has no framework dependency or economy feature. Local factory-profile eligibility is gameplay
configuration, not an anti-cheat boundary. A modified client can manipulate local assistance; the server
must never award money, items or ownership based on that state.

The manifest replaces the old monolithic entrypoints rather than loading them alongside the recovery
code. Lua policies are separate from native adapters. NUI renders bounded snapshots using text nodes;
it cannot install modules or send requests.

## Controller

States: `off`, `driving`, `interrupted`, `arrived`.

Activation requires an eligible driver with entity control, a finite waypoint and a fresh clear sensor.
Restarting a route is explicit. Live speed changes update the existing task. Driver/vehicle changes,
lost control, manual input, changed waypoints, stale sensors and hazards interrupt it. Arrival requires
low longitudinal speed. The conservative 30-second distance-to-destination progress watchdog can cancel
legitimate long detours or traffic waits; it is not intelligent route recovery.

Cleanup checks the original ped/vehicle and expected task type. Task control is shared with other
resources: these checks cannot establish exclusive ownership if another resource starts the same task
type. Coexistence requires integration tests. No network-ownership takeover is attempted.

## Sensors and braking

At most one capsule query is in flight. Pending results are never treated as completed misses. Expired
handles are drained instead of repeatedly replaced, bounding allocation even if a native stalls. Missing
or stale data reports `unavailable` and cancels waypoint drive. A new vehicle/direction/epoch invalidates
old samples. The capture timestamp, not delayed completion time, determines freshness.

The mask includes world geometry, vehicles, peds, ragdolls and objects. World hits need no entity handle.
Probes start near model bounds; no UI/camera flag selects travel direction. The 30-metre probe and fixed
thresholds do not model road curvature, closing speed, stopping distance, grip or the complete swept
volume. Slopes, walls, clutter, high speeds and traffic require real acceptance tests. Calibration is pending.

Braking uses per-frame control requests: forward motion requests brake; reverse motion requests its
opposing control. No `SetVehicleBrake` or `SetVehicleHandbrake` flag is latched. The expected AI task is
cancelled before a brake request. Effectiveness, release and coexistence still need FiveM verification.

## UI and workload

State changes publish at most every 100 ms plus a one-second heartbeat; teardown can force a hidden
snapshot. The HUD reports stale status after 2.5 seconds without a valid snapshot. It does not leave a
green indication after losing the Lua bridge. Sensor starts are limited to 50-ms cadence while active;
disabled/ineligible contexts do not start probes. Eligible-driver input/braking retains a frame loop.
These bounds are not measured CPU/frame-time or scalability results.

NUI has no remote dependencies or network requests. Optional Web Audio alerts are rate-limited and
disabled by default; autoplay rejection does not break the HUD.

## Future installation boundary: M2, not implemented

Never restore the plate-only event. Validate player, job/permissions, target entity, model, routing bucket,
distance and stable vehicle identity against server-owned records, again at commit time. Network ownership
is not legal vehicle ownership. Neither a client plate nor a state-bag ID establishes entitlement.

The persistent registry is authoritative. Entity state bags are a cache, not proof: owning clients can write
entity state under the default policy. No server-wide convars are changed by this preview.

Inventory reservation/removal and persistence need explicit idempotent commit/compensation semantics.
Separate providers do not become atomic by wrapping one database call in a transaction. Test concurrent
requests, duplicates, disconnects, restarts, persistence failures and every crash boundary. Unknown/failed
provider operations must reject, not silently permit, installation. Pending work needs per-player/global
bounds, expiry, cleanup and durable recovery.

## Primary technical references

- Event security: https://docs.fivem.net/docs/developers/server-security/
- State bags: https://docs.fivem.net/docs/scripting-manual/networking/state-bags/
- Async probes/masks: https://github.com/citizenfx/natives/blob/master/SHAPETEST/StartShapeTestLosProbe.md
- Capsules: https://github.com/citizenfx/natives/blob/master/SHAPETEST/StartShapeTestCapsule.md
- Set speed: https://github.com/citizenfx/natives/blob/master/TASK/SetDriveTaskCruiseSpeed.md

These references guide implementation; they are not evidence of an in-game test of this resource.
