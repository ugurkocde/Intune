# MgGraphCommunity

A community-maintained drop-in alternative to `Connect-MgGraph`. Pure PowerShell, no MSAL DLL hunting, no compiled C#, **no WAM**.

> Same flows. Working interactive. Safer-by-default cache. No SDK black box.

## Why this exists

Starting in `Microsoft.Graph` v2.34, the SDK made the **Windows Account Manager (WAM)** the default broker for interactive sign-in on Windows. WAM is on by default on current Windows builds, and as a result `Connect-MgGraph` no longer behaves the way many admins rely on:

- Secondary / service accounts not registered on the local device fail or require full credentials (email + password + MFA) on every call.
- The classic interactive authorization-code flow (system browser, loopback redirect) is unreachable from the SDK's interactive path.
- For admins managing multiple tenants from one workstation, this is a real productivity and security regression.

Reference: <https://github.com/microsoftgraph/msgraph-sdk-powershell/issues/3481#issuecomment-3687499347>

## What it does

`MgGraphCommunity` ships a single cmdlet, `Connect-MgGraphCommunity`, that supports every flow `Connect-MgGraph` supports — implemented as pure PowerShell against the Microsoft identity platform v2 endpoints. After acquiring a token it hands it to `Connect-MgGraph -AccessToken`, so all existing `Microsoft.Graph.*` cmdlets keep working unchanged.

| Flow                 | How to invoke                                               |
|----------------------|-------------------------------------------------------------|
| Interactive (PKCE)   | `Connect-MgGraphCommunity` *(default — no WAM)*             |
| Device Code          | `Connect-MgGraphCommunity -UseDeviceCode`                   |
| Client Secret        | `Connect-MgGraphCommunity -ClientSecretCredential $cred`    |
| Certificate (X509)   | `Connect-MgGraphCommunity -Certificate $cert`               |
| Certificate (Thumb)  | `Connect-MgGraphCommunity -CertificateThumbprint '...'`     |
| Certificate (Name)   | `Connect-MgGraphCommunity -CertificateName 'CN=...'`        |
| Access Token (BYO)   | `Connect-MgGraphCommunity -AccessToken $secure`             |
| Managed Identity     | `Connect-MgGraphCommunity -Identity`                        |

Sovereign clouds: pass `-Environment Global|USGov|USGovDoD|China`.

## Comparison

| Behavior                          | Connect-MgGraph (SDK)             | MgGraphCommunity                                  |
|-----------------------------------|-----------------------------------|---------------------------------------------------|
| Interactive sign-in on Windows    | WAM (broken for secondary accts)  | System browser + PKCE                             |
| Dependency                        | MSAL (`Microsoft.Identity.Client`)| None beyond `Microsoft.Graph.Authentication`      |
| Token persistence default         | DPAPI via MSAL, no opt-out flag   | In-memory only; disk persistence opt-in           |
| Compiled assemblies               | Yes                               | None — pure PowerShell                            |
| Cold start                        | Slower (MSAL load)                | Fast                                              |
| Auditability                      | Opaque                            | Every line readable                               |

## Requirements

- PowerShell 7.0 or later
- `Microsoft.Graph.Authentication` (used only for the final `Connect-MgGraph -AccessToken` handoff)

## Install (from this repo)

```powershell
git clone https://github.com/ugurkocde/Intune.git
Import-Module ./Intune/MgGraphCommunity/MgGraphCommunity.psd1
```

PowerShell Gallery publish coming after live smoke-testing.

## Usage

```powershell
# Basic interactive sign-in
Connect-MgGraphCommunity

# Specific tenant + Intune scopes
Connect-MgGraphCommunity `
    -TenantId 'contoso.onmicrosoft.com' `
    -Scopes   'User.Read','DeviceManagementConfiguration.Read.All','DeviceManagementManagedDevices.Read.All'

# Re-consent (e.g. when adding scopes)
Connect-MgGraphCommunity -Scopes 'NewScope.Read.All' -ForceConsent

# Persist refresh token to disk (silent re-auth across sessions)
Connect-MgGraphCommunity -PersistRefreshToken

# Use existing Microsoft.Graph cmdlets after connect
Get-MgUser -Top 5

# Disconnect (also clears in-memory cache)
Disconnect-MgGraphCommunity

# Disconnect + delete on-disk persisted refresh tokens
Disconnect-MgGraphCommunity -ClearCache
```

## Token cache & security posture

By default, the only place a refresh token lives is **in memory**, scoped to the PowerShell session. Close the shell and it's gone.

- `-PersistRefreshToken` opts in to disk persistence: DPAPI-encrypted on Windows (`%LOCALAPPDATA%\MgGraphCommunity\tokens.json`), restricted-permission JSON on macOS/Linux (`~/.local/share/MgGraphCommunity/tokens.json`).
- The cache key includes ClientId, TenantId, Authority, and ParameterSet, so multiple identities and flows coexist.
- `-NoCache` skips both layers for one call.
- `Disconnect-MgGraphCommunity -ClearCache` wipes the persisted file.

This is intentionally more conservative than Microsoft's SDK, which persists tokens via MSAL by default with no opt-out flag.

## Bring your own app registration

Pass `-ClientId` and `-TenantId` (and optionally `-RedirectPort`):

```powershell
Connect-MgGraphCommunity `
    -ClientId     '00000000-0000-0000-0000-000000000000' `
    -TenantId     'contoso.onmicrosoft.com' `
    -RedirectPort 1985
```

App reg setup:

1. Register a new application in Entra ID.
2. **Authentication → Add a platform → Mobile and desktop applications**: add `http://localhost` (or a specific `http://localhost:PORT`, in which case pass `-RedirectPort PORT`).
3. **API permissions**: add the delegated Graph scopes you need and grant admin consent if required.

## License

MIT — see [LICENSE](LICENSE).

## Credits

Inspired by the OAuth Auth Code + PKCE loopback patterns in [MSGraphRequest](https://www.powershellgallery.com/packages/MSGraphRequest), [M365Permissions](https://github.com/jflieben/M365Permissions), and Mark Orr's [Entra-PIM](https://github.com/markorr321/Entra-PIM).
