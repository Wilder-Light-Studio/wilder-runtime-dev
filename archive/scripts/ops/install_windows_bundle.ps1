<#
.SYNOPSIS
  Install Wilder Cosmos Runtime from extracted Windows installer bundle.
.DESCRIPTION
  Prompts for install mode (user/system), creates required runtime-home tree,
  copies cosmos.exe into bin, and optionally adds bin to PATH.
.EXAMPLE
  .\install_windows_bundle.ps1
.EXAMPLE
  .\install_windows_bundle.ps1 -InstallMode user -AddToPath -NoPrompt
#>
param(
  [ValidateSet("user", "system")]
  [string]$InstallMode,

  [switch]$AddToPath,

  [switch]$NoPrompt,

  [string]$BundleRoot = ".",

  [string]$InstallRoot,

  [string]$Version = "unknown"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$requiredDirs = @(
  "config",
  "logs",
  "cache",
  "messages",
  "projects",
  "registry",
  "bin",
  "temp"
)

function Test-IsAdministrator {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = New-Object Security.Principal.WindowsPrincipal($identity)
  return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Resolve-InstallMode {
  param(
    [string]$Mode,
    [bool]$Interactive
  )

  if (-not [string]::IsNullOrWhiteSpace($Mode)) {
    return $Mode.ToLowerInvariant()
  }

  if (-not $Interactive) {
    return "user"
  }

  while ($true) {
    $answer = (Read-Host "Choose install mode [user/system]").Trim().ToLowerInvariant()
    if ($answer -in @("user", "system")) {
      return $answer
    }
    Write-Host "Please enter 'user' or 'system'."
  }
}

function Resolve-InstallRoot {
  param(
    [string]$Mode,
    [string]$OverrideRoot
  )

  if (-not [string]::IsNullOrWhiteSpace($OverrideRoot)) {
    return $OverrideRoot
  }

  if ($Mode -eq "user") {
    return (Join-Path $env:USERPROFILE ".wilder/cosmos")
  }

  $programData = if ([string]::IsNullOrWhiteSpace($env:ProgramData)) {
    "C:\ProgramData"
  } else {
    $env:ProgramData
  }

  return (Join-Path $programData "Wilder/Cosmos")
}

function Set-PathEntry {
  param(
    [string]$Scope,
    [string]$Entry
  )

  $current = [Environment]::GetEnvironmentVariable("Path", $Scope)
  $segments = @()
  if (-not [string]::IsNullOrWhiteSpace($current)) {
    $segments = $current.Split(';', [StringSplitOptions]::RemoveEmptyEntries)
  }

  $exists = $false
  foreach ($segment in $segments) {
    if ($segment.TrimEnd('\\') -ieq $Entry.TrimEnd('\\')) {
      $exists = $true
      break
    }
  }

  if (-not $exists) {
    $newPath = if ([string]::IsNullOrWhiteSpace($current)) {
      $Entry
    } else {
      "$current;$Entry"
    }
    [Environment]::SetEnvironmentVariable("Path", $newPath, $Scope)
  }
}

$interactive = -not $NoPrompt
$mode = Resolve-InstallMode -Mode $InstallMode -Interactive $interactive

if ($mode -eq "system" -and -not (Test-IsAdministrator)) {
  throw "System mode installation requires an elevated PowerShell session."
}

$resolvedBundleRoot = (Resolve-Path -Path $BundleRoot).Path
$bundleBinaryPath = Join-Path $resolvedBundleRoot "cosmos.exe"
if (-not (Test-Path -LiteralPath $bundleBinaryPath)) {
  throw "Installer bundle is missing cosmos.exe at $bundleBinaryPath"
}

$root = Resolve-InstallRoot -Mode $mode -OverrideRoot $InstallRoot
New-Item -ItemType Directory -Force -Path $root | Out-Null
foreach ($name in $requiredDirs) {
  New-Item -ItemType Directory -Force -Path (Join-Path $root $name) | Out-Null
}

$binPath = Join-Path $root "bin"
$targetBinaryPath = Join-Path $binPath "cosmos.exe"
Copy-Item -LiteralPath $bundleBinaryPath -Destination $targetBinaryPath -Force

$pathOptIn = $false
if ($AddToPath.IsPresent) {
  $pathOptIn = $true
} elseif ($interactive) {
  $response = (Read-Host "Add runtime bin directory to PATH? [y/N]").Trim().ToLowerInvariant()
  $pathOptIn = $response -in @("y", "yes")
}

$pathScope = if ($mode -eq "system") { "Machine" } else { "User" }
$pathEntry = $binPath
if ($pathOptIn) {
  Set-PathEntry -Scope $pathScope -Entry $pathEntry
}

$registryPath = Join-Path $root "registry"
$manifestPath = Join-Path $registryPath "installer.manifest"
$versionRegistryPath = Join-Path $registryPath "version-registry.json"
$pathMetadataPath = Join-Path $registryPath "path-metadata.json"

Set-Content -LiteralPath $manifestPath -Value "owned=true" -Encoding utf8

$versionRegistry = [ordered]@{
  installedVersion = $Version
  channel = "stable"
  mode = $mode
  installedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
}
($versionRegistry | ConvertTo-Json) | Set-Content -LiteralPath $versionRegistryPath -Encoding utf8

$pathMetadata = [ordered]@{
  pathIntegrated = $pathOptIn
  scope = $pathScope
  addedEntry = if ($pathOptIn) { $pathEntry } else { "" }
}
($pathMetadata | ConvertTo-Json) | Set-Content -LiteralPath $pathMetadataPath -Encoding utf8

Write-Host "Install mode: $mode"
Write-Host "Install root: $root"
Write-Host "Binary: $targetBinaryPath"
if ($pathOptIn) {
  Write-Host "PATH integration enabled in $pathScope scope."
} else {
  Write-Host "PATH integration skipped."
}
