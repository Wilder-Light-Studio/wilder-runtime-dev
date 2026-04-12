
# Application Developer Getting Started Guide (Beginner Edition)

Welcome! This guide is designed for absolute beginners who want to build applications using the Wilder Cosmos Runtime. It will walk you through every step, explain key concepts, and help you avoid common mistakes. No prior experience with this codebase is required.

---

---

## Table of Contents
1. [Introduction & Overview](#introduction--overview)
2. [Prerequisites & Environment Setup](#prerequisites--environment-setup)
3. [Core Concepts](#core-concepts)
4. [First App Walkthrough](#first-app-walkthrough)
5. [Key APIs and Extension Points](#key-apis-and-extension-points)
6. [Debugging & Testing](#debugging--testing)
7. [CLI and GUI Tools Overview](#cli-and-gui-tools-overview)
8. [Troubleshooting & FAQ](#troubleshooting--faq)
9. [Common Mistakes & Pitfalls](#common-mistakes--pitfalls)
10. [Next Steps & Resources](#next-steps--resources)

---

## 1. Introduction & Overview

The Wilder Cosmos Runtime provides a robust foundation for building distributed, modular applications. As an app developer, you'll use its services and things (modular components) to create, extend, and orchestrate new functionality. This guide will help you:
- Set up your environment
- Understand core concepts (services, things, waves)
- Build and run your first app
- Use essential tools
- Avoid common pitfalls


## 2. Prerequisites & Environment Setup

### What You Need

- **Basic programming knowledge** (any language is fine; Nim is used here)
- **Git** (for downloading the code)
- **Windows, macOS, or Linux**

### Step 1: Install Git

If you don’t have Git:
- Download from [git-scm.com](https://git-scm.com/downloads) and follow the installer instructions.

### Step 2: Install Nim

Nim is the programming language used for modules and the runtime.
- Go to the [Nim installation guide](https://nim-lang.org/install.html) and follow the steps for your operating system.

### Step 3: Download the Wilder Cosmos Runtime

Open a terminal (Command Prompt, PowerShell, or Terminal app) and run:

```sh
git clone https://github.com/your-org/wilder-cosmos-runtime.git
cd wilder-cosmos-runtime
```

### Step 4: Install Dependencies

In the same terminal, run:

```sh
nimble install -y
```

This will download and install all required libraries.

### Step 5: Verify Your Setup

Run:

```sh
nimble verify
```

This command checks that everything is working and runs tests. If you see errors, check the troubleshooting section below.

## 3. Core Concepts

- **Services:** Modular, reusable logic units that provide capabilities to your app.
- **Things:** The primary building blocks—represent entities, resources, or actors in your app.
- **Waves:** The communication mechanism for events and data between things and services.
- **Modules:** Packages of related things/services, easily extended or replaced.

For more, see [docs/public/concepts/](../concepts/).


## 4. First App Walkthrough (Step-by-Step)

Let’s build a simple "counter" module that counts how many times it receives a message. This will show you how to create, register, build, and test a module from scratch.

### Step 1: Copy the Module Template

The project provides a template for new modules. In your terminal, run:

```sh
cp templates/cosmos_runtime_module.nim src/modules/my_counter.nim
```

If you’re on Windows and `cp` doesn’t work, use:

```powershell
copy templates\cosmos_runtime_module.nim src\modules\my_counter.nim
```

### Step 2: Edit Your Module

Open `src/modules/my_counter.nim` in your code editor. You’ll see comments and example code. Update the following:

- Change the module name to something unique, like `my.counter`.
- Update the description to explain what your module does.
- Implement the state and logic for your counter.

**Example:**

```nim
const
   moduleName* = "my.counter"
   moduleSchemaVersion* = 1

let myCounterMeta* = ModuleMetadata(
   name: moduleName,
   kind: mkLoadable,
   schemaVersion: moduleSchemaVersion,
   memoryCap: 1 * 1024 * 1024,  # 1 MiB
   resourceBudget: 100,         # 100 ticks per frame
   description: "A simple counter module."
)


   MyCounterState* = object
      counter*: int
      lastMessage*: string

proc initMyCounter*(ctx: var ModuleContext) {.nimcall.} =
   ctx.state.config = %*{"counter": 0, "lastMessage": ""}

proc handleMyCounter*(ctx: var ModuleContext, msg: JsonNode): JsonNode =
   if msg.hasKey("increment"):
      let inc = msg["increment"].getInt(1)
      let cur = ctx.state.config{"counter"}.getInt
      ctx.state.config["counter"] = %(cur + inc)
      ctx.state.config["lastMessage"] = %("Incremented by " & $inc)
   result = ctx.state.config

# Register your module (see next step)
```

### Step 3: Register Your Module

To make your module available to the runtime, you must register it. Open `src/runtime/modules.nim` and add your registration code near the other `registerModule` calls. For example:

```nim
import ../modules/my_counter

let reg = newModuleRegistry()
registerModule(reg, myCounterMeta, initMyCounter)
```

Make sure the import path matches your file location.

### Step 4: Build the Runtime

In your terminal, run:

```sh
nimble buildRuntime
```

This will compile the runtime and your new module.

### Step 5: Run the Runtime

After building, run:

```sh
./bin/cosmos.exe
```

On Windows, use:

```powershell
.\bin\cosmos.exe
```

You should see output indicating your module is loaded.

### Step 6: Test Your Module

Add tests in `tests/unit/` or `tests/integration/`. You can copy an existing test as a starting point. To run all tests:

```sh
nimble test
```

If your module passes the tests, congratulations! You’ve built and registered your first module.

See [examples/counter.nim](../../examples/counter.nim) for a full working example.
## 5. Key APIs and Extension Points

- **Runtime API:** See `src/runtime/api.nim` for core interfaces.
- **Messaging:** Use waves to send/receive events (see `src/runtime/messaging.nim`).
- **Persistence:** Store and retrieve data (see `src/runtime/persistence.nim`).
- **Extending things/services:** Follow patterns in `src/runtime/things/` and `src/runtime/services/`.

## 6. Debugging & Testing

- **Debugging:**
  - Use logging (see `src/runtime/observability.nim`).
  - Run in verbose mode if available.
- **Testing:**
  - Place unit tests in `tests/unit/`.
  - Use `nimble test` to run all tests.
  - For integration tests, see `tests/integration/`.

## 7. CLI and GUI Tools Overview

- **CLI Tools:**
  - `nimble` — build, test, verify
  - `cosmos.exe` — run the runtime
  - Custom scripts in `scripts/` (e.g., `build_binary.ps1`)
- **GUI Tools:**
  - (If available) See [docs/public/tools/](../tools/) for any graphical tools. If none, all development is CLI-based for now.


## 8. Troubleshooting & FAQ

**Q: I get an error about missing dependencies when building or running?**
A: Run `nimble install -y` to install all required libraries.

**Q: My module isn’t showing up or loading?**
A: Make sure you:
- Registered your module in `src/runtime/modules.nim`.
- Used the correct import path.
- Rebuilt the runtime after making changes.

**Q: Tests are not running or not found?**
A: Ensure your test files are in the correct directory (`tests/unit/` or `tests/integration/`) and named with a `.nim` extension.

**Q: I get a permissions error on Windows?**
A: Try running your terminal as Administrator, or check file permissions.

**Q: Where can I get help?**
A: See [docs/public/](../) or ask in the project chat/forum.


## 9. Common Mistakes & Pitfalls

- Forgetting to register new modules in the loader (`src/runtime/modules.nim`).
- Not running `nimble install -y` after pulling new code or dependencies change.
- Placing test files in the wrong directory or with the wrong extension.
- Using legacy terminology (always use "wave" instead of "precept").
- Not following code style guidelines (see [docs/implementation/COMMENT_STYLE.md](../../implementation/COMMENT_STYLE.md)).
- Not rebuilding the runtime after making changes to modules.
- Typos in module names or import paths.


## 10. Next Steps & Resources

- Explore more examples in the `examples/` directory.
- Read the [DEVELOPMENT-GUIDELINES.md](../../implementation/DEVELOPMENT-GUIDELINES.md) for coding standards.
- Review the [COMPLIANCE-MATRIX.md](../../implementation/COMPLIANCE-MATRIX.md) for requirements.
- Try building a more complex module or contribute improvements!

---


---

Welcome to the Wilder Cosmos developer community! If you get stuck, don’t hesitate to ask for help or check the documentation. Every expert was once a beginner.
