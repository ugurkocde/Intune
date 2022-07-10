# Define parameters
$Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Advanced Threat Protection\DeviceTagging" # Dont change this.
$Tag = "VIP" # Fill in a device Tag you like. VIP is just an example.
$Name = "Group" # Dont change this.

# Create folders
New-Item -Path $Path -Force

# Create and set the key value ($tag)
Set-ItemProperty -Path $Path -Name $Name -Value $Tag -Force

$Value = (Get-ItemProperty $Path).Group

if ($Value -ne $Tag) {
    Write-Output = "Error. Could not set the device tag."
    exit 1 # Sends Exit code 1 (Error) to Intune.
} else {
    Write-Output = "Success."
    exit 0 # Sends a Exit code 0 (Success) to Intune.
}