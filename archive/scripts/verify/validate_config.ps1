<#
.SYNOPSIS
  Validate runtime config against the Cue schema.
.DESCRIPTION
  Exports and validates config/runtime.json against config/runtime.cue using
  the Cue CLI. Requires: cue (https://cuelang.org).
.EXAMPLE
  .\scripts\verify\validate_config.ps1
#>
param(
  [string]$SchemaPath = "config/runtime.cue",
  [string]$ConfigPath = "config/runtime.json",
  [string]$DefinitionPath = "runtime"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $SchemaPath)) {
  Write-Error "Cue schema not found: $SchemaPath"
  exit 1
}

if (-not (Test-Path $ConfigPath)) {
  Write-Error "Exported runtime config not found: $ConfigPath. Generate it first, for example: cue export $SchemaPath -e $DefinitionPath > $ConfigPath"
  exit 1
}

if (-not (Get-Command cue -ErrorAction SilentlyContinue)) {
  Write-Error "Cue CLI not found on PATH. Install cue and rerun validation."
  exit 1
}

try {
  Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json | Out-Null
} catch {
  Write-Error "Exported runtime config is not valid JSON: $ConfigPath"
  exit 1
}

& cue vet $ConfigPath $SchemaPath -d $DefinitionPath
if ($LASTEXITCODE -ne 0) {
  Write-Error "Cue validation failed for $ConfigPath against $SchemaPath"
  exit $LASTEXITCODE
}

Write-Host "Config validation succeeded: $ConfigPath"