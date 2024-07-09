<#
.SYNOPSIS
    This script updates the Microsoft Defender signature version on the client.
#>

function Update-DefenderSignature {
    Write-Output "Updating Microsoft Defender Signature..."
    Start-Process PowerShell -ArgumentList "Update-MpSignature" -Wait
    Write-Output "Microsoft Defender Signature updated."

    # Get the updated version number
    $updatedVersion = (Get-MpComputerStatus).AntivirusSignatureVersion
    Write-Output "Updated Defender Signature Version: $updatedVersion"
}

# Update the Microsoft Defender Signature
Update-DefenderSignature
