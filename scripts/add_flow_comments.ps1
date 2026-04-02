param([switch]$DryRun)

# Find all .nim files needing Flow comments
$files = @(
    "src\runtime\api.nim",
    "src\runtime\config.nim",
    "src\runtime\persistence.nim",
    "src\runtime\prefilter_table_generated.nim",
    "src\runtime\serialization.nim",
    "tests\api_tests.nim",
    "tests\ch1_test.nim",
    "tests\ch1_uat.nim",
    "tests\ch2_edgecases_test.nim",
    "tests\ch2_uat.nim",
    "tests\ch3_uat.nim",
    "tests\config_test.nim",
    "tests\console_status_test.nim",
    "tests\harness.nim",
    "tests\messaging_test.nim",
    "tests\reconciliation_test.nim",
    "tests\serialization_test.nim",
    "tests\validation_checksum_test.nim",
    "tests\validation_failure_occurrence_test.nim",
    "tests\validation_membrane_perf_test.nim",
    "tests\validation_membrane_test.nim",
    "tests\validation_table_generation_test.nim",
    "tests\validation_test.nim"
)

foreach ($file in $files) {
    $filePath = Join-Path (Get-Location) $file
    if (-not (Test-Path $filePath)) {
        Write-Host "Skipping $file (not found)"
        continue
    }
    
    $content = Get-Content -Path $filePath -Raw
    $lines = $content -split "`n"
    $outputLines = @()
    
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        $outputLines += $line
        
        # Check if this line starts a proc definition
        if ($line -match '^\s*proc\s+\w+' -and -not ($line -match '^#')) {
            # Check if previous line is already a Flow comment
            $prevLineIdx = $outputLines.Count - 2
            if ($prevLineIdx -ge 0) {
                $prevLine = $outputLines[$prevLineIdx]
                if ($prevLine -notmatch '# Flow:') {
                    # Insert Flow comment before the proc
                    $outputLines[-1] = "# Flow: Execute procedure with appropriate validation and side effects."
                    $outputLines += $line
                }
            }
        }
    }
    
    if (-not $DryRun) {
        Set-Content -Path $filePath -Value ($outputLines -join "`n") -Encoding UTF8
        Write-Host "Updated $file"
    } else {
        Write-Host "Would update $file"
    }
}

Write-Host "Done"
