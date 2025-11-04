#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Retrieves Azure Function App keys and saves them locally.

.DESCRIPTION
    Downloads function keys from Azure Function App and saves them to .keys directory
    for local development use. The .keys directory is excluded from git to prevent
    accidentally committing sensitive keys.

.PARAMETER ResourceGroup
    Azure resource group name. Defaults to rg-azure-health-dev.

.PARAMETER FunctionAppName
    Azure Function App name. If not provided, will auto-discover from resource group.

.PARAMETER Environment
    Environment name (dev, prod). Defaults to dev.

.PARAMETER OutputDirectory
    Directory to save keys. Defaults to .keys in repository root.

.EXAMPLE
    ./get-function-keys.ps1

.EXAMPLE
    ./get-function-keys.ps1 -Environment prod

.EXAMPLE
    ./get-function-keys.ps1 -ResourceGroup rg-azure-health-prod -FunctionAppName my-function-app
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$ResourceGroup,

    [Parameter()]
    [string]$FunctionAppName,

    [Parameter()]
    [ValidateSet('dev', 'prod')]
    [string]$Environment = 'dev',

    [Parameter()]
    [string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

<#
.SYNOPSIS
    Writes an informational message with optional ANSI coloring.
.DESCRIPTION
    Wraps Write-Information so scripts can present status updates without using Write-Host.
.PARAMETER Message
    Text to display to the user.
.PARAMETER Color
    Optional color name applied when ANSI styling is available.
#>
function Write-Message {
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet('Default', 'Blue', 'Cyan', 'Gray', 'Green', 'Red', 'Yellow')]
        [string]$Color = 'Default'
    )

    $prefix = ''
    $suffix = ''

    if ($PSStyle) {
        switch ($Color) {
            'Blue'   { $prefix = $PSStyle.Foreground.Blue }
            'Cyan'   { $prefix = $PSStyle.Foreground.Cyan }
            'Gray'   { $prefix = $PSStyle.Foreground.Gray }
            'Green'  { $prefix = $PSStyle.Foreground.Green }
            'Red'    { $prefix = $PSStyle.Foreground.Red }
            'Yellow' { $prefix = $PSStyle.Foreground.Yellow }
        }

        if ($prefix) {
            $suffix = $PSStyle.Reset
        }
    }

    Write-Information ("{0}{1}{2}" -f $prefix, $Message, $suffix)
}

<#
.SYNOPSIS
    Displays a formatted header block in script output.
.DESCRIPTION
    Emits a blank line, a colored separator, the supplied message, and another separator.
.PARAMETER Message
    Header text to display.
#>
function Write-Header {
    param([string]$Message)
    Write-Message ''
    Write-Message '========================================' -Color Blue
    Write-Message $Message -Color Blue
    Write-Message '========================================' -Color Blue
    Write-Message ''
}

# Determine repository root
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (-not $OutputDirectory) {
    $OutputDirectory = Join-Path $repoRoot ".keys"
}

# Set default resource group if not provided
if (-not $ResourceGroup) {
    $ResourceGroup = "rg-azure-health-$Environment"
}

Write-Header "Azure Function Keys Retrieval"

Write-Message 'Configuration:' -Color Yellow
Write-Message "  Environment:     $Environment"
Write-Message "  Resource Group:  $ResourceGroup"
Write-Message "  Output Dir:      $OutputDirectory"
Write-Message ''

# Check if Azure CLI is installed
try {
    $azVersion = az version --output json | ConvertFrom-Json
    Write-Message "[OK] Azure CLI detected (version: $($azVersion.'azure-cli'))" -Color Green
}
catch {
    Write-Message '[ERROR] Azure CLI not found. Please install Azure CLI first.' -Color Red
    Write-Message '  Install from: https://docs.microsoft.com/cli/azure/install-azure-cli'
    exit 1
}

# Check if logged in
Write-Message ''
Write-Message 'Checking Azure authentication...' -Color Yellow
try {
    $account = az account show --output json | ConvertFrom-Json
    Write-Message "[OK] Logged in as: $($account.user.name)" -Color Green
    Write-Message "  Subscription: $($account.name)"
}
catch {
    Write-Message "[ERROR] Not logged in to Azure. Please run 'az login' first." -Color Red
    exit 1
}

# Auto-discover Function App if not provided
if (-not $FunctionAppName) {
    Write-Message ''
    Write-Message 'Discovering Function App in resource group...' -Color Yellow

    $functionApps = az functionapp list --resource-group $ResourceGroup --output json | ConvertFrom-Json

    if (-not $functionApps -or $functionApps.Count -eq 0) {
        Write-Message "[ERROR] No Function Apps found in resource group: $ResourceGroup" -Color Red
        exit 1
    }

    $FunctionAppName = $functionApps[0].name
    Write-Message "[OK] Found Function App: $FunctionAppName" -Color Green
}

