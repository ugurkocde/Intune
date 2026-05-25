function Invoke-MgcDeviceCodeAuth {
    <#
    .SYNOPSIS
        OAuth 2.0 Device Authorization Grant (RFC 8628).

    .DESCRIPTION
        - Requests a device + user code from /devicecode.
        - Displays the verification URL + user code.
        - Polls /token at the device-code's interval until success, expiration, or denial.

        NOTE: Device code is increasingly blocked by Conditional Access policies. Prefer
        Interactive flow whenever a browser on the same machine is available.
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost','',
        Justification = 'Device code flow requires displaying user_code to the operator.')]
    param(
        [Parameter(Mandatory)][string]$LoginEndpoint,
        [Parameter(Mandatory)][string]$TenantSegment,
        [Parameter(Mandatory)][string]$ClientId,
        [Parameter(Mandatory)][string[]]$Scopes
    )

    $deviceUrl = "$LoginEndpoint/$TenantSegment/oauth2/v2.0/devicecode"
    $tokenUrl  = "$LoginEndpoint/$TenantSegment/oauth2/v2.0/token"

    $deviceBody = @{
        client_id = $ClientId
        scope     = ($Scopes -join ' ')
    }

    try {
        $device = Invoke-RestMethod -Uri $deviceUrl -Method POST -Body $deviceBody `
            -ContentType 'application/x-www-form-urlencoded' -ErrorAction Stop
    } catch {
        throw "Device code request failed: $($_.Exception.Message)"
    }

    Write-Host ''
    Write-Host $device.message -ForegroundColor Yellow
    Write-Host ''

    $interval = if ($device.interval) { [int]$device.interval } else { 5 }
    $deadline = (Get-Date).AddSeconds([int]$device.expires_in)

    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds $interval
        try {
            $body = @{
                client_id   = $ClientId
                grant_type  = 'urn:ietf:params:oauth:grant-type:device_code'
                device_code = $device.device_code
            }
            return Invoke-MgcTokenEndpoint -Url $tokenUrl -Body $body
        } catch {
            $msg = $_.Exception.Message
            if ($msg -match 'authorization_pending') { continue }
            if ($msg -match 'slow_down') { $interval += 5; continue }
            if ($msg -match 'expired_token|access_denied') { throw $msg }
            throw $msg
        }
    }
    throw "Device code expired before the user completed sign-in."
}
