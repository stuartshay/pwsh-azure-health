# Ensure pre-commit uses a workspace-local cache so hooks run without touching read-only home directories
if (-not $Env:PRE_COMMIT_HOME) {
    try {
        $workspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    } catch {
        $workspaceRoot = $PWD.Path
    }

    $preCommitCache = Join-Path $workspaceRoot '.pre-commit-cache'
    if (-not (Test-Path $preCommitCache)) {
        New-Item -ItemType Directory -Path $preCommitCache | Out-Null
    }

    $Env:PRE_COMMIT_HOME = $preCommitCache
}

# PowerShell Profile with Git Branch and Azure Subscription Display

<#
.SYNOPSIS
    Custom PowerShell prompt function displaying current path, Git branch, and Azure subscription.

.DESCRIPTION
    This prompt function enhances the default PowerShell prompt by adding:
    - Current directory path (with ~ for home directory)
    - Git branch name (if in a Git repository)
    - Azure subscription name (from Az module or Azure CLI)

    The prompt uses color coding:
    - Cyan for the current path
    - Green for Git branch
    - Yellow for Azure subscription
    - White for prompt indicators

.OUTPUTS
    String
    Returns a space character as the actual prompt text, with colored information displayed via Write-Host.

.EXAMPLE
    PS ~\projects\myapp [main] [Az: MySubscription] PS>
#>
function prompt {
    $currentPath = $PWD.Path.Replace($HOME, '~')

    # Get Git branch information
    $gitBranch = ""
    try {
        $branch = git rev-parse --abbrev-ref HEAD 2>$null
        if ($branch) {
            $gitBranch = " [$branch]"
        }
    } catch {
        Write-Verbose "Not in a git repository or git not available" -Verbose:$false
    }

    # Get Azure subscription information
    $azureInfo = ""

    # Try PowerShell Az module first
    try {
        $context = Get-AzContext -ErrorAction SilentlyContinue
        if ($context -and $context.Subscription) {
            $subscriptionName = $context.Subscription.Name
            $azureInfo = " [Az: $subscriptionName]"
        }
    } catch {
        Write-Verbose "Az module context not available" -Verbose:$false
    }

    # If no Az module context, try Azure CLI
    if (-not $azureInfo) {
        try {
            $azAccount = az account show 2>$null | ConvertFrom-Json
            if ($azAccount -and $azAccount.name) {
                $azureInfo = " [Az: $($azAccount.name)]"
            }
        } catch {
            Write-Verbose "Azure CLI context not available" -Verbose:$false
        }
    }

    # Build prompt string with ANSI color sequences when available
    $segments = @()
    $reset = ''

    if ($PSStyle) {
        $reset = $PSStyle.Reset
        $segments += $PSStyle.Foreground.White + 'PS '
        $segments += $PSStyle.Foreground.Cyan + $currentPath
        if ($gitBranch) {
            $segments += $PSStyle.Foreground.Green + $gitBranch
        }
        if ($azureInfo) {
            $segments += $PSStyle.Foreground.Yellow + $azureInfo
        }
        $segments += $PSStyle.Foreground.White + ' PS>' + $reset + ' '
    }
    else {
        $segments += "PS $currentPath"
        if ($gitBranch) {
            $segments += " $gitBranch"
        }
        if ($azureInfo) {
            $segments += " $azureInfo"
        }
        $segments += ' PS> '
    }

    return ($segments -join '')
}

# Optional: Set window title to current directory
$Host.UI.RawUI.WindowTitle = "PowerShell - $PWD"

Write-Information "PowerShell profile loaded with Git and Azure subscription display" -InformationAction Continue
