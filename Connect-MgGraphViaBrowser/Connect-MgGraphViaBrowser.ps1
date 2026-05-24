#Requires -Version 7.0
<#
.SYNOPSIS
    Standalone test of MSAL system-browser authentication for Microsoft Graph.

.DESCRIPTION
    Bypasses the Microsoft.Graph SDK's built-in interactive flow (which now defaults
    to WAM on Windows and breaks for many users). Instead, loads MSAL directly,
    acquires a token via the user's default system browser (loopback redirect),
    then hands the token to Connect-MgGraph -AccessToken.

    Adapted from Mark Orr's Entra-PIM pattern:
    https://github.com/markorr321/Entra-PIM/blob/main/Entra-PIM.ps1

.PARAMETER ClientId
    Optional. Custom app registration Client ID. If omitted, uses Microsoft's
    well-known PowerShell public client ID (14d82eec-204b-4c2f-b7e8-296a70dab67e),
    which already has http://localhost configured as a redirect URI.

.PARAMETER TenantId
    Optional. Specific tenant to authenticate against. If omitted, uses common
    endpoint (multi-tenant).

.PARAMETER Scopes
    Microsoft Graph scopes to request. Defaults to a small read-only set.

.EXAMPLE
    .\Test-BrowserAuth.ps1
    Run with defaults - opens system browser, signs in, calls /me.

.EXAMPLE
    .\Test-BrowserAuth.ps1 -TenantId "contoso.onmicrosoft.com"
    Restrict to a specific tenant.
#>

[CmdletBinding()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '',
    Justification = 'Interactive script; Write-Host is intentional for console feedback.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '',
    Justification = 'Connect-MgGraph -AccessToken requires a SecureString; the token is already in memory as plaintext.')]
param(
    [string]$ClientId,
    [string]$TenantId,
    [string[]]$Scopes = @('User.Read', 'Directory.Read.All')
)

$ErrorActionPreference = 'Stop'

# Default to Microsoft's PowerShell public client if no custom ClientId provided.
# This app reg already has http://localhost as a redirect URI - no setup needed.
if (-not $ClientId) {
    $ClientId = '14d82eec-204b-4c2f-b7e8-296a70dab67e'
}

# ============================================================
# Step 1: Locate Microsoft.Identity.Client.dll (MSAL)
# ============================================================
function Find-MsalAssembly {
    Write-Host "[1/4] Locating MSAL assemblies..." -ForegroundColor Cyan

    $paths = @{}

    # Look for MSAL in the NuGet cache first
    $nugetCache = Join-Path $env:USERPROFILE '.nuget\packages\microsoft.identity.client'
    if (Test-Path $nugetCache) {
        $latest = Get-ChildItem -Path $nugetCache -Directory |
            Sort-Object { [version]($_.Name -replace '[^0-9.]', '') } -Descending |
            Select-Object -First 1
        if ($latest) {
            foreach ($tfm in @('net6.0', 'netstandard2.0')) {
                $candidate = Join-Path $latest.FullName "lib\$tfm\Microsoft.Identity.Client.dll"
                if (Test-Path $candidate) {
                    $paths['Msal'] = $candidate
                    break
                }
            }
        }
    }

    # Fallback: search Az.Accounts module folder
    if (-not $paths.ContainsKey('Msal')) {
        $az = Get-Module -ListAvailable -Name Az.Accounts |
            Sort-Object Version -Descending | Select-Object -First 1
        if ($az) {
            $found = Get-ChildItem -Path (Split-Path $az.Path) -Filter 'Microsoft.Identity.Client.dll' -Recurse -ErrorAction SilentlyContinue |
                Select-Object -First 1
            if ($found) { $paths['Msal'] = $found.FullName }
        }
    }

    # Fallback: search Microsoft.Graph.Authentication module folder
    if (-not $paths.ContainsKey('Msal')) {
        $graphAuth = Get-Module -ListAvailable -Name Microsoft.Graph.Authentication |
            Sort-Object Version -Descending | Select-Object -First 1
        if ($graphAuth) {
            $found = Get-ChildItem -Path (Split-Path $graphAuth.Path) -Filter 'Microsoft.Identity.Client.dll' -Recurse -ErrorAction SilentlyContinue |
                Select-Object -First 1
            if ($found) { $paths['Msal'] = $found.FullName }
        }
    }

    if (-not $paths.ContainsKey('Msal')) {
        throw "Could not find Microsoft.Identity.Client.dll. Install Az.Accounts or Microsoft.Graph.Authentication, or restore the MSAL NuGet package."
    }

    # Microsoft.IdentityModel.Abstractions is sometimes required as a sibling assembly
    $abstractionsCandidate = Join-Path (Split-Path $paths['Msal']) 'Microsoft.IdentityModel.Abstractions.dll'
    if (Test-Path $abstractionsCandidate) {
        $paths['Abstractions'] = $abstractionsCandidate
    }

    Write-Host "      MSAL: $($paths['Msal'])" -ForegroundColor Gray
    if ($paths.ContainsKey('Abstractions')) {
        Write-Host "      Abstractions: $($paths['Abstractions'])" -ForegroundColor Gray
    }
    return $paths
}

