function Get-BlobCacheContext {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ContainerName
    )

    $connectionString = $env:AzureWebJobsStorage
    if (-not $connectionString) {
        throw "AzureWebJobsStorage connection string is not configured."
    }

    $context = New-AzStorageContext -ConnectionString $connectionString

    return [pscustomobject]@{
        Context       = $context
        ContainerName = $ContainerName
    }
}

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

function Set-BlobCacheItem {
    [CmdletBinding()]
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

    $json = $Content | ConvertTo-Json -Depth 6

    Set-AzStorageBlobContent -Context $ctx.Context -Container $ContainerName -Blob $BlobName -StringContent $json -Force | Out-Null
}
