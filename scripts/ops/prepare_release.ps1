<#
.SYNOPSIS
  Create dist/v<version> release artifacts.
.DESCRIPTION
  Reads the version from the nimble file, creates a versioned dist directory,
  copies the binary and checksums, and generates the release manifest.
.EXAMPLE
  .\scripts\ops\prepare_release.ps1
.EXAMPLE
  .\scripts\ops\prepare_release.ps1 -Channel preview
#>
param(
  [string]$RootPath = ".",
  [string]$Version,
  [ValidateSet("preview", "stable")]
  [string]$Channel = "stable"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-VersionFromNimble {
  param([string]$NimblePath)

  if (-not (Test-Path -LiteralPath $NimblePath)) {
    throw "Nimble file not found: $NimblePath"
  }

  $content = Get-Content -LiteralPath $NimblePath -Raw
  $match = [regex]::Match($content, 'version\s*=\s*"([^"]+)"')
  if (-not $match.Success) {
    throw "Could not parse version from $NimblePath"
  }

  return $match.Groups[1].Value
}

function Get-ChecksumValue {
  param([string]$ChecksumPath)

  $raw = (Get-Content -LiteralPath $ChecksumPath -Raw).Trim()
  if ([string]::IsNullOrWhiteSpace($raw)) {
    throw "Checksum file is empty: $ChecksumPath"
  }

  return ($raw -split "\s+")[0]
}

$resolvedRoot = (Resolve-Path -Path $RootPath).Path
$nimblePath = Join-Path $resolvedRoot "wilder_cosmos_runtime.nimble"

if ([string]::IsNullOrWhiteSpace($Version)) {
  $Version = Get-VersionFromNimble -NimblePath $nimblePath
}

$tag = if ($Version.StartsWith("v")) { $Version } else { "v$Version" }
$distRoot = Join-Path $resolvedRoot "dist/$tag"
$binariesDir = Join-Path $distRoot "binaries"
$installersDir = Join-Path $distRoot "installers"
$checksumsDir = Join-Path $distRoot "checksums"
$manifestDir = Join-Path $distRoot "manifest"
$manifestPath = Join-Path $manifestDir "release-manifest.json"

$binaryPath = Join-Path $resolvedRoot "bin/cosmos.exe"
if (-not (Test-Path -LiteralPath $binaryPath)) {
  & (Join-Path $resolvedRoot "scripts/build/build_binary.ps1") -RootPath $resolvedRoot -OutputPath "bin/cosmos.exe" -ReleaseTag $tag
}

if (Test-Path -LiteralPath $distRoot) {
  Remove-Item -LiteralPath $distRoot -Recurse -Force
}

New-Item -ItemType Directory -Force -Path $binariesDir | Out-Null
New-Item -ItemType Directory -Force -Path $installersDir | Out-Null
New-Item -ItemType Directory -Force -Path $checksumsDir | Out-Null
New-Item -ItemType Directory -Force -Path $manifestDir | Out-Null

$binaryArtifactName = "cosmos-windows-amd64.exe"
$binaryArtifactPath = Join-Path $binariesDir $binaryArtifactName
Copy-Item -LiteralPath $binaryPath -Destination $binaryArtifactPath -Force

$installGuideSource = Join-Path $resolvedRoot "docs/public/getting-started/install-windows.md"
$installerScriptSource = Join-Path $resolvedRoot "scripts/ops/install_windows_bundle.ps1"
if (-not (Test-Path -LiteralPath $installGuideSource)) {
  throw "Missing required Windows install guide: $installGuideSource"
}
if (-not (Test-Path -LiteralPath $installerScriptSource)) {
  throw "Missing required installer script: $installerScriptSource"
}

# Package a deterministic installer artifact bundle containing runtime files.
$installerStage = Join-Path $distRoot "_installer_stage"
New-Item -ItemType Directory -Force -Path $installerStage | Out-Null
Copy-Item -LiteralPath $binaryArtifactPath -Destination (Join-Path $installerStage "cosmos.exe") -Force
Copy-Item -LiteralPath $installGuideSource -Destination (Join-Path $installerStage "WINDOWS-INSTALL.md") -Force
Copy-Item -LiteralPath $installerScriptSource -Destination (Join-Path $installerStage "install_windows_bundle.ps1") -Force

$installInstructions = @(
  "Wilder Cosmos Runtime Installer Bundle",
  "",
  "1. Review WINDOWS-INSTALL.md for full Windows installation guidance.",
  "2. Run .\\install_windows_bundle.ps1 to install with mode and PATH prompts.",
  "3. Use -InstallMode user|system and -AddToPath for non-interactive installs.",
  "4. Installer writes metadata in registry/ and preserves projects on uninstall."
)
Set-Content -LiteralPath (Join-Path $installerStage "INSTALL.txt") -Value $installInstructions -Encoding utf8

$installerArtifactName = "cosmos-windows-amd64-installer-$tag.zip"
$installerArtifactPath = Join-Path $installersDir $installerArtifactName
Compress-Archive -Path (Join-Path $installerStage "*") -DestinationPath $installerArtifactPath -Force
Remove-Item -LiteralPath $installerStage -Recurse -Force

$artifacts = @($binaryArtifactPath, $installerArtifactPath)
& (Join-Path $resolvedRoot "scripts/ops/generate_artifact_checksums.ps1") -Files $artifacts

foreach ($artifactPath in $artifacts) {
  $artifactShaInPlace = "$($artifactPath).sha256"
  $checksumTarget = Join-Path $checksumsDir ([System.IO.Path]::GetFileName($artifactShaInPlace))
  Copy-Item -LiteralPath $artifactShaInPlace -Destination $checksumTarget -Force
}

$commit = "unknown"
try {
  $commit = (& git -C $resolvedRoot rev-parse HEAD).Trim()
}
catch {
  $commit = "unknown"
}

$buildId = (Get-Date).ToUniversalTime().ToString("yyyyMMddHHmmss")

foreach ($artifactPath in $artifacts) {
  $checksumPath = "$artifactPath.sha256"
  $checksumValue = Get-ChecksumValue -ChecksumPath $checksumPath
  $artifactName = [System.IO.Path]::GetFileName($artifactPath)

  & (Join-Path $resolvedRoot "scripts/ops/generate_release_manifest.ps1") `
    -OutFile $manifestPath `
    -ArtifactName $artifactName `
    -Version $Version `
    -Channel $Channel `
    -Target "windows-amd64" `
    -ChecksumSha256 $checksumValue `
    -SignatureType "unsigned-scaffold" `
    -SourceCommit $commit `
    -BuildId $buildId
}

Write-Host "Release prepared at: $distRoot"
Write-Host "Binary artifact: $binaryArtifactPath"
Write-Host "Installer artifact: $installerArtifactPath"
Write-Host "Manifest: $manifestPath"
