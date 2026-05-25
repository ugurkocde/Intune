function Invoke-MgcClientCertificateAuth {
    <#
    .SYNOPSIS
        OAuth 2.0 Client Credentials grant using a signed JWT (private_key_jwt).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$LoginEndpoint,
        [Parameter(Mandatory)][string]$TenantSegment,
        [Parameter(Mandatory)][string]$ClientId,
        [Parameter(Mandatory)][System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate,
        [Parameter(Mandatory)][string]$GraphResource
    )

    $tokenUrl = "$LoginEndpoint/$TenantSegment/oauth2/v2.0/token"
    $assertion = New-MgcClientAssertion -ClientId $ClientId -TokenEndpoint $tokenUrl -Certificate $Certificate

    $body = @{
        client_id             = $ClientId
        scope                 = "$GraphResource/.default"
        client_assertion_type = 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer'
        client_assertion      = $assertion
        grant_type            = 'client_credentials'
    }
    return Invoke-MgcTokenEndpoint -Url $tokenUrl -Body $body
}
