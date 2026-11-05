# Application Developer Getting Started Guide

What this is. This guide takes you from nothing to a built runtime, a passing gate
and your first runtime module. No prior experience with this codebase is needed.

---

## Table of Contents

1. [Where Things Stand](#1-where-things-stand)
2. [Set Up](#2-set-up)
3. [The Model in Brief](#3-the-model-in-brief)
4. [Your First Module](#4-your-first-module)
5. [Testing](#5-testing)
6. [Troubleshooting](#6-troubleshooting)
7. [Next Steps](#7-next-steps)

---

## 1. Where Things Stand

Cosmos is being re-scoped to a Minimum Viable Product (MVP). Two ways of building
exist, one now and one coming:

- **Today:** runtime modules, written in Nim and registered with the module registry.
  This guide covers them.
- **From Phase 3:** Concepts. You declare a Concept in a `manifest.json`, give it an
  implementation or build it from other Concepts, and Cosmos makes Things from it.
  This becomes the main way to build. Modules become Things too.

[STATUS.md](../../../STATUS.md) shows which phase is current.

## 2. Set Up

You need Windows 11, Git, and Nim 2.0.8 with Nimble
([nim-lang.org/install](https://nim-lang.org/install.html)).

```powershell
git clone https://github.com/Wilder-Light-Studio/wilder-runtime-dev.git
cd wilder-runtime-dev
nimble install --depsOnly -y
nimble verify
```

`nimble verify` runs the full gate. It should end with `Gate passed.`: 46 tests pass,
and 4 are known failures listed in `tests/KNOWN_FAILURES.txt`.

## 3. The Model in Brief

- **Things** are the only kind of entity. The Cosmos is the root Thing.
- **Concepts** are templates. Every other Thing is made from one.
- **Waves** are how Things talk: a wave reaches every Thing with a matching sense.
- **Wires** connect one Thing's output to other Things' inputs.
- **Frames** are how time moves. The history records each frame's changes.
- **Nothing is inherited.** A Thing knows only what it declares, senses or is wired
  to.

[Concepts](../concepts/primitives.md) explains each one.

## 4. Your First Module

[examples/counter.nim](../../../examples/counter.nim) is a complete, working
loadable module that counts the messages it receives. Start from it.

1. **Copy it** to `src/modules/my_counter.nim`.
2. **Rename it.** Give `ModuleMetadata.name` a unique lowercase-dot name, such as
   `my.counter`, and update the description.
3. **Keep state in the context.** Store it in `ModuleContext`, never in a global
   variable.
4. **Update the header comments.** Every Nim file needs Summary, Simile, Memory note
   and Flow lines, and a `# Flow:` comment before each `proc`. `nimble compliance`
   checks this.
5. **Register it** with the module registry:

   ```nim
   let reg = newModuleRegistry()
   registerModule(reg, myCounterMeta, initMyCounter)
   ```

   Registration fails fast if the name is empty or already taken. Loadable modules
   load in name order, after the kernel modules.

For a brand-new module rather than a copy, `scripts/dev/new_nim_module.ps1` creates
the file with the header already filled in.

## 5. Testing

- Put unit tests in `tests/unit/` and integration tests in `tests/integration/`.
  Any `.nim` file there joins the gate automatically.
- `tests/unit/module_test.nim` shows how tests register and load modules.
- Run one file with `nim c -r tests/unit/<name>.nim`, or everything with
  `nimble test`.
- If a test fails, its logs are in `tests/tmp/gate/logs/`.

## 6. Troubleshooting

**`nimble verify` reports a compliance failure.** Read the list it prints. It's
usually a missing header line or a missing `# Flow:` comment before a `proc`.

**A test is reported as KNOWN.** That's expected: it's a listed known failure. If a
listed test starts passing, the gate fails until you remove its line from
`tests/KNOWN_FAILURES.txt`.

**My module isn't loading.** Check it's registered, its name is unique, and you
rebuilt.

**A `cosmos` command says "method not found".** That's a known daemon bug that Phase
2 fixes. See the [Runtime CLI Guide](runtime-cli-guide.md).

## 7. Next Steps

- [DEVELOPMENT-GUIDELINES.md](../../implementation/DEVELOPMENT-GUIDELINES.md):
  how to work in this repository.
- [COMMENT_STYLE.md](../../implementation/COMMENT_STYLE.md): comment and
  documentation style.
- [MVP-REQUIREMENTS.md](../../implementation/MVP-REQUIREMENTS.md): what Cosmos must
  do.

---
*&copy; 2026 Wilder. All rights reserved.*\
*Contact: teamwilder@wildercode.org*\
*Licensed under the Wilder Foundation License 1.0.*\
*See LICENSE for details.*
