function Show-MgcWelcomeBanner {
    <#
    .SYNOPSIS
        Prints a Connect-MgGraph-style welcome banner for the active session.
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost','',
        Justification = 'User-visible welcome banner — Write-Host is intentional.')]
    param(
        [Parameter(Mandatory)][object]$Context
    )

    Write-Host ''
    Write-Host 'Welcome To MgGraphCommunity!' -ForegroundColor Green
    if ($Context.Account)     { Write-Host ("  Account     : {0}" -f $Context.Account) -ForegroundColor Gray }
    elseif ($Context.AppName) { Write-Host ("  App         : {0}" -f $Context.AppName) -ForegroundColor Gray }
    Write-Host ("  TenantId    : {0}" -f $Context.TenantId)    -ForegroundColor Gray
    Write-Host ("  Environment : {0}" -f $Context.Environment) -ForegroundColor Gray
    Write-Host ("  AuthType    : {0}" -f $Context.AuthType)    -ForegroundColor Gray
    if ($Context.Scopes) {
        Write-Host ("  Scopes      : {0}" -f ($Context.Scopes -join ', ')) -ForegroundColor Gray
    }
    if ($Context.ExpiresOn) {
        $remaining = [int]([math]::Max(0, ($Context.ExpiresOn - (Get-Date)).TotalMinutes))
        Write-Host ("  ExpiresOn   : {0} (in {1} min)" -f $Context.ExpiresOn, $remaining) -ForegroundColor Gray
    }
    Write-Host ("  Persisted   : {0}" -f $Context.Persisted) -ForegroundColor Gray
    Write-Host ''
}
