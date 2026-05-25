function Invoke-MgcRefreshTokenAuth {
    <#
    .SYNOPSIS
        Exchanges a refresh token for a new access token (silent re-auth).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$LoginEndpoint,
        [Parameter(Mandatory)][string]$TenantSegment,
        [Parameter(Mandatory)][string]$ClientId,
        [Parameter(Mandatory)][string]$RefreshToken,
        [Parameter(Mandatory)][string[]]$Scopes
    )

    $body = @{
        client_id     = $ClientId
        grant_type    = 'refresh_token'
        refresh_token = $RefreshToken
        scope         = ($Scopes -join ' ')
    }
    return Invoke-MgcTokenEndpoint -Url "$LoginEndpoint/$TenantSegment/oauth2/v2.0/token" -Body $body
}
