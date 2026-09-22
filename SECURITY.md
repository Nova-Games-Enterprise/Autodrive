# Security policy

This is an experimental FiveM resource, not a security certification or anti-cheat product. The recovery
preview has no paid installation, inventory mutation or module-sync network endpoint. Local gameplay
state does not prove money, item ownership, permissions or vehicle ownership.

Do not post exploit instructions, credentials, server/player data or personal identifiers publicly.
Use GitHub private vulnerability reporting when available, or contact a maintainer privately through an
existing trusted channel. No dedicated monitored disclosure address or response SLA is established yet.

Future economy features require server validation, bounded/idempotent requests, crash-tested persistence,
tested inventory adapters and explicit failure handling. Entity-owner state bags are not an authoritative
registry. See `docs/ARCHITECTURE.md`.

This recovery work changes no production server, server-wide security convar, firewall, DNS or proxy.
Use a disposable development server for validation.
