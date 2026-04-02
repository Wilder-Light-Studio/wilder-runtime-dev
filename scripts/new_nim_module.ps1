param(
  [Parameter(Mandatory = $true)]
  [ValidateSet("runtime", "cosmos", "test", "example", "style")]
  [string]$Kind,

  [Parameter(Mandatory = $true)]
  [string]$Name,

  [Parameter(Mandatory = $true)]
  [string]$RelativePath,

  [Parameter(Mandatory = $true)]
  [string]$Summary,

  [Parameter(Mandatory = $true)]
  [string]$Simile,

  [Parameter(Mandatory = $true)]
  [string]$MemoryNote,

  [Parameter(Mandatory = $true)]
  [string]$Flow,

  [string]$Version = "0.1.1",

  [switch]$Force
)

$ErrorActionPreference = "Stop"

function Get-TemplatePath {
  param([string]$KindValue)

  $map = @{
    runtime = "templates/headers/runtime_header.tpl"
    cosmos  = "templates/headers/cosmos_header.tpl"
    test    = "templates/headers/test_header.tpl"
    example = "templates/headers/example_header.tpl"
    style   = "templates/headers/style_template_header.tpl"
  }

  return $map[$KindValue]
}

function New-GeneratedHeader {
  param(
    [string]$KindValue,
    [string]$ModuleName,
    [string]$ModulePath,
    [string]$ModuleSummary,
    [string]$ModuleSimile,
    [string]$ModuleMemoryNote,
    [string]$ModuleFlow,
    [string]$ModuleVersion
  )

  $templatePath = Get-TemplatePath -KindValue $KindValue
  if (-not (Test-Path -Path $templatePath)) {
    throw "Template not found: $templatePath"
  }

  $template = Get-Content -Path $templatePath -Raw
  $replacements = @{
    "{{VERSION}}" = $ModuleVersion
    "{{MODULE_NAME}}" = $ModuleName
    "{{MODULE_PATH}}" = ($ModulePath -replace "\\", "/")
    "{{SUMMARY}}" = $ModuleSummary
    "{{SIMILE}}" = $ModuleSimile
    "{{MEMORY_NOTE}}" = $ModuleMemoryNote
    "{{FLOW}}" = $ModuleFlow
  }

  foreach ($key in $replacements.Keys) {
    $template = $template.Replace($key, $replacements[$key])
  }

  return $template
}

function Get-BodyForKind {
  param([string]$KindValue)

  switch ($KindValue) {
    "test" {
      return @"
import unittest

# Flow: Define test suites and assertions for this module.
suite "<replace-with-suite-name>":
  test "placeholder":
    check true
"@
    }
    default {
      return @"
import json

# Flow: Initialize module resources and default runtime state.
proc initModule*() =
  discard

# Flow: Release module resources during shutdown.
proc cleanupModule*() =
  discard
"@
    }
  }
}

$footer = @"
# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
"@

$targetPath = Join-Path -Path (Get-Location) -ChildPath $RelativePath
$targetDir = Split-Path -Path $targetPath -Parent

if ((Test-Path -Path $targetPath) -and -not $Force) {
  throw "Target file already exists: $RelativePath. Use -Force to overwrite."
}

if (-not (Test-Path -Path $targetDir)) {
  New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
}

$header = New-GeneratedHeader `
  -KindValue $Kind `
  -ModuleName $Name `
  -ModulePath $RelativePath `
  -ModuleSummary $Summary `
  -ModuleSimile $Simile `
  -ModuleMemoryNote $MemoryNote `
  -ModuleFlow $Flow `
  -ModuleVersion $Version

$body = Get-BodyForKind -KindValue $Kind

$content = @(
  $header.TrimEnd(),
  "",
  $body.TrimEnd(),
  "",
  $footer.TrimEnd()
) -join [Environment]::NewLine

Set-Content -Path $targetPath -Value $content -NoNewline

Write-Host "Generated: $RelativePath"
Write-Host "Template: $(Get-TemplatePath -KindValue $Kind)"
