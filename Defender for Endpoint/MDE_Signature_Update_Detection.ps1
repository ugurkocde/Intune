<#
.SYNOPSIS
    This script checks the latest available Microsoft Defender signature version on the Microsoft website
    and compares it with the currently installed signature version on the client.
#>

function Get-LatestDefenderVersion {
    # Fetch the Microsoft Defender signature version page
    $url = "https://www.microsoft.com/en-us/wdsi/definitions/antimalware-definition-release-notes"
    $response = Invoke-WebRequest -Uri $url -UseBasicParsing

    # Pattern to extract the version number
    $pattern = '<span id="(?<dropdown>.*)" tabindex=(?<tabindex>.*) aria-label=(?<arialabel>.*) versionid=(?<versionid>.*)>(?<version>.*)</span>'
    
    # Extract version numbers
    $matches = ($response.Content | Select-String -Pattern $pattern -AllMatches).Matches

    $latestVersion = $matches[0].Groups["version"].Value
    return $latestVersion
}

function Get-InstalledDefenderVersion {
    # Get the currently installed signature version on the client
    $currentVersionDevice = (Get-MpComputerStatus).AntivirusSignatureVersion
    return $currentVersionDevice
}

# Get versions
$latestVersion = Get-LatestDefenderVersion
$installedVersion = Get-InstalledDefenderVersion

# Compare versions
if ($installedVersion -ne $latestVersion) {
    Write-Output "The installed signature version is not up-to-date: $installedVersion"
    exit 1
} else {
    Write-Output "The installed signature version is up-to-date: $installedVersion"
    exit 0
}
