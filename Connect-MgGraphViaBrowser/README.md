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

`Connect-MgGraphViaBrowser.ps1` sidesteps the SDK's interactive flow entirely:

1. Locates `Microsoft.Identity.Client.dll` (MSAL) from the local NuGet cache, `Az.Accounts`, or `Microsoft.Graph.Authentication`.
2. Compiles a small inline C# helper that calls MSAL directly.
3. Acquires an access token via the **system default browser** using a loopback redirect (`http://localhost`) — no WAM, no embedded WebView.
4. Hands the resulting token to `Connect-MgGraph -AccessToken` so the rest of the Graph SDK works as normal.
5. Runs a `GET /me` smoke test to confirm the connection.

By default the script uses Microsoft's well-known PowerShell public client ID (`14d82eec-204b-4c2f-b7e8-296a70dab67e`), which already has `http://localhost` configured as a redirect URI, so no app registration is required.

## Requirements

- PowerShell 7.0 or later
- `Microsoft.Graph.Authentication` module installed
- One of the following to provide MSAL: `Az.Accounts`, `Microsoft.Graph.Authentication`, or a restored `Microsoft.Identity.Client` NuGet package

## Usage

Run with defaults (multi-tenant, `User.Read` and `Directory.Read.All`):

```powershell
.\Connect-MgGraphViaBrowser.ps1
```

Restrict to a specific tenant:

```powershell
.\Connect-MgGraphViaBrowser.ps1 -TenantId "contoso.onmicrosoft.com"
```

Request custom scopes:

```powershell
.\Connect-MgGraphViaBrowser.ps1 -Scopes 'User.Read.All','Group.Read.All'
```

Use a custom app registration:

```powershell
.\Connect-MgGraphViaBrowser.ps1 -ClientId '00000000-0000-0000-0000-000000000000' -TenantId 'contoso.onmicrosoft.com'
```

If you bring your own `ClientId`, make sure the app registration has `http://localhost` configured as a redirect URI for the **Mobile and desktop applications** platform.

## Parameters

| Parameter | Description |
|-----------|-------------|
| `ClientId` | Optional. Custom app registration Client ID. Defaults to Microsoft's PowerShell public client. |
| `TenantId` | Optional. Tenant to authenticate against. Defaults to the `common` endpoint. |
| `Scopes`   | Microsoft Graph scopes to request. Defaults to `User.Read`, `Directory.Read.All`. |

## Roadmap

This script will be published as a proper PowerShell module so it can be installed from the PowerShell Gallery and consumed as a drop-in replacement for the interactive `Connect-MgGraph` flow until the SDK exposes a non-WAM interactive option again.

## Credits

The MSAL + loopback pattern is adapted from Mark Orr's Entra-PIM script:
https://github.com/markorr321/Entra-PIM/blob/main/Entra-PIM.ps1
