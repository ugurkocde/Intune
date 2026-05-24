#Requires -Version 7.0
<#
.SYNOPSIS
    Pure-PowerShell interactive sign-in to Microsoft Graph via the system browser.

.DESCRIPTION
    Bypasses the Microsoft.Graph SDK's built-in interactive flow (which defaults to
    WAM on Windows). Uses OAuth 2.0 Authorization Code Flow with PKCE and a local
    loopback HTTP listener — no MSAL, no embedded WebView, no WAM, no compiled C#.

    Defaults to Microsoft's well-known PowerShell public client
    (14d82eec-204b-4c2f-b7e8-296a70dab67e) so no app registration is required.
    Optionally accepts -ClientId / -TenantId for bring-your-own app registrations.

    Refresh tokens are cached locally (DPAPI-encrypted on Windows, restricted-perm
    JSON file on macOS/Linux) so subsequent sign-ins are silent until the refresh
    token expires.

.PARAMETER Scopes
    Microsoft Graph delegated scopes to request. Bare names (e.g. 'User.Read') are
    auto-prefixed with the Graph resource URI. Fully-qualified scopes
    ('https://graph.microsoft.com/...') and OIDC reserved scopes
    ('openid', 'profile', 'email') are passed through unchanged.
    'offline_access' is always added so a refresh token is returned.

.PARAMETER ClientId
    Optional. Custom app registration Client ID. Defaults to Microsoft's
    well-known PowerShell public client.

.PARAMETER TenantId
    Optional. Tenant ID or verified domain. Defaults to /common (multi-tenant).
    Required when using a single-tenant custom app registration.

.PARAMETER RedirectPort
    Optional. Fixed loopback port for the redirect URI. Defaults to a random
    free port. Set this when your custom app registration has a specific
    http://localhost:PORT redirect URI configured.

.PARAMETER ForceConsent
    Force the consent prompt to appear (prompt=consent). Use when adding new
    scopes or re-granting permissions.

.PARAMETER NoCache
    Do not read or write the refresh-token cache for this call.

.EXAMPLE
    .\Connect-MgGraphViaBrowser.ps1
    Sign in with defaults (User.Read on /common, MS PowerShell client).

.EXAMPLE
    .\Connect-MgGraphViaBrowser.ps1 -Scopes 'User.Read','DeviceManagementConfiguration.Read.All','DeviceManagementManagedDevices.Read.All' -TenantId 'contoso.onmicrosoft.com'
    Sign in to a specific tenant with multiple Intune-flavored scopes.

.EXAMPLE
    .\Connect-MgGraphViaBrowser.ps1 -ClientId '00000000-0000-0000-0000-000000000000' -TenantId 'contoso.onmicrosoft.com' -RedirectPort 1985
    Use a bring-your-own app registration with a fixed redirect port.
#>

[CmdletBinding()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '',
    Justification = 'Interactive script; Write-Host is intentional for console feedback.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '',
    Justification = 'Connect-MgGraph -AccessToken requires a SecureString; token is already in memory as plaintext.')]
param(
    [string[]]$Scopes = @('User.Read'),
    [string]  $ClientId = '14d82eec-204b-4c2f-b7e8-296a70dab67e',
    [string]  $TenantId,
    [int]     $RedirectPort,
    [switch]  $ForceConsent,
    [switch]  $NoCache
)

$ErrorActionPreference = 'Stop'

# ============================================================
# Constants
# ============================================================
$script:GraphResource = 'https://graph.microsoft.com'
$script:CacheDir      = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Connect-MgGraphViaBrowser'
$script:CacheFile     = Join-Path $script:CacheDir 'tokens.json'

