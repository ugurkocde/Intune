# Changelog

All notable changes to MgGraphCommunity are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-05-25

Initial community release. Drop-in alternative to `Connect-MgGraph` with full flow parity, fixing the WAM-broken interactive sign-in.

### Added
- `Connect-MgGraphCommunity` with parameter sets for every flow `Connect-MgGraph` exposes:
  - Interactive (default) — Authorization Code + PKCE via system browser and loopback listener
  - DeviceCode (`-UseDeviceCode`)
  - ClientSecret (`-ClientSecretCredential`)
  - Certificate (`-Certificate`, `-CertificateThumbprint`, `-CertificateName`)
  - AccessToken (`-AccessToken`)
  - Managed Identity (`-Identity`, optional `-ManagedIdentityClientId`) — IMDS, App Service, and Azure Arc
- `Disconnect-MgGraphCommunity` (optionally `-ClearCache`)
- `Get-MgGraphCommunityContext` returning the active connection context
- `-Environment Global|USGov|USGovDoD|China` for sovereign clouds
- `-PersistRefreshToken` opt-in disk cache (DPAPI on Windows, `chmod 600` JSON elsewhere)
- In-memory token cache by default — no credentials written to disk unless explicitly opted in
- Silent refresh-token flow when a cached refresh token exists
- Pester smoke tests for PKCE generation, scope resolution, authority resolution, JWT decode, and cache round-trip
- Hands the access token to `Connect-MgGraph -AccessToken` so all `Microsoft.Graph.*` cmdlets keep working

### Notes
- Replaces the earlier standalone script (previously under `Connect-MgGraphViaBrowser/`), which has been removed in favor of the module structure.
- Not yet published to PowerShell Gallery — install from this repository via `Import-Module`. Gallery publish planned after live smoke-testing.
