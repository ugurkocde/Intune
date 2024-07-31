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

    Version: 1.0
    Created: 31/07/2024

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

# Get all Windows devices from Intune
$devicesUri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=operatingSystem eq 'Windows'"
$devices = Invoke-MgGraphRequest -Uri $devicesUri -Method GET

$results = @()

foreach ($device in $devices.value) {
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

$results | Export-Csv -Path "BitLockerKeyStatus.csv" -NoTypeInformation