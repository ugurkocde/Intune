function Connect-MgGraphCommunity {
    <#
    .SYNOPSIS
        Community drop-in for Connect-MgGraph. Pure-PowerShell OAuth, WAM-free.

    .DESCRIPTION
        Authenticates to Microsoft Graph using one of six flows and hands the
        access token to Connect-MgGraph -AccessToken so all existing Microsoft.Graph.*
        cmdlets work unchanged.

        Flows (parameter sets):
            Interactive       (default)  Authorization Code + PKCE via system browser
            DeviceCode        -UseDeviceCode
            ClientSecret      -ClientSecretCredential
            Certificate       -Certificate | -CertificateThumbprint | -CertificateName
            AccessToken       -AccessToken
            ManagedIdentity   -Identity [-ManagedIdentityClientId]

        Tokens are kept in memory by default. Use -PersistRefreshToken to write the
        refresh token to disk (DPAPI on Windows, chmod 600 elsewhere) for silent
        re-auth across PowerShell sessions.

    .PARAMETER Scopes
        Microsoft Graph delegated scopes. Bare names (e.g. 'User.Read') are auto-prefixed
        with the Graph resource URI for the active environment. Defaults to 'User.Read'.
        Ignored for ClientSecret / Certificate / ManagedIdentity flows (which use /.default).

    .PARAMETER TenantId
        Tenant ID or verified domain. Defaults to 'common' (multi-tenant). Required for
        ClientSecret and Certificate flows.

    .PARAMETER ClientId
        Application ID. Defaults to Microsoft's well-known PowerShell client
        (14d82eec-204b-4c2f-b7e8-296a70dab67e) for Interactive and DeviceCode flows.
        Required for ClientSecret and Certificate flows.

    .PARAMETER Environment
        Microsoft cloud environment. One of Global, USGov, USGovDoD, China. Defaults to Global.

    .PARAMETER RedirectPort
        Optional fixed loopback port for the Interactive flow's redirect URI. Defaults
        to an OS-assigned free port. Set this if your app registration requires a
        specific http://localhost:PORT redirect URI.

    .PARAMETER NoWelcome
        Suppresses the connection summary banner.

    .PARAMETER NoCache
        Skips both in-memory and on-disk caches for this call. Forces a fresh token.

    .PARAMETER PersistRefreshToken
        Opt-in: write the refresh token to disk so subsequent sessions can re-auth
        silently. DPAPI-encrypted on Windows; chmod 600 JSON elsewhere. Off by default
        for safer posture.

    .PARAMETER ForceConsent
        Forces the consent prompt to appear (prompt=consent). Use when adding new
        scopes or re-granting permissions.

    .PARAMETER UseDeviceCode
        Switch to the device code flow.

    .PARAMETER ClientSecretCredential
        PSCredential whose UserName is the ClientId and Password is the client secret.

    .PARAMETER Certificate
        X509Certificate2 (with private key) for certificate-based client credentials.

    .PARAMETER CertificateThumbprint
        Thumbprint of a certificate in the current-user MY store.

    .PARAMETER CertificateName
        Subject name (CN=...) of a certificate in the current-user MY store.

    .PARAMETER AccessToken
        Pre-acquired access token (SecureString) to use directly.

    .PARAMETER Identity
        Switch to use Azure Managed Identity (IMDS / App Service / Arc).

    .PARAMETER ManagedIdentityClientId
        Optional Client ID of a user-assigned managed identity. Omit for system-assigned.

    .EXAMPLE
        Connect-MgGraphCommunity
        Interactive sign-in with default scopes.

    .EXAMPLE
        Connect-MgGraphCommunity -Scopes 'User.Read','DeviceManagementConfiguration.Read.All' -TenantId 'contoso.onmicrosoft.com'

    .EXAMPLE
        Connect-MgGraphCommunity -UseDeviceCode -TenantId 'contoso.onmicrosoft.com'

    .EXAMPLE
        $cred = Get-Credential   # username = AppId, password = client secret
        Connect-MgGraphCommunity -TenantId 'contoso.onmicrosoft.com' -ClientId '<app-id>' -ClientSecretCredential $cred

    .EXAMPLE
        Connect-MgGraphCommunity -TenantId 'contoso.onmicrosoft.com' -ClientId '<app-id>' -CertificateThumbprint 'ABCD...'

    .EXAMPLE
        Connect-MgGraphCommunity -Identity

    .EXAMPLE
        Connect-MgGraphCommunity -AccessToken (Read-Host -AsSecureString)

    .EXAMPLE
        Connect-MgGraphCommunity -PersistRefreshToken
        First-time sign-in that persists the refresh token; subsequent sessions skip the browser.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Interactive')]
    param(
        # Common parameters (most sets)
        [Parameter(ParameterSetName = 'Interactive')]
        [Parameter(ParameterSetName = 'DeviceCode')]
        [Parameter(ParameterSetName = 'ClientSecret')]
        [Parameter(ParameterSetName = 'Certificate')]
        [Parameter(ParameterSetName = 'CertificateThumbprint')]
        [Parameter(ParameterSetName = 'CertificateName')]
        [string[]]$Scopes,

        [Parameter(ParameterSetName = 'Interactive')]
        [Parameter(ParameterSetName = 'DeviceCode')]
        [Parameter(Mandatory, ParameterSetName = 'ClientSecret')]
        [Parameter(Mandatory, ParameterSetName = 'Certificate')]
        [Parameter(Mandatory, ParameterSetName = 'CertificateThumbprint')]
        [Parameter(Mandatory, ParameterSetName = 'CertificateName')]
        [string]$TenantId,

        [Parameter(ParameterSetName = 'Interactive')]
        [Parameter(ParameterSetName = 'DeviceCode')]
        [Parameter(Mandatory, ParameterSetName = 'ClientSecret')]
        [Parameter(Mandatory, ParameterSetName = 'Certificate')]
        [Parameter(Mandatory, ParameterSetName = 'CertificateThumbprint')]
        [Parameter(Mandatory, ParameterSetName = 'CertificateName')]
        [string]$ClientId = '14d82eec-204b-4c2f-b7e8-296a70dab67e',

        [ValidateSet('Global','USGov','USGovDoD','China')]
        [string]$Environment = 'Global',

        [switch]$NoWelcome,
        [switch]$NoCache,
        [switch]$PersistRefreshToken,

        # Interactive
        [Parameter(ParameterSetName = 'Interactive')]
        [int]$RedirectPort,

        [Parameter(ParameterSetName = 'Interactive')]
        [switch]$ForceConsent,

        # DeviceCode
        [Parameter(Mandatory, ParameterSetName = 'DeviceCode')]
        [switch]$UseDeviceCode,

        # ClientSecret
        [Parameter(Mandatory, ParameterSetName = 'ClientSecret')]
        [pscredential]$ClientSecretCredential,

        # Certificate (3 variants)
        [Parameter(Mandatory, ParameterSetName = 'Certificate')]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate,

        [Parameter(Mandatory, ParameterSetName = 'CertificateThumbprint')]
        [string]$CertificateThumbprint,

        [Parameter(Mandatory, ParameterSetName = 'CertificateName')]
        [string]$CertificateName,

        # AccessToken
        [Parameter(Mandatory, ParameterSetName = 'AccessToken')]
        [securestring]$AccessToken,

        # Managed Identity
        [Parameter(Mandatory, ParameterSetName = 'ManagedIdentity')]
        [switch]$Identity,

        [Parameter(ParameterSetName = 'ManagedIdentity')]
        [string]$ManagedIdentityClientId
    )

    $ErrorActionPreference = 'Stop'

    $authority      = Resolve-MgcAuthority -Environment $Environment
    $tenantSegment  = if ($TenantId) { $TenantId } else { 'common' }
    $resolvedScopes = Resolve-MgcScopes -Scopes $Scopes -GraphResource $authority.GraphResource
    $cacheKey       = "$($authority.Login)|$ClientId|$tenantSegment|$($PSCmdlet.ParameterSetName)"

    $tokens   = $null
    $flowType = $PSCmdlet.ParameterSetName

    switch ($PSCmdlet.ParameterSetName) {

        'Interactive' {
            # Try silent refresh first if we have a cached refresh token
            if (-not $NoCache -and -not $ForceConsent) {
                $cached = Get-MgcTokenCacheEntry -Key $cacheKey -IncludeDisk:$PersistRefreshToken
                if ($cached -and $cached.refresh_token) {
                    try {
                        Write-Verbose "Attempting silent refresh."
                        $tokens = Invoke-MgcRefreshTokenAuth `
                            -LoginEndpoint $authority.Login `
                            -TenantSegment $tenantSegment `
                            -ClientId      $ClientId `
                            -RefreshToken  $cached.refresh_token `
                            -Scopes        $resolvedScopes
                    } catch {
                        Write-Verbose "Silent refresh failed, falling back to browser: $_"
                        $tokens = $null
                    }
                }
            }

            if (-not $tokens) {
                $tokens = Invoke-MgcInteractiveAuth `
                    -LoginEndpoint $authority.Login `
                    -TenantSegment $tenantSegment `
                    -ClientId      $ClientId `
                    -Scopes        $resolvedScopes `
                    -RedirectPort  $RedirectPort `
                    -ForceConsent: $ForceConsent
            }
        }

        'DeviceCode' {
            if (-not $NoCache) {
                $cached = Get-MgcTokenCacheEntry -Key $cacheKey -IncludeDisk:$PersistRefreshToken
                if ($cached -and $cached.refresh_token) {
                    try {
                        $tokens = Invoke-MgcRefreshTokenAuth `
                            -LoginEndpoint $authority.Login `
                            -TenantSegment $tenantSegment `
                            -ClientId      $ClientId `
                            -RefreshToken  $cached.refresh_token `
                            -Scopes        $resolvedScopes
                    } catch { $tokens = $null }
                }
            }
            if (-not $tokens) {
                $tokens = Invoke-MgcDeviceCodeAuth `
                    -LoginEndpoint $authority.Login `
                    -TenantSegment $tenantSegment `
                    -ClientId      $ClientId `
                    -Scopes        $resolvedScopes
            }
        }

        'ClientSecret' {
            $secret = $ClientSecretCredential.GetNetworkCredential().Password
            $tokens = Invoke-MgcClientSecretAuth `
                -LoginEndpoint $authority.Login `
                -TenantSegment $tenantSegment `
                -ClientId      $ClientId `
                -ClientSecret  $secret `
                -GraphResource $authority.GraphResource
        }

        { $_ -in 'Certificate','CertificateThumbprint','CertificateName' } {
            $cert = switch ($PSCmdlet.ParameterSetName) {
                'Certificate' { $Certificate }
                'CertificateThumbprint' {
                    $found = Get-ChildItem -Path "Cert:\CurrentUser\My\$CertificateThumbprint" -ErrorAction SilentlyContinue
                    if (-not $found) { $found = Get-ChildItem -Path "Cert:\LocalMachine\My\$CertificateThumbprint" -ErrorAction SilentlyContinue }
                    if (-not $found) { throw "Certificate with thumbprint '$CertificateThumbprint' not found in CurrentUser\My or LocalMachine\My." }
                    $found
                }
                'CertificateName' {
                    $needle = $CertificateName
                    $found = Get-ChildItem -Path 'Cert:\CurrentUser\My' | Where-Object { $_.Subject -eq $needle -or $_.Subject -eq "CN=$needle" } | Select-Object -First 1
                    if (-not $found) { $found = Get-ChildItem -Path 'Cert:\LocalMachine\My' | Where-Object { $_.Subject -eq $needle -or $_.Subject -eq "CN=$needle" } | Select-Object -First 1 }
                    if (-not $found) { throw "Certificate with subject '$CertificateName' not found in CurrentUser\My or LocalMachine\My." }
                    $found
                }
            }

            $tokens = Invoke-MgcClientCertificateAuth `
                -LoginEndpoint $authority.Login `
                -TenantSegment $tenantSegment `
                -ClientId      $ClientId `
                -Certificate   $cert `
                -GraphResource $authority.GraphResource
            $flowType = 'Certificate'
        }

        'AccessToken' {
            $plain = (New-Object System.Net.NetworkCredential('', $AccessToken)).Password
            $tokens = [pscustomobject]@{
                access_token  = $plain
                refresh_token = $null
                expires_in    = 3600
                token_type    = 'Bearer'
            }
        }

        'ManagedIdentity' {
            $miParams = @{ GraphResource = $authority.GraphResource }
            if ($ManagedIdentityClientId) { $miParams['ManagedIdentityClientId'] = $ManagedIdentityClientId }
            $tokens = Invoke-MgcManagedIdentityAuth @miParams
            $flowType = 'ManagedIdentity'
        }
    }

    # Cache the result (always in memory; opt-in to disk)
    if (-not $NoCache) {
        Save-MgcTokenCache -Key $cacheKey -Tokens $tokens -Persist:$PersistRefreshToken
    }

    # Hand off to the Graph SDK so Microsoft.Graph.* cmdlets work
    Send-MgcTokenToSdk -AccessToken $tokens.access_token -NoWelcome

    # Build and store context
    $context = Set-MgcConnectionContext `
        -Tokens      $tokens `
        -FlowType    $flowType `
        -ClientId    $ClientId `
        -TenantId    $tenantSegment `
        -Environment $authority.Environment `
        -Scopes      $resolvedScopes `
        -Persisted:  $PersistRefreshToken

    if (-not $NoWelcome) { Show-MgcWelcomeBanner -Context $context }
    return $context
}
