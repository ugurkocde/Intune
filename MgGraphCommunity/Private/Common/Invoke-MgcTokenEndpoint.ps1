function Invoke-MgcTokenEndpoint {
    <#
    .SYNOPSIS
        Sends a form-encoded POST to a Microsoft identity platform token endpoint.

    .DESCRIPTION
        Centralizes all /token calls. Parses AAD error responses into a useful
        exception message ("error - error_description") instead of a raw HTTP error.

    .PARAMETER Url
        Full token endpoint URL.

    .PARAMETER Body
        Hashtable of form parameters.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)][hashtable]$Body
    )

    try {
        return Invoke-RestMethod -Uri $Url -Method POST -Body $Body `
            -ContentType 'application/x-www-form-urlencoded' -ErrorAction Stop
    } catch {
        $msg = $_.Exception.Message
        try {
            if ($_.ErrorDetails.Message) {
                $err = $_.ErrorDetails.Message | ConvertFrom-Json
                if ($err.error -or $err.error_description) {
                    $msg = "Token request failed: $($err.error) - $($err.error_description)"
                }
            }
        } catch { }
        throw $msg
    }
}
