<#
.SYNOPSIS
    Checks if BitLocker keys for Windows devices are stored in Entra ID.

.DESCRIPTION
    This script connects to Microsoft Graph API, retrieves all Windows devices from Intune,
    and checks if each device has a BitLocker key stored in Entra ID. The results are 
    displayed in a table and exported to a CSV file.

.EXAMPLE
    .\BitLocker_EntraID_Check.ps1

.NOTES
    Author: Ugur Koc
    GitHub: https://github.com/ugurkocde
    Twitter: https://x.com/UgurKocDe
    LinkedIn: https://www.linkedin.com/in/ugurkocde/

    Version: 1.1
    Created: 31/07/2024
    Updated: 01/08/2024
    Changes: Added nextlink to get all devices with pagination. (limit without nextlink is 1000 devices)

    Required Permissions:
    - DeviceManagementManagedDevices.Read.All
    - BitlockerKey.Read.All

    Disclaimer: This script is provided AS IS without warranty of any kind.
#>

# Check if Microsoft.Graph.Authentication module is installed and import it
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
    Write-Host "Microsoft.Graph.Authentication module not found. Attempting to install..." -ForegroundColor Yellow
    try {
        Install-Module -Name Microsoft.Graph.Authentication -Scope CurrentUser -Force -AllowClobber
        Write-Host "Microsoft.Graph.Authentication module installed successfully" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to install Microsoft.Graph.Authentication module: $_" -ForegroundColor Red
        Write-Host "Please install the Microsoft.Graph.Authentication module manually and rerun the script" -ForegroundColor Red
        exit 1
    }
}

# Connect to Microsoft Graph
Connect-MgGraph -Scopes "DeviceManagementManagedDevices.Read.All", "BitlockerKey.Read.All" -NoWelcome

# Function to get BitLocker key for a device
function Get-BitLockerKey {
    param (
        [string]$azureADDeviceId
    )

    $keyIdUri = "https://graph.microsoft.com/beta/informationProtection/bitlocker/recoveryKeys?`$filter=deviceId eq '$azureADDeviceId'"
    $keyIdResponse = Invoke-MgGraphRequest -Uri $keyIdUri -Method GET

    if ($keyIdResponse.value.Count -gt 0) {
        return "Yes"
    }
    return "No"
}

# Get all Windows devices from Intune (with pagination)
$devicesUri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=operatingSystem eq 'Windows'"
$devices = @()

do {
    $response = Invoke-MgGraphRequest -Uri $devicesUri -Method GET
    $devices += $response.value
    $devicesUri = $response.'@odata.nextLink'
} while ($devicesUri)

$results = @()

foreach ($device in $devices) {
    $hasBitlockerKey = Get-BitLockerKey -azureADDeviceId $device.azureADDeviceId

    $results += [PSCustomObject]@{
        DeviceName = $device.deviceName
        SerialNumber = $device.serialNumber
        "BitLocker Key in EntraID" = $hasBitlockerKey
        "Last Sync With Intune" = $device.lastSyncDateTime.ToString("yyyy-MM-dd")
    }
}

# Display results
$results | Format-Table -AutoSize

# Calculate summary statistics
$totalDevices = $results.Count
$devicesWithKey = ($results | Where-Object { $_.'BitLocker Key in EntraID' -eq 'Yes' }).Count
$devicesWithoutKey = $totalDevices - $devicesWithKey

# Display summary
Write-Host "`nSummary:" -ForegroundColor Cyan
Write-Host "Total Windows devices in Intune: $totalDevices" -ForegroundColor Yellow
Write-Host "Devices with BitLocker key stored in Entra ID: $devicesWithKey" -ForegroundColor Green
Write-Host "Devices without BitLocker key stored in Entra ID: $devicesWithoutKey" -ForegroundColor Red

$results | Export-Csv -Path "BitLockerKeyStatus.csv" -NoTypeInformation