<#
.SYNOPSIS
    Retrieves device details from Intune and writes them to the extensionAttributes of the corresponding device in EntraID.

.DESCRIPTION
    This script connects to Microsoft Graph API to fetch device details from Intune and then updates the extensionAttributes
    of the corresponding device in EntraID. It writes the following details:
    - SerialNumber
    - DeviceEnrollmentType
    - IsEncrypted
    - TotalStorageSpaceInGB
    - EnrollmentProfileName
    - ComplianceState
    - Model
    - Manufacturer

    This script will also write a log file to the current directory.

    It can only write data to the extensionAttributes if the device is already enrolled in Intune.

.NOTES
    Author: Ugur Koc
    GitHub: https://github.com/ugurkocde
    Twitter: https://x.com/UgurKocDe
    LinkedIn: https://www.linkedin.com/in/ugurkocde/

    Version: 1.0
    Created: 24/07/2024

.REQUIREMENTS
    - PowerShell 5.1 or later
    - Microsoft.Graph.Authentication module

.LINK
    https://github.com/ugurkocde/Intune

.EXAMPLE
    .\Write_DeviceDetails_to_ExtensionAttributes.ps1

.NOTES
    EntraID App Registration Permissions (Least privileged):
    - Device.Read.All
    - DeviceManagementManagedDevices.Read.All
    - Directory.AccessAsUser.All

    Disclaimer: This script is provided AS IS without warranty of any kind. Use it at your own risk.
#>

# Check if Microsoft.Graph.Authentication module is installed and import it
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
    Write-Log "Microsoft.Graph.Authentication module not found. Attempting to install..." -Level "WARNING"
    try {
        Install-Module -Name Microsoft.Graph.Authentication -Scope CurrentUser -Force -AllowClobber
        Write-Log "Microsoft.Graph.Authentication module installed successfully" -Level "SUCCESS"
    }
    catch {
        Write-Log "Failed to install Microsoft.Graph.Authentication module: $_" -Level "ERROR"
        Write-Log "Please install the Microsoft.Graph.Authentication module manually and rerun the script" -Level "ERROR"
        exit 1
    }
}

# Function to write log messages
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp [$Level] $Message"
    Add-Content -Path $logFile -Value $logMessage
    
    switch ($Level) {
        "INFO" { Write-Host $logMessage -ForegroundColor Cyan }
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
        "ERROR" { Write-Host $logMessage -ForegroundColor Red }
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        default { Write-Host $logMessage }
    }
}

# Set up logging
$logFile = ".\Write_DeviceDetails_to_ExtensionAttributes_All_Devices.log"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Add-Content -Path $logFile -Value "`n`n--- Script execution started at $timestamp ---"
Write-Log "Script started"

try {
    Connect-MgGraph -Scopes "Device.Read.All", "DeviceManagementManagedDevices.Read.All", "Directory.AccessAsUser.All" -NoWelcome
    Write-Log "Connected to Microsoft Graph"
}
catch {
    Write-Log "Failed to connect to Microsoft Graph: $_" -Level "ERROR"
    exit 1
}

# Get all devices from EntraID with pagination
$devices = @()
$nextLink = "https://graph.microsoft.com/v1.0/devices?`$select=id,displayName,extensionAttributes"

while ($nextLink) {
    try {
        $response = Invoke-MgGraphRequest -Method GET -Uri $nextLink
        $devices += $response.value
        $nextLink = $response.'@odata.nextLink'
    }
    catch {
        Write-Log "Failed to retrieve devices: $_" -Level "ERROR"
        exit 1
    }
}

$deviceCount = $devices.Count
Write-Log "Total devices retrieved: $deviceCount"

if ($deviceCount -eq 0) {
    Write-Log "No devices found. Exiting script." -Level "WARNING"
    exit 0
}

$successCount = 0
$failureCount = 0

for ($i = 0; $i -lt $devices.Count; $i++) {
    $device = $devices[$i]
    $deviceName = $device.displayName
    $deviceId = $device.id

    Write-Log "Processing device: $deviceName"

    # Get device details from Intune
    try {
        $deviceDetailsUri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$filter=deviceName eq '$deviceName'&`$select=serialNumber,deviceEnrollmentType,isEncrypted,totalStorageSpaceInBytes,enrollmentProfileName,complianceState,model,manufacturer"
        $deviceDetailsResponse = Invoke-MgGraphRequest -Uri $deviceDetailsUri -Method GET

        if ($deviceDetailsResponse.value.Count -eq 0) {
            Write-Log "No details found for device $deviceName" -Level "WARNING"
            $failureCount++
            continue
        }

        $deviceDetails = $deviceDetailsResponse.value[0]
        $serialNumber = $deviceDetails.serialNumber
        $deviceEnrollmentType = $deviceDetails.deviceEnrollmentType
        $isEncrypted = $deviceDetails.isEncrypted
        $totalStorageSpaceInGB = [math]::Round($deviceDetails.totalStorageSpaceInBytes / 1GB, 2)
        $enrollmentProfileName = $deviceDetails.enrollmentProfileName
        $complianceState = $deviceDetails.complianceState
        $model = $deviceDetails.model
        $manufacturer = $deviceDetails.manufacturer

        # Update extensionAttributes with device details
        $updateUri = "https://graph.microsoft.com/v1.0/devices/$deviceId"
        $body = @{
            extensionAttributes = @{
                extensionAttribute1 = "$serialNumber"
                extensionAttribute2 = "$deviceEnrollmentType"
                extensionAttribute3 = "Encrypted: $isEncrypted"
                extensionAttribute4 = "Storage: $totalStorageSpaceInGB GB"
                extensionAttribute5 = "$enrollmentProfileName"
                extensionAttribute6 = "$complianceState"
                extensionAttribute7 = "$model"
                extensionAttribute8 = "$manufacturer"
            }
        }

        Invoke-MgGraphRequest -Uri $updateUri -Method PATCH -Body ($body | ConvertTo-Json -Compress)
        Write-Log "Successfully updated extensionAttributes for device $deviceName" -Level "SUCCESS"
        $successCount++
    }
    catch {
        Write-Log "Failed to update extensionAttributes for device $deviceName : $_" -Level "ERROR"
        $failureCount++
    }
}

Write-Progress -Activity "Processing Devices" -Completed

Write-Log "Device details update process completed."
Write-Log "Total devices processed: $deviceCount"
Write-Log "Successful updates: $successCount" -Level "SUCCESS"
Write-Log "Failed updates: $failureCount" -Level $(if ($failureCount -eq 0) { "SUCCESS" } else { "WARNING" })

Write-Log "Script completed"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Add-Content -Path $logFile -Value "--- Script execution ended at $timestamp ---`n"