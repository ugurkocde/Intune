# Upload custom inventory data to Azure Log Analytics
# This script is intended to be used with Microsoft Intune for macOS
# Author: Ugur Koc, Twitter: @ugurkocde

#!/bin/bash

# Azure Log Analytics Workspace details
# Do not forget to replace the workspaceId and sharedKey variables below with your actual values
workspaceId=""
sharedKey=""
logType="CustomInventory" # Name of the table you want to add to in Azure Log Analytics
apiVersion="2016-04-01"   # Do not change

# Gather OS Information
os_version=$(sw_vers -productVersion)
OSBuild=$(sw_vers -buildVersion)
os_friendly=$(awk '/SOFTWARE LICENSE AGREEMENT FOR macOS/' '/System/Library/CoreServices/Setup Assistant.app/Contents/Resources/en.lproj/OSXSoftwareLicense.rtf' | awk -F 'macOS ' '{print $NF}' | awk '{print substr($0, 0, length($0)-1)}')

# Gather SIP Status
sip_status=$(csrutil status)
if [[ $sip_status == *"enabled"* ]]; then
    sip_status="enabled"
elif [[ $sip_status == *"disabled"* ]]; then
    sip_status="disabled"
else
    sip_status="unknown"
fi

# Gather Secure Boot Status
secure_boot_status=$(system_profiler SPiBridgeDataType | awk -F': ' '/Secure Boot/ {print $2}')

# Gather Device Information
DeviceName=$(scutil --get ComputerName)
SerialNumber=$(system_profiler SPHardwareDataType | awk '/Serial/ {print $4}')
Chip=$(sysctl -n machdep.cpu.brand_string)
Memory=$(sysctl -n hw.memsize | awk '{print $0/1024/1024 " MB"}')

# Get FileVault Status
filevault_status=$(fdesetup status)
if [[ $filevault_status == *"FileVault is On."* ]]; then
    filevault_status="Enabled"
elif [[ $filevault_status == *"FileVault is Off."* ]]; then
    filevault_status="Disabled"
else
    filevault_status="Unknown"
fi

# Storage Information
Storage_Total=$(df -Hl | grep '/System/Volumes/Data' | awk '{print $2}')
Storage_Free=$(df -Hl | grep '/System/Volumes/Data' | awk '{print $4}')

# Last Boot Time
LastBoot=$(sysctl -n kern.boottime | awk '{print $4}' | sed 's/,//')
LastBootFormatted=$(date -jf "%s" "$LastBoot" +"%m/%d/%Y, %I:%M:%S %p")

# Get Model
Model=$(system_profiler SPHardwareDataType | awk -F: '/Model Name/ {print $2}' | sed 's/^ *//')

# Get DeviceID
LOG_DIR="$HOME/Library/Logs/Microsoft/Intune"
DEVICE_ID=$(grep -o 'DeviceId: [^ ]*' "$LOG_DIR"/*.log | awk '{print $NF}' | sort | uniq)

# Get AAD Tenant ID
TENANT_ID=$(grep -o 'AADTenantId: [^ ]*' "$LOG_DIR"/*.log | awk '{print $NF}' | sort | uniq)

# Get Local Admins
LocalAdmins=$(dscl . -read /Groups/admin GroupMembership | awk '{for (i=2; i<=NF; i++) printf $i " "; print ""}')

# Prepare JSON Data, LAW expects JSON format uploads
jsonData="{ \
  \"DeviceName\": \"${DeviceName}\", \
  \"SerialNumber\": \"${SerialNumber}\", \
  \"Model\": \"${Model}\", \
  \"OSVersion\": \"${os_version}\", \
  \"OSBuild\": \"${OSBuild}\", \
  \"OSFriendlyName\": \"${os_friendly}\", \
  \"SIPStatus\": \"${sip_status}\", \
  \"SecureBootStatus\": \"${secure_boot_status}\", \
  \"Chip\": \"${Chip}\", \
  \"Memory\": \"${Memory}\", \
  \"FileVaultStatus\": \"${filevault_status}\", \
  \"StorageTotal\": \"${Storage_Total}\", \
  \"StorageFree\": \"${Storage_Free}\", \
  \"LastBoot\": \"${LastBootFormatted}\", \
  \"DeviceID\": \"${DEVICE_ID}\", \
  \"TenantID\": \"${TENANT_ID}\", \
  \"LocalAdmins\": \"${LocalAdmins}\" \
}"

echo "JSON Data: $jsonData"

# Generate the current date in RFC 1123 format
rfc1123date=$(date -u +"%a, %d %b %Y %H:%M:%S GMT")

# String to sign
stringToSign="POST\n${#jsonData}\napplication/json\nx-ms-date:$rfc1123date\n/api/logs"

# Create the signature
decodedKey=$(echo "$sharedKey" | base64 -d)
signature=$(printf "%b" "$stringToSign" | openssl dgst -sha256 -hmac "$decodedKey" -binary | base64)

# Format the Authorization header
authHeader="SharedKey $workspaceId:$signature"

# Send Data to Azure Log Analytics
response=$(curl -X POST "https://$workspaceId.ods.opinsights.azure.com/api/logs?api-version=$apiVersion" \
    -H "Content-Type: application/json" \
    -H "Log-Type: $logType" \
    -H "Authorization: $authHeader" \
    -H "x-ms-date: $rfc1123date" \
    -d "$jsonData" -w "%{http_code}")

# Extract HTTP Status Code
httpStatusCode=$(echo $response | tail -n1)

# Check Response
if [ "$httpStatusCode" -eq 200 ]; then
    echo "Data successfully sent to Azure Log Analytics."
elif [[ "$httpStatusCode" == 4* ]]; then
    echo "Client error occurred: $response"
elif [[ "$httpStatusCode" == 5* ]]; then
    echo "Server error occurred: $response"
else
    echo "Unexpected response: $response"
fi
