function Invoke-MgcClientSecretAuth {
    <#
    .SYNOPSIS
        OAuth 2.0 Client Credentials grant using a client secret.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$LoginEndpoint,
        [Parameter(Mandatory)][string]$TenantSegment,
        [Parameter(Mandatory)][string]$ClientId,
        [Parameter(Mandatory)][string]$ClientSecret,
        [Parameter(Mandatory)][string]$GraphResource
    )

    $body = @{
        client_id     = $ClientId
        client_secret = $ClientSecret
        scope         = "$GraphResource/.default"
        grant_type    = 'client_credentials'
    }
    return Invoke-MgcTokenEndpoint -Url "$LoginEndpoint/$TenantSegment/oauth2/v2.0/token" -Body $body
}
