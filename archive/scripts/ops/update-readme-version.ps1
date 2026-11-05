<#
.SYNOPSIS
  Sync the README version badge from the nimble file.
.DESCRIPTION
  Reads the version from wilder_cosmos_runtime.nimble and updates the version
  line in README.md to match. Use -Force to overwrite even if already current.
.EXAMPLE
  .\scripts\ops\update-readme-version.ps1
#>
param([switch]$Force)

# Get paths - assuming script is in scripts/ subdirectory of project root
$projectRoot = Split-Path -Parent (Get-Location)
if (-not (Test-Path (Join-Path $projectRoot "wilder_cosmos_runtime.nimble"))) {
    $projectRoot = (Get-Location).Path
}

$nimbleFile = Join-Path $projectRoot "wilder_cosmos_runtime.nimble"
$readmeFile = Join-Path $projectRoot "README.md"

# Extract version from .nimble file
$nimbleContent = Get-Content $nimbleFile -Raw
$versionMatch = $nimbleContent | Select-String 'version\s*=\s*"([^"]+)"'

if (-not $versionMatch) {
    Write-Error "Could not find version in nimble file at $nimbleFile"
    exit 1
}

$version = $versionMatch.Matches[0].Groups[1].Value
$tagVersion = "v$version"

Write-Host "Current version from .nimble: $version"
Write-Host "Tag version will be: $tagVersion"

# Read README
$readmeContent = Get-Content $readmeFile -Raw

# Extract current version from README
$oldVersionMatch = $readmeContent | Select-String "Version.*?(\d+\.\d+\.\d+)"
if (-not $oldVersionMatch) {
    Write-Error "Could not find Version line in README"
    exit 1
}

$oldVersion = $oldVersionMatch.Matches[0].Groups[1].Value

if ($oldVersion -eq $version) {
    Write-Host "README is already up to date with version $version"
    exit 0
}

Write-Host "README version is out of date: $oldVersion to $version"

if (-not $Force) {
    $response = Read-Host "Update README (Y/n)"
    if ($response -eq 'n' -or $response -eq 'N') {
        Write-Host "Update cancelled"
        exit 0
    }
}

# Update version in README
$newContent = $readmeContent -replace [regex]::Escape("**Version:** $oldVersion"), "**Version:** $version"

# Also update Current Tag Level if present
if ($readmeContent -like "*Current Tag Level*") {
    $oldTag = "v$oldVersion"
    $newContent = $newContent -replace [regex]::Escape("**Current Tag Level**: $oldTag"), "**Current Tag Level**: $tagVersion"
}

# Write back
Set-Content -Path $readmeFile -Value $newContent -Encoding UTF8
Write-Host "README updated successfully"
exit 0
