<#
.SYNOPSIS
    Sets up local development environment for Azure Health Functions.

.DESCRIPTION
    This script installs required PowerShell modules and validates the local development environment.

.EXAMPLE
    .\setup-local-dev.ps1
#>

[CmdletBinding()]
param()

Write-Host "Setting up local development environment..." -ForegroundColor Cyan

# Check PowerShell version
Write-Host "`nChecking PowerShell version..." -ForegroundColor Yellow
$psVersion = $PSVersionTable.PSVersion
if ($psVersion.Major -lt 7) {
    Write-Host "ERROR: PowerShell 7 or later is required. Current version: $psVersion" -ForegroundColor Red
    Write-Host "Download from: https://github.com/PowerShell/PowerShell" -ForegroundColor Yellow
    exit 1
}
Write-Host "  ✓ PowerShell version: $psVersion" -ForegroundColor Green

# Check Azure Functions Core Tools
Write-Host "`nChecking Azure Functions Core Tools..." -ForegroundColor Yellow
$funcVersion = func --version 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Azure Functions Core Tools not found" -ForegroundColor Red
    Write-Host "Install from: https://docs.microsoft.com/en-us/azure/azure-functions/functions-run-local" -ForegroundColor Yellow
    exit 1
}
Write-Host "  ✓ Azure Functions Core Tools version: $funcVersion" -ForegroundColor Green

# Check .NET SDK
Write-Host "`nChecking .NET SDK..." -ForegroundColor Yellow
$dotnetVersion = dotnet --version 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "WARNING: .NET SDK not found. It's recommended for development." -ForegroundColor Yellow
} else {
    Write-Host "  ✓ .NET SDK version: $dotnetVersion" -ForegroundColor Green
}

# Install PowerShell modules
Write-Host "`nInstalling PowerShell modules..." -ForegroundColor Yellow
$modules = @(
    @{ Name = "Az"; Version = "12.*" }
    @{ Name = "Az.ResourceGraph"; Version = "1.*" }
    @{ Name = "Az.Monitor"; Version = "5.*" }
)

foreach ($module in $modules) {
    Write-Host "  Installing $($module.Name)..." -ForegroundColor Cyan
    try {
        $installedModule = Get-Module -ListAvailable -Name $module.Name | Select-Object -First 1
        if ($installedModule) {
            Write-Host "    Module already installed: $($installedModule.Version)" -ForegroundColor Gray
        } else {
            Install-Module -Name $module.Name -Repository PSGallery -Force -AllowClobber -Scope CurrentUser -ErrorAction Stop
            Write-Host "    ✓ Installed $($module.Name)" -ForegroundColor Green
        }
    } catch {
        Write-Host "    ERROR: Failed to install $($module.Name): $_" -ForegroundColor Red
    }
}

# Validate local.settings.json
Write-Host "`nValidating local.settings.json..." -ForegroundColor Yellow
$localSettingsPath = Join-Path $PSScriptRoot ".." "local.settings.json"
if (Test-Path $localSettingsPath) {
    try {
        $localSettings = Get-Content $localSettingsPath | ConvertFrom-Json
        if ([string]::IsNullOrWhiteSpace($localSettings.Values.AZURE_SUBSCRIPTION_ID)) {
            Write-Host "  WARNING: AZURE_SUBSCRIPTION_ID not configured in local.settings.json" -ForegroundColor Yellow
        } else {
            Write-Host "  ✓ local.settings.json configured" -ForegroundColor Green
        }
    } catch {
        Write-Host "  ERROR: Invalid local.settings.json format" -ForegroundColor Red
    }
} else {
    Write-Host "  ERROR: local.settings.json not found" -ForegroundColor Red
}

# Test Azure authentication
Write-Host "`nTesting Azure authentication..." -ForegroundColor Yellow
try {
    $context = Get-AzContext -ErrorAction SilentlyContinue
    if ($context) {
        Write-Host "  ✓ Authenticated as: $($context.Account)" -ForegroundColor Green
        Write-Host "  ✓ Subscription: $($context.Subscription.Name)" -ForegroundColor Green
    } else {
        Write-Host "  WARNING: Not authenticated with Azure. Run 'Connect-AzAccount'" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  WARNING: Azure PowerShell modules not loaded" -ForegroundColor Yellow
}

Write-Host "`n✓ Setup complete!" -ForegroundColor Green
Write-Host "`nNext steps:" -ForegroundColor Cyan
Write-Host "  1. Configure AZURE_SUBSCRIPTION_ID in local.settings.json" -ForegroundColor White
Write-Host "  2. Run 'Connect-AzAccount' to authenticate" -ForegroundColor White
Write-Host "  3. Run 'func start' to start the function app" -ForegroundColor White
