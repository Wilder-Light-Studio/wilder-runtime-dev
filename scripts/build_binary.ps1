param(
  [string]$RootPath = ".",
  [string]$MainModule = "src/cosmos_main.nim",
  [string]$OutputPath = "bin/cosmos.exe",
  [string]$ReleaseTag,
  [switch]$Clean
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$resolvedRoot = (Resolve-Path -Path $RootPath).Path
$resolvedMain = Join-Path $resolvedRoot $MainModule
$resolvedOutput = Join-Path $resolvedRoot $OutputPath
$outputDir = Split-Path -Parent $resolvedOutput

if (-not (Test-Path -LiteralPath $resolvedMain)) {
  throw "Main module not found: $resolvedMain"
}

if (-not (Test-Path -LiteralPath $outputDir)) {
  New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
}

if ($Clean -and (Test-Path -LiteralPath $resolvedOutput)) {
  Remove-Item -LiteralPath $resolvedOutput -Force
}

$nimArgs = @(
  "c",
  "-d:release",
  "--opt:speed",
  "-o:$resolvedOutput",
  $resolvedMain
)

Write-Host "Compiling runtime binary..."
& nim @nimArgs
if ($LASTEXITCODE -ne 0) {
  throw "Nim compiler failed with exit code $LASTEXITCODE"
}

if (-not (Test-Path -LiteralPath $resolvedOutput)) {
  throw "Expected output binary was not created: $resolvedOutput"
}

$buildInfoPath = "$resolvedOutput.build-info.json"
$buildInfo = [ordered]@{
  outputPath = (Resolve-Path -LiteralPath $resolvedOutput).Path
  mainModule = $MainModule
  releaseTag = $ReleaseTag
  builtAtUtc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
}

$buildInfo | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $buildInfoPath -Encoding utf8
Write-Host "Built binary: $resolvedOutput"
Write-Host "Build metadata: $buildInfoPath"
