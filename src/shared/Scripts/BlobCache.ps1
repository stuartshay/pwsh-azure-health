<#
.SYNOPSIS
    Gets blob storage context for caching.
.PARAMETER ContainerName
    The container name.
#>
function Get-BlobCacheContext {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ContainerName
    )

    # Support both connection string and identity-based authentication
    $connectionString = $env:AzureWebJobsStorage
    $storageAccountName = $env:AzureWebJobsStorage__accountname

    if ($connectionString) {
        # Use connection string if available
        $context = New-AzStorageContext -ConnectionString $connectionString
    }
    elseif ($storageAccountName) {
        # Use managed identity (identity-based authentication)
        $context = New-AzStorageContext -StorageAccountName $storageAccountName -UseConnectedAccount
    }
    else {
        throw "AzureWebJobsStorage connection string or AzureWebJobsStorage__accountname is not configured."
    }

    return [pscustomobject]@{
        Context       = $context
        ContainerName = $ContainerName
    }
}

<#
.SYNOPSIS
    Gets a cached item from blob storage.
.PARAMETER ContainerName
    The container name.
.PARAMETER BlobName
    The blob name.
#>
function Get-BlobCacheItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ContainerName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$BlobName
    )

    $ctx = Get-BlobCacheContext -ContainerName $ContainerName

    $container = Get-AzStorageContainer -Name $ContainerName -Context $ctx.Context -ErrorAction SilentlyContinue
    if (-not $container) {
        return $null
    }

    $blob = Get-AzStorageBlob -Context $ctx.Context -Container $ContainerName -Blob $BlobName -ErrorAction SilentlyContinue
    if (-not $blob) {
        return $null
    }

    $content = $blob.ICloudBlob.DownloadText()
    if (-not $content) {
        return $null
    }

    return $content | ConvertFrom-Json -ErrorAction Stop
}

<#
.SYNOPSIS
    Sets a cached item in blob storage.
.PARAMETER ContainerName
    The container name.
.PARAMETER BlobName
    The blob name.
.PARAMETER Content
    The content to cache.
#>
function Set-BlobCacheItem {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ContainerName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$BlobName,

        [Parameter(Mandatory = $true)]
        $Content
    )

    $ctx = Get-BlobCacheContext -ContainerName $ContainerName

    $container = Get-AzStorageContainer -Name $ContainerName -Context $ctx.Context -ErrorAction SilentlyContinue
    if (-not $container) {
        $container = New-AzStorageContainer -Name $ContainerName -Context $ctx.Context -Permission Off
    }

    if ($PSCmdlet.ShouldProcess($BlobName, "Set blob cache item")) {
        $json = $Content | ConvertTo-Json -Depth 6
        $tempFile = [System.IO.Path]::GetTempFileName()
        try {
            $json | Out-File -FilePath $tempFile -Encoding utf8 -NoNewline
            $null = Set-AzStorageBlobContent -Context $ctx.Context -Container $ContainerName -Blob $BlobName -File $tempFile -Force
        }
        finally {
            if (Test-Path $tempFile) {
                Remove-Item $tempFile -Force
            }
        }
    }
}
