<#
.SYNOPSIS
    Mass rename script for Intune-managed devices using a CSV file.

.DESCRIPTION
    This script reads a CSV file containing device names and serial numbers, then uses the Microsoft Graph API to rename the corresponding devices in Intune.

    Note: Device renaming requires a sync with the device to take effect. In some cases, a device restart may also be needed.

.NOTES
    Version:        1.0.0
    Author:         Ugur Koc
    Creation Date:  2024-11-10
    Last Modified:  2024-11-10

.LINK
    https://github.com/ugurkocde/Intune

.EXAMPLE
    CSV file format:
    Devicename,Serialnumber
    PC-001,1234567890
    PC-002,0987654321
#>

# Parameters
$csvPath = "C:\rename.csv" # Example path, change it to your own path

#region Authentication - DO NOT MODIFY

################################ Prerequisites #####################################################

# Fill in your App ID, Tenant ID, and Certificate Thumbprint
$appid = '<YourAppIdHere>' # App ID of the App Registration
$tenantid = '<YourTenantIdHere>' # Tenant ID of your EntraID
$certThumbprint = '<YourCertificateThumbprintHere>' # Thumbprint of the certificate associated with the App Registration
# $certName = '<YourCertificateNameHere>' # You can also use the name of the certificate associated with the App Registration

####################################################################################################

# Connect to Microsoft Graph using certificate-based authentication
try {

    # Define required permissions with reasons
    $requiredPermissions = @(
        @{
            Permission = "DeviceManagementManagedDevices.PrivilegedOperations.All"
            Reason     = "Needed to rename devices"
        }
    )

    # Check if any of the variables are not set or contain placeholder values
    if (-not $appid -or $appid -eq '<YourAppIdHere>' -or
        -not $tenantid -or $tenantid -eq '<YourTenantIdHere>' -or
        -not $certThumbprint -or $certThumbprint -eq '<YourCertificateThumbprintHere>') {
        Write-Host "App ID, Tenant ID, or Certificate Thumbprint is missing or not set correctly." -ForegroundColor Red
        $manualConnection = Read-Host "Would you like to attempt a manual interactive connection? (y/n)"
        if ($manualConnection -eq 'y') {
            # Manual connection using interactive login
            write-host "Attempting manual interactive connection (you need privileges to consent permissions)..." -ForegroundColor Yellow
            $permissionsList = ($requiredPermissions | ForEach-Object { $_.Permission }) -join ', '
            $connectionResult = Connect-MgGraph -Scopes $permissionsList -NoWelcome -ErrorAction Stop
        }
        else {
            Write-Host "Script execution cancelled by user." -ForegroundColor Red
            exit
        }
    }
    else {
        $connectionResult = Connect-MgGraph -ClientId $appid -TenantId $tenantid -CertificateThumbprint $certThumbprint -NoWelcome -ErrorAction Stop
    }
    Write-Host "Successfully connected to Microsoft Graph" -ForegroundColor Green

    # Check and display the current permissions
    $context = Get-MgContext
    $currentPermissions = $context.Scopes

    Write-Host "Checking required permissions:" -ForegroundColor Cyan
    $missingPermissions = @()
    foreach ($permissionInfo in $requiredPermissions) {
        $permission = $permissionInfo.Permission
        $reason = $permissionInfo.Reason

        # Check if either the exact permission or a "ReadWrite" version of it is granted
        $hasPermission = $currentPermissions -contains $permission -or $currentPermissions -contains $permission.Replace(".Read", ".ReadWrite")

        if ($hasPermission) {
            Write-Host "  [✓] $permission" -ForegroundColor Green
            Write-Host "      Reason: $reason" -ForegroundColor Gray
        }
        else {
            Write-Host "  [✗] $permission" -ForegroundColor Red
            Write-Host "      Reason: $reason" -ForegroundColor Gray
            $missingPermissions += $permission
        }
    }

    if ($missingPermissions.Count -eq 0) {
        Write-Host "All required permissions are present." -ForegroundColor Green
        Write-Host ""
    }
    else {
        Write-Host "WARNING: The following permissions are missing:" -ForegroundColor Red
        $missingPermissions | ForEach-Object { 
            $missingPermission = $_
            $reason = ($requiredPermissions | Where-Object { $_.Permission -eq $missingPermission }).Reason
            Write-Host "  - $missingPermission" -ForegroundColor Yellow
            Write-Host "    Reason: $reason" -ForegroundColor Gray
        }
        Write-Host "The script will continue, but it may not function correctly without these permissions." -ForegroundColor Red
        Write-Host "Please ensure these permissions are granted to the app registration for full functionality." -ForegroundColor Yellow
        
        $continueChoice = Read-Host "Do you want to continue anyway? (y/n)"
        if ($continueChoice -ne 'y') {
            Write-Host "Script execution cancelled by user." -ForegroundColor Red
            exit
        }
    }
}

