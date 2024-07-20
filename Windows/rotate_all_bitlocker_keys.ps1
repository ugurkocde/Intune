<#
.SYNOPSIS
    Rotates All BitLocker keys for all Windows devices in Intune using Graph API.

.DESCRIPTION
    This script connects to Intune via Graph API and rotates the BitLocker keys for all managed Windows devices.

.NOTES
    Author: Ugur Koc
    GitHub: https://github.com/ugurkocde
    Twitter: https://x.com/UgurKocDe
    LinkedIn: https://www.linkedin.com/in/ugurkocde/

    Version: 1.0
    Created: 07/20/2024
    Version: 1.1 (07/20/2024)
    - Changed Authentication to Connect-MgGraph -Scopes only. 

.REQUIREMENTS
    - PowerShell 5.1 or later
    - Microsoft.Graph.Authentication module

.LINK
    https://learn.microsoft.com/en-us/graph/api/intune-devices-manageddevice-rotatebitlockerkeys?view=graph-rest-beta

.EXAMPLE
    .\rotate_all_bitlocker_keys.ps1

.NOTES
    Disclaimer: This script is provided AS IS without warranty of any kind. Use it at your own risk.
#>

Connect-MgGraph -Scopes "DeviceManagementManagedDevices.ReadWrite.All" -NoWelcome

# Get all managed Windows devices from Intune with pagination
$managedDevices = @()
$nextLink = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$select=id,deviceName,operatingSystem&`$filter=operatingSystem eq 'Windows'"

# This loop will get all managed devices from Intune with pagination
while ($nextLink) {
    $response = Invoke-MgGraphRequest -Method GET -Uri $nextLink
    $managedDevices += $response.value
    $nextLink = $response.'@odata.nextLink'
}

foreach ($device in $managedDevices) {
    $deviceId = $device.id
    $deviceName = $device.deviceName

    Write-Host "Processing device: $deviceName" -ForegroundColor Cyan

    # Attempt to rotate the BitLocker keys
    try {
        Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices('$deviceId')/rotateBitLockerKeys" -ContentType "application/json"

        Write-Host "Successfully rotated BitLocker keys for device $deviceName" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to rotate BitLocker keys for device $deviceName" -ForegroundColor Red
        Write-Host "Error: $_" -ForegroundColor Red
    }
}

Write-Host "BitLocker key rotation process completed." -ForegroundColor Cyan
