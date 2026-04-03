param(
  [Parameter(Mandatory = $true)]
  [string]$OutFile,

  [Parameter(Mandatory = $true)]
  [string]$ArtifactName,

  [Parameter(Mandatory = $true)]
  [string]$Version,

  [Parameter(Mandatory = $true)]
  [string]$Channel,

  [Parameter(Mandatory = $true)]
  [string]$Target,

  [Parameter(Mandatory = $true)]
  [string]$ChecksumSha256,

  [Parameter(Mandatory = $true)]
  [string]$SignatureType,

  [Parameter(Mandatory = $true)]
  [string]$SourceCommit,

  [Parameter(Mandatory = $true)]
  [string]$BuildId,

  [string]$PublishedAtUtc
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($PublishedAtUtc)) {
  $PublishedAtUtc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
}

$entry = [ordered]@{
  artifactName   = $ArtifactName
  version        = $Version
  channel        = $Channel
  target         = $Target
  checksumSha256 = $ChecksumSha256
  signatureType  = $SignatureType
  sourceCommit   = $SourceCommit
  buildId        = $BuildId
  publishedAtUtc = $PublishedAtUtc
}

$manifest = @()
if (Test-Path -LiteralPath $OutFile) {
  $raw = Get-Content -LiteralPath $OutFile -Raw
  if (-not [string]::IsNullOrWhiteSpace($raw)) {
    $existing = $raw | ConvertFrom-Json
    if ($existing -is [System.Array]) {
      $manifest = @($existing)
    }
    else {
      $manifest = @($existing)
    }
  }
}

$manifest += [pscustomobject]$entry

$dir = Split-Path -Parent $OutFile
if (-not [string]::IsNullOrWhiteSpace($dir)) {
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
}

$manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutFile -Encoding utf8
Write-Host "Wrote release manifest entry for target '$Target' to $OutFile"
