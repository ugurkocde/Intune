function New-MgcPkcePair {
    <#
    .SYNOPSIS
        Generates a PKCE (RFC 7636) code verifier + S256 challenge pair.
    .OUTPUTS
        [pscustomobject] with .Verifier and .Challenge (base64url, unpadded)
    #>
    [CmdletBinding()]
    param()

    $verifierBytes = [byte[]]::new(32)
    [System.Security.Cryptography.RandomNumberGenerator]::Fill($verifierBytes)
    $verifier = [Convert]::ToBase64String($verifierBytes).TrimEnd('=').Replace('+','-').Replace('/','_')

    $hash = [System.Security.Cryptography.SHA256]::HashData([System.Text.Encoding]::UTF8.GetBytes($verifier))
    $challenge = [Convert]::ToBase64String($hash).TrimEnd('=').Replace('+','-').Replace('/','_')

    return [pscustomobject]@{
        Verifier  = $verifier
        Challenge = $challenge
        Method    = 'S256'
    }
}
