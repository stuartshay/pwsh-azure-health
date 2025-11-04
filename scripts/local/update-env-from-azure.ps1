#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Populates .env file with values from Azure CLI
.DESCRIPTION
    Retrieves subscription and tenant information from Azure CLI
    and updates the .env file with these values.
.EXAMPLE
    ./scripts/local/update-env-from-azure.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

<#
.SYNOPSIS
    Writes an informational message with optional ANSI coloring.
.DESCRIPTION
    Wraps Write-Information so status updates avoid using Write-Host.
.PARAMETER Message
    Text to display.
.PARAMETER Color
    Optional color name applied when ANSI styling is available.
#>
function Write-Message {
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet('Default', 'Cyan', 'Gray', 'Green', 'Red', 'Yellow')]
        [string]$Color = 'Default'
    )

    $prefix = ''
    $suffix = ''

    if ($PSStyle) {
        switch ($Color) {
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

$envFile = Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath @('..', '.env')

if (-not (Test-Path $envFile)) {
    Write-Error ".env file not found at: $envFile"
    Write-Message 'Run: cp .env.template .env' -Color Yellow
    exit 1
}

Write-Message 'Checking Azure CLI authentication...' -Color Cyan

try {
    $accountJson = az account show 2>$null
    if (-not $accountJson) {
        Write-Error "Not logged in to Azure CLI. Run: az login"
        exit 1
    }

    $account = $accountJson | ConvertFrom-Json
    $subscriptionId = $account.id
    $tenantId = $account.tenantId

    Write-Message '[OK] Found Azure account' -Color Green
    Write-Message "  Subscription: $($account.name)" -Color Gray
    Write-Message "  ID: $subscriptionId" -Color Gray
    Write-Message "  Tenant: $tenantId" -Color Gray
    Write-Message ''

    # Read current .env content
    $envContent = Get-Content -Path $envFile -Raw

    # Update AZURE_SUBSCRIPTION_ID if empty
    if ($envContent -match 'AZURE_SUBSCRIPTION_ID=\s*$') {
        $envContent = $envContent -replace '(AZURE_SUBSCRIPTION_ID=)\s*$', "`$1$subscriptionId"
        Write-Message '[OK] Updated AZURE_SUBSCRIPTION_ID' -Color Green
    }
    else {
        Write-Message '[INFO] AZURE_SUBSCRIPTION_ID already set' -Color Yellow
    }

    # Update AZURE_TENANT_ID if empty
    if ($envContent -match 'AZURE_TENANT_ID=\s*$') {
        $envContent = $envContent -replace '(AZURE_TENANT_ID=)\s*$', "`$1$tenantId"
        Write-Message '[OK] Updated AZURE_TENANT_ID' -Color Green
    }
    else {
        Write-Message '[INFO] AZURE_TENANT_ID already set' -Color Yellow
    }

    # Write updated content back to file
    $envContent | Set-Content -Path $envFile -NoNewline

    Write-Message ''
    Write-Message '.env file updated successfully' -Color Green
    Write-Message ''
    Write-Message 'Next steps:' -Color Cyan
    Write-Message '  1. Review and update other variables in .env as needed' -Color Gray
    Write-Message '  2. Ensure Azurite is running for local development' -Color Gray
    Write-Message '  3. Start the Function App with: func start' -Color Gray
}
catch {
    Write-Error "Failed to update .env file: $_"
    exit 1
}