# ============================================================
# PKCE helpers
# ============================================================
function New-CodeVerifier {
    $bytes = [byte[]]::new(32)
    [System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
    return [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
}

function New-CodeChallenge {
    param([Parameter(Mandatory)][string]$Verifier)
    $hash = [System.Security.Cryptography.SHA256]::HashData([System.Text.Encoding]::UTF8.GetBytes($Verifier))
    return [Convert]::ToBase64String($hash).TrimEnd('=').Replace('+', '-').Replace('/', '_')
}

# ============================================================
# Free-port discovery
# ============================================================
function Get-FreePort {
    $tcp = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
    $tcp.Start()
    try { return $tcp.LocalEndpoint.Port } finally { $tcp.Stop() }
}

# ============================================================
# Scope normalization
# ============================================================
function Resolve-Scopes {
    param([string[]]$Scopes)
    $oidc = @('openid', 'profile', 'offline_access', 'email')
    $resolved = @(foreach ($s in $Scopes) {
        if ($s -like 'https://*' -or $s -in $oidc) { $s } else { "$script:GraphResource/$s" }
    })
    if ('offline_access' -notin $resolved) { $resolved += 'offline_access' }
    return ,$resolved
}

# ============================================================
# Token cache (DPAPI on Windows, plain JSON elsewhere)
# ============================================================
function Save-TokenCache {
    param(
        [Parameter(Mandatory)][pscustomobject]$Tokens,
        [Parameter(Mandatory)][string]$Key
    )

    if (-not (Test-Path $script:CacheDir)) {
        New-Item -ItemType Directory -Path $script:CacheDir -Force | Out-Null
    }

    $payload = $Tokens | ConvertTo-Json -Compress -Depth 5

    if ($IsWindows) {
        $secure    = ConvertTo-SecureString -String $payload -AsPlainText -Force
        $encrypted = ConvertFrom-SecureString -SecureString $secure
        $entry     = [pscustomobject]@{ encrypted = $true;  data = $encrypted; saved = (Get-Date).ToString('o') }
    } else {
        $entry     = [pscustomobject]@{ encrypted = $false; data = $payload;   saved = (Get-Date).ToString('o') }
    }

    $cache = @{}
    if (Test-Path $script:CacheFile) {
        try {
            $existing = Get-Content $script:CacheFile -Raw | ConvertFrom-Json
            foreach ($prop in $existing.PSObject.Properties) { $cache[$prop.Name] = $prop.Value }
        } catch {
            Write-Verbose "Existing cache unreadable, starting fresh: $_"
        }
    }
    $cache[$Key] = $entry

    $cache | ConvertTo-Json -Depth 6 | Set-Content -Path $script:CacheFile -NoNewline

    if (-not $IsWindows) {
        try { & chmod 600 $script:CacheFile } catch { Write-Verbose "chmod 600 failed: $_" }
    }
}

function Get-TokenCacheEntry {
    param([Parameter(Mandatory)][string]$Key)
    if (-not (Test-Path $script:CacheFile)) { return $null }
    try {
        $cache = Get-Content $script:CacheFile -Raw | ConvertFrom-Json
        $entry = $cache.$Key
        if (-not $entry) { return $null }

        if ($entry.encrypted) {
            $secure  = ConvertTo-SecureString -String $entry.data
            $payload = ConvertFrom-SecureString -SecureString $secure -AsPlainText
        } else {
            $payload = $entry.data
        }
        return $payload | ConvertFrom-Json
    } catch {
        Write-Verbose "Cache read failed for key '$Key': $_"
        return $null
    }
}

# ============================================================
# OAuth token endpoint
# ============================================================
function Invoke-TokenEndpoint {
    param(
        [Parameter(Mandatory)][string]$TenantSegment,
        [Parameter(Mandatory)][hashtable]$Body
    )
    $url = "https://login.microsoftonline.com/$TenantSegment/oauth2/v2.0/token"
    return Invoke-RestMethod -Method POST -Uri $url -Body $Body `
        -ContentType 'application/x-www-form-urlencoded' -ErrorAction Stop
}

# ============================================================
# Silent token refresh
# ============================================================
function Get-TokenViaRefresh {
    param(
        [Parameter(Mandatory)][string]$RefreshToken,
        [Parameter(Mandatory)][string[]]$Scopes,
        [Parameter(Mandatory)][string]$ClientId,
        [Parameter(Mandatory)][string]$TenantSegment
    )
    $body = @{
        client_id     = $ClientId
        grant_type    = 'refresh_token'
        refresh_token = $RefreshToken
        scope         = ($Scopes -join ' ')
    }
    return Invoke-TokenEndpoint -TenantSegment $TenantSegment -Body $body
}

# ============================================================
# Interactive browser flow (Auth Code + PKCE on loopback)
# ============================================================
function Get-TokenViaBrowser {
    param(
        [Parameter(Mandatory)][string]$ClientId,
        [Parameter(Mandatory)][string]$TenantSegment,
        [Parameter(Mandatory)][string[]]$Scopes,
        [int]    $Port,
        [switch] $ForceConsent
    )

    if (-not $Port -or $Port -le 0) { $Port = Get-FreePort }
    $redirectUri = "http://localhost:$Port/"

    $verifier  = New-CodeVerifier
    $challenge = New-CodeChallenge -Verifier $verifier
    $state     = [Guid]::NewGuid().ToString('N')

    $authParams = [ordered]@{
        client_id             = $ClientId
        response_type         = 'code'
        redirect_uri          = $redirectUri
        response_mode         = 'query'
        scope                 = ($Scopes -join ' ')
        state                 = $state
        code_challenge        = $challenge
        code_challenge_method = 'S256'
        prompt                = $(if ($ForceConsent) { 'consent' } else { 'select_account' })
    }

    $query = ($authParams.GetEnumerator() | ForEach-Object {
        "$($_.Key)=$([Uri]::EscapeDataString([string]$_.Value))"
    }) -join '&'

    $authUrl = "https://login.microsoftonline.com/$TenantSegment/oauth2/v2.0/authorize?$query"

    $listener = [System.Net.HttpListener]::new()
    $listener.Prefixes.Add($redirectUri)
    $listener.Start()

    try {
        Write-Host "Opening browser for sign-in (listening on $redirectUri)..." -ForegroundColor Cyan
        Start-Process $authUrl | Out-Null

        $ctxTask = $listener.GetContextAsync()
        if (-not $ctxTask.Wait([TimeSpan]::FromMinutes(5))) {
            throw "Authentication timed out after 5 minutes."
        }
        $ctx = $ctxTask.Result

        $code          = $ctx.Request.QueryString['code']
        $err           = $ctx.Request.QueryString['error']
        $errDesc       = $ctx.Request.QueryString['error_description']
        $returnedState = $ctx.Request.QueryString['state']

        $successHtml = "<html><body style='font-family:Segoe UI,sans-serif;text-align:center;padding-top:80px;'><h2>Authentication Successful</h2><p>You can close this window and return to PowerShell.</p></body></html>"
        $errorHtml   = "<html><body style='font-family:Segoe UI,sans-serif;text-align:center;padding-top:80px;color:#c0392b;'><h2>Authentication Failed</h2><p>$([System.Net.WebUtility]::HtmlEncode($errDesc))</p></body></html>"

        $html  = if ($code) { $successHtml } else { $errorHtml }
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($html)
        $ctx.Response.ContentType    = 'text/html'
        $ctx.Response.ContentLength64 = $bytes.Length
        $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
        $ctx.Response.Close()

        if ($returnedState -ne $state) {
            throw "OAuth state mismatch - possible CSRF. Aborting."
        }
        if (-not $code) {
            throw "Authorization failed: $err - $errDesc"
        }

        $body = @{
            client_id     = $ClientId
            grant_type    = 'authorization_code'
            code          = $code
            redirect_uri  = $redirectUri
            code_verifier = $verifier
            scope         = ($Scopes -join ' ')
        }
        return Invoke-TokenEndpoint -TenantSegment $TenantSegment -Body $body
    }
    finally {
        $listener.Stop()
        $listener.Close()
    }
}

# ============================================================
# Public entry point
# ============================================================
function Connect-MgGraphViaBrowser {
    [CmdletBinding()]
    param(
        [string[]]$Scopes = @('User.Read'),
        [string]  $ClientId = '14d82eec-204b-4c2f-b7e8-296a70dab67e',
        [string]  $TenantId,
        [int]     $RedirectPort,
        [switch]  $ForceConsent,
        [switch]  $NoCache
    )

    $tenantSegment  = if ($TenantId) { $TenantId } else { 'common' }
    $resolvedScopes = Resolve-Scopes -Scopes $Scopes
    $cacheKey       = "$ClientId|$tenantSegment"

    $tokens = $null

    # 1. Try silent refresh
    if (-not $NoCache -and -not $ForceConsent) {
        $cached = Get-TokenCacheEntry -Key $cacheKey
        if ($cached -and $cached.refresh_token) {
            try {
                Write-Host "Attempting silent token refresh..." -ForegroundColor DarkGray
                $tokens = Get-TokenViaRefresh `
                    -RefreshToken  $cached.refresh_token `
                    -Scopes        $resolvedScopes `
                    -ClientId      $ClientId `
                    -TenantSegment $tenantSegment
                Write-Host "Silent refresh succeeded." -ForegroundColor DarkGray
            } catch {
                Write-Verbose "Silent refresh failed, falling back to interactive: $_"
                $tokens = $null
            }
        }
    }

    # 2. Fall through to interactive browser flow
    if (-not $tokens) {
        $tokens = Get-TokenViaBrowser `
            -ClientId      $ClientId `
            -TenantSegment $tenantSegment `
            -Scopes        $resolvedScopes `
            -Port          $RedirectPort `
            -ForceConsent: $ForceConsent
    }

    # 3. Persist refresh token for next session
    if (-not $NoCache -and $tokens.refresh_token) {
        Save-TokenCache -Tokens $tokens -Key $cacheKey
    }

    # 4. Hand the access token to the Graph SDK
    if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
        throw "Microsoft.Graph.Authentication is not installed. Run: Install-Module Microsoft.Graph.Authentication -Scope CurrentUser"
    }
    Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null

    $secure = ConvertTo-SecureString $tokens.access_token -AsPlainText -Force
    Connect-MgGraph -AccessToken $secure -NoWelcome -ErrorAction Stop

    $ctx = Get-MgContext
    if (-not $ctx) { throw "Connect-MgGraph succeeded but Get-MgContext returned null." }

    Write-Host ""
    Write-Host "Connected." -ForegroundColor Green
    Write-Host "  Account:  $($ctx.Account)" -ForegroundColor Gray
    Write-Host "  Tenant:   $($ctx.TenantId)" -ForegroundColor Gray
    Write-Host "  Scopes:   $($ctx.Scopes -join ', ')" -ForegroundColor Gray

    return $ctx
}

# ============================================================
# Script entry — only runs when the file is executed directly,
# not when dot-sourced (so a future module can re-use the function).
# ============================================================
if ($MyInvocation.InvocationName -ne '.' -and -not $MyInvocation.Line.StartsWith('. ')) {
    try {
        Connect-MgGraphViaBrowser @PSBoundParameters | Out-Null
    } catch {
        Write-Host ""
        Write-Host "FAILED: $_" -ForegroundColor Red
        Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
        exit 1
    }
}
