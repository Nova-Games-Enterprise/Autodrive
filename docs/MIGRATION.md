# Migration from the 2025 prototype

This is not a drop-in production update. Keep the old installation/configuration intact and use a separate
development server. Do not run both resources together on the same vehicle. No automatic deployment,
database migration, repository rename or default-branch change is performed.

## Deliberate changes

- New configuration schema: use the supplied file, not the old `config.lua`.
- `Config.Units` controls cruise values. The default is now km/h, not implicit mph.
- Eligibility is `Config.Vehicles`; no persistent installed-module state exists yet.
- `MechanicModule` and old install/sync events are unavailable. No item is consumed or charge made.
- No ESX/QB/ox/qs inventory bridge and no unrestricted-installer fallback.
- The old overlay-only "rear camera" is no longer loaded. A real camera is roadmap work.
- Sport naming is replaced by an explicit collision-assistance toggle, not engine/handling tuning.
- Remappable controls replace hardcoded controls: K, J, Page Up, Page Down.
- No InteractSound. Optional local alert audio is disabled by default.
- Old monolithic entrypoints are replaced by modules, never loaded concurrently.

## Rollback

The historical runtime source and original commit `681dff42c6915aba7edfcda414c211b78ac5cf47` remain available. The default branch has received a documentation-only recovery notice, not this runtime rewrite.
Use a separate checkout of that revision to reproduce the prototype. It is not security-hardened: its
installer trusted a client-supplied plate and its module table was not persistent. This recovery preview
creates no inventory/module records to migrate back.
