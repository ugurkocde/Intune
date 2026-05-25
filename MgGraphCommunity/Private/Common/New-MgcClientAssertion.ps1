function New-MgcClientAssertion {
    <#
    .SYNOPSIS
        Builds a signed JWT client assertion for certificate-based client credentials.

    .DESCRIPTION
        Creates an RS256-signed JWT with:
          - Header: alg=RS256, typ=JWT, x5t = base64url(SHA-1 of cert raw bytes)
          - Body:   aud (token endpoint), iss/sub (ClientId), jti (random), nbf, exp
        Uses the certificate's private key to sign. The cert MUST have a usable
        private key.

    .PARAMETER ClientId
        App registration Client ID.

    .PARAMETER TokenEndpoint
        Full token endpoint URL (audience of the assertion).

    .PARAMETER Certificate
        X509Certificate2 with private key.

    .PARAMETER LifetimeSeconds
        Assertion lifetime. Defaults to 600 (10 min) - AAD allows up to ~24h.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ClientId,
        [Parameter(Mandatory)][string]$TokenEndpoint,
        [Parameter(Mandatory)][System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate,
        [int]$LifetimeSeconds = 600
    )

    if (-not $Certificate.HasPrivateKey) {
        throw "Certificate has no usable private key."
    }

    $rsa = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($Certificate)
    if (-not $rsa) {
        throw "Certificate private key is not RSA. Only RSA-signed assertions are supported."
    }

    # x5t = base64url(SHA-1(cert raw bytes)) per RFC 7515
    $thumbHash = [System.Security.Cryptography.SHA1]::HashData($Certificate.RawData)
    $x5t = [Convert]::ToBase64String($thumbHash).TrimEnd('=').Replace('+','-').Replace('/','_')

    $header = [ordered]@{
        alg = 'RS256'
        typ = 'JWT'
        x5t = $x5t
    }

    $now = [int][double]::Parse((Get-Date -Date '1970-01-01T00:00:00Z' | New-TimeSpan -End ([DateTime]::UtcNow)).TotalSeconds)
    $body = [ordered]@{
        aud = $TokenEndpoint
        iss = $ClientId
        sub = $ClientId
        jti = [Guid]::NewGuid().ToString('N')
        nbf = $now
        exp = $now + $LifetimeSeconds
    }

    $encode = {
        param($obj)
        $json = $obj | ConvertTo-Json -Compress -Depth 10
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
        return [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+','-').Replace('/','_')
    }

    $segHeader = & $encode $header
    $segBody   = & $encode $body
    $unsigned  = "$segHeader.$segBody"

    $sig = $rsa.SignData(
        [System.Text.Encoding]::ASCII.GetBytes($unsigned),
        [System.Security.Cryptography.HashAlgorithmName]::SHA256,
        [System.Security.Cryptography.RSASignaturePadding]::Pkcs1
    )
    $segSig = [Convert]::ToBase64String($sig).TrimEnd('=').Replace('+','-').Replace('/','_')

    return "$unsigned.$segSig"
}
