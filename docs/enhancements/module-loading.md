
Cosmos Modules — Runtime Extensions and Explicit Management
Modules in Cosmos extend the substrate itself. They are not Things and do
not live in the world. Modules provide capabilities that Things may depend
on, such as persistence, codecs, schedulers, or external system bridges.

A module:
- has no lifecycle
- does not participate in events
- does not represent a semantic entity
- extends or augments the runtime substrate
- is explicitly installed, loaded, or removed by the developer

Modules are managed through explicit Git‑style CLI verbs:

cosmos add module <modulefile>
Installs a module from a transparent bundle (e.g. persistence.cosmosmod)
or from a source file. Registers it with the runtime.

cosmos remove module <module-id>
Uninstalls the module and unregisters its capabilities.

cosmos list modules
Shows all installed modules and their status.

cosmos inspect module <module-id>
Displays module metadata, capabilities, and load state.

cosmos load module <module-id>
cosmos reload module <module-id>
Explicitly loads or reloads a module in push mode.

Modules must be transparent and manifest‑driven. A `.cosmosmod` bundle is
inspectable and contains:

module-id/
manifest.json
src/
assets/ (optional)

The manifest defines:
- module id
- capabilities provided
- entry points
- dependencies (if any)

The runtime never auto-discovers modules. They are only loaded when the
developer explicitly installs or loads them. This preserves explicit-over-
implicit and keeps the substrate deterministic and inspectable.
