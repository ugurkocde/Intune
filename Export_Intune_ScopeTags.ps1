<#
.SYNOPSIS
    This PowerShell script connects to the Microsoft Graph API and retrieves all scope tags for all Objects in Intune.
.DESCRIPTION
    This script provides functions to fetch and process information related to managed devices, device configurations,
    compliance policies, shell scripts, configuration policies, and mobile apps from Microsoft Graph API. It also supports
    exporting the data to different formats.
    
    To use this script, you need to fill in your App ID, Tenant ID, and Secret in the appropriate variables.

    For more details and setup instructions, refer to the accompanying documentation.

.AUTHOR
    Ugur Koc
#>

# Step 1: Authentication to Microsoft Graph (Please fill in your App ID, Tenant ID, and Secret)

# Recommended: Use App Registration to Authenticate to Microsoft Graph
# A guide how to setup the App registration and Scopes can be found here: https://helloitsliam.com/2022/04/20/connect-to-microsoft-graph-powershell-using-an-app-registration/
# Scopes needed: DeviceManagementManagedDevices.Read.All, DeviceManagementRBAC.Read.All, DeviceManagementApps.Read.All, DeviceManagementConfiguration.Read.All

# Fill in your App ID, Tenant ID, and Secret
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

# Alternative: Connect with your EntraID User Account to Microsoft Graph
# Connect-MgGraph -Scopes "DeviceManagementManagedDevices.Read.All, DeviceManagementRBAC.Read.All, DeviceManagementApps.Read.All, DeviceManagementConfiguration.Read.All" -NoWelcome

# Step 2: Function to Fetch Scope Tag Details
function Get-ScopeTagDetails {
    $Uri = "https://graph.microsoft.com/beta/deviceManagement/roleScopeTags"
    $scopeTagsResponse = Invoke-MgGraphRequest -Uri $Uri -Method GET

    $scopeTagDetails = @{}
    foreach ($scopeTag in $scopeTagsResponse.value) {
        $scopeTagDetails[$scopeTag.id] = @{
            DisplayName = $scopeTag.displayName
            Description = $scopeTag.description
        }
    }
    return $scopeTagDetails
}

