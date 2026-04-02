# First Module Tutorial

What this is. This page walks through writing and registering a minimal module using the repository conventions.

## Goal

Create a small module that can be registered with metadata and loaded deterministically.

## Step 1: Choose Placement

Use this rule:

- `src/runtime_modules/` for built-in runtime modules with stronger startup and compatibility expectations.
- `src/modules/` for optional, experimental, or replaceable modules.

## Step 2: Start From Template

Use the module template in `templates/cosmos_runtime_module.nim` or `src/style_templates/` depending on your workflow.

## Step 3: Define Metadata

In the module system, metadata includes:

- name
- kind (kernel or loadable)
- schema version
- memory cap
- resource budget
- description

## Step 4: Register

Register through the runtime module registry and provide an init proc.

```nim
let reg = newModuleRegistry()
registerModule(reg, ModuleMetadata(
  name: "counter.example",
  kind: mkLoadable,
  schemaVersion: 1,
  memoryCap: 1024 * 1024,
  resourceBudget: 0,
  description: "Example counter module"
), initProc = nil)
```

## Step 5: Verify Load Order

Load order is deterministic:

- kernel modules first (lexicographic)
- loadable modules second (lexicographic)

## Step 6: Test

Add focused tests under `tests/` and run:

```powershell
nimble test
```

## Important Boundary

This tutorial describes registration mechanics from current runtime module code. It does not assume dynamic plugin loading.

---
*&copy; 2026 Wilder. All rights reserved.*\
*Contact: teamwilder@wildercode.org*\
*Licensed under the Wilder Foundation License 1.0.*\
*See LICENSE for details.*
