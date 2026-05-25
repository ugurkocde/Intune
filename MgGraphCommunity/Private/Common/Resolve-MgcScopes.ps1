function Resolve-MgcScopes {
    <#
    .SYNOPSIS
        Normalizes a scope list for the Microsoft identity platform.

    .DESCRIPTION
        - Bare names (e.g. 'User.Read') are auto-prefixed with the Graph resource URI for the active environment.
        - Fully-qualified scopes (https://...) and OIDC reserved scopes (openid/profile/email/offline_access) pass through.
        - 'offline_access' is always added (required to receive a refresh_token).
    #>
    [CmdletBinding()]
    param(
        [string[]]$Scopes,

        [Parameter(Mandatory)]
        [string]$GraphResource
    )

    if (-not $Scopes -or $Scopes.Count -eq 0) {
        $Scopes = @('User.Read')
    }

    $oidc = @('openid','profile','offline_access','email')
    $resolved = @(foreach ($s in $Scopes) {
        if ([string]::IsNullOrWhiteSpace($s)) { continue }
        if ($s -like 'https://*' -or $s -in $oidc) { $s } else { "$GraphResource/$s" }
    })

    if ('offline_access' -notin $resolved) { $resolved += 'offline_access' }
    return ,$resolved
}
