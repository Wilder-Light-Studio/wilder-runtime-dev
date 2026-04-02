# Auto-configuration script for Wilder Cosmos project
# Runs automatically when opening the project in VS Code

# Metadata cache loaded from the Nimble package file.
$script:ProjectMeta = [ordered]@{
    RepoName = "repo"
    PackageName = "project"
    ProjectTitle = ""
    Version = "unknown"
    Description = ""
    License = ""
    NimblePath = ""
}

function Get-NimbleValue {
    param(
        [string]$Content,
        [string]$Key
    )

    $escapedKey = [regex]::Escape($Key)
    $pattern = '(?m)^\s*' + $escapedKey + '\s*=\s*"([^"]+)"'
    $match = [regex]::Match($Content, $pattern)
    if ($match.Success) {
        return $match.Groups[1].Value.Trim()
    }

    return $null
}

function Initialize-ProjectMetadata {
    try {
        $gitRoot = git rev-parse --show-toplevel 2>$null
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($gitRoot)) {
            return
        }

        $script:ProjectMeta.RepoName = Split-Path -Path $gitRoot -Leaf

        $nimbleFile = Get-ChildItem -Path $gitRoot -Filter *.nimble -File -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($null -eq $nimbleFile) {
            $script:ProjectMeta.PackageName = $script:ProjectMeta.RepoName
            return
        }

        $script:ProjectMeta.NimblePath = $nimbleFile.FullName
        $nimbleContent = Get-Content -Path $nimbleFile.FullName -Raw

        $name = Get-NimbleValue -Content $nimbleContent -Key "name"
        if ([string]::IsNullOrWhiteSpace($name)) {
            $name = [System.IO.Path]::GetFileNameWithoutExtension($nimbleFile.Name)
        }

        $version = Get-NimbleValue -Content $nimbleContent -Key "version"
        $projectTitle = Get-NimbleValue -Content $nimbleContent -Key "project"
        $description = Get-NimbleValue -Content $nimbleContent -Key "description"
        $license = Get-NimbleValue -Content $nimbleContent -Key "license"

        $script:ProjectMeta.PackageName = $name
        if (-not [string]::IsNullOrWhiteSpace($projectTitle)) { $script:ProjectMeta.ProjectTitle = $projectTitle }
        if (-not [string]::IsNullOrWhiteSpace($version)) { $script:ProjectMeta.Version = $version }
        if (-not [string]::IsNullOrWhiteSpace($description)) { $script:ProjectMeta.Description = $description }
        if (-not [string]::IsNullOrWhiteSpace($license)) { $script:ProjectMeta.License = $license }
    } catch {
        # Keep defaults; shell prompt must stay usable even if metadata parsing fails.
    }
}

Initialize-ProjectMetadata

function Register-GitSessionStopOnExit {
    # Avoid duplicate registrations in the same shell process.
    if ($script:GitSessionStopHookRegistered) {
        return
    }

    Register-EngineEvent -SourceIdentifier PowerShell.Exiting -SupportEvent -Action {
        try {
            $gitRoot = git rev-parse --show-toplevel 2>$null
            if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($gitRoot)) {
                return
            }

            $hashInput = [System.Text.Encoding]::UTF8.GetBytes($gitRoot)
            $hashBytes = [System.Security.Cryptography.SHA256]::Create().ComputeHash($hashInput)
            $hash = [System.BitConverter]::ToString($hashBytes).Replace("-", "").Substring(0, 16)
            $mutexName = "Global\WilderCosmosGitSessionStop_$hash"

            $mutex = [System.Threading.Mutex]::new($false, $mutexName)
            $hasHandle = $false
            try {
                try {
                    $hasHandle = $mutex.WaitOne(0, $false)
                } catch [System.Threading.AbandonedMutexException] {
                    # If another process abandoned the mutex, we still own it now.
                    $hasHandle = $true
                }

                if (-not $hasHandle) {
                    return
                }

                git session stop -m "Cosmos Runtime Session complete" | Out-Null
            } finally {
                if ($hasHandle) {
                    $mutex.ReleaseMutex()
                }

                $mutex.Dispose()
            }
        } catch {
            # Exit hook should stay silent and never block shell teardown.
        }
    } | Out-Null

    $script:GitSessionStopHookRegistered = $true
}

