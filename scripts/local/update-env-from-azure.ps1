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

$envFile = Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath @('..', '.env')

if (-not (Test-Path $envFile)) {
    Write-Error ".env file not found at: $envFile"
    Write-Host "Run: cp .env.template .env" -ForegroundColor Yellow
    exit 1
}

Write-Host "Checking Azure CLI authentication..." -ForegroundColor Cyan

try {
    $accountJson = az account show 2>$null
    if (-not $accountJson) {
        Write-Error "Not logged in to Azure CLI. Run: az login"
        exit 1
    }

    $account = $accountJson | ConvertFrom-Json
    $subscriptionId = $account.id
    $tenantId = $account.tenantId

    Write-Host "✓ Found Azure account" -ForegroundColor Green
    Write-Host "  Subscription: $($account.name)" -ForegroundColor Gray
    Write-Host "  ID: $subscriptionId" -ForegroundColor Gray
    Write-Host "  Tenant: $tenantId" -ForegroundColor Gray
    Write-Host ""

    # Read current .env content
    $envContent = Get-Content -Path $envFile -Raw

    # Update AZURE_SUBSCRIPTION_ID if empty
    if ($envContent -match 'AZURE_SUBSCRIPTION_ID=\s*$') {
        $envContent = $envContent -replace '(AZURE_SUBSCRIPTION_ID=)\s*$', "`$1$subscriptionId"
        Write-Host "✓ Updated AZURE_SUBSCRIPTION_ID" -ForegroundColor Green
    }
    else {
        Write-Host "○ AZURE_SUBSCRIPTION_ID already set" -ForegroundColor Yellow
    }

    # Update AZURE_TENANT_ID if empty
    if ($envContent -match 'AZURE_TENANT_ID=\s*$') {
        $envContent = $envContent -replace '(AZURE_TENANT_ID=)\s*$', "`$1$tenantId"
        Write-Host "✓ Updated AZURE_TENANT_ID" -ForegroundColor Green
    }
    else {
        Write-Host "○ AZURE_TENANT_ID already set" -ForegroundColor Yellow
    }

    # Write updated content back to file
    $envContent | Set-Content -Path $envFile -NoNewline

    Write-Host ""
    Write-Host "✓ .env file updated successfully" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  1. Review and update other variables in .env as needed" -ForegroundColor Gray
    Write-Host "  2. Ensure Azurite is running for local development" -ForegroundColor Gray
    Write-Host "  3. Start the Function App with: func start" -ForegroundColor Gray
}
catch {
    Write-Error "Failed to update .env file: $_"
    exit 1
}
