<#
.SYNOPSIS
  Discover, compile and run every test file under tests/, each with a time limit.
.DESCRIPTION
  The gate for MVP-GATE-1 to MVP-GATE-4 (docs/implementation/MVP-SPECIFICATION.md §8).
  - Every .nim file under tests/ is a test, except tests/harness.nim.
  - Each test runs alone, under a time limit. Hitting the limit is a failure.
  - -Fast skips tests that import net or osproc (sockets and processes).
  - tests/KNOWN_FAILURES.txt lists files expected to fail, with a reason. A listed file
    that fails is reported as KNOWN. A listed file that passes fails the gate, so the
    list never goes stale.
  Logs and binaries go to tests/tmp/ (ignored by git).
.PARAMETER Fast
  Skip tests that import net or osproc (the fast check, MVP-GATE-4).
.PARAMETER TimeoutSeconds
  Time limit per test file. Default 90.
.EXAMPLE
  .\scripts\verify\run_tests.ps1
.EXAMPLE
  .\scripts\verify\run_tests.ps1 -Fast
#>
param(
  [switch]$Fast,
  [int]$TimeoutSeconds = 90
)
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repo = (Get-Location).Path
$testsDir = Join-Path $repo "tests"
$binDir = Join-Path $testsDir "tmp/gate/bin"
$logDir = Join-Path $testsDir "tmp/gate/logs"
New-Item -ItemType Directory -Force -Path $binDir, $logDir | Out-Null

function Get-RelPath([string]$path) {
  return $path.Substring($repo.Length + 1).Replace('\', '/')
}

# Known failures: "<path>  <reason>" per line; '#' starts a comment.
$known = @{}
$knownFile = Join-Path $testsDir "KNOWN_FAILURES.txt"
if (Test-Path $knownFile) {
  foreach ($line in Get-Content $knownFile) {
    $trimmed = $line.Trim()
    if ($trimmed.Length -eq 0 -or $trimmed.StartsWith("#")) { continue }
    $parts = $trimmed -split '\s+', 2
    $known[$parts[0]] = if ($parts.Length -gt 1) { $parts[1] } else { "" }
  }
}

$files = Get-ChildItem -Path $testsDir -Recurse -Filter *.nim |
  Where-Object { $_.Name -ne "harness.nim" -and $_.FullName -notlike "*\tmp\*" } |
  Sort-Object FullName

$results = @()
$problems = @()

foreach ($f in $files) {
  $rel = Get-RelPath $f.FullName
  if ($Fast -and ((Get-Content -Raw $f.FullName) -match '(?m)^\s*import\s.*\b(net|osproc)\b')) { continue }
  $name = [IO.Path]::GetFileNameWithoutExtension($f.Name)
  $exe = Join-Path $binDir "$name.exe"
  $compileLog = Join-Path $logDir "$name.compile.log"
  $runLog = Join-Path $logDir "$name.run.log"

  & nim c --hints:off --warnings:off "-o:$exe" $f.FullName *> $compileLog
  if ($LASTEXITCODE -ne 0) {
    $status = "COMPILE_ERROR"
  } else {
    $proc = Start-Process -FilePath $exe -NoNewWindow -PassThru `
      -RedirectStandardOutput $runLog -RedirectStandardError "$runLog.err"
    $null = $proc.Handle  # Hold the handle now, or ExitCode reads as empty after exit.
    if (-not $proc.WaitForExit($TimeoutSeconds * 1000)) {
      $proc.Kill()
      $status = "TIMEOUT"
    } elseif ($proc.ExitCode -eq 0) {
      $status = "PASS"
    } else {
      $status = "FAIL"
    }
  }

  $isKnown = $known.ContainsKey($rel)
  $outcome = $status
  if ($status -ne "PASS" -and $isKnown) { $outcome = "KNOWN" }
  if ($status -eq "PASS" -and $isKnown) {
    $problems += "${rel}: passes but is listed in tests/KNOWN_FAILURES.txt; remove it"
  }
  if ($status -ne "PASS" -and -not $isKnown) {
    $problems += "${rel}: $status (logs: tests/tmp/gate/logs/$name.*)"
  }
  $results += [pscustomobject]@{ File = $rel; Result = $outcome }
  Write-Host ("{0,-14} {1}" -f $outcome, $rel)
}

Write-Host ""
$results | Group-Object Result | Sort-Object Name |
  ForEach-Object { Write-Host ("{0}: {1}" -f $_.Name, $_.Count) }

if ($problems.Count -gt 0) {
  Write-Host ""
  Write-Host "Gate FAILED:"
  $problems | ForEach-Object { Write-Host "  $_" }
  exit 1
}
Write-Host ""
Write-Host "Gate passed."
exit 0
