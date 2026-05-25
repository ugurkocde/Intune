function Get-MgGraphCommunityContext {
    <#
    .SYNOPSIS
        Returns the active MgGraphCommunity connection context (mirrors Get-MgContext).
    #>
    [CmdletBinding()]
    param()

    return $script:MgcContext
}
