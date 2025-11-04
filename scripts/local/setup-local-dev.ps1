# encoding: utf-8
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

Write-Information "Setting up local development environment..." -InformationAction Continue

# Check PowerShell version
Write-Information "`nChecking PowerShell version..." -InformationAction Continue
$psVersion = $PSVersionTable.PSVersion
if ($psVersion.Major -lt 7) {
    Write-Information "ERROR: PowerShell 7 or later is required. Current version: $psVersion" -InformationAction Continue
    Write-Information "Download from: https://github.com/PowerShell/PowerShell" -InformationAction Continue
    exit 1
}
Write-Information "  [OK] PowerShell version: $psVersion" -InformationAction Continue

# Check Azure Functions Core Tools
Write-Information "`nChecking Azure Functions Core Tools..." -InformationAction Continue
$funcVersion = func --version 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Information "ERROR: Azure Functions Core Tools not found" -InformationAction Continue
    Write-Information "Install from: https://docs.microsoft.com/en-us/azure/azure-functions/functions-run-local" -InformationAction Continue
    exit 1
}
Write-Information "  [OK] Azure Functions Core Tools version: $funcVersion" -InformationAction Continue

# Check .NET SDK
Write-Information "`nChecking .NET SDK..." -InformationAction Continue
$dotnetVersion = dotnet --version 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Information "WARNING: .NET SDK not found. It's recommended for development." -InformationAction Continue
}
else {
    Write-Information "  [OK] .NET SDK version: $dotnetVersion" -InformationAction Continue
}

# Install PowerShell modules
Write-Information "`nInstalling PowerShell modules..." -InformationAction Continue
$modules = @(
    @{ Name = "Az"; Version = "12.*" }
    @{ Name = "Az.ResourceGraph"; Version = "1.*" }
    @{ Name = "Az.Monitor"; Version = "5.*" }
)

foreach ($module in $modules) {
    Write-Information "  Installing $($module.Name)..." -InformationAction Continue
    try {
        $installedModule = Get-Module -ListAvailable -Name $module.Name | Select-Object -First 1
        if ($installedModule) {
            Write-Information "    Module already installed: $($installedModule.Version)" -InformationAction Continue
        }
        else {
            Install-Module -Name $module.Name -Repository PSGallery -Force -AllowClobber -Scope CurrentUser -ErrorAction Stop
            Write-Information "    [OK] Installed $($module.Name)" -InformationAction Continue
        }
    }
    catch {
        Write-Information "    ERROR: Failed to install $($module.Name): $_" -InformationAction Continue
    }
}

# Validate local.settings.json
Write-Information "`nValidating local.settings.json..." -InformationAction Continue
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$localSettingsPath = Join-Path -Path $repoRoot -ChildPath "src" -AdditionalChildPath "local.settings.json"
if (Test-Path $localSettingsPath) {
    try {
        $localSettings = Get-Content $localSettingsPath | ConvertFrom-Json
        if ([string]::IsNullOrWhiteSpace($localSettings.Values.AZURE_SUBSCRIPTION_ID)) {
            Write-Information "  WARNING: AZURE_SUBSCRIPTION_ID not configured in local.settings.json" -InformationAction Continue
        }
        else {
            Write-Information "  [OK] local.settings.json configured" -InformationAction Continue
        }
    }
    catch {
        Write-Information "  ERROR: Invalid local.settings.json format" -InformationAction Continue
    }
}
else {
    Write-Information "  ERROR: local.settings.json not found in src/" -InformationAction Continue
}

# Test Azure authentication
Write-Information "`nTesting Azure authentication..." -InformationAction Continue
try {
    $context = Get-AzContext -ErrorAction SilentlyContinue
    if ($context) {
        Write-Information "  [OK] Authenticated as: $($context.Account)" -InformationAction Continue
        Write-Information "  [OK] Subscription: $($context.Subscription.Name)" -InformationAction Continue
    }
    else {
        Write-Information "  WARNING: Not authenticated with Azure. Run 'Connect-AzAccount'" -InformationAction Continue
    }
}
catch {
    Write-Information "  WARNING: Azure PowerShell modules not loaded" -InformationAction Continue
}

Write-Information "`n[OK] Setup complete!" -InformationAction Continue
Write-Information "`nNext steps:" -InformationAction Continue
Write-Information "  1. Configure AZURE_SUBSCRIPTION_ID in src/local.settings.json" -InformationAction Continue
Write-Information "  2. Run 'Connect-AzAccount' to authenticate" -InformationAction Continue
Write-Information "  3. Run 'func start --script-root src' to start the function app" -InformationAction Continue
