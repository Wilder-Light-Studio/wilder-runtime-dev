<#
.SYNOPSIS
  Generate or verify SHA-256 checksums for release artifacts.
.DESCRIPTION
  For each file provided, generates a .sha256 sidecar file. With -Verify,
  checks existing .sha256 files against actual hashes.
.EXAMPLE
  .\scripts\ops\generate_artifact_checksums.ps1 -Files bin/cosmos.exe
.EXAMPLE
  .\scripts\ops\generate_artifact_checksums.ps1 -Files bin/cosmos.exe -Verify
#>
param(
  [Parameter(Mandatory = $true)]
  [string[]]$Files,

  [switch]$Verify
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-ShaLine {
  param(
    [string]$Path,
    [string]$Hash
  )

  return "$Hash  $([System.IO.Path]::GetFileName($Path))"
}

foreach ($file in $Files) {
  if (-not (Test-Path -LiteralPath $file)) {
    throw "File not found: $file"
  }

  $shaPath = "$file.sha256"
  $actualHash = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()

  if ($Verify) {
    if (-not (Test-Path -LiteralPath $shaPath)) {
      throw "Checksum file not found: $shaPath"
    }

    $content = (Get-Content -LiteralPath $shaPath -Raw).Trim()
    if ([string]::IsNullOrWhiteSpace($content)) {
      throw "Checksum file is empty: $shaPath"
    }

    $expectedHash = ($content -split "\s+")[0].ToLowerInvariant()
    if ($expectedHash -ne $actualHash) {
      throw "Checksum mismatch for $file. Expected $expectedHash, got $actualHash"
    }

    Write-Host "Verified checksum for $file"
    continue
  }

  $line = Get-ShaLine -Path $file -Hash $actualHash
  Set-Content -LiteralPath $shaPath -Value $line -Encoding utf8
  Write-Host "Wrote checksum: $shaPath"
}
