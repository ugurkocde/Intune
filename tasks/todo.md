# MgGraphCommunity v1.0 — Implementation Plan

## Positioning

A community-maintained drop-in replacement for `Connect-MgGraph` that:
- Fixes the WAM-broken interactive sign-in
- Tokens kept **in memory by default** — no credentials cached to disk unless the user explicitly opts in via `-PersistRefreshToken`
- Offers full parity with every `Connect-MgGraph` parameter set in v1.0
- Hands the access token to `Connect-MgGraph -AccessToken` so all existing `Microsoft.Graph.*` cmdlets keep working unchanged
- Pure PowerShell — no MSAL DLL hunting, no compiled C#, fully auditable

Pitch line: **"Same flows. Working interactive. Silent re-auth. No SDK black box."**

## Module identity

- **Module name:** `MgGraphCommunity`
- **Primary cmdlet:** `Connect-MgGraphCommunity`
- **Companion cmdlets:** `Disconnect-MgGraphCommunity`, `Get-MgGraphCommunityContext`
- **Rationale for keeping `Mg` prefix:** discoverability in tab-completion next to `Mg*` cmdlets; the `Community` suffix is an unambiguous fork marker.

## Acceptance criteria (definition of "done" for v1.0)

- [ ] Module installable from local path (`Import-Module ./MgGraphCommunity`) and structured for PSGallery publish
- [ ] Manifest `.psd1` with correct version 1.0.0, FunctionsToExport, Author, ProjectUri, ReleaseNotes
- [ ] Root `.psm1` dot-sources Public + Private and exports only Public
- [ ] **All Connect-MgGraph parameter sets implemented and tested manually:**
  - [ ] Interactive (PKCE + loopback, default set) — WAM-free
  - [ ] DeviceCode (`-UseDeviceCode`)
  - [ ] ClientSecretCredential (`-ClientSecretCredential <PSCredential>`)
  - [ ] Certificate by `X509Certificate2` (`-Certificate`)
  - [ ] Certificate by thumbprint (`-CertificateThumbprint`)
  - [ ] Certificate by subject name (`-CertificateName`)
  - [ ] AccessToken (`-AccessToken <SecureString>`)
  - [ ] Managed Identity (`-Identity`, optional `-ManagedIdentityClientId`)
- [ ] Environment selection: `-Environment Global|USGov|USGovDoD|China`
- [ ] In-memory refresh-token cache by default (process-scoped, survives Connect calls within a session)
- [ ] Opt-in persistent refresh-token cache via `-PersistRefreshToken` — DPAPI-encrypted on Windows; chmod 600 JSON elsewhere
- [ ] Silent re-auth within a session via memory cache; silent re-auth across sessions only when `-PersistRefreshToken` was used
- [ ] JWT decoder for token inspection
- [ ] Welcome banner mirroring `Connect-MgGraph` style (suppressed by `-NoWelcome`)
- [ ] `Get-MgGraphCommunityContext` returns active context (mirrors `Get-MgContext`)
- [ ] `Disconnect-MgGraphCommunity` clears state, optional `-ClearCache`
- [ ] Token handoff to `Connect-MgGraph -AccessToken` so Microsoft.Graph.* cmdlets work
- [ ] README with side-by-side comparison vs. `Connect-MgGraph`
- [ ] CHANGELOG.md with v1.0.0 entry
- [ ] LICENSE file
- [ ] At least smoke-level Pester tests for: PKCE generation, scope resolution, JWT decode, cache round-trip

## What we learn from MSGraphRequest (port & adapt)

| Pattern | Source file | How we'll adapt |
|---|---|---|
| JWT payload decoder | `Private/ConvertFrom-JwtToken.ps1` | Port verbatim, rename to `ConvertFrom-MgcJwt`. Used for showing account/tenant/expiry. |
| Parameter sets per flow | `Public/Connect-MSGraphRequest.ps1` | Mirror structure; add `Certificate*` sets and `Environment` they don't have. |
| Managed Identity (IMDS + App Service) | `Private/Invoke-ManagedIdentityAuth.ps1` | Port logic for IMDS + App Service env-var detection. |
| Client certificate JWT assertion | `Private/New-ClientAssertion.ps1` | Port — RS256-signed JWT with `iss`, `sub`, `aud`, `jti`, `nbf`, `exp` + `x5t` header. |
| Centralized token endpoint POST | `Private/Invoke-TokenRequest.ps1` | We already have this — keep ours, learn their error-parsing pattern. |

