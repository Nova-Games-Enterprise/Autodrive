# Roadmap

Planning, not a list of available features or delivery dates.

| Phase | Scope | Current position |
| --- | --- | --- |
| M0 | Recovery baseline, isolated workspace/branch, issue, docs and CI entrypoint | Implemented in recovery branch; remote CI/review must be checked |
| M1 | Testable core, lifecycle, bounded sensors/UI, actual speed updates | First increment implemented; native/visual acceptance pending |
| M2 | Authoritative installer, stable identity, inventory adapters, persistence/recovery, replication | Constraints documented; not implemented |
| M3 | Calibrated AEB/parking, ACC and blind-spot/cross-traffic policies | Not implemented |
| M4 | Real rear camera, cleanup and calibrated guidelines | Not implemented |
| M5 | Robust routing/progress, traffic/stuck handling and controller integration | Not implemented |
| M6 | Runtime matrix, license decision, demonstrated use, release packaging | Not ready |

## Next exact step

Run M1 native smoke/lifecycle tests on an isolated FiveM server, starting with resource start/stop,
forward/reverse braking and keyboard takeover. Record evidence before merging the runtime rewrite.
Then implement M2 in separate reviewable increments; never reopen the legacy installer as a shortcut.

The repository URL stays stable. Introduce a conventional `main` only as an explicit integration step
after review. Do not rewrite the original history or delete historical branches.
