# Security model and reporting

The historical prototype is not approved for production. Its networked module
installation is being retired before further feature expansion.

## Boundaries

- A client can modify its own scripts. Assistance is not an anti-cheat.
- No inventory, payments or durable entitlement may be authorized by a
  client-supplied plate, boolean, local event or state-bag value.
- State bags can distribute state; they are not a database or authorization boundary.
- Sensor/UI/audio loops must not generate per-frame network requests.
- Vehicle ownership is checked before control changes. Do not request ownership
  of unrelated vehicles or change global server/anti-cheat configuration.
- Network features are unavailable until authority and persistence paths are
  tested. No permissive fallback when a framework, database or inventory is missing.

The project follows the principles in Cfx's
[Secure Your Events](https://docs.fivem.net/docs/developers/server-security/).

## Reporting

For a suspected security issue, contact the NGE maintainers through an existing
private channel. Do not post a working abuse payload, credentials or private
server data in a public issue. There is not yet a dedicated disclosure mailbox
or a guaranteed response-time policy.

## Release gate

A passing test suite does not establish production security. Public-server
use requires the runtime and integration gates in `docs/VALIDATION.md`.
