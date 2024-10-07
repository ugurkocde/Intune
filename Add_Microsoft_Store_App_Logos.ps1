<#
.SYNOPSIS
    This script uploads logos for Microsoft Store apps (New) in Intune.

.DESCRIPTION
    This PowerShell script connects to Microsoft Graph and updates the logos for Microsoft Store Apps (New)
    in Intune. It checks for existing logos and only updates apps without logos.

    You need the DeviceManagementApps.ReadWrite.All permission to use this script. Either via a App Registration or an account with the necessary privileges.

.NOTES
    File Name      : add_microsoft_store_app_logos.ps1
    Author         : Ugur Koc
    Prerequisite   : PowerShell 7+, Microsoft Graph PowerShell SDK
    Version        : 1.0

.EXAMPLE
    .\add_microsoft_store_app_logos.ps1

.LINK
    https://github.com/ugurkocde/Intune
#>

# Disclaimer: This script is provided AS IS without warranty of any kind. I am not responsible for any damage caused by this script. Use it at your own risk.

# You can use a App Registration or just run this script and when asked, you can do an interactive login with your browser.

# Fill in your App ID, Tenant ID, and Certificate Thumbprint
$appid = '<YourAppIdHere>' # App ID of the App Registration
$tenantid = '<YourTenantIdHere>' # Tenant ID of your EntraID
$certThumbprint = '<YourCertificateThumbprintHere>' # Thumbprint of the certificate associated with the App Registration
# $certName = '<YourCertificateNameHere>' # Name of the certificate associated with the App Registration

## Start of Authentication 

# Connect to Microsoft Graph using certificate-based authentication
try {

    # Define required permissions with reasons
    $requiredPermissions = @(
        @{
            Permission = "DeviceManagementApps.ReadWrite.All"
            Reason     = "Required to upload logos to Intune"
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

## End of Authentication

## Start of Functions

# Function to get base64 encoded image from URL
function Get-Base64EncodedImage {
    param (
        [string]$ImageUrl
    )
    
    try {
        $webClient = New-Object System.Net.WebClient
        $imageBytes = $webClient.DownloadData($ImageUrl)
        $base64 = [System.Convert]::ToBase64String($imageBytes)
        return $base64
    }
    catch {
        Write-Host "Error downloading image from $ImageUrl : $_" -ForegroundColor Red
        return $null
    }
    finally {
        if ($webClient -ne $null) {
            $webClient.Dispose()
        }
    }
}

## End of Functions

## Start of Main Script

# Get all Store Apps
$StoreApps = @()
$StoreAppsUri = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps?`$filter=isof('microsoft.graph.winGetApp')"

do {
    $StoreAppsResponse = Invoke-MgGraphRequest -Uri $StoreAppsUri -Method Get
    $StoreApps += $StoreAppsResponse.value
    $StoreAppsUri = $StoreAppsResponse.'@odata.nextLink'
} while ($StoreAppsUri)

if ($StoreApps.Count -eq 0) {
    Write-Host "No Store apps found in your Intune tenant." -ForegroundColor Yellow
    Write-Host "Script execution completed." -ForegroundColor Cyan
    exit
}

Write-Host "Store Apps in Intune:" -ForegroundColor Cyan
foreach ($app in $StoreApps) {
    Write-Host "$($app.DisplayName) ($($app.PackageIdentifier))" -ForegroundColor Green
}
Write-Host "---"

# Process each app
$totalApps = $StoreApps.Count
$processedApps = 0
$updatedApps = 0
$skippedApps = 0
$failedApps = 0

foreach ($app in $StoreApps) {
    $processedApps++
    Write-Host "[$processedApps/$totalApps] Processing $($app.DisplayName)..." -ForegroundColor Cyan
    
    # Check if the app already has a logo
    $appDetailsUri = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$($app.id)?`$expand=categories"
    $appDetails = Invoke-MgGraphRequest -Uri $appDetailsUri -Method Get

    if ($appDetails.largeIcon -and $appDetails.largeIcon.value) {
        Write-Host "  [SKIPPED] App already has a logo." -ForegroundColor Yellow
        $skippedApps++
        continue
    }

    $storeUrl = "https://apps.microsoft.com/detail/$($app.PackageIdentifier)"
    
    try {
        $response = Invoke-WebRequest -Uri $storeUrl -UseBasicParsing
        $html = $response.Content

        # Extract image URL using regex
        $imgPattern = '"iconUrl":"(https://store-images\.s-microsoft\.com/[^"]+)"'
        $imgMatch = [regex]::Match($html, $imgPattern)
        
        if ($imgMatch.Success) {
            $imageUrl = $imgMatch.Groups[1].Value
            Write-Host "  [INFO] Found image URL: $imageUrl" -ForegroundColor Green

            # Get base64 encoded image
            $base64Image = Get-Base64EncodedImage -ImageUrl $imageUrl

            # Prepare the update payload
            $updatePayload = @{
                "@odata.type" = "#microsoft.graph.winGetApp"
                largeIcon     = @{
                    "@odata.type" = "#microsoft.graph.mimeContent"
                    "type"        = "image/png"
                    "value"       = $base64Image
                }
            }

            # Update the app
            $updateUri = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$($app.id)"
            Invoke-MgGraphRequest -Uri $updateUri -Method Patch -Body ($updatePayload | ConvertTo-Json)
            Write-Host "  [SUCCESS] Updated logo for $($app.DisplayName)" -ForegroundColor Green
            $updatedApps++
        }
        else {
            Write-Host "  [WARNING] No logo found for $($app.DisplayName)" -ForegroundColor Yellow
            $failedApps++
        }
    }
    catch {
        Write-Host "  [ERROR] Failed to process $($app.DisplayName): $_" -ForegroundColor Red
        $failedApps++
    }
}

# Display summary
Write-Host "`nSummary:" -ForegroundColor Cyan
Write-Host "Total apps processed: $totalApps" -ForegroundColor White
Write-Host "Apps updated: $updatedApps" -ForegroundColor Green
Write-Host "Apps skipped (already had logo): $skippedApps" -ForegroundColor Yellow
Write-Host "Apps failed to update: $failedApps" -ForegroundColor Red