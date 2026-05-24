# Connect-MgGraphViaBrowser

A standalone PowerShell script that signs in to Microsoft Graph using the system's default web browser, bypassing the Microsoft Graph PowerShell SDK's built-in interactive flow.

## Why this exists

Recent updates to the `Microsoft.Graph` PowerShell SDK (starting with v2.34) made the **Windows Account Manager (WAM)** the default broker for interactive sign-in on Windows. WAM is enabled by default on current Windows builds, and as a result `Connect-MgGraph` no longer behaves the way many admins rely on:

- Secondary / service accounts that are not registered on the local device cannot be used cleanly. Each sign-in requires full credentials (email + password + MFA) every time, even for accounts that previously worked with passkeys or browser-based delegated auth.
- The classic interactive authorization-code flow (system browser, loopback redirect) is effectively unreachable from the SDK's interactive path.
- For admins who manage multiple tenants from a single workstation, this is a real productivity and security regression, and is pushing people toward unofficial modules.

Reference / discussion thread:
https://github.com/microsoftgraph/msgraph-sdk-powershell/issues/3481#issuecomment-3687499347

## What this script does

`Connect-MgGraphViaBrowser.ps1` sidesteps the SDK's interactive flow entirely using pure PowerShell — no MSAL, no compiled C#, no embedded WebView, no WAM:

1. Generates an OAuth 2.0 PKCE challenge.
2. Starts a local loopback `HttpListener` on a free port (or a port you specify).
3. Opens the user's **system default browser** to the Microsoft identity platform `/authorize` endpoint.
4. Captures the authorization code on the loopback redirect.
5. Exchanges the code for an access + refresh token at the `/token` endpoint.
6. Hands the access token to `Connect-MgGraph -AccessToken` so the rest of the Graph SDK works as normal.
7. Caches the refresh token locally (DPAPI-encrypted on Windows, restricted-permission JSON on macOS/Linux) so subsequent sign-ins are silent until the refresh token expires.

By default the script uses Microsoft's well-known PowerShell public client ID (`14d82eec-204b-4c2f-b7e8-296a70dab67e`), which already has `http://localhost` configured as a redirect URI, so no app registration is required.

## Requirements

- PowerShell 7.0 or later
- `Microsoft.Graph.Authentication` module installed (used only for the final `Connect-MgGraph -AccessToken` handoff)

## Usage

Run with defaults (multi-tenant, `User.Read`):

```powershell
.\Connect-MgGraphViaBrowser.ps1
```

Restrict to a specific tenant:

```powershell
.\Connect-MgGraphViaBrowser.ps1 -TenantId "contoso.onmicrosoft.com"
```

Request custom scopes (Intune example):

```powershell
.\Connect-MgGraphViaBrowser.ps1 -Scopes `
    'User.Read', `
    'DeviceManagementConfiguration.Read.All', `
    'DeviceManagementManagedDevices.Read.All'
```

Force the consent prompt (e.g. when adding new scopes):

```powershell
.\Connect-MgGraphViaBrowser.ps1 -Scopes 'NewScope.Read.All' -ForceConsent
```

Skip the refresh-token cache for this call:

```powershell
.\Connect-MgGraphViaBrowser.ps1 -NoCache
```

## Bring your own app registration

Pass `-ClientId` and `-TenantId` (and optionally `-RedirectPort`) to authenticate against your own multi-tenant or single-tenant app registration:

```powershell
.\Connect-MgGraphViaBrowser.ps1 `
    -ClientId     '00000000-0000-0000-0000-000000000000' `
    -TenantId     'contoso.onmicrosoft.com' `
    -RedirectPort 1985
```

To prepare a BYO app registration:

1. Register a new application in Entra ID.
2. Under **Authentication → Add a platform → Mobile and desktop applications**, add `http://localhost` (or a specific `http://localhost:PORT`, in which case pass `-RedirectPort PORT`).
3. Under **API permissions**, add the delegated Microsoft Graph scopes you need and grant admin consent if required.
4. Pass `-ClientId <appId>` and `-TenantId <tenantId>` when calling the script.

## Parameters

| Parameter | Description |
|-----------|-------------|
| `Scopes`        | Microsoft Graph delegated scopes. Bare names are auto-prefixed with the Graph resource URI; fully-qualified scopes and OIDC reserved scopes are passed through. `offline_access` is always added. Default: `User.Read`. |
| `ClientId`      | Optional. Custom app registration Client ID. Defaults to Microsoft's PowerShell public client. |
| `TenantId`      | Optional. Tenant ID or verified domain. Defaults to the `common` endpoint. |
| `RedirectPort`  | Optional. Fixed loopback port for the redirect URI. Defaults to a random free port. |
| `ForceConsent`  | Force the consent prompt (`prompt=consent`). |
| `NoCache`       | Do not read or write the refresh-token cache for this call. |

## Token cache

Refresh tokens are persisted to:

```
%LOCALAPPDATA%\Connect-MgGraphViaBrowser\tokens.json     (Windows)
~/.local/share/Connect-MgGraphViaBrowser/tokens.json     (macOS/Linux)
```

- On Windows the refresh token is encrypted with **DPAPI** (the same mechanism Edge, Chrome, and the Microsoft.Graph SDK use). The ciphertext is decryptable only by the same Windows user on the same machine.
- On macOS/Linux the file is written with `chmod 600` and stored as plain JSON. This is weaker than DPAPI and may be tightened in a future version.
- The cache is keyed by `ClientId|TenantId` so multiple identities and tenants coexist without conflicting.

## Roadmap

This script will be published as a proper PowerShell module so it can be installed from the PowerShell Gallery and consumed as a drop-in replacement for the interactive `Connect-MgGraph` flow until the SDK exposes a non-WAM interactive option again.

## Credits

Inspired by the OAuth Auth Code + PKCE loopback pattern used in [M365Permissions](https://github.com/jflieben/M365Permissions) by Jos Lieben, and Mark Orr's [Entra-PIM](https://github.com/markorr321/Entra-PIM) script.
