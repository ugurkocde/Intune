function Invoke-MgcInteractiveAuth {
    <#
    .SYNOPSIS
        OAuth 2.0 Authorization Code + PKCE via system browser and a loopback listener.

    .DESCRIPTION
        - Generates a PKCE pair.
        - Starts an HttpListener on an OS-assigned (or user-specified) loopback port.
        - Opens the user's default browser to the /authorize endpoint.
        - Waits (async with 5-min timeout) for the redirect callback.
        - Validates the state parameter to defend against CSRF.
        - Exchanges the authorization code + verifier for tokens at /token.
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost','',
        Justification = 'Interactive flow — user-visible progress.')]
    param(
        [Parameter(Mandatory)][string]$LoginEndpoint,
        [Parameter(Mandatory)][string]$TenantSegment,
        [Parameter(Mandatory)][string]$ClientId,
        [Parameter(Mandatory)][string[]]$Scopes,
        [int]    $RedirectPort,
        [switch] $ForceConsent
    )

    if (-not $RedirectPort -or $RedirectPort -le 0) { $RedirectPort = Get-MgcFreePort }
    $redirectUri = "http://localhost:$RedirectPort/"

    $pkce  = New-MgcPkcePair
    $state = [Guid]::NewGuid().ToString('N')

    $authParams = [ordered]@{
        client_id             = $ClientId
        response_type         = 'code'
        redirect_uri          = $redirectUri
        response_mode         = 'query'
        scope                 = ($Scopes -join ' ')
        state                 = $state
        code_challenge        = $pkce.Challenge
        code_challenge_method = $pkce.Method
        prompt                = $(if ($ForceConsent) { 'consent' } else { 'select_account' })
    }

    $query   = ($authParams.GetEnumerator() | ForEach-Object {
        "$($_.Key)=$([Uri]::EscapeDataString([string]$_.Value))"
    }) -join '&'
    $authUrl = "$LoginEndpoint/$TenantSegment/oauth2/v2.0/authorize?$query"

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

        if ($returnedState -ne $state) { throw "OAuth state mismatch - possible CSRF. Aborting." }
        if (-not $code) { throw "Authorization failed: $err - $errDesc" }

        $body = @{
            client_id     = $ClientId
            grant_type    = 'authorization_code'
            code          = $code
            redirect_uri  = $redirectUri
            code_verifier = $pkce.Verifier
            scope         = ($Scopes -join ' ')
        }
        return Invoke-MgcTokenEndpoint -Url "$LoginEndpoint/$TenantSegment/oauth2/v2.0/token" -Body $body
    }
    finally {
        $listener.Stop()
        $listener.Close()
    }
}
