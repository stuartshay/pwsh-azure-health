# Azure Functions PowerShell profile.ps1
#
# This profile.ps1 will get executed every "cold start" of your Function App.
# "cold start" occurs when:
#
# * A Function App starts up for the very first time
# * A Function App starts up after being de-allocated due to inactivity
#
# You can define helper functions, run commands, or specify environment variables
# NOTE: any variables defined that are not environment variables will get reset after the first execution

# Authenticate with Azure PowerShell using MSI.
# Remove this if you are not planning on using MSI or Azure PowerShell.
if ($env:MSI_SECRET) {
    Disable-AzContextAutosave -Scope Process | Out-Null
    Connect-AzAccount -Identity
}

# Uncomment the next line to enable legacy AzureRm alias in Azure PowerShell.
# Enable-AzureRmAlias

$profileRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$sharedPath = Join-Path $profileRoot 'shared'

# Import shared modules so they are available to every function.
Get-ChildItem -Path (Join-Path $sharedPath 'Modules') -Filter '*.psm1' -File -ErrorAction SilentlyContinue | ForEach-Object {
    Import-Module $_.FullName -Force
}

# Dot source shared scripts to make helper functions available.
Get-ChildItem -Path (Join-Path $sharedPath 'Scripts') -Filter '*.ps1' -File -ErrorAction SilentlyContinue | ForEach-Object {
    . $_.FullName
}

Write-Host "PowerShell Azure Health Functions Profile loaded."
