<#
.SYNOPSIS
  Discover, compile and run every test file under tests/, each with a time limit.
.DESCRIPTION
  The gate for MVP-GATE-1 to MVP-GATE-4 (docs/implementation/MVP-SPECIFICATION.md §8).
  - Every .nim file under tests/ is a test, except tests/harness.nim.
  - Each test runs as its own process, under a time limit. Hitting the limit is a
    failure.
  - Tests are built and run in parallel, up to -Jobs at a time.
  - Daemon tests (files that import net, osproc or cosmos_main) can reach the
    daemon's port, so they run one at a time, alongside the parallel ones.
  - -Fast skips daemon tests (the fast check, MVP-GATE-4).
  - tests/KNOWN_FAILURES.txt lists files expected to fail, with a reason. A listed file
    that fails is reported as KNOWN. A listed file that passes fails the gate, so the
    list never goes stale.
  Results print as each file finishes. Logs and binaries go to tests/tmp/ (ignored
  by git).
.PARAMETER Fast
  Skip daemon tests (the fast check, MVP-GATE-4).
.PARAMETER TimeoutSeconds
  Time limit per test file. Default 90.
.PARAMETER Jobs
  How many builds or runs may happen at once. Default: the number of processors.
  -Jobs 1 runs everything one at a time.
.EXAMPLE
  .\scripts\verify\run_tests.ps1
.EXAMPLE
  .\scripts\verify\run_tests.ps1 -Fast
.EXAMPLE
  .\scripts\verify\run_tests.ps1 -Jobs 1
#>
param(
  [switch]$Fast,
  [int]$TimeoutSeconds = 90,
  [int]$Jobs = [Math]::Max(1, [int]$env:NUMBER_OF_PROCESSORS)
)
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if ($Jobs -lt 1) { $Jobs = 1 }

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

# A daemon test can open sockets, start processes or start the daemon itself.
$daemonTestPattern = '(?m)^\s*import\s.*\b(net|osproc|cosmos_main)\b'

$items = @()
foreach ($f in (Get-ChildItem -Path $testsDir -Recurse -Filter *.nim |
    Where-Object { $_.Name -ne "harness.nim" -and $_.FullName -notlike "*\tmp\*" } |
    Sort-Object FullName)) {
  $isDaemonTest = (Get-Content -Raw $f.FullName) -match $daemonTestPattern
  if ($Fast -and $isDaemonTest) { continue }
  $name = [IO.Path]::GetFileNameWithoutExtension($f.Name)
  $items += [pscustomobject]@{
    Rel = Get-RelPath $f.FullName
    Source = $f.FullName
    Name = $name
    Exe = Join-Path $binDir "$name.exe"
    Log = Join-Path $logDir $name
    Serial = $isDaemonTest
    State = "Pending"   # Pending -> Compiling -> Built -> Running -> Done
    Proc = $null
    Started = $null
    Status = ""
  }
}

$results = @()
$problems = @()
$active = New-Object System.Collections.Generic.List[object]

# Flow: Record one finished test, print its line and note any gate problem.
function Complete-Item($item, [string]$status) {
  $item.State = "Done"
  $item.Status = $status
  $item.Proc = $null
  $isKnown = $known.ContainsKey($item.Rel)
  $outcome = $status
  if ($status -ne "PASS" -and $isKnown) { $outcome = "KNOWN" }
  if ($status -eq "PASS" -and $isKnown) {
    $script:problems += "$($item.Rel): passes but is listed in tests/KNOWN_FAILURES.txt; remove it"
  }
  if ($status -ne "PASS" -and -not $isKnown) {
    $script:problems += "$($item.Rel): $status (logs: tests/tmp/gate/logs/$($item.Name).*)"
  }
  $script:results += [pscustomobject]@{ File = $item.Rel; Result = $outcome }
  Write-Host ("{0,-14} {1}" -f $outcome, $item.Rel)
}

# Flow: Start a process with redirected output and hold its handle for ExitCode.
function Start-Logged([string]$file, [string]$arguments, [string]$logBase) {
  $startArgs = @{
    FilePath = $file
    NoNewWindow = $true
    PassThru = $true
    RedirectStandardOutput = "$logBase.out.log"
    RedirectStandardError = "$logBase.err.log"
  }
  if ($arguments.Length -gt 0) { $startArgs.ArgumentList = $arguments }
  $proc = Start-Process @startArgs
  $null = $proc.Handle  # Hold the handle now, or ExitCode reads as empty after exit.
  return $proc
}

try {
  while (@($items | Where-Object { $_.State -ne "Done" }).Count -gt 0) {
    # Collect finished builds and runs, and stop runs past the time limit.
    foreach ($item in $active.ToArray()) {
      if ($item.State -eq "Compiling" -and $item.Proc.HasExited) {
        $null = $active.Remove($item)
        if ($item.Proc.ExitCode -eq 0) { $item.State = "Built" }
        else { Complete-Item $item "COMPILE_ERROR" }
      } elseif ($item.State -eq "Running") {
        if ($item.Proc.HasExited) {
          $null = $active.Remove($item)
          Complete-Item $item ($(if ($item.Proc.ExitCode -eq 0) { "PASS" } else { "FAIL" }))
        } elseif (((Get-Date) - $item.Started).TotalSeconds -ge $TimeoutSeconds) {
          try { $item.Proc.Kill() } catch [System.InvalidOperationException] { }
          $null = $active.Remove($item)
          Complete-Item $item "TIMEOUT"
        }
      }
    }

    # Fill free slots: runs first, so finished builds don't wait; then builds.
    $serialBusy = @($active | Where-Object { $_.Serial -and $_.State -eq "Running" }).Count -gt 0
    foreach ($item in @($items | Where-Object { $_.State -eq "Built" })) {
      if ($active.Count -ge $Jobs) { break }
      if ($item.Serial) {
        if ($serialBusy) { continue }
        $serialBusy = $true
      }
      $item.Proc = Start-Logged $item.Exe "" "$($item.Log).run"
      $item.Started = Get-Date
      $item.State = "Running"
      $active.Add($item)
    }
    foreach ($item in @($items | Where-Object { $_.State -eq "Pending" })) {
      if ($active.Count -ge $Jobs) { break }
      $nimArgs = "c --hints:off --warnings:off `"-o:$($item.Exe)`" `"$($item.Source)`""
      $item.Proc = Start-Logged "nim" $nimArgs "$($item.Log).compile"
      $item.State = "Compiling"
      $active.Add($item)
    }

    Start-Sleep -Milliseconds 100
  }
} finally {
  # Never leave builds or test processes behind, even if the gate is interrupted.
  foreach ($item in $active.ToArray()) {
    if ($null -ne $item.Proc -and -not $item.Proc.HasExited) {
      try { $item.Proc.Kill() } catch [System.InvalidOperationException] { }
    }
  }
}

Write-Host ""
$results | Group-Object Result | Sort-Object Name |
  ForEach-Object { Write-Host ("{0}: {1}" -f $_.Name, $_.Count) }

if ($problems.Count -gt 0) {
  Write-Host ""
  Write-Host "Gate FAILED:"
  $problems | Sort-Object | ForEach-Object { Write-Host "  $_" }
  exit 1
}
Write-Host ""
Write-Host "Gate passed."
exit 0
