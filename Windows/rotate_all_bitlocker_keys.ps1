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

.REQUIREMENTS
    - PowerShell 5.1 or later
    - Microsoft.Graph.Authentication module
    - Microsoft.Graph.DeviceManagement module

.LINK
    https://learn.microsoft.com/en-us/graph/api/intune-devices-manageddevice-rotatebitlockerkeys?view=graph-rest-beta

.EXAMPLE
    .\rotate-bitlocker-keys.ps1

.NOTES
    EntraID App Registration Permission (Least privileged permissions):
    - DeviceManagementManagedDevices.ReadWrite.All, Details: https://learn.microsoft.com/en-us/graph/api/intune-devices-manageddevice-rotatebitlockerkeys?view=graph-rest-beta

    Disclaimer: This script is provided AS IS without warranty of any kind. Use it at your own risk.
#>

<#
.SYNOPSIS
    Rotates BitLocker keys for all Windows devices in Intune using Graph API.

.DESCRIPTION
    This script connects to Intune via Graph API and rotates the BitLocker keys for all managed Windows devices.

.NOTES
    Author: Ugur Koc
    GitHub: https://github.com/ugurkocde
    Twitter: https://x.com/UgurKocDe
    LinkedIn: https://www.linkedin.com/in/ugurkocde/

    Version: 1.0
    Created: [Insert creation date]
    Last Updated: [Insert last update date]

.REQUIREMENTS
    - PowerShell 5.1 or later
    - Microsoft.Graph.Authentication module
    - Microsoft.Graph.DeviceManagement module

.LINK
    https://learn.microsoft.com/en-us/graph/api/intune-devices-manageddevice-rotatebitlockerkeys?view=graph-rest-beta

.EXAMPLE
    .\rotate-bitlocker-keys.ps1

.NOTES
    EntraID App Registration Permission (Least privileged permissions):
    - DeviceManagementManagedDevices.ReadWrite.All

    Disclaimer: This script is provided AS IS without warranty of any kind. Use it at your own risk.
#>

# Prerequisites
$appid = '' # App ID of the App Registration
$tenantid = '' # Tenant ID of your EntraID
$secret = '' # Secret of the App Registration

$body = @{
    Grant_Type    = "client_credentials"
    Scope         = "https://graph.microsoft.com/.default"
    Client_Id     = $appid
    Client_Secret = $secret
}

$connection = Invoke-RestMethod `
    -Uri https://login.microsoftonline.com/$tenantid/oauth2/v2.0/token `
    -Method POST `
    -Body $body

$token = $connection.access_token
$secureToken = ConvertTo-SecureString $token -AsPlainText -Force
Connect-MgGraph -AccessToken $secureToken -NoWelcome

# Get all managed devices from Intune
$managedDevices = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$select=id,deviceName,operatingSystem"

foreach ($device in $managedDevices.value) {
    $deviceId = $device.id
    $deviceName = $device.deviceName
    $operatingSystem = $device.operatingSystem

    Write-Host "Processing device: $deviceName" -ForegroundColor Cyan

    if ($operatingSystem -like "*Windows*") {
        # Attempt to rotate the BitLocker keys
        try {
            $rotatedKey = Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices('$deviceId')/rotateBitLockerKeys" -ContentType "application/json"

            Write-Host "Successfully rotated BitLocker keys for device $deviceName" -ForegroundColor Green
        }
        catch {
            Write-Host "Failed to rotate BitLocker keys for device $deviceName" -ForegroundColor Red
            Write-Host "Error: $_" -ForegroundColor Red
        }
    }
    else {
        Write-Host "Skipping non-Windows device: $deviceName" -ForegroundColor Yellow
    }
}

Write-Host "BitLocker key rotation process completed." -ForegroundColor Cyan