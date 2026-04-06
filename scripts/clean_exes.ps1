param(
  [string]$RootPath = "."
)

$ErrorActionPreference = "Stop"

$resolvedRoot = (Resolve-Path -Path $RootPath).Path

$exeFiles = Get-ChildItem -Path $resolvedRoot -Recurse -File -Filter "*.exe" |
  Where-Object {
    $_.FullName -notmatch "[\\/]\.git[\\/]" -and
    $_.FullName -notmatch "[\\/]nimcache[\\/]"
  }

if (-not $exeFiles -or $exeFiles.Count -eq 0) {
  Write-Host "No .exe files found under $resolvedRoot"
  exit 0
}

foreach ($file in $exeFiles) {
  Remove-Item -LiteralPath $file.FullName -Force
  Write-Host "Removed $($file.FullName)"
}

Write-Host "Removed $($exeFiles.Count) .exe file(s)."
exit 0