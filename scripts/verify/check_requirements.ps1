<#
.SYNOPSIS
  Validate requirements compliance documentation and gates.
.DESCRIPTION
  Checks that the MVP requirements, specification and compliance matrix, the
  long-term REQUIREMENTS.md, DEVELOPMENT-GUIDELINES.md and the ND docs
  checklist exist and are consistent, and that every Nim file follows the
  header comment contract (MVP-DX-4).
  Every MVP requirement ID must have exactly one matrix row, and every matrix
  row must name a real requirement.
  CI workflows, the PR template and release scripts are not checked: the MVP
  targets one machine and defers them (MVP-SPECIFICATION §8).
  Called by: nimble compliance
.EXAMPLE
  .\scripts\verify\check_requirements.ps1
#>
param(
  [string]$RequirementsPath = "docs/implementation/REQUIREMENTS.md",
  [string]$MvpRequirementsPath = "docs/implementation/MVP-REQUIREMENTS.md",
  [string]$MvpSpecificationPath = "docs/implementation/MVP-SPECIFICATION.md",
  [string]$MatrixPath = "docs/implementation/MVP-COMPLIANCE-MATRIX.md",
  [string]$GuidelinesPath = "docs/implementation/DEVELOPMENT-GUIDELINES.md",
  [string]$NdChecklistPath = "docs/implementation/ND_DOCS_CHECKLIST.md"
)

$ErrorActionPreference = "Stop"

$requiredFiles = @(
  $RequirementsPath,
  $MvpRequirementsPath,
  $MvpSpecificationPath,
  $MatrixPath,
  $GuidelinesPath,
  $NdChecklistPath
)

foreach ($path in $requiredFiles) {
  if (-not (Test-Path $path)) {
    Write-Host "Compliance check failed: required file not found: $path" -ForegroundColor Red
    exit 1
  }
}

$content = Get-Content -Path $RequirementsPath -Raw
$mvpContent = Get-Content -Path $MvpRequirementsPath -Raw
$matrixContent = Get-Content -Path $MatrixPath -Raw
$guidelinesContent = Get-Content -Path $GuidelinesPath -Raw
$missing = New-Object System.Collections.Generic.List[string]

# Required high-value sections and examples.
$requiredPatterns = @(
  "## Terms and Definitions",
  "### Core Principle Use Cases",
  "### Core Principle Flow Diagram",
  "### Command Examples \(Expected Output\)",
  "### Runtime Lifecycle Flow Diagram",
  "### Code Comment Requirements",
  "## Compliance Testing Guidelines",
  "### Compliance Gate Requirements"
)

foreach ($pattern in $requiredPatterns) {
  if (-not ($content -match $pattern)) {
    $missing.Add("Missing section/pattern: $pattern")
  }
}

# Required command examples.
$requiredCommandSnippets = @(
  "attach alpha-local",
  "ls",
  "state",
  "detach",
  "ERROR: command requires an attached instance"
)

foreach ($snippet in $requiredCommandSnippets) {
  if (-not ($content.Contains($snippet))) {
    $missing.Add("Missing command example snippet: $snippet")
  }
}

# Mermaid usage requirement for visual clarity.
$mermaidCount = ([regex]::Matches($content, "```mermaid")).Count
if ($mermaidCount -lt 2) {
  $missing.Add("Expected at least 2 mermaid diagrams, found: $mermaidCount")
}

# Ensure referenced tests exist.
$expectedTestFiles = @(
  "tests/unit/console_status_test.nim",
  "tests/unit/reconciliation_test.nim"
)

foreach ($testFile in $expectedTestFiles) {
  if (-not (Test-Path $testFile)) {
    $missing.Add("Missing expected test file: $testFile")
  }
}

# MVP matrix checks: one row per requirement ID, and no row without one.
$requirementIds = [regex]::Matches($mvpContent, '(?m)^- \*\*(MVP-[A-Z]+-\d+)\*\*') |
  ForEach-Object { $_.Groups[1].Value }
$matrixIds = [regex]::Matches($matrixContent, '(?m)^\| (MVP-[A-Z]+-\d+) \|') |
  ForEach-Object { $_.Groups[1].Value }

if ($requirementIds.Count -eq 0) {
  $missing.Add("No requirement IDs found in $MvpRequirementsPath")
}

foreach ($id in $requirementIds) {
  $rows = @($matrixIds | Where-Object { $_ -eq $id }).Count
  if ($rows -eq 0) {
    $missing.Add("Requirement $id has no row in $MatrixPath")
  } elseif ($rows -gt 1) {
    $missing.Add("Requirement $id has $rows rows in $MatrixPath (expected 1)")
  }
}

