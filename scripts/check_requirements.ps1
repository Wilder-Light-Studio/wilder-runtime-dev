param(
  [string]$RequirementsPath = "docs/implementation/REQUIREMENTS.md",
  [string]$MatrixPath = "docs/implementation/COMPLIANCE-MATRIX.md",
  [string]$GuidelinesPath = "docs/implementation/DEVELOPMENT-GUIDELINES.md",
  [string]$PullRequestTemplatePath = ".github/pull_request_template.md",
  [string]$PreReleaseWorkflowPath = ".github/workflows/pre_release_verify.yml",
  [string]$ReleaseArtifactsWorkflowPath = ".github/workflows/release_artifacts.yml",
  [string]$ReleaseManifestScriptPath = "scripts/generate_release_manifest.ps1"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $RequirementsPath)) {
  Write-Error "Requirements file not found: $RequirementsPath"
  exit 1
}

if (-not (Test-Path $MatrixPath)) {
  Write-Error "Compliance matrix file not found: $MatrixPath"
  exit 1
}

if (-not (Test-Path $GuidelinesPath)) {
  Write-Error "Development guidelines file not found: $GuidelinesPath"
  exit 1
}

if (-not (Test-Path $PullRequestTemplatePath)) {
  Write-Error "Pull request template file not found: $PullRequestTemplatePath"
  exit 1
}

if (-not (Test-Path $PreReleaseWorkflowPath)) {
  Write-Error "Pre-release workflow file not found: $PreReleaseWorkflowPath"
  exit 1
}

if (-not (Test-Path $ReleaseArtifactsWorkflowPath)) {
  Write-Error "Release artifacts workflow file not found: $ReleaseArtifactsWorkflowPath"
  exit 1
}

if (-not (Test-Path $ReleaseManifestScriptPath)) {
  Write-Error "Release manifest script not found: $ReleaseManifestScriptPath"
  exit 1
}

$content = Get-Content -Path $RequirementsPath -Raw
$matrixContent = Get-Content -Path $MatrixPath -Raw
$guidelinesContent = Get-Content -Path $GuidelinesPath -Raw
$prTemplateContent = Get-Content -Path $PullRequestTemplatePath -Raw
$preReleaseWorkflowContent = Get-Content -Path $PreReleaseWorkflowPath -Raw
$releaseArtifactsWorkflowContent = Get-Content -Path $ReleaseArtifactsWorkflowPath -Raw
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
  "tests/console_status_test.nim",
  "tests/reconciliation_test.nim"
)

foreach ($testFile in $expectedTestFiles) {
  if (-not (Test-Path $testFile)) {
    $missing.Add("Missing expected test file: $testFile")
  }
}

# Compliance matrix structure checks.
$requiredMatrixPatterns = @(
  "# Wilder Cosmos Runtime - Compliance Matrix",
  "\| Requirement Area \| Requirement Statement \| Verification Method \| Test Artifact \| Status \|",
  "## Maintenance Rule"
)

foreach ($pattern in $requiredMatrixPatterns) {
  if (-not ($matrixContent -match $pattern)) {
    $missing.Add("Missing matrix section/pattern: $pattern")
  }
}

$requiredMatrixSnippets = @(
  "Core Architectural Principles",
  "Storage and Persistence Requirements",
  "Console Subsystem Requirements",
  "Documentation Requirements",
  "Release and Packaging Requirements"
)

foreach ($snippet in $requiredMatrixSnippets) {
  if (-not ($matrixContent.Contains($snippet))) {
    $missing.Add("Missing matrix mapping snippet: $snippet")
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

# Pull request template structure checks.
$requiredPrTemplatePatterns = @(
  "# Pull Request Template",
  "## Requirements Coverage \(Required\)",
  "## Compliance Matrix Updates \(Required\)",
  "## Verification Evidence \(Required\)",
  "## Command Output Summary \(Required\)",
  "## Documentation and ND-Friendly Quality"
)

foreach ($pattern in $requiredPrTemplatePatterns) {
  if (-not ($prTemplateContent -match $pattern)) {
    $missing.Add("Missing PR template section/pattern: $pattern")
  }
}

$requiredPrTemplateSnippets = @(
  "docs/implementation/COMPLIANCE-MATRIX.md",
  "nimble compliance",
  "nimble verify",
  "Summary, Simile, Memory note, and Flow"
)

foreach ($snippet in $requiredPrTemplateSnippets) {
  if (-not ($prTemplateContent.Contains($snippet))) {
    $missing.Add("Missing PR template snippet: $snippet")
  }
}

# Inactive pre-release workflow checks.
$requiredWorkflowPatterns = @(
  "name: Pre-Release Verify \(Inactive\)",
  "workflow_dispatch:",
  "if: \$\{\{ vars.ENABLE_PRE_RELEASE_CI == 'true' \}\}",
  "ENABLE_PRE_RELEASE_CI"
)

foreach ($pattern in $requiredWorkflowPatterns) {
  if (-not ($preReleaseWorkflowContent -match $pattern)) {
    $missing.Add("Missing pre-release workflow section/pattern: $pattern")
  }
}

if ($preReleaseWorkflowContent -match '(?m)^\s*pull_request:\s*$' -or $preReleaseWorkflowContent -match '(?m)^\s*push:\s*$') {
  $missing.Add("Pre-release workflow must remain inactive and must not include push/pull_request triggers.")
}

# Phase 19A release scaffold checks.
$requiredReleaseWorkflowPatterns = @(
  "name: Release Artifacts \(Phase 19A Scaffold\)",
  "workflow_dispatch:",
  "if: \$\{\{ vars.ENABLE_RELEASE_ARTIFACTS == 'true' \}\}",
  "windows-amd64",
  "linux-amd64",
  "linux-arm64",
  "darwin-amd64",
  "darwin-arm64",
  "generate_release_manifest.ps1"
)

foreach ($pattern in $requiredReleaseWorkflowPatterns) {
  if (-not ($releaseArtifactsWorkflowContent -match $pattern)) {
    $missing.Add("Missing release workflow section/pattern: $pattern")
  }
}

# Header template and generator artifact checks.
$requiredHeaderArtifacts = @(
  "templates/headers/runtime_header.tpl",
  "templates/headers/cosmos_header.tpl",
  "templates/headers/test_header.tpl",
  "templates/headers/example_header.tpl",
  "templates/headers/style_template_header.tpl",
  "scripts/new_nim_module.ps1"
)

foreach ($artifact in $requiredHeaderArtifacts) {
  if (-not (Test-Path $artifact)) {
    $missing.Add("Missing header generation artifact: $artifact")
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
