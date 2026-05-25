@{
    RootModule           = 'MgGraphCommunity.psm1'
    ModuleVersion        = '1.0.0'
    GUID                 = 'a7c1f4b8-5d20-4e6e-9a3b-2e8f0d1c7b42'
    Author               = 'MgGraphCommunity contributors'
    CompanyName          = 'Community'
    Copyright            = '(c) MgGraphCommunity contributors. Licensed under MIT.'
    Description          = 'A community-maintained drop-in alternative to Connect-MgGraph. Pure-PowerShell OAuth 2.0 flows (PKCE, device code, client credentials, certificate, managed identity, BYO token). Bypasses WAM on Windows so interactive sign-in actually works. Tokens kept in memory by default; persistent cache is opt-in.'
    PowerShellVersion    = '7.0'

    RequiredModules      = @(
        @{ ModuleName = 'Microsoft.Graph.Authentication'; ModuleVersion = '2.0.0' }
    )

    FunctionsToExport    = @(
        'Connect-MgGraphCommunity',
        'Disconnect-MgGraphCommunity',
        'Get-MgGraphCommunityContext'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()

    PrivateData = @{
        PSData = @{
            Tags         = @('Microsoft','Graph','MgGraph','Authentication','OAuth','PKCE','Intune','Entra','EntraID','Community')
            LicenseUri   = 'https://github.com/ugurkocde/Intune/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/ugurkocde/Intune/tree/main/MgGraphCommunity'
            ReleaseNotes = @'
1.0.0
- Initial community release
- Interactive (PKCE + loopback), DeviceCode, ClientSecret, Certificate (X509/Thumbprint/Subject), AccessToken, ManagedIdentity flows
- Environment selection: Global, USGov, USGovDoD, China
- In-memory token cache by default; opt-in DPAPI-encrypted persistence via -PersistRefreshToken
- Hands tokens to Connect-MgGraph -AccessToken so Microsoft.Graph.* cmdlets keep working
- Pure PowerShell, no MSAL DLL hunting, no compiled C#
'@
        }
    }
}