foreach ($id in ($matrixIds | Sort-Object -Unique)) {
  if ($requirementIds -notcontains $id) {
    $missing.Add("Matrix row $id names no requirement in $MvpRequirementsPath")
  }
}

# Development guidelines structure checks.
$requiredGuidelinePatterns = @(
  "# Wilder Cosmos Runtime - Development Guidelines",
  "## Standard Development Loop",
  "## Requirement Change Checklist",
  "## Code Comment Contract",
  "## PR Evidence Checklist",
  "## Development Flow Diagram",
  "## ND-Friendly Writing Rules"
)

foreach ($pattern in $requiredGuidelinePatterns) {
  if (-not ($guidelinesContent -match $pattern)) {
    $missing.Add("Missing guidelines section/pattern: $pattern")
  }
}

$requiredGuidelineSnippets = @(
  "nimble compliance",
  "nimble verify",
  "```mermaid"
)

foreach ($snippet in $requiredGuidelineSnippets) {
  if (-not ($guidelinesContent.Contains($snippet))) {
    $missing.Add("Missing guidelines snippet: $snippet")
  }
}

# Header template and generator artifact checks.
$requiredHeaderArtifacts = @(
  "templates/headers/runtime_header.tpl",
  "templates/headers/cosmos_header.tpl",
  "templates/headers/test_header.tpl",
  "templates/headers/example_header.tpl",
  "templates/headers/style_template_header.tpl",
  "scripts/dev/new_nim_module.ps1"
)

foreach ($artifact in $requiredHeaderArtifacts) {
  if (-not (Test-Path $artifact)) {
    $missing.Add("Missing header generation artifact: $artifact")
  }
}

$requiredCompletionArtifacts = @(
  "tests/unit/security_boundary_test.nim",
  "tests/unit/core_principles_test.nim"
)

foreach ($artifact in $requiredCompletionArtifacts) {
  if (-not (Test-Path $artifact)) {
    $missing.Add("Missing completion artifact: $artifact")
  }
}

# Nim code comment contract checks.
$nimFiles = Get-ChildItem -Recurse -File | Where-Object { $_.Extension -eq ".nim" -and $_.FullName -notmatch "\\nimcache\\" }
foreach ($nimFile in $nimFiles) {
  $lines = Get-Content -Path $nimFile.FullName
  if ($lines.Count -eq 0) {
    $missing.Add("Empty Nim file: $($nimFile.FullName)")
    continue
  }

  $firstProcIndex = -1
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^\s*proc\s+') {
      $firstProcIndex = $i
      break
    }
  }

  $headerEnd = if ($firstProcIndex -ge 0) { [Math]::Max(0, $firstProcIndex - 1) } else { [Math]::Min($lines.Count - 1, 40) }
  $headerText = ($lines[0..$headerEnd] -join "`n")

  if (-not ($headerText -match '(?im)^\s*#\s*Wilder\s+Cosmos\s+')) {
    $missing.Add("Missing module identity line 'Wilder Cosmos <version>' in $($nimFile.FullName)")
  }
  if (-not ($headerText -match '(?im)^\s*#\s*Module\s*name:')) {
    $missing.Add("Missing module identity line 'Module name' in $($nimFile.FullName)")
  }
  if (-not ($headerText -match '(?im)^\s*#\s*Module\s*Path:')) {
    $missing.Add("Missing module identity line 'Module Path' in $($nimFile.FullName)")
  }

  if (-not ($headerText -match '(?im)^\s*#\s*Summary:')) {
    $missing.Add("Missing module header Summary in $($nimFile.FullName)")
  }
  if (-not ($headerText -match '(?im)^\s*#\s*Simile:')) {
    $missing.Add("Missing module header Simile in $($nimFile.FullName)")
  }
  if (-not ($headerText -match '(?im)^\s*#\s*Memory\s*note:')) {
    $missing.Add("Missing module header Memory note in $($nimFile.FullName)")
  }
  if (-not ($headerText -match '(?im)^\s*#\s*Flow:')) {
    $missing.Add("Missing module header Flow in $($nimFile.FullName)")
  }

  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^\s*proc\s+') {
      $prev = if ($i -gt 0) { $lines[$i - 1].Trim() } else { '' }
      if ($prev -notmatch '^#\s*Flow:') {
        $missing.Add("Missing Flow comment before proc in $($nimFile.FullName):$($i + 1)")
      }
    }
  }
}

if ($missing.Count -gt 0) {
  Write-Host "Compliance check failed:" -ForegroundColor Red
  foreach ($entry in $missing) {
    Write-Host " - $entry" -ForegroundColor Red
  }
  exit 1
}

Write-Host "Compliance check passed." -ForegroundColor Green
exit 0