# Create output directory
if (-not (Test-Path $OutputDirectory)) {
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    Write-Message "[OK] Created directory: $OutputDirectory" -Color Green
}

Write-Message ''
Write-Header "Retrieving Function Keys"

# Get host keys (master keys)
Write-Message 'Retrieving host keys...' -Color Yellow
try {
    $hostKeys = az functionapp keys list `
        --name $FunctionAppName `
        --resource-group $ResourceGroup `
        --output json | ConvertFrom-Json

    Write-Message '[OK] Retrieved host keys' -Color Green

    # Save master key
    if ($hostKeys.masterKey) {
        $masterKeyFile = Join-Path $OutputDirectory "master.key"
        $hostKeys.masterKey | Out-File -FilePath $masterKeyFile -NoNewline -Encoding utf8
        Write-Message "  -> Saved master key to: $masterKeyFile"
    }

    # Save default function key
    if ($hostKeys.functionKeys.default) {
        $defaultKeyFile = Join-Path $OutputDirectory "default.key"
        $hostKeys.functionKeys.default | Out-File -FilePath $defaultKeyFile -NoNewline -Encoding utf8
        Write-Message "  -> Saved default key to: $defaultKeyFile"
    }

    # Save all named function keys
    if ($hostKeys.functionKeys.PSObject.Properties.Name.Count -gt 1) {
        foreach ($keyName in $hostKeys.functionKeys.PSObject.Properties.Name) {
            if ($keyName -ne 'default') {
                $keyValue = $hostKeys.functionKeys.$keyName
                $keyFile = Join-Path $OutputDirectory "$keyName.key"
                $keyValue | Out-File -FilePath $keyFile -NoNewline -Encoding utf8
                Write-Message "  -> Saved $keyName key to: $keyFile"
            }
        }
    }

}
catch {
    Write-Message "[ERROR] Failed to retrieve function keys: $_" -Color Red
    exit 1
}

# Create a summary file with key information
Write-Message ''
Write-Message 'Creating summary file...' -Color Yellow

$summaryFile = Join-Path $OutputDirectory "keys-info.txt"
$functionUrl = "https://$FunctionAppName.azurewebsites.net"

$summary = @"
Azure Function Keys Summary
===========================
Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

Function App: $FunctionAppName
Resource Group: $ResourceGroup
Environment: $Environment
Function URL: $functionUrl

Available Keys:
"@

# List all key files
Get-ChildItem -Path $OutputDirectory -Filter "*.key" | ForEach-Object {
    $keyName = $_.BaseName
    $summary += "`n  - $keyName ($($_.Name))"
}

$summary += @"


Usage Examples:
===============

1. Using default function key (query parameter):
   curl "$functionUrl/api/GetServiceHealth?code=`$(cat .keys/default.key)"

2. Using function key (header):
   curl -H "x-functions-key: `$(cat .keys/default.key)" $functionUrl/api/GetServiceHealth

3. PowerShell with function key:
   `$key = Get-Content .keys/default.key -Raw
   `$headers = @{ "x-functions-key" = `$key }
   Invoke-RestMethod -Uri "$functionUrl/api/GetServiceHealth" -Headers `$headers

4. Test health endpoint (no auth required):
   curl $functionUrl/api/health

Security Notes:
===============
- Keys are saved in .keys/ directory
- This directory is excluded from git (.gitignore)
- Never commit keys to source control
- Rotate keys regularly for security
- Use master key only for administrative tasks
- Use function keys for API access

Key Files:
==========
"@

Get-ChildItem -Path $OutputDirectory -Filter "*.key" | ForEach-Object {
    $summary += "`n  $($_.FullName)"
}

$summary | Out-File -FilePath $summaryFile -Encoding utf8
Write-Message "[OK] Saved summary to: $summaryFile" -Color Green

Write-Message ''
Write-Header "Success!"

Write-Message 'Function keys have been downloaded and saved to:' -Color Green
Write-Message "  $OutputDirectory"
Write-Message ''
Write-Message 'Key files:' -Color Yellow
Get-ChildItem -Path $OutputDirectory -Filter "*.key" | ForEach-Object {
    Write-Message "  - $($_.Name)"
}
Write-Message ''
Write-Message "See $summaryFile for usage examples" -Color Blue
Write-Message ''
Write-Message 'Remember: Never commit these keys to git!' -Color Red
Write-Message ''
