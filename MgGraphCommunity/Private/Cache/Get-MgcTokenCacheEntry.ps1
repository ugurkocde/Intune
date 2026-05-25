function Get-MgcTokenCacheEntry {
    <#
    .SYNOPSIS
        Retrieves cached tokens by key. Checks in-memory first, then disk if -IncludeDisk.

    .PARAMETER Key
        Cache key, typically "{authority}|{clientId}|{tenantId}".

    .PARAMETER IncludeDisk
        If set, also consult the on-disk persistent cache.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Key,
        [switch]$IncludeDisk
    )

    if ($script:MgcMemoryCache.ContainsKey($Key)) {
        return $script:MgcMemoryCache[$Key]
    }

    if (-not $IncludeDisk) { return $null }

    $cacheFile = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'MgGraphCommunity/tokens.json'
    if (-not (Test-Path $cacheFile)) { return $null }

    try {
        $cache = Get-Content $cacheFile -Raw | ConvertFrom-Json
        $entry = $cache.$Key
        if (-not $entry) { return $null }

        if ($entry.encrypted) {
            $secure  = ConvertTo-SecureString -String $entry.data
            $payload = ConvertFrom-SecureString -SecureString $secure -AsPlainText
        } else {
            $payload = $entry.data
        }
        $tokens = $payload | ConvertFrom-Json

        # Promote disk entry into memory for the session
        $script:MgcMemoryCache[$Key] = $tokens
        return $tokens
    } catch {
        Write-Verbose "Disk cache read failed for key '$Key': $_"
        return $null
    }
}
