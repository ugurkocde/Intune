<#
.SYNOPSIS
    Deletes all extension attributes for devices in EntraID.

.DESCRIPTION
    This script connects to Microsoft Graph API and deletes all extension attributes
    for devices in EntraID by setting them to null. It processes all devices retrieved
    from EntraID and clears their extension attributes from extensionAttribute1 to
    extensionAttribute15.

    This script will also write a log file to the current directory.

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
    .\Delete_All_ExtensionAttributes.ps1

.NOTES
    EntraID App Registration Permissions (Least privileged):
    - Device.Read.All, This permission is required to read the device details from EntraID.
    - Directory.AccessAsUser.All, This permission is required to read and update the extensionAttributes of the device.

    Disclaimer: This script is provided AS IS without warranty of any kind. Use it at your own risk.
#>

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
$logFile = ".\Delete_All_ExtensionAttributes.log"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Add-Content -Path $logFile -Value "`n`n--- Script execution started at $timestamp ---"
Write-Log "Script started"

try {
    Connect-MgGraph -Scopes "Device.Read.All", "Directory.AccessAsUser.All" -NoWelcome
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

    # Clear all extension attributes
    $updateUri = "https://graph.microsoft.com/v1.0/devices/$deviceId"
    $body = @{
        extensionAttributes = @{
            extensionAttribute1  = $null
            extensionAttribute2  = $null
            extensionAttribute3  = $null
            extensionAttribute4  = $null
            extensionAttribute5  = $null
            extensionAttribute6  = $null
            extensionAttribute7  = $null
            extensionAttribute8  = $null
            extensionAttribute9  = $null
            extensionAttribute10 = $null
            extensionAttribute11 = $null
            extensionAttribute12 = $null
            extensionAttribute13 = $null
            extensionAttribute14 = $null
            extensionAttribute15 = $null
        }
    }

    try {
        Invoke-MgGraphRequest -Uri $updateUri -Method PATCH -Body ($body | ConvertTo-Json -Compress)
        Write-Log "Successfully cleared extension attributes for device $deviceName" -Level "SUCCESS"
        $successCount++
    }
    catch {
        Write-Log "Failed to clear extension attributes for device $deviceName : $_" -Level "ERROR"
        $failureCount++
    }
}

Write-Progress -Activity "Processing Devices" -Completed

Write-Log "Extension attribute deletion process completed."
Write-Log "Total devices processed: $deviceCount"
Write-Log "Successful deletions: $successCount" -Level "SUCCESS"
Write-Log "Failed deletions: $failureCount" -Level $(if ($failureCount -eq 0) { "SUCCESS" } else { "WARNING" })

Write-Log "Script completed"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Add-Content -Path $logFile -Value "--- Script execution ended at $timestamp ---`n"