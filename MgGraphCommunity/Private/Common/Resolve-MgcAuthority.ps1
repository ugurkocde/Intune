function Resolve-MgcAuthority {
    <#
    .SYNOPSIS
        Resolves the login + Graph endpoints for a named Microsoft cloud environment.

    .DESCRIPTION
        Mirrors the -Environment parameter on Connect-MgGraph. Supported values:
            Global    -> login.microsoftonline.com    + graph.microsoft.com
            USGov     -> login.microsoftonline.us     + graph.microsoft.us
            USGovDoD  -> login.microsoftonline.us     + dod-graph.microsoft.us
            China     -> login.chinacloudapi.cn       + microsoftgraph.chinacloudapi.cn

    .OUTPUTS
        [pscustomobject] with .Login, .GraphResource, .Environment
    #>
    [CmdletBinding()]
    param(
        [ValidateSet('Global','USGov','USGovDoD','China')]
        [string]$Environment = 'Global'
    )

    switch ($Environment) {
        'USGov' {
            return [pscustomobject]@{
                Environment   = 'USGov'
                Login         = 'https://login.microsoftonline.us'
                GraphResource = 'https://graph.microsoft.us'
            }
        }
        'USGovDoD' {
            return [pscustomobject]@{
                Environment   = 'USGovDoD'
                Login         = 'https://login.microsoftonline.us'
                GraphResource = 'https://dod-graph.microsoft.us'
            }
        }
        'China' {
            return [pscustomobject]@{
                Environment   = 'China'
                Login         = 'https://login.chinacloudapi.cn'
                GraphResource = 'https://microsoftgraph.chinacloudapi.cn'
            }
        }
        default {
            return [pscustomobject]@{
                Environment   = 'Global'
                Login         = 'https://login.microsoftonline.com'
                GraphResource = 'https://graph.microsoft.com'
            }
        }
    }
}