catch {
    Write-Host "Failed to connect to Microsoft Graph. Error: $_" -ForegroundColor Red
    
    # Additional error handling for certificate issues
    if ($_.Exception.Message -like "*Certificate with thumbprint*was not found*") {
        Write-Host "The specified certificate was not found or has expired. Please check your certificate configuration." -ForegroundColor Yellow
    }
    
    exit
}

#endregion Authentication

# Validate CSV File
if (-not (Test-Path $csvPath) -or [System.IO.Path]::GetExtension($csvPath) -ne ".csv") {
    Write-Host "Invalid CSV file path or extension: $csvPath" -ForegroundColor Red
    exit
}

# Import CSV Data with column validation
try {
    $devices = Import-Csv -Path $csvPath

    if (-not ($devices | Get-Member -Name "Devicename") -or -not ($devices | Get-Member -Name "Serialnumber")) {
        Write-Host "CSV file must contain 'Devicename' and 'Serialnumber' columns." -ForegroundColor Red
        exit
    }

    # Check for empty values
    $emptyValues = $devices | Where-Object { -not $_.Devicename -or -not $_.Serialnumber }
    if ($emptyValues.Count -gt 0) {
        Write-Host "CSV contains rows with empty 'Devicename' or 'Serialnumber'. Skipping these rows." -ForegroundColor Yellow
        $devices = $devices | Where-Object { $_.Devicename -and $_.Serialnumber }
    }

    # Check for duplicate serial numbers
    $duplicateSerials = $devices | Group-Object Serialnumber | Where-Object { $_.Count -gt 1 }
    if ($duplicateSerials.Count -gt 0) {
        Write-Host "Warning: Duplicate serial numbers found. Only the first instance will be processed." -ForegroundColor Yellow
        $devices = $devices | Group-Object Serialnumber | ForEach-Object { $_.Group[0] }
    }

    Write-Host "CSV validated successfully. Processing $($devices.Count) devices." -ForegroundColor Green
}
catch {
    Write-Host "Error reading CSV file: $_" -ForegroundColor Red
    exit
}

# Track operation summary
$summary = [PSCustomObject]@{
    TotalDevices        = $devices.Count
    SuccessfullyRenamed = 0
    AlreadyCorrectName  = 0
    NotFound            = 0
    Errors              = 0
}

# Process Devices
foreach ($device in $devices) {
    try {
        $serialNumber = $device.Serialnumber
        $apiUrl = "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=serialNumber eq '$serialNumber'"
        
        $deviceResult = Invoke-MgGraphRequest -Method GET -Uri $apiUrl
        
        if ($deviceResult.value.Count -eq 0) {
            Write-Host "No device found with serial number: $serialNumber" -ForegroundColor Yellow
            $summary.NotFound++
            continue
        }
        
        $intuneDeviceId = $deviceResult.value[0].id
        $currentDeviceName = $deviceResult.value[0].deviceName
        $newDeviceName = $device.Devicename

        # Skip if the device already has the correct name
        if ($currentDeviceName -eq $newDeviceName) {
            Write-Host "Device with serial $serialNumber already has the correct name: $currentDeviceName" -ForegroundColor Cyan
            $summary.AlreadyCorrectName++
            continue
        }

        $body = @{ deviceName = $newDeviceName } | ConvertTo-Json
        $updateUrl = "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$intuneDeviceId/setDeviceName"

        Invoke-MgGraphRequest -Method POST -Uri $updateUrl -Body $body
        Write-Host "Successfully renamed device with serial $serialNumber from $currentDeviceName to $newDeviceName" -ForegroundColor Green
        $summary.SuccessfullyRenamed++
    }
    catch {
        Write-Host "Error processing device with serial $serialNumber : $_" -ForegroundColor Red
        $summary.Errors++
    }
}

# Disconnect from Microsoft Graph
Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
Write-Host "Disconnected from Microsoft Graph." -ForegroundColor Green

# Display Summary
Write-Host "`nOperation Summary:" -ForegroundColor Cyan
Write-Host "Total devices processed: $($summary.TotalDevices)"
Write-Host "Successfully renamed: $($summary.SuccessfullyRenamed)"
Write-Host "Already correct name: $($summary.AlreadyCorrectName)"
Write-Host "Devices not found: $($summary.NotFound)"
Write-Host "Errors encountered: $($summary.Errors)"
