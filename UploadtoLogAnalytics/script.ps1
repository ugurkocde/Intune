# Activate TLS 1.2 
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Your Log Analytics Workspace ID
$CustomerId = ""  

# Primary Key of your Log Analytics Workspace
$SharedKey = ""

# Name of the new Table, which will be created, in Log Analytics
$LogName = "MDE_Signature"
$Date = (Get-Date)

# Do not change this
$TimeStampField = ""

# LA Function to send the results
Function Send-LogAnalyticsData() {
   param(
	   [string]$sharedKey,
	   [array]$body, 
	   [string]$logType,
	   [string]$customerId
   )
   #Defining method and datatypes
   $method = "POST"
   $contentType = "application/json"
   $resource = "/api/logs"
   $date = [DateTime]::UtcNow.ToString("r")
   $contentLength = $body.Length
   #Construct authorization signature
   $xHeaders = "x-ms-date:" + $date
   $stringToHash = $method + "`n" + $contentLength + "`n" + $contentType + "`n" + $xHeaders + "`n" + $resource
   $bytesToHash = [Text.Encoding]::UTF8.GetBytes($stringToHash)
   $keyBytes = [Convert]::FromBase64String($sharedKey)
   $sha256 = New-Object System.Security.Cryptography.HMACSHA256
   $sha256.Key = $keyBytes
   $calculatedHash = $sha256.ComputeHash($bytesToHash)
   $encodedHash = [Convert]::ToBase64String($calculatedHash)
   $signature = 'SharedKey {0}:{1}' -f $customerId, $encodedHash
   
   #Construct uri 
   $uri = "https://" + $customerId + ".ods.opinsights.azure.com" + $resource + "?api-version=2016-04-01"
   
   #validate that payload data does not exceed limits
   if ($body.Length -gt (31.9 *1024*1024))
   {
	   throw("Upload payload is too big and exceed the 32Mb limit for a single upload. Please reduce the payload size. Current payload size is: " + ($body.Length/1024/1024).ToString("#.#") + "Mb")
   }
   $payloadsize = ("Upload payload size is " + ($body.Length/1024).ToString("#.#") + "Kb ")
   
   #Create authorization Header
   $headers = @{
	   "Authorization"        = $signature;
	   "Log-Type"             = $logType;
	   "x-ms-date"            = $date;
	   "time-generated-field" = $TimeStampField;
   }
   #Sending data to log analytics 
   $response = Invoke-WebRequest -Uri $uri -Method $method -ContentType $contentType -Headers $headers -Body $body -UseBasicParsing
   $statusmessage = "$($response.StatusCode) : $($payloadsize)"
   return $statusmessage 
}

# Date
$Date = Get-Date -Format "dddd MM/dd/yyyy HH:mm"


# Check current version from Microsoft

$websiteSignature = Invoke-WebRequest -Uri https://www.microsoft.com/en-us/wdsi/definitions/antimalware-definition-release-notes -UseBasicParsing

$Pattern = '<span id="(?<dropdown>.*)" tabindex=(?<tabindex>.*) aria-label=(?<arialabel>.*) versionid=(?<versionid>.*)>(?<version>.*)</span>'

$AllMatches = ($websiteSignature | Select-String $Pattern -AllMatches).Matches

$VersionList = foreach ($group in $AllMatches)
{
    [PSCustomObject]@{
        'version' = ($group.Groups.Where{$_.Name -like 'version'}).Value
    }
}

$CurrentVersion = $VersionList | Select-Object -First 1
$CurrentVersionMicrosoft = $CurrentVersion.version


# Check "Released on" from Microsoft

$Pattern = '<p id="releaseDate_0">(?<released_on>.*)</p>'

$AllMatches = ($websiteSignature | Select-String $Pattern -AllMatches).Matches

$ReleaseList = foreach ($group in $AllMatches)
{
    [PSCustomObject]@{
        'released_on' = ($group.Groups.Where{$_.Name -like 'released_on'}).Value
    }
}

$ReleaseDate = $ReleaseList.released_on

$websiteplatform = Invoke-WebRequest -Uri https://docs.microsoft.com/en-us/microsoft-365/security/defender-endpoint/manage-updates-baselines-microsoft-defender-antivirus -UseBasicParsing

$PlatformPattern = "Platform: <strong>(?<Platform>.*)</strong><br>"

$PlatformMatches = ($websiteplatform | Select-String $PlatformPattern -AllMatches).Matches

$PlatformVersionList = foreach ($group in $PlatformMatches)
{
    [PSCustomObject]@{
        'Platform_Version' = ($group.Groups.Where{$_.Name -like 'Platform'}).Value
    }
}

$CurrentPlatformVersion = $PlatformVersionList | Select-Object -First 1

$CurrentPlatformVersionMicrosoft = $CurrentPlatformVersion.Platform_Version


$EnginePattern = "Engine: <strong>(?<Engine>.*)</strong><br>"

$EngineMatches = ($websiteplatform | Select-String $EnginePattern -AllMatches).Matches

$EngineVersionList = foreach ($group in $EngineMatches)
{
    [PSCustomObject]@{
        'Engine_Version' = ($group.Groups.Where{$_.Name -like 'Engine'}).Value
    }
}

$CurrentEngineVersion = $EngineVersionList | Select-Object -First 1

$CurrentEngineVersionMicrosoft = $CurrentEngineVersion.Engine_Version

# Create Body
$MDE = New-Object System.Object
$MDE | Add-Member -MemberType NoteProperty -Name "Signatur Version" -Value "$CurrentVersionMicrosoft" -Force
$MDE | Add-Member -MemberType NoteProperty -Name "Signatur Release" -Value "$ReleaseDate" -Force
$MDE | Add-Member -MemberType NoteProperty -Name "Platform Version" -Value "$CurrentPlatformVersionMicrosoft" -Force
$MDE | Add-Member -MemberType NoteProperty -Name "Engine Release" -Value "$CurrentEngineVersionMicrosoft" -Force

$PayLoad = $MDE

# Create Json 
$Devicejson = $PayLoad | ConvertTo-Json

# Sending the data to Log Analytics Workspace
# Submit the data to the API endpoint
Send-LogAnalyticsData -customerId $customerId -sharedKey $sharedKey -body ([System.Text.Encoding]::UTF8.GetBytes($Devicejson)) -logType $LogName