Register-GitSessionStopOnExit

# Session shortcuts
function global:ss {
    if ($args.Count -eq 0) {
        Write-Host "Usage: ss <comment>" -ForegroundColor Yellow
        return
    }
    $message = $args -join ' '
    git session start -m "$message"
}

function global:st {
    git session stop
}

function global:sp {
    git session pause
}

function global:sr {
    git session resume
}

function global:sta {
    git session status
}

# Define prompt function in global scope
function global:Get-GitPrompt {
    # Get current directory
    $currentDir = Get-Location
    
    # Try to find git root
    try {
        $gitRoot = git rev-parse --show-toplevel 2>$null
        if ($LASTEXITCODE -ne 0) {
            $gitRoot = $null
        }
    } catch {
        $gitRoot = $null
    }
    
    if ($null -eq $gitRoot) {
        # Not in a git repo, show relative path from current directory
        $currentPath = $currentDir.Path.Replace("\", "/")
        return "no-git: $($currentDir.Name)> "
    }
    
    # Normalize both paths to use forward slashes
    $currentPath = $currentDir.Path.Replace("\", "/")
    $gitRootPath = $gitRoot.Replace("\", "/")
    $projectName = $script:ProjectMeta.PackageName
    if ([string]::IsNullOrWhiteSpace($projectName)) {
        $projectName = Split-Path -Path $gitRoot -Leaf
    }
    
    # Get relative path from git root
    $relativePath = $currentPath.Replace($gitRootPath, "")
    if ($relativePath -eq "") {
        $relativePath = "/"  # Project root shows as "/"
    } elseif ($relativePath.StartsWith("/")) {
        $relativePath = $relativePath.Substring(1)  # Remove leading slash
    }
    
    # Try to get current branch
    try {
        $branch = git branch --show-current 2>$null
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrEmpty($branch)) {
            # Fallback: try to get branch from git branch command
            $branch = git branch 2>$null | Where-Object { $_.Trim().StartsWith("*") } | ForEach-Object { $_.Trim().Substring(2) }
            if ([string]::IsNullOrEmpty($branch)) {
                $branch = "unknown"
            }
        }
    } catch {
        $branch = "unknown"
    }
    
    # Format prompt with repo name
    if ($relativePath -eq "/") {
        return "$($branch): $($projectName)/> "
    } else {
        return "$($branch): $($projectName)/$($relativePath)> "
    }
}

# Override the prompt function
function global:prompt {
    return Get-GitPrompt
}

Write-Host "[OK] Custom prompt loaded!" -ForegroundColor Green
$displayTitle = $script:ProjectMeta.ProjectTitle
if ([string]::IsNullOrWhiteSpace($displayTitle)) {
    $displayTitle = "$($script:ProjectMeta.PackageName) v$($script:ProjectMeta.Version)"
}
Write-Host "[READY] $displayTitle workspace ready!" -ForegroundColor Blue
if (-not [string]::IsNullOrWhiteSpace($script:ProjectMeta.License)) {
    Write-Host "[LICENSE] $($script:ProjectMeta.License)" -ForegroundColor DarkGray
}

# Quick commands reminder
Write-Host ""
Write-Host "[COMMANDS] Quick commands:" -ForegroundColor White
Write-Host "  nimble compliance                     # Validate requirements gates" -ForegroundColor Gray
Write-Host "  nimble test                           # Compile-check planning test stubs" -ForegroundColor Gray
Write-Host "  nimble verify                         # Run compliance then tests" -ForegroundColor Gray
Write-Host "  ./scripts/check_requirements.ps1      # Direct compliance script" -ForegroundColor Gray
Write-Host "  git status --short                    # Show working tree changes" -ForegroundColor Gray
Write-Host "  ss <comment>                          # git session start -m `"<comment>`"" -ForegroundColor Gray
Write-Host "  st                                    # git session stop" -ForegroundColor Gray
Write-Host "  sp                                    # git session pause" -ForegroundColor Gray
Write-Host "  sr                                    # git session resume" -ForegroundColor Gray
Write-Host "  sta                                   # git session status" -ForegroundColor Gray
Write-Host ""