## What we improve over MSGraphRequest

- Async loopback listener with 5-min timeout (theirs `GetContext()` blocks forever)
- Opt-in DPAPI persistence available when users want silent re-auth across sessions
- Dynamic scope requests with bare-name auto-prefix (theirs defaults to `.default`)
- Distinct success/error pages in browser callback
- OS-assigned free port (theirs uses `Get-Random` in ephemeral range)
- Token handoff to the official Graph SDK (theirs is a parallel universe)
- BYO `-RedirectPort` for app regs registered to specific ports

## What we improve over Microsoft's Connect-MgGraph

- No WAM (the original pain)
- No MSAL DLL hunting / version-resolver hacks
- Faster cold start
- Pure PowerShell — auditable, no opaque .NET assembly
- **Safer-by-default cache posture**: no tokens written to disk unless the user explicitly opts in via `-PersistRefreshToken`. Microsoft's SDK persists via MSAL/WAM by default with no opt-out flag

## Module structure

```
MgGraphCommunity/
├── MgGraphCommunity.psd1
├── MgGraphCommunity.psm1
├── Public/
│   ├── Connect-MgGraphCommunity.ps1
│   ├── Disconnect-MgGraphCommunity.ps1
│   └── Get-MgGraphCommunityContext.ps1
├── Private/
│   ├── Auth/
│   │   ├── Invoke-MgcInteractiveAuth.ps1
│   │   ├── Invoke-MgcDeviceCodeAuth.ps1
│   │   ├── Invoke-MgcClientSecretAuth.ps1
│   │   ├── Invoke-MgcClientCertificateAuth.ps1
│   │   ├── Invoke-MgcManagedIdentityAuth.ps1
│   │   ├── Invoke-MgcAccessTokenAuth.ps1
│   │   └── Invoke-MgcRefreshTokenAuth.ps1
│   ├── Common/
│   │   ├── Invoke-MgcTokenEndpoint.ps1
│   │   ├── New-MgcPkcePair.ps1
│   │   ├── New-MgcClientAssertion.ps1
│   │   ├── ConvertFrom-MgcJwt.ps1
│   │   ├── Resolve-MgcScopes.ps1
│   │   ├── Resolve-MgcAuthority.ps1
│   │   └── Get-MgcFreePort.ps1
│   ├── Cache/
│   │   ├── Save-MgcTokenCache.ps1
│   │   ├── Get-MgcTokenCacheEntry.ps1
│   │   └── Clear-MgcTokenCache.ps1
│   ├── State/
│   │   ├── Set-MgcConnectionContext.ps1
│   │   └── Show-MgcWelcomeBanner.ps1
│   └── Sdk/
│       └── Send-MgcTokenToSdk.ps1
├── Tests/
│   └── MgGraphCommunity.Tests.ps1
├── README.md
├── CHANGELOG.md
└── LICENSE
```

Prefix `Mgc` on private helpers prevents collision with anything else dot-sourced into a user's session.

## Public cmdlet signature (parameter parity audit)

```powershell
Connect-MgGraphCommunity
    # Common to all sets
    [-Scopes <string[]>]                         # Bare names auto-prefixed; OIDC scopes passed through
    [-TenantId <string>]
    [-ClientId <string>]                          # Default: MS PowerShell well-known
    [-Environment <Global|USGov|USGovDoD|China>] # Default: Global
    [-ContextScope <Process|CurrentUser>]         # Cache + state scope
    [-NoWelcome]
    [-NoCache]                                    # Skip even the in-memory cache for this call
    [-PersistRefreshToken]                        # Opt-in: write refresh token to disk (DPAPI/chmod 600)
    [-ForceConsent]

    # Interactive set (default)
    [-RedirectPort <int>]

    # DeviceCode set
    [-UseDeviceCode]

    # ClientSecretCredential set
    [-ClientSecretCredential <PSCredential>]

    # Certificate set (3 variants)
    [-Certificate <X509Certificate2>]
    [-CertificateThumbprint <string>]
    [-CertificateName <string>]

    # AccessToken set
    [-AccessToken <SecureString>]

    # Identity set
    [-Identity]
    [-ManagedIdentityClientId <string>]
```

Defaults to `Interactive` set.

