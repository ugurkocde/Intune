function Disconnect-MgGraphCommunity {
    <#
    .SYNOPSIS
        Clears MgGraphCommunity state and disconnects the underlying Microsoft.Graph session.

    .PARAMETER ClearCache
        Also delete the on-disk persistent cache file (refresh tokens).
    #>
    [CmdletBinding()]
    param(
        [switch]$ClearCache
    )

    Clear-MgcTokenCache -IncludeDisk:$ClearCache
    $script:MgcContext = $null

    try {
        if (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication) {
            Import-Module Microsoft.Graph.Authentication -ErrorAction SilentlyContinue
            Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
        }
    } catch {
        Write-Verbose "Disconnect-MgGraph cleanup failed (non-fatal): $_"
    }
}
