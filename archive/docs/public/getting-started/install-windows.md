# Install On Windows

What this is. This page is the detailed Windows installation guide for Wilder
Cosmos Runtime, including mode selection, PATH opt-in, validation, upgrade, and
uninstall behavior.

## Installer Bundle Contents

Windows installer bundles include these core files:

- `cosmos.exe`
- `INSTALL.txt`
- `WINDOWS-INSTALL.md` (this guide, packaged for offline reference)
- `install_windows_bundle.ps1`

## Install Modes

You can install in one of two explicit modes:

- `user` mode (no administrator permissions required)
- `system` mode (administrator permissions required)

Default install roots on Windows:

- `user`: `%USERPROFILE%\\.wilder\\cosmos\\`
- `system`: `%ProgramData%\\Wilder\\Cosmos\\`

## Quick Install (Recommended)

1. Download and extract the Windows installer ZIP from the release assets.
2. Open PowerShell in the extracted folder.
3. Run:

```powershell
.\install_windows_bundle.ps1
```

4. Choose install mode when prompted.
5. Choose whether to add runtime `bin` path to PATH when prompted.

## Non-Interactive Install

Use flags for automation:

```powershell
.\install_windows_bundle.ps1 -InstallMode user -AddToPath -NoPrompt
```

System mode example (requires elevated PowerShell):

```powershell
.\install_windows_bundle.ps1 -InstallMode system -AddToPath -NoPrompt
```

## What The Installer Creates

Under the selected install root, the installer creates:

```text
config/
logs/
cache/
messages/
projects/
registry/
bin/
temp/
```

The runtime binary is installed to:

- `%USERPROFILE%\\.wilder\\cosmos\\bin\\cosmos.exe` (user mode)
- `%ProgramData%\\Wilder\\Cosmos\\bin\\cosmos.exe` (system mode)

Installer metadata files are written to `registry/`:

- `installer.manifest`
- `version-registry.json`
- `path-metadata.json`

## PATH Opt-In Behavior

PATH updates are optional and require explicit consent.

- User mode updates user PATH only.
- System mode updates machine PATH only.
- If PATH opt-in is declined, no PATH mutation is performed.

After opting in, open a new PowerShell window and verify:

```powershell
Get-Command cosmos.exe
```

## Post-Install Verification

Check binary location and version:

```powershell
cosmos.exe --help
```

If PATH was not enabled, run directly from install root:

```powershell
$root = Join-Path $env:USERPROFILE ".wilder\\cosmos"
& (Join-Path $root "bin\\cosmos.exe") --help
```

## Upgrade Flow

1. Extract the new installer bundle.
2. Re-run `install_windows_bundle.ps1` with the same mode you already use.
3. Re-apply `-AddToPath` only if PATH is missing or changed.
4. Confirm with `cosmos.exe --help`.

## Uninstall Ownership Rules

Uninstall operations must remove installer-owned files, including PATH entries
added by the installer, while preserving user-created project content.

Installer-owned paths include:

- `config/` (installer defaults only)
- `logs/`
- `cache/`
- `messages/`
- `registry/`
- `bin/`
- `temp/`

User project content under `projects/` must be preserved.

## Troubleshooting

- Error: system mode requires elevation.
  - Fix: re-open PowerShell as Administrator and rerun.
- `cosmos.exe` not found after install.
  - Fix: verify `bin/cosmos.exe` exists under selected install root.
- PATH update did not appear in current shell.
  - Fix: open a new terminal session.
- Wrong mode installed.
  - Fix: rerun installer script with desired `-InstallMode`.

---
*&copy; 2026 Wilder. All rights reserved.*\
*Contact: teamwilder@wildercode.org*\
*Licensed under the Wilder Foundation License 1.0.*\
*See LICENSE for details.*