# Step 3: Function to Fetch Devices and their Scope Tags
function Get-ManagedDevices {
    param($Uri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices")
    $devices = @()
    try {
        $response = Invoke-MgGraphRequest -Uri $Uri -Method GET

        foreach ($device in $response.value) {
            # Retrieve scope tags for the device
            $deviceDetailsResponse = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices('$($device.id)')" -Method GET
            $scopeTagIds = $deviceDetailsResponse.roleScopeTagIds

            # Fetch the display names of each scope tag
            $scopeTagNames = @()
            foreach ($tagId in $scopeTagIds) {
                $tagDetailsResponse = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/roleScopeTags/$tagId" -Method GET
                $scopeTagNames += $tagDetailsResponse.displayName
            }

            $devices += New-Object PSObject -Property @{
                DeviceName = $device.deviceName  
                DeviceId   = $device.id             
                ScopeTags  = ($scopeTagNames -join ", ")
            }
        }

        # Recursively call for next link if available
        if ($response.'@odata.nextLink') {
            $devices += Get-ManagedDevices -Uri $response.'@odata.nextLink'
        }
    }
    catch {
        Write-Host "Error fetching devices: $($_.Exception.Message)"
    }

    return $devices
}

# Step 4: Function to Fetch Device Configuration Details
function Get-DeviceConfigDetails {
    param($DeviceConfig, $ScopeTags)
    $Uri = "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations/$($DeviceConfig.id)"

    $response = Invoke-MgGraphRequest -Uri $Uri -Method GET

    $scopeTagNames = @()
    foreach ($tagId in $response.roleScopeTagIds) {
        if ($ScopeTags[$tagId]) {
            $scopeTagNames += $ScopeTags[$tagId].DisplayName
        }
    }

    [PSCustomObject]@{
        Type      = "Device Configuration"
        Name      = $DeviceConfig.displayName
        Id        = $DeviceConfig.id
        #RoleScopeTagIds = $response.roleScopeTagIds -join ', '
        ScopeTags = $scopeTagNames -join ', '
    }
}

# Step 5: Function to Fetch Device Compliance Policy Details
function Get-DeviceCompliancePolicyDetails {
    param($DeviceCompliancePolicy, $ScopeTags)
    $Uri = "https://graph.microsoft.com/beta/deviceManagement/deviceCompliancePolicies/$($DeviceCompliancePolicy.id)"

    $response = Invoke-MgGraphRequest -Uri $Uri -Method GET

    $scopeTagNames = @()
    foreach ($tagId in $response.roleScopeTagIds) {
        if ($ScopeTags[$tagId]) {
            $scopeTagNames += $ScopeTags[$tagId].DisplayName
        }
    }

    [PSCustomObject]@{
        Type      = "Device Compliance Policy"
        Name      = $DeviceCompliancePolicy.displayName
        Id        = $DeviceCompliancePolicy.id
        #RoleScopeTagIds = $response.roleScopeTagIds -join ', '
        ScopeTags = $scopeTagNames -join ', '
    }
}

# Step 6: Function to Fetch Device Shell Script Details
function Get-DeviceShellScriptDetails {
    param($DeviceShellScript, $ScopeTags)
    $Uri = "https://graph.microsoft.com/beta/deviceManagement/deviceShellScripts/$($DeviceShellScript.id)"

    $response = Invoke-MgGraphRequest -Uri $Uri -Method GET

    $scopeTagNames = @()
    foreach ($tagId in $response.roleScopeTagIds) {
        if ($ScopeTags[$tagId]) {
            $scopeTagNames += $ScopeTags[$tagId].DisplayName
        }
    }

    [PSCustomObject]@{
        Type      = "Device Shell Script"
        Name      = $DeviceShellScript.displayName
        Id        = $DeviceShellScript.id
        #RoleScopeTagIds = $response.roleScopeTagIds -join ', '
        ScopeTags = $scopeTagNames -join ', '
    }
}

# Step 7: Function to Fetch Configuration Policy Details
function Get-ConfigurationPolicyDetails {
    param($ConfigurationPolicy, $ScopeTags)
    $Uri = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies('$($ConfigurationPolicy.id)')"

    $response = Invoke-MgGraphRequest -Uri $Uri -Method GET

    $scopeTagNames = @()
    foreach ($tagId in $response.roleScopeTagIds) {
        if ($ScopeTags[$tagId]) {
            $scopeTagNames += $ScopeTags[$tagId].DisplayName
        }
    }

    [PSCustomObject]@{
        Type      = "Configuration Policy"
        Name      = $ConfigurationPolicy.name
        Id        = $ConfigurationPolicy.id
        #RoleScopeTagIds = $response.roleScopeTagIds -join ', '
        ScopeTags = $scopeTagNames -join ', '
        Platform  = $ConfigurationPolicy.platforms
    }
}

# Step 8: Function to Fetch Mobile App Details
function Get-MobileAppDetails {
    param($ScopeTags)

    $mobileAppDetails = @()
    $Uri = 'https://graph.microsoft.com/beta/deviceAppManagement/mobileApps?$filter=isAssigned eq true&$orderby=displayName&$top=100'

    do {
        $response = Invoke-MgGraphRequest -Uri $Uri -Method GET
        foreach ($app in $response.value) {
            # Additional request to fetch roleScopeTagIds for each app
            
            $appDetailsUri = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$($app.id)?$select=roleScopeTagIds"
            $appDetailsResponse = Invoke-MgGraphRequest -Uri $appDetailsUri -Method GET

            $scopeTagNames = @()
            foreach ($tagId in $appDetailsResponse.roleScopeTagIds) {
                if ($ScopeTags[$tagId]) {
                    $scopeTagNames += $ScopeTags[$tagId].DisplayName
                }
            }

            $mobileAppDetails += [PSCustomObject]@{
                Type      = "Application"
                Name      = $appDetailsResponse.displayName
                AppId     = $appDetailsResponse.id
                Assigned  = $appDetailsResponse.isAssigned
                #RoleScopeTagIds = $appDetailsResponse.roleScopeTagIds -join ', '
                ScopeTags = ($scopeTagNames -join ', ')
            }
        }
        $Uri = $response.'@odata.nextLink'
    } while ($Uri)

    return $mobileAppDetails
}

# Step 9: Fetch All Device Configurations, Compliance Policies, Shell Scripts, Configuration Policies, and Mobile Apps and Process Each
$scopeTags = Get-ScopeTagDetails
$allDevices = Get-ManagedDevices

$deviceConfigUri = "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations"
$deviceComplianceUri = "https://graph.microsoft.com/beta/deviceManagement/deviceCompliancePolicies"
$deviceShellScriptUri = "https://graph.microsoft.com/beta/deviceManagement/deviceShellScripts"
$configurationPolicyUri = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies"

$configs = Invoke-MgGraphRequest -Uri $deviceConfigUri -Method GET
$compliances = Invoke-MgGraphRequest -Uri $deviceComplianceUri -Method GET
$shellScripts = Invoke-MgGraphRequest -Uri $deviceShellScriptUri -Method GET
$configurationPolicies = Invoke-MgGraphRequest -Uri $configurationPolicyUri -Method GET
$mobileApps = Get-MobileAppDetails -ScopeTags $scopeTags

$results = @()

# Combine Mobile App Details with Other Results
$results += $mobileApps

# Process and Combine Device Details with Other Results
foreach ($device in $allDevices) {
    $deviceResult = [PSCustomObject]@{
        Type      = "Managed Device"
        Name      = $device.DeviceName
        DeviceId  = $device.DeviceId
        ScopeTags = $device.ScopeTags
    }
    $results += $deviceResult
}

if ($configs.value) {
    foreach ($config in $configs.value) {
        $results += Get-DeviceConfigDetails -DeviceConfig $config -ScopeTags $scopeTags
    }
}

if ($compliances.value) {
    foreach ($compliance in $compliances.value) {
        $results += Get-DeviceCompliancePolicyDetails -DeviceCompliancePolicy $compliance -ScopeTags $scopeTags
    }
}

if ($shellScripts.value) {
    foreach ($script in $shellScripts.value) {
        $results += Get-DeviceShellScriptDetails -DeviceShellScript $script -ScopeTags $scopeTags
    }
}

if ($configurationPolicies.value) {
    foreach ($policy in $configurationPolicies.value) {
        $results += Get-ConfigurationPolicyDetails -ConfigurationPolicy $policy -ScopeTags $scopeTags
    }
}

<# if ($mobileApps.value) {
    foreach ($app in $mobileApps.value) {
        $results += Get-MobileAppDetails -MobileApp $app -ScopeTags $scopeTags
    }
} #>

# Uncomment the following line to view the output in a list format
$results | Format-List


# Uncomment the following line to view the output in a grid view
# $results | Select-Object Type, Name, ScopeTags | Out-GridView -PassThru -Title "Select Items to Export" 

# Uncomment the following line to export the output to CSV
# $results | Export-Csv -Path "Intune_ScopeTags.csv" -NoTypeInformation