function Clear-MgcTokenCache {
    <#
    .SYNOPSIS
        Clears the in-memory token cache and optionally deletes the on-disk cache file.

    .PARAMETER IncludeDisk
        If set, also remove the persistent cache file from %LOCALAPPDATA%.
    #>
    [CmdletBinding()]
    param(
        [switch]$IncludeDisk
    )

    $script:MgcMemoryCache = @{}

    if ($IncludeDisk) {
        $cacheFile = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'MgGraphCommunity/tokens.json'
        if (Test-Path $cacheFile) {
            Remove-Item -Path $cacheFile -Force -ErrorAction SilentlyContinue
        }
    }
}
