# Import required modules
Import-Module Microsoft.Graph.Authentication
Import-Module Microsoft.Graph.DeviceManagement

# Function to encrypt the app file
function Encrypt-AppFile {
    param (
        [string]$FilePath
    )
    
    $encryptionKey = New-Object byte[] 32
    [Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($encryptionKey)
    
    $hmacKey = New-Object byte[] 32
    [Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($hmacKey)
    
    $initializationVector = New-Object byte[] 16
    [Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($initializationVector)
    
    $fileContent = [System.IO.File]::ReadAllBytes($FilePath)
    
    $aes = [System.Security.Cryptography.Aes]::Create()
    $aes.Key = $encryptionKey
    $aes.IV = $initializationVector
    $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
    $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
    
    $encryptor = $aes.CreateEncryptor()
    $encryptedData = $encryptor.TransformFinalBlock($fileContent, 0, $fileContent.Length)
    
    $hmac = New-Object System.Security.Cryptography.HMACSHA256
    $hmac.Key = $hmacKey
    $signature = $hmac.ComputeHash($initializationVector + $encryptedData)
    
    $encryptedPackage = $signature + $initializationVector + $encryptedData
    
    $fileDigest = (Get-FileHash -Path $FilePath -Algorithm SHA256).Hash
    
    $encryptionInfo = @{
        encryptionKey        = [Convert]::ToBase64String($encryptionKey)
        macKey               = [Convert]::ToBase64String($hmacKey)
        initializationVector = [Convert]::ToBase64String($initializationVector)
        mac                  = [Convert]::ToBase64String($signature)
        profileIdentifier    = "ProfileVersion1"
        fileDigest           = $fileDigest
        fileDigestAlgorithm  = "SHA256"
    }
    
    return @{
        EncryptedPackage = $encryptedPackage
        EncryptionInfo   = $encryptionInfo
        EncryptedSize    = $encryptedPackage.Length
        EncryptedContent = $encryptedData  # Add this line to return the encrypted content
    }
}

# Function to create block list and upload file
function Upload-FileInBlocks {
    param (
        [byte[]]$FileContent,
        [string]$AzureStorageUri
    )
    
    $chunkSize = 2 * 1024 * 1024 # 2 MB chunks
    $totalChunks = [Math]::Ceiling($FileContent.Length / $chunkSize)
    
    $chunks = New-Object System.Collections.Generic.List[string]

    Write-Host "File is $($FileContent.Length) bytes, will be uploaded in $totalChunks chunks"

    for ($chunk = 0; $chunk -lt $totalChunks; $chunk++) {
        $chunkId = [Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("block-{0:D8}" -f $chunk))
        $chunks.Add($chunkId)
        $start = $chunk * $chunkSize
        $length = [Math]::Min($chunkSize, $FileContent.Length - $start)
        $chunkData = $FileContent[$start..($start + $length - 1)]
        
        Write-Host "Uploading chunk $chunk of $totalChunks"
        
        $uri = "$AzureStorageUri&comp=block&blockid=$chunkId"
        $headers = @{
            "x-ms-blob-type" = "BlockBlob"
        }
        Invoke-RestMethod -Uri $uri -Method Put -Body $chunkData -Headers $headers
    }

    Write-Host "Finalizing chunk upload"
    $blockListXml = '<?xml version="1.0" encoding="utf-8"?><BlockList>' + ($chunks | ForEach-Object { "<Latest>$_</Latest>" }) + '</BlockList>'
    $uri = "$AzureStorageUri&comp=blocklist"
    Invoke-RestMethod -Uri $uri -Method Put -Body $blockListXml -ContentType "application/xml"
    
    Write-Host "Block list XML:"
    Write-Host $blockListXml
}

# Main script
Write-Host "Starting the app upload process to Intune..."

# Connect to Microsoft Graph
Write-Host "Connecting to Microsoft Graph..."
Connect-MgGraph -Scopes "DeviceManagementApps.ReadWrite.All"
Write-Host "Connected to Microsoft Graph successfully."

# Set variables
$appFilePath = "KeePassXC.dmg"  
$appDisplayName = "KeePassXC"
$appDescription = "Password manager app"
$appPublisher = "KeePassXC"
$appBundleId = "org.keepassxc.keepassxc"
$appBundleVersion = "2.7.9"

Write-Host "App details:"
Write-Host "  File: $appFilePath"
Write-Host "  Display Name: $appDisplayName"
Write-Host "  Bundle ID: $appBundleId"
Write-Host "  Version: $appBundleVersion"

# Create the app in Intune
Write-Host "Creating the app in Intune..."
$app = @{
    "@odata.type"                   = "#microsoft.graph.macOSDmgApp"  
    displayName                     = $appDisplayName
    description                     = $appDescription
    publisher                       = $appPublisher
    fileName                        = (Split-Path $appFilePath -Leaf)
    packageIdentifier               = $appBundleId
    versionNumber                   = $appBundleVersion
    primaryBundleId                 = $appBundleId  
    primaryBundleVersion            = $appBundleVersion  
    minimumSupportedOperatingSystem = @{
        "@odata.type" = "#microsoft.graph.macOSMinimumOperatingSystem"
        v11_0         = $true
    }
    includedApps                    = @(
        @{
            "@odata.type" = "#microsoft.graph.macOSIncludedApp"
            bundleId      = $appBundleId
            bundleVersion = $appBundleVersion
        }
    )
}

$createAppUri = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps"
Write-Host "Creating app using URI: $createAppUri"
$newApp = Invoke-MgGraphRequest -Method POST -Uri $createAppUri -Body ($app | ConvertTo-Json -Depth 10)
Write-Host "App created successfully. App ID: $($newApp.id)"

# Create content version
$contentVersionUri = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$($newApp.id)/microsoft.graph.macOSDmgApp/contentVersions"  
Write-Host "Creating content version using URI: $contentVersionUri"
$contentVersion = Invoke-MgGraphRequest -Method POST -Uri $contentVersionUri -Body "{}"
Write-Host "Content version created successfully. Version ID: $($contentVersion.id)"

# Encrypt the app file
Write-Host "Encrypting the app file..."
$encryptionResult = Encrypt-AppFile -FilePath $appFilePath
Write-Host "App file encrypted successfully."

# Print file encryption info
Write-Host "File Encryption Info:"
$encryptionResult.EncryptionInfo.GetEnumerator() | ForEach-Object {
    Write-Host "  $($_.Key): $($_.Value)"
}

# Prepare file content info
Write-Host "Preparing file content info..."
$fileContent = @{
    "@odata.type" = "#microsoft.graph.mobileAppContentFile"
    name          = (Split-Path $appFilePath -Leaf)
    size          = (Get-Item $appFilePath).Length
    sizeEncrypted = $encryptionResult.EncryptedSize
    manifest      = $null
    isDependency  = $false
}

Write-Host "Original file size: $($fileContent.size) bytes"
Write-Host "Encrypted file size: $($fileContent.sizeEncrypted) bytes"

$contentFileUri = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$($newApp.id)/microsoft.graph.macOSDmgApp/contentVersions/$($contentVersion.id)/files"  
Write-Host "Creating content file using URI: $contentFileUri"
$contentFile = Invoke-MgGraphRequest -Method POST -Uri $contentFileUri -Body ($fileContent | ConvertTo-Json)
Write-Host "Content file created successfully. File ID: $($contentFile.id)"

# Wait for Azure Storage URI
Write-Host "Waiting for Azure Storage URI..."
do {
    Start-Sleep -Seconds 5
    $fileStatusUri = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$($newApp.id)/microsoft.graph.macOSDmgApp/contentVersions/$($contentVersion.id)/files/$($contentFile.id)"
    Write-Host "Checking file status using URI: $fileStatusUri"
    $fileStatus = Invoke-MgGraphRequest -Method GET -Uri $fileStatusUri
} while ($fileStatus.uploadState -ne "azureStorageUriRequestSuccess")
Write-Host "Azure Storage URI received successfully."

# Upload encrypted file to Azure Storage
Write-Host "Uploading encrypted file to Azure Storage..."
Upload-FileInBlocks -FileContent $encryptionResult.EncryptedContent -AzureStorageUri $fileStatus.azureStorageUri
Write-Host "Encrypted file uploaded to Azure Storage successfully."

# After Upload-FileInBlocks
Write-Host "Attempting to get blob info..."
try {
    $blobInfoUri = $fileStatus.azureStorageUri
    Write-Host "Blob info URI: $blobInfoUri"
    
    $blobInfoResponse = Invoke-WebRequest -Uri $blobInfoUri -Method Head -Headers @{"x-ms-blob-type" = "BlockBlob" } -UseBasicParsing
    
    Write-Host "Uploaded blob info:"
    Write-Host "StatusCode: $($blobInfoResponse.StatusCode)"
    Write-Host "StatusDescription: $($blobInfoResponse.StatusDescription)"
    Write-Host "Content-Length: $($blobInfoResponse.Headers['Content-Length'])"
    Write-Host "Content-MD5: $($blobInfoResponse.Headers['Content-MD5'])"
    Write-Host "Last-Modified: $($blobInfoResponse.Headers['Last-Modified'])"
}
catch {
    Write-Host "Error getting blob info:"
    Write-Host "Exception Type: $($_.Exception.GetType().FullName)"
    Write-Host "Exception Message: $($_.Exception.Message)"
    if ($_.Exception.Response) {
        Write-Host "StatusCode: $($_.Exception.Response.StatusCode.value__)"
        Write-Host "StatusDescription: $($_.Exception.Response.StatusDescription)"
    }
    Write-Host "StackTrace:"
    Write-Host $_.ScriptStackTrace
}

# Commit the file
Write-Host "Committing the file..."
$commitData = @{
    fileEncryptionInfo = $encryptionResult.EncryptionInfo
}
$commitUri = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$($newApp.id)/microsoft.graph.macOSDmgApp/contentVersions/$($contentVersion.id)/files/$($contentFile.id)/commit"
Write-Host "Committing file using URI: $commitUri"
Write-Host "Commit data:"
$commitData | ConvertTo-Json -Depth 10 | Write-Host

try {
    $commitResponse = Invoke-MgGraphRequest -Method POST -Uri $commitUri -Body ($commitData | ConvertTo-Json -Depth 10)
    Write-Host "Commit response:"
    $commitResponse | ConvertTo-Json -Depth 10 | Write-Host
}
catch {
    Write-Host "Error during commit:"
    Write-Host "StatusCode:" $_.Exception.Response.StatusCode.value__ 
    Write-Host "StatusDescription:" $_.Exception.Response.StatusDescription
    Write-Host "ResponseBody:" $_.ErrorDetails.Message
    Write-Host "StackTrace:" $_.ScriptStackTrace
}

# Wait for successful commit
Write-Host "Waiting for successful commit..."
$retryCount = 0
$maxRetries = 10
do {
    Start-Sleep -Seconds 10
    $fileStatusUri = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$($newApp.id)/microsoft.graph.macOSDmgApp/contentVersions/$($contentVersion.id)/files/$($contentFile.id)"
    Write-Host "Checking commit status using URI: $fileStatusUri"
    $fileStatus = Invoke-MgGraphRequest -Method GET -Uri $fileStatusUri
    Write-Host "Current upload state: $($fileStatus.uploadState)"
    Write-Host "File status details:"
    $fileStatus | ConvertTo-Json -Depth 10 | Write-Host
    
    if ($fileStatus.uploadState -eq "commitFileFailed") {
        Write-Host "Commit failed. Retrying..."
        $commitResponse = Invoke-MgGraphRequest -Method POST -Uri $commitUri -Body ($commitData | ConvertTo-Json -Depth 10)
        Write-Host "Retry commit response:"
        $commitResponse | ConvertTo-Json -Depth 10 | Write-Host
        $retryCount++
    }
} while ($fileStatus.uploadState -ne "commitFileSuccess" -and $retryCount -lt $maxRetries)

if ($fileStatus.uploadState -eq "commitFileSuccess") {
    Write-Host "File committed successfully."
}
else {
    Write-Host "Failed to commit file after $maxRetries attempts. Last state: $($fileStatus.uploadState)"
    exit 1
}

# Update the app to use the new content version
Write-Host "Updating the app with the new content version..."
$updateAppUri = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$($newApp.id)"
$updateData = @{
    "@odata.type"           = "#microsoft.graph.macOSDmgApp" 
    committedContentVersion = $contentVersion.id
}
Write-Host "Updating app using URI: $updateAppUri"
Invoke-MgGraphRequest -Method PATCH -Uri $updateAppUri -Body ($updateData | ConvertTo-Json)

Write-Host "App uploaded and updated successfully in Intune!"