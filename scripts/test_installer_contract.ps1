param(
  [Parameter(Mandatory = $true)]
  [ValidateSet("windows", "linux", "darwin")]
  [string]$TargetOs,

  [Parameter(Mandatory = $true)]
  [ValidateSet("user", "system")]
  [string]$Mode,

  [Parameter(Mandatory = $true)]
  [string]$SandboxRoot
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

function Resolve-InstallRoot {
  param(
    [string]$Os,
    [string]$InstallMode,
    [string]$Root
  )

  switch ($Os) {
    "windows" {
      if ($InstallMode -eq "user") { return (Join-Path $Root "UserProfile/.wilder/cosmos") }
      return (Join-Path $Root "ProgramData/Wilder/Cosmos")
    }
    "linux" {
      if ($InstallMode -eq "user") { return (Join-Path $Root "home/.wilder/cosmos") }
      return (Join-Path $Root "var/lib/wilder/cosmos")
    }
    "darwin" {
      if ($InstallMode -eq "user") { return (Join-Path $Root "home/.wilder/cosmos") }
      return (Join-Path $Root "var/lib/wilder/cosmos")
    }
  }

  throw "Unsupported target OS: $Os"
}

function Ensure-Layout {
  param([string]$Root)

  foreach ($name in $requiredDirs) {
    New-Item -ItemType Directory -Force -Path (Join-Path $Root $name) | Out-Null
  }

  # Installer-owned metadata marker.
  Set-Content -LiteralPath (Join-Path $Root "registry/installer.manifest") -Value "owned=true" -Encoding utf8
  Set-Content -LiteralPath (Join-Path $Root "registry/version-registry.json") -Value '{"installedVersion":"0.0.0","channel":"nightly"}' -Encoding utf8
  Set-Content -LiteralPath (Join-Path $Root "registry/path-metadata.json") -Value '{"pathIntegrated":true}' -Encoding utf8
  # Simulate installer-owned binary.
  Set-Content -LiteralPath (Join-Path $Root "bin/cosmos.exe") -Value "placeholder" -Encoding utf8
}

function Assert-Layout {
  param([string]$Root)

  foreach ($name in $requiredDirs) {
    $path = Join-Path $Root $name
    if (-not (Test-Path -LiteralPath $path)) {
      throw "Missing required layout directory: $path"
    }
  }
}

function Uninstall-Owned {
  param([string]$Root)

  $owned = @("config", "logs", "cache", "messages", "registry", "bin", "temp")
  foreach ($name in $owned) {
    $path = Join-Path $Root $name
    if (Test-Path -LiteralPath $path) {
      Remove-Item -LiteralPath $path -Recurse -Force
    }
  }
}

$installRoot = Resolve-InstallRoot -Os $TargetOs -InstallMode $Mode -Root $SandboxRoot
New-Item -ItemType Directory -Force -Path $installRoot | Out-Null

# Install pass 1 and pass 2 to prove idempotence.
Ensure-Layout -Root $installRoot
Ensure-Layout -Root $installRoot
Assert-Layout -Root $installRoot

# Simulate user-created project content that must survive uninstall.
$projectFile = Join-Path $installRoot "projects/user-content.txt"
Set-Content -LiteralPath $projectFile -Value "preserve-me" -Encoding utf8

# Uninstall installer-owned paths and verify contract.
Uninstall-Owned -Root $installRoot

if (-not (Test-Path -LiteralPath (Join-Path $installRoot "projects"))) {
  throw "Uninstall contract violation: projects directory was removed"
}

if (-not (Test-Path -LiteralPath $projectFile)) {
  throw "Uninstall contract violation: user project content was removed"
}

$mustBeAbsent = @("config", "logs", "cache", "messages", "registry", "bin", "temp")
foreach ($name in $mustBeAbsent) {
  $path = Join-Path $installRoot $name
  if (Test-Path -LiteralPath $path) {
    throw "Uninstall contract violation: installer-owned path still present: $path"
  }
}

Write-Host "Installer contract checks passed for $TargetOs/$Mode at $installRoot"
