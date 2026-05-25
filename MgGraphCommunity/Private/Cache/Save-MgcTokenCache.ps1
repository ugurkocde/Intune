function Save-MgcTokenCache {
    <#
    .SYNOPSIS
        Stores tokens for a given cache key. In-memory by default; opt-in to disk.

    .PARAMETER Key
        Cache key, typically "{authority}|{clientId}|{tenantId}".

    .PARAMETER Tokens
        Token response object (must include refresh_token to be worth caching).

    .PARAMETER Persist
        If set, additionally write the entry to disk (DPAPI on Windows, chmod 600 elsewhere).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)][object]$Tokens,
        [switch]$Persist
    )

    # In-memory store (always)
    $script:MgcMemoryCache[$Key] = $Tokens

    if (-not $Persist) { return }
    if (-not $Tokens.refresh_token) { return }

    $cacheDir  = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'MgGraphCommunity'
    $cacheFile = Join-Path $cacheDir 'tokens.json'

    if (-not (Test-Path $cacheDir)) {
        New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
    }

    $payload = $Tokens | ConvertTo-Json -Compress -Depth 5

    if ($IsWindows) {
        $secure    = ConvertTo-SecureString -String $payload -AsPlainText -Force
        $encrypted = ConvertFrom-SecureString -SecureString $secure
        $entry     = [pscustomobject]@{ encrypted = $true;  data = $encrypted; saved = (Get-Date).ToString('o') }
    } else {
        $entry     = [pscustomobject]@{ encrypted = $false; data = $payload;   saved = (Get-Date).ToString('o') }
    }

    $cache = @{}
    if (Test-Path $cacheFile) {
        try {
            $existing = Get-Content $cacheFile -Raw | ConvertFrom-Json
            foreach ($prop in $existing.PSObject.Properties) { $cache[$prop.Name] = $prop.Value }
        } catch {
            Write-Verbose "Existing cache unreadable, starting fresh: $_"
        }
    }
    $cache[$Key] = $entry

    $cache | ConvertTo-Json -Depth 6 | Set-Content -Path $cacheFile -NoNewline

    if (-not $IsWindows) {
        try { & chmod 600 $cacheFile } catch { Write-Verbose "chmod 600 failed: $_" }
    }
}
