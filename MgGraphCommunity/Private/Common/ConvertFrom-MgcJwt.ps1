function ConvertFrom-MgcJwt {
    <#
    .SYNOPSIS
        Decodes the payload of a JSON Web Token without validating the signature.

    .DESCRIPTION
        Splits the JWT, base64url-decodes the payload segment, and returns the parsed
        JSON as a PSCustomObject. Used only for displaying identity/tenant/expiry to
        the user — never trust unsigned token contents for authorization decisions.

    .PARAMETER Token
        The raw JWT string (header.payload.signature).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Token
    )

    $parts = $Token -split '\.'
    if ($parts.Count -lt 2) { throw "Not a valid JWT (expected 3 segments)." }

    $payload = $parts[1].Replace('-','+').Replace('_','/')
    switch ($payload.Length % 4) {
        2 { $payload += '==' }
        3 { $payload += '='  }
    }

    $bytes = [Convert]::FromBase64String($payload)
    $json  = [System.Text.Encoding]::UTF8.GetString($bytes)
    return $json | ConvertFrom-Json
}