# ============================================================
# Step 2: Compile inline C# helper that calls MSAL
# ============================================================
function Initialize-MsalHelper {
    param([hashtable]$AssemblyPaths)

    Write-Host "[2/4] Compiling MSAL browser-auth helper..." -ForegroundColor Cyan

    # Pre-load Abstractions and MSAL so the AppDomain can resolve them at runtime.
    # Must run BEFORE the "already compiled" shortcut: if BrowserAuthHelper was
    # compiled in a previous run against a different MSAL location/version, the
    # resolver below is what makes the existing type still work.
    if ($AssemblyPaths.ContainsKey('Abstractions')) {
        try { [System.Reflection.Assembly]::LoadFrom($AssemblyPaths['Abstractions']) | Out-Null }
        catch { Write-Verbose "Abstractions pre-load failed (non-fatal): $_" }
    }
    try { [System.Reflection.Assembly]::LoadFrom($AssemblyPaths['Msal']) | Out-Null }
    catch { throw "Failed to load MSAL from $($AssemblyPaths['Msal']): $_" }

    # Register an AssemblyResolve handler that returns the MSAL/Abstractions we
    # loaded, regardless of what version is requested. LoadFrom ignores the
    # requested version and binds whatever is at the path.
    $script:BrowserAuthMsalDir = Split-Path $AssemblyPaths['Msal']
    if (-not $script:BrowserAuthResolverRegistered) {
        $handler = {
            param($eventSource, $resolveArgs)
            $null = $eventSource
            $requested = ($resolveArgs.Name -split ',')[0].Trim()
            if ($requested -eq 'Microsoft.Identity.Client' -or $requested -eq 'Microsoft.IdentityModel.Abstractions') {
                $candidate = Join-Path $script:BrowserAuthMsalDir "$requested.dll"
                if (Test-Path $candidate) {
                    return [System.Reflection.Assembly]::LoadFrom($candidate)
                }
            }
            return $null
        }.GetNewClosure()
        [System.AppDomain]::CurrentDomain.add_AssemblyResolve($handler)
        $script:BrowserAuthResolverRegistered = $true
    }

    # Skip recompile if the helper type already exists in this session
    try {
        $null = [BrowserAuthHelper]
        Write-Host "      (already loaded)" -ForegroundColor Gray
        return
    } catch {
        Write-Verbose "BrowserAuthHelper not yet compiled in this session; building."
    }

    # PS7 compiling against netstandard2.0 libs needs BCL refs supplied explicitly.
    # Force-load netstandard so its location is resolvable.
    try { [System.Reflection.Assembly]::Load('netstandard, Version=2.0.0.0, Culture=neutral, PublicKeyToken=cc7b13ffcd2ddd51') | Out-Null }
    catch { Write-Verbose "netstandard force-load failed (non-fatal): $_" }

    $loaded = [System.AppDomain]::CurrentDomain.GetAssemblies()
    $bclRefs = @()
    foreach ($name in @('netstandard', 'System.Runtime', 'System.Threading.Tasks', 'System.Private.CoreLib', 'mscorlib')) {
        $asm = $loaded | Where-Object { $_.GetName().Name -eq $name } | Select-Object -First 1
        if ($asm -and $asm.Location -and (Test-Path $asm.Location)) {
            $bclRefs += $asm.Location
        }
    }

    $referencedAssemblies = @($AssemblyPaths['Msal']) + $bclRefs
    if ($AssemblyPaths.ContainsKey('Abstractions')) {
        $referencedAssemblies += $AssemblyPaths['Abstractions']
    }
    $referencedAssemblies = $referencedAssemblies | Select-Object -Unique

    $code = @'
using System;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Identity.Client;

public class BrowserAuthHelper
{
    public static string GetAccessToken(string clientId, string[] scopes, string tenantId)
    {
        var task = Task.Run(async () => await GetAccessTokenAsync(clientId, scopes, tenantId));
        if (task.Wait(TimeSpan.FromSeconds(180)))
        {
            return task.Result;
        }
        throw new TimeoutException("Authentication timed out after 180 seconds");
    }

    private static async Task<string> GetAccessTokenAsync(string clientId, string[] scopes, string tenantId)
    {
        // System browser + loopback redirect = no WAM, no embedded webview
        var builder = PublicClientApplicationBuilder.Create(clientId)
            .WithRedirectUri("http://localhost");

        if (!string.IsNullOrEmpty(tenantId))
        {
            builder = builder.WithAuthority("https://login.microsoftonline.com/" + tenantId);
        }

        var app = builder.Build();

        using (var cts = new CancellationTokenSource(TimeSpan.FromSeconds(180)))
        {
            var webViewOptions = new SystemWebViewOptions
            {
                HtmlMessageSuccess = "<html><body style='font-family:Segoe UI,sans-serif;text-align:center;padding-top:80px;'><h2>Authentication Successful</h2><p>You can close this window and return to PowerShell.</p></body></html>",
                HtmlMessageError = "<html><body style='font-family:Segoe UI,sans-serif;text-align:center;padding-top:80px;color:#c0392b;'><h2>Authentication Failed</h2><p>Please close this window and try again.</p></body></html>"
            };

            var tokenBuilder = app.AcquireTokenInteractive(scopes)
                .WithPrompt(Prompt.SelectAccount)
                .WithUseEmbeddedWebView(false)
                .WithSystemWebViewOptions(webViewOptions);

            if (!string.IsNullOrEmpty(tenantId))
            {
                tokenBuilder = tokenBuilder.WithExtraQueryParameters("domain_hint=" + tenantId);
            }

            var result = await tokenBuilder.ExecuteAsync(cts.Token).ConfigureAwait(false);
            return result.AccessToken;
        }
    }
}
'@

    Add-Type -ReferencedAssemblies $referencedAssemblies -TypeDefinition $code -Language CSharp -ErrorAction Stop
    Write-Host "      Compiled." -ForegroundColor Gray
}

