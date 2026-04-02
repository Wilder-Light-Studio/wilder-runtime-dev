Modules
=======

This directory is for optional, experimental, replaceable, or community-facing
modules.

Use `src/modules/` when a module is not part of the trusted runtime core and can
reasonably be added, swapped, disabled, or evolved independently.

Typical uses:

- examples and tutorial modules
- experimental features
- community extensions
- optional integrations

If a module must ship as part of the runtime, initialize deterministically at
startup, or carry stronger stability guarantees, it belongs in
`src/runtime_modules/` instead.

See `docs/implementation/MODULES.md` for the full distinction.

---
*&copy; 2026 Wilder. All rights reserved.*\
*Contact: teamwilder@wildercode.org*\
*Licensed under the Wilder Foundation License 1.0.*\
*See LICENSE for details.*