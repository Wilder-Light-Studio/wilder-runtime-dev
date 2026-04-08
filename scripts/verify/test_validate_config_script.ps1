$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$root = Join-Path (Get-Location) "tests/tmp/validate_config_script"
if (Test-Path $root) { Remove-Item -Recurse -Force $root }
New-Item -ItemType Directory -Force -Path $root | Out-Null

$schemaPath = Join-Path $root "runtime.cue"
$validPath = Join-Path $root "runtime_valid.json"
$missingConfigPath = Join-Path $root "runtime_missing.json"
$invalidJsonPath = Join-Path $root "runtime_invalid_json.json"
$shimDir = Join-Path $root "shim"

New-Item -ItemType Directory -Force -Path $shimDir | Out-Null

@'
runtime: {
  mode: "development" | "debug" | "production"
  transport: "json" | "protobuf"
  logLevel: "trace" | "debug" | "info" | "warn" | "error"
  endpoint: string & !=""
  port: >=1 & <=65535
}
'@ | Set-Content -LiteralPath $schemaPath -Encoding utf8

@'
{
  "mode": "development",
  "transport": "json",
  "logLevel": "info",
  "endpoint": "localhost",
  "port": 8080
}
'@ | Set-Content -LiteralPath $validPath -Encoding utf8

"{ invalid-json" | Set-Content -LiteralPath $invalidJsonPath -Encoding utf8

$cueCmd = Join-Path $shimDir "cue.cmd"
@'
@echo off
if "%1"=="vet" (
  echo %2 | findstr /I /C:"runtime_valid.json" >nul
  if %ERRORLEVEL% EQU 0 exit /b 0
  exit /b 2
)
exit /b 2
'@ | Set-Content -LiteralPath $cueCmd -Encoding ascii

$oldPath = $env:PATH
$env:PATH = "$shimDir;$oldPath"

function Invoke-Validate([string]$configPath) {
  try {
    & powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify/validate_config.ps1 `
      -SchemaPath $schemaPath `
      -ConfigPath $configPath `
      -DefinitionPath runtime *> $null
  }
  catch {
    # Expected for negative cases: return native exit code for assertions.
  }
  return [int]$LASTEXITCODE
}

try {
  $codeValid = Invoke-Validate $validPath
  if ($codeValid -ne 0) {
    throw "Expected valid config to pass, got exit code $codeValid"
  }

  $codeMissing = Invoke-Validate $missingConfigPath
  if ($codeMissing -eq 0) {
    throw "Expected missing config path to fail"
  }

  $codeInvalidJson = Invoke-Validate $invalidJsonPath
  if ($codeInvalidJson -eq 0) {
    throw "Expected invalid JSON config to fail"
  }

  Write-Host "validate_config script tests passed"
}
finally {
  $env:PATH = $oldPath
  if (Test-Path $root) { Remove-Item -Recurse -Force $root }
}
