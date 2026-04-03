# Wilder Cosmos 0.4.0
# Module name: coordinator
# Module Path: src/runtime/coordinator.nim
# Summary: Compatibility placeholder for legacy coordinator module path.
# Simile: Like a forwarding label that preserves old routes during a refactor.
# Memory note: active runtime entrypoint coordinator logic lives in src/cosmos_main.nim.
# Flow: import this module -> read guidance -> use src/cosmos_main.nim for coordinator behavior.

# Flow: Return guidance for callers still referencing legacy coordinator path.
proc coordinatorModuleNotice*(): string =
  "Coordinator CLI implementation lives in src/cosmos_main.nim"

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
