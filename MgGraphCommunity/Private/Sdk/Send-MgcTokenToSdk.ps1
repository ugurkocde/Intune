function Send-MgcTokenToSdk {
    <#
    .SYNOPSIS
        Hands an access token to Microsoft.Graph.Authentication's Connect-MgGraph
        so that downstream Microsoft.Graph.* cmdlets work normally.

    .PARAMETER AccessToken
        Raw access token string.

    .PARAMETER NoWelcome
        Suppresses the Connect-MgGraph welcome banner (we print our own).
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText','',
        Justification = 'Connect-MgGraph requires SecureString; token already in memory as plaintext.')]
    param(
        [Parameter(Mandatory)][string]$AccessToken,
        [switch]$NoWelcome
    )

    if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
        throw "Microsoft.Graph.Authentication is not installed. Run: Install-Module Microsoft.Graph.Authentication -Scope CurrentUser"
    }
    Import-Module Microsoft.Graph.Authentication -ErrorAction Stop

    # Avoid duplicate sessions inside the SDK
    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null

    $secure = ConvertTo-SecureString $AccessToken -AsPlainText -Force
    if ($NoWelcome) {
        Connect-MgGraph -AccessToken $secure -NoWelcome -ErrorAction Stop | Out-Null
    } else {
        # Always suppress the SDK banner — we print our own
        Connect-MgGraph -AccessToken $secure -NoWelcome -ErrorAction Stop | Out-Null
    }
}
