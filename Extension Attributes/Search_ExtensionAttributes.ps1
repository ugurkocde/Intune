<#
.SYNOPSIS
    Retrieves devices with specific extension attribute values from EntraID.

.DESCRIPTION
    This script connects to Microsoft Graph API and retrieves devices based on
    a specified value in any of the extension attributes. 

    Example: Search for Serialnumbers.

.PARAMETER AttributeValue
    The value to search for in any extension attribute.

.EXAMPLE
    .\Search_ExtensionAttributes.ps1 -AttributeValue "compliant"

.NOTES
    Author: Ugur Koc
    GitHub: https://github.com/ugurkocde
    Twitter: https://x.com/UgurKocDe
    LinkedIn: https://www.linkedin.com/in/ugurkocde/

    Version: 1.0
    Created: 24/07/2024

    Required Permissions:
    - Device.Read.All

    Disclaimer: This script is provided AS IS without warranty of any kind.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$AttributeValue
)

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
$logFile = ".\Search_ExtensionAttributes.log"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Add-Content -Path $logFile -Value "`n`n--- Script execution started at $timestamp ---"
Write-Log "Script started"
Write-Log "Search criteria: AttributeValue = '$AttributeValue'"

try {
    # Connect to Microsoft Graph
    Connect-MgGraph -Scopes "Device.Read.All" -NoWelcome
    Write-Log "Connected to Microsoft Graph"

    # Construct the filter
    $filter = (1..15 | ForEach-Object { "extensionAttributes/extensionAttribute$_ eq '$AttributeValue'" }) -join " or "

    # Initialize variables for pagination
    $uri = "https://graph.microsoft.com/v1.0/devices?`$filter=$filter&`$count=true&`$select=id,displayName,extensionAttributes"
    $devices = @()
    $totalCount = 0

    # Paginate through all results
    do {
        # Make the request with the ConsistencyLevel header
        $response = Invoke-MgGraphRequest -Method GET -Uri $uri -Headers @{ConsistencyLevel = "eventual" }

        # Add devices from this page to the collection
        $devices += $response.value
        $totalCount = $response.'@odata.count'

        # Get the next page URL, if any
        $uri = $response.'@odata.nextLink'
    } while ($uri)

    Write-Log "Total devices matching the criteria '$AttributeValue': $totalCount"
    foreach ($device in $devices) {
        Write-Log "Device Name: $($device.displayName)" -Level "SUCCESS"
        foreach ($attr in (1..15)) {
            $attrName = "extensionAttribute$attr"
            $attrValue = $device.extensionAttributes.$attrName
            if ($attrValue -eq $AttributeValue) {
                Write-Log "  $attrName : $attrValue" -Level "INFO"
            }
        }
    }
}
catch {
    Write-Log "An error occurred: $_" -Level "ERROR"
}
finally {
    Write-Log "Script completed"
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $logFile -Value "--- Script execution ended at $timestamp ---`n"
}