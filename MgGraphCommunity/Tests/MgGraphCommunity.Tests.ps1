#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

# Smoke tests — pure unit, no live tenant calls.

BeforeAll {
    $script:ModuleRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
    Import-Module (Join-Path $script:ModuleRoot 'MgGraphCommunity.psd1') -Force

    # Dot-source private helpers into this test scope for direct testing
    Get-ChildItem -Path (Join-Path $script:ModuleRoot 'Private') -Recurse -Filter '*.ps1' |
        ForEach-Object { . $_.FullName }
}

Describe 'New-MgcPkcePair' {
    It 'returns a verifier and S256 challenge of the right shape' {
        $pair = New-MgcPkcePair
        $pair.Verifier  | Should -Match '^[A-Za-z0-9\-_]+$'
        $pair.Challenge | Should -Match '^[A-Za-z0-9\-_]+$'
        $pair.Method    | Should -Be 'S256'
        $pair.Verifier.Length  | Should -BeGreaterThan 40
        $pair.Challenge.Length | Should -Be 43   # SHA-256 base64url unpadded
    }

    It 'produces a unique pair each call' {
        $a = New-MgcPkcePair
        $b = New-MgcPkcePair
        $a.Verifier | Should -Not -Be $b.Verifier
    }
}

Describe 'Resolve-MgcAuthority' {
    It 'returns Global endpoints by default' {
        $a = Resolve-MgcAuthority
        $a.Login         | Should -Be 'https://login.microsoftonline.com'
        $a.GraphResource | Should -Be 'https://graph.microsoft.com'
    }

    It 'returns USGov endpoints' {
        $a = Resolve-MgcAuthority -Environment USGov
        $a.GraphResource | Should -Be 'https://graph.microsoft.us'
    }

    It 'returns China endpoints' {
        $a = Resolve-MgcAuthority -Environment China
        $a.Login         | Should -Be 'https://login.chinacloudapi.cn'
        $a.GraphResource | Should -Be 'https://microsoftgraph.chinacloudapi.cn'
    }
}

Describe 'Resolve-MgcScopes' {
    It 'auto-prefixes bare scopes with the Graph resource URI' {
        $s = Resolve-MgcScopes -Scopes 'User.Read','Mail.Read' -GraphResource 'https://graph.microsoft.com'
        $s | Should -Contain 'https://graph.microsoft.com/User.Read'
        $s | Should -Contain 'https://graph.microsoft.com/Mail.Read'
    }

    It 'always adds offline_access' {
        $s = Resolve-MgcScopes -Scopes 'User.Read' -GraphResource 'https://graph.microsoft.com'
        $s | Should -Contain 'offline_access'
    }

    It 'passes through fully-qualified scopes unchanged' {
        $s = Resolve-MgcScopes -Scopes 'https://graph.microsoft.com/.default' -GraphResource 'https://graph.microsoft.com'
        $s | Should -Contain 'https://graph.microsoft.com/.default'
    }

    It 'passes through OIDC scopes unchanged' {
        $s = Resolve-MgcScopes -Scopes 'openid','profile' -GraphResource 'https://graph.microsoft.com'
        $s | Should -Contain 'openid'
        $s | Should -Contain 'profile'
    }

    It 'defaults to User.Read when nothing supplied' {
        $s = Resolve-MgcScopes -Scopes @() -GraphResource 'https://graph.microsoft.com'
        $s | Should -Contain 'https://graph.microsoft.com/User.Read'
    }
}

Describe 'ConvertFrom-MgcJwt' {
    It 'decodes a known payload' {
        # Hand-crafted JWT: header={alg:none}, payload={sub:abc,upn:test@x.com}, sig=
        $header  = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes('{"alg":"none","typ":"JWT"}')).TrimEnd('=').Replace('+','-').Replace('/','_')
        $payload = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes('{"sub":"abc","upn":"test@example.com","tid":"tenant-guid","exp":1700000000}')).TrimEnd('=').Replace('+','-').Replace('/','_')
        $jwt = "$header.$payload."
        $decoded = ConvertFrom-MgcJwt -Token $jwt
        $decoded.sub | Should -Be 'abc'
        $decoded.upn | Should -Be 'test@example.com'
        $decoded.tid | Should -Be 'tenant-guid'
        $decoded.exp | Should -Be 1700000000
    }

    It 'throws on a malformed token' {
        { ConvertFrom-MgcJwt -Token 'not-a-jwt' } | Should -Throw
    }
}

Describe 'Token cache round-trip (in-memory)' {
    BeforeEach { Clear-MgcTokenCache }

    It 'stores and retrieves a token by key' {
        $tokens = [pscustomobject]@{ access_token = 'AT'; refresh_token = 'RT'; expires_in = 3600 }
        Save-MgcTokenCache -Key 'k1' -Tokens $tokens
        $back = Get-MgcTokenCacheEntry -Key 'k1'
        $back.access_token  | Should -Be 'AT'
        $back.refresh_token | Should -Be 'RT'
    }

    It 'returns null for unknown keys' {
        Get-MgcTokenCacheEntry -Key 'never-saved' | Should -BeNullOrEmpty
    }

    It 'Clear-MgcTokenCache empties the in-memory store' {
        Save-MgcTokenCache -Key 'k2' -Tokens ([pscustomobject]@{ access_token = 'x' })
        Clear-MgcTokenCache
        Get-MgcTokenCacheEntry -Key 'k2' | Should -BeNullOrEmpty
    }
}

Describe 'Module loads and exports the expected functions' {
    It 'exports the three public functions' {
        $m = Get-Module MgGraphCommunity
        $m.ExportedFunctions.Keys | Should -Contain 'Connect-MgGraphCommunity'
        $m.ExportedFunctions.Keys | Should -Contain 'Disconnect-MgGraphCommunity'
        $m.ExportedFunctions.Keys | Should -Contain 'Get-MgGraphCommunityContext'
    }
}