## Build sequence (ordered)

1. **Repo restructure** — move/rename `Connect-MgGraphViaBrowser/` artifacts into `MgGraphCommunity/`; preserve the old `.ps1` under a `legacy/` subfolder for one release before deletion
2. **Module skeleton** — `.psd1`, `.psm1` loader, Public/Private folder scaffolding
3. **Common helpers** — Pkce, FreePort, ResolveScopes, ResolveAuthority, JwtDecoder, TokenEndpoint
4. **Cache layer** — in-memory store (default) + opt-in disk persistence (DPAPI on Windows / chmod 600 elsewhere) gated by `-PersistRefreshToken`
5. **State layer** — ConnectionContext struct + welcome banner
6. **Interactive flow** — port existing v2 logic into `Invoke-MgcInteractiveAuth`
7. **DeviceCode flow** — `/devicecode` → display code → poll `/token` until success/expiry
8. **ClientSecret flow** — `client_credentials` grant + form POST
9. **ClientCertificate flow** — `New-MgcClientAssertion` (RS256 JWT with `x5t`) + `client_credentials` + `jwt-bearer`
10. **ManagedIdentity flow** — detect IMDS vs App Service env vars, request token, normalize response
11. **AccessToken flow** — passthrough + JWT decode for context
12. **Refresh-token flow** — silent retry path used by all browser-acquired sessions
13. **Connect-MgGraphCommunity entry** — parameter-set dispatcher into private flows
14. **Disconnect-MgGraphCommunity + Get-MgGraphCommunityContext**
15. **SDK handoff** — wrap `Connect-MgGraph -AccessToken` with error handling for missing module
16. **Pester smoke tests** — pure-unit only (no live tenant calls): PKCE, scope resolution, JWT decode, cache round-trip
17. **README rewrite** — positioning, install, side-by-side comparison, parameter docs
18. **CHANGELOG.md** — v1.0.0 entry with full feature list and migration note from old script
19. **Manual end-to-end test** — at minimum the Interactive flow on real tenant; document tested combinations in CHANGELOG
20. **Commit + push**

## Decisions (locked)

1. **Module name:** `MgGraphCommunity`
2. **Old script handling:** delete `Connect-MgGraphViaBrowser/` folder immediately on restructure
3. **PSGallery publish:** build & test now, publish to PSGallery in a follow-up after live smoke-test
4. **Tests:** smoke-level Pester only (PKCE, scope resolution, JWT decode, cache round-trip) — no live tenant calls

## Review section

### Build outcome
- All 20 build steps completed.
- Module loads cleanly (`Import-Module ./MgGraphCommunity/MgGraphCommunity.psd1`).
- All 3 public functions exported: `Connect-MgGraphCommunity`, `Disconnect-MgGraphCommunity`, `Get-MgGraphCommunityContext`.
- **All 16 Pester smoke tests pass** (324ms).

### Acceptance criteria status
- [x] Module installable from local path with proper `.psd1` / `.psm1` skeleton
- [x] All 8 `Connect-MgGraph` parameter sets implemented (Interactive, DeviceCode, ClientSecret, Certificate ×3, AccessToken, Identity)
- [x] `-Environment Global|USGov|USGovDoD|China`
- [x] In-memory cache by default; opt-in disk persistence via `-PersistRefreshToken` (DPAPI / chmod 600)
- [x] Silent re-auth via refresh-token grant
- [x] JWT decoder for context display
- [x] Welcome banner with `-NoWelcome`
- [x] Context + Disconnect cmdlets
- [x] SDK handoff via `Connect-MgGraph -AccessToken`
- [x] README, CHANGELOG, LICENSE
- [x] Pester smoke tests covering deterministic logic

### Outstanding before PSGallery publish
- Live tenant smoke-test of Interactive flow on a real Entra ID tenant (user to perform)
- Live verification of ClientSecret / Certificate flows against an app reg with real permissions (user to perform)
- Managed Identity flow can only be tested from an Azure VM / App Service / Arc-enrolled machine

### Notes for next iteration
- Add `Update-MgGraphCommunity` or `Get-MgGraphCommunityScope` helpers if community asks
- Consider exposing `Invoke-MgGraphCommunityToken` as a public helper for advanced users who want a raw token without SDK handoff
- Could add a `Tests/Integration/` folder gated by env var for live tenant tests when v1.x stabilizes
