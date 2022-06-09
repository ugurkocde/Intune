<#
.Synopsis
This script provides a method to gather geolocation data from the targeted devices.
1. It enables the Location service.
2. Connects to MS Graph to trigger the API.
3. Uploads data to the Log Analytics Workspace.
4. It disables the Location service.

.Notes
FileName:    device_localization.ps1
Author:      Ugur Koc
Created:     2022-01-Jan
Updated:     2022-23-Mar

Version history:
1.0.0 - (2022-05-01) Script written.
1.2.0 - (2022-05-11) Synopsis, Notes and added the date to the output.
2.0.0 - (2022-05-12) LA Upload configured and tested.
#>

# Enable TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Log Analytics Workspace ID
$CustomerId = "YOUR WORKSPACE ID"  

# Primary key of the Log Analytics Workspace
$SharedKey = "YOUR SHARED KEY"

# Name of the table in Log Analytics
$TableName = "Localization" # You can change the name of the table.
$Date = (Get-Date)

# Define time zone, important for body
$TimeStampField = "" # Dont change this.

# LA Function to send the results
Function Send-LogAnalyticsData() {
   param(
	   [string]$sharedKey,
	   [array]$body, 
	   [string]$logType,
	   [string]$customerId
   )
   # Defining method and datatypes
   $method = "POST"
   $contentType = "application/json"
   $resource = "/api/logs"
   $date = [DateTime]::UtcNow.ToString("r")
   $contentLength = $body.Length
   # Construct authorization signature
   $xHeaders = "x-ms-date:" + $date
   $stringToHash = $method + "`n" + $contentLength + "`n" + $contentType + "`n" + $xHeaders + "`n" + $resource
   $bytesToHash = [Text.Encoding]::UTF8.GetBytes($stringToHash)
   $keyBytes = [Convert]::FromBase64String($sharedKey)
   $sha256 = New-Object System.Security.Cryptography.HMACSHA256
   $sha256.Key = $keyBytes
   $calculatedHash = $sha256.ComputeHash($bytesToHash)
   $encodedHash = [Convert]::ToBase64String($calculatedHash)
   $signature = 'SharedKey {0}:{1}' -f $customerId, $encodedHash
   
   # Construct uri 
   $uri = "https://" + $customerId + ".ods.opinsights.azure.com" + $resource + "?api-version=2016-04-01"
   
   # Validate that payload data does not exceed limits
   if ($body.Length -gt (31.9 *1024*1024))
   {
	   throw("Upload payload is too big and exceed the 32Mb limit for a single upload. Please reduce the payload size. Current payload size is: " + ($body.Length/1024/1024).ToString("#.#") + "Mb")
   }
   $payloadsize = ("Upload payload size is " + ($body.Length/1024).ToString("#.#") + "Kb ")
   
   # Create authorization Header
   $headers = @{
	   "Authorization"        = $signature;
	   "Log-Type"             = $logType;
	   "x-ms-date"            = $date;
	   "time-generated-field" = $TimeStampField;
   }
   # Sending data to log analytics 
   $response = Invoke-WebRequest -Uri $uri -Method $method -ContentType $contentType -Headers $headers -Body $body -UseBasicParsing
   $statusmessage = "$($response.StatusCode) : $($payloadsize)"
   return $statusmessage 
}

# Authentication part with Azure app
$tenantID = "YOUR TENANT ID"
$clientId = "YOUR AZURE APP CLIENT ID"

# Secret for authentication
$Secret = "YOUR SECRET"
$authority = "https://login.windows.net/$tenantID"

# Connect to MSGraph
Update-MSGraphEnvironment -AppId $clientId -Quiet
Update-MSGraphEnvironment -AuthUrl $authority -Quiet
Connect-MSGraph -ClientSecret $Secret -Quiet
Write-Output "Successfully connected to MSGraph."


# Activate localizaton service
$Path = "SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location"
New-ItemProperty -Path "HKLM:\$Path" -Name "Value" -Type String -Value "Allow" -Force
Write-Output "Successfully activated localizaton on this device."

# Device information
$ComputerInfo = Get-CimInstance -ClassName Win32_ComputerSystem
$ComputerName = $ComputerInfo.Name
$Get_Device = Get-IntuneManagedDevice | Get-MSGraphAllPages | where{$_.deviceName -like "$ComputerName"}
$Get_Device_ID = $Get_Device.ID
$url_locate = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices/$Get_Device_ID/locateDevice"
Invoke-MSGraphRequest -Url $url_locate -HttpMethod POST

$url = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices/$Get_Device_ID"

while ($Latitude -eq $null) {
    $Latitude = (Invoke-MSGraphRequest -Url $url -HttpMethod GET).deviceActionResults.deviceLocation.latitude
    $Longtitude = (Invoke-MSGraphRequest -Url $url -HttpMethod GET).deviceActionResults.deviceLocation.longitude
    Start-Sleep 600
    Write-Output "Run again cause Variable is NULL.This will take aprox. 10 minutes"
}

# Create bodies
$Inventory = New-Object System.Object
$Inventory | Add-Member -MemberType NoteProperty -Name "ComputerName" -Value "$ComputerName" -Force
$Inventory | Add-Member -MemberType NoteProperty -Name "Latitude" -Value "$Latitude" -Force
$Inventory | Add-Member -MemberType NoteProperty -Name "Longtitude" -Value "$Longtitude" -Force
$Maps = "https://www.google.com/maps?q=" + "$Latitude" + "," + "$Longtitude"
$Inventory | Add-Member -MemberType NoteProperty -Name "Google Maps" -Value "$Maps" -Force

$DevicePayLoad = $Inventory

# Create JSON
$Devicejson = $DevicePayLoad | ConvertTo-Json

# Send the data to Log Analytics Workspace
# Submit the data to the API endpoint
Send-LogAnalyticsData -customerId $customerId -sharedKey $sharedKey -body ([System.Text.Encoding]::UTF8.GetBytes($Devicejson)) -logType $TableName

# Disable localizaton service
New-ItemProperty -Path "HKLM:\$Path" -Name "Value" -Type String -Value "Deny" -Force
Write-Output "Successfully deactivated localizaton on this device."

# Report success to Intune
Exit 0

Write-Output "Success! Script run on $Date"