# ============================================================
# Step 3: Acquire token via system browser
# ============================================================
function Get-GraphTokenViaBrowser {
    param(
        [string]$ClientId,
        [string]$TenantId,
        [string[]]$Scopes
    )

    Write-Host "[3/4] Opening system browser for sign-in..." -ForegroundColor Cyan
    Write-Host "      ClientId: $ClientId" -ForegroundColor Gray
    if ($TenantId) { Write-Host "      TenantId: $TenantId" -ForegroundColor Gray }
    Write-Host "      Scopes:   $($Scopes -join ', ')" -ForegroundColor Gray

    # Normalize scopes - MSAL needs fully-qualified URIs for resource scopes
    $fullScopes = $Scopes | ForEach-Object {
        if ($_ -like 'https://*' -or $_ -in @('openid', 'profile', 'offline_access', 'email')) {
            $_
        } else {
            "https://graph.microsoft.com/$_"
        }
    }

    $token = [BrowserAuthHelper]::GetAccessToken($ClientId, [string[]]$fullScopes, $TenantId)

    if (-not $token) { throw "MSAL returned an empty token." }
    Write-Host "      Token acquired ($(($token.Length)) chars)." -ForegroundColor Green
    return $token
}

# ============================================================
# Step 4: Hand token to Connect-MgGraph and run a test call
# ============================================================
function Test-GraphConnection {
    param([string]$AccessToken)

    Write-Host "[4/4] Connecting Graph SDK with acquired token..." -ForegroundColor Cyan

    # Verify the SDK is available
    if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
        throw "Microsoft.Graph.Authentication module is not installed. Run: Install-Module Microsoft.Graph.Authentication -Scope CurrentUser"
    }
    Import-Module Microsoft.Graph.Authentication -ErrorAction Stop

    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null

    $secure = ConvertTo-SecureString $AccessToken -AsPlainText -Force
    Connect-MgGraph -AccessToken $secure -NoWelcome -ErrorAction Stop

    $ctx = Get-MgContext
    if (-not $ctx) { throw "Connect-MgGraph succeeded but Get-MgContext returned null." }

    Write-Host ""
    Write-Host "Connected." -ForegroundColor Green
    Write-Host "  Account:   $($ctx.Account)" -ForegroundColor Gray
    Write-Host "  Tenant:    $($ctx.TenantId)" -ForegroundColor Gray
    Write-Host "  AuthType:  $($ctx.AuthType)" -ForegroundColor Gray
    Write-Host "  Scopes:    $($ctx.Scopes -join ', ')" -ForegroundColor Gray

    Write-Host ""
    Write-Host "Calling GET /me as a smoke test..." -ForegroundColor Cyan
    try {
        $me = Invoke-MgGraphRequest -Method GET -Uri 'https://graph.microsoft.com/v1.0/me'
        Write-Host "  displayName:       $($me.displayName)" -ForegroundColor Gray
        Write-Host "  userPrincipalName: $($me.userPrincipalName)" -ForegroundColor Gray
        Write-Host "  id:                $($me.id)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "SUCCESS - browser-based auth works end-to-end." -ForegroundColor Green
    } catch {
        Write-Host "GET /me failed: $_" -ForegroundColor Red
        throw
    }
}

# ============================================================
# Main
# ============================================================
try {
    $paths = Find-MsalAssembly
    Initialize-MsalHelper -AssemblyPaths $paths
    $token = Get-GraphTokenViaBrowser -ClientId $ClientId -TenantId $TenantId -Scopes $Scopes
    Test-GraphConnection -AccessToken $token
} catch {
    Write-Host ""
    Write-Host "FAILED: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    exit 1
}
