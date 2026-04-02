Runtime Modules
===============

This directory holds first-class modules that ship with the runtime itself.

Use `src/runtime_modules/` for modules that are considered part of the trusted
runtime surface and must participate in deterministic startup, stronger
stability guarantees, or runtime-level compatibility expectations.

Typical uses:

- core services
- platform backends
- persistence or scheduler integrations
- built-in runtime capabilities that must be present at startup

If a module is optional, experimental, or intended to be replaceable without
being treated as core runtime behavior, it belongs in `src/modules/` instead.

See `docs/implementation/MODULES.md` for the full rationale.

---
*&copy; 2026 Wilder. All rights reserved.*\
*Contact: teamwilder@wildercode.org*\
*Licensed under the Wilder Foundation License 1.0.*\
*See LICENSE for details.*