# Define parameters
$Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Advanced Threat Protection\DeviceTagging"
$Tag = "VIP"
$Name = "Group"

# Create folders
New-Item -Path $Path -Force

# Create and set the key value ($tag)
Set-ItemProperty -Path $Path -Name $Name -Value $Tag -Force

$Value = (Get-ItemProperty $Path).Group

if ($Value -ne $Tag) {
    Write-Output = "Error. Couldn´t set the device tag."
    exit 1 # Sends Exit code 1 (Error) to Intune.
} else {
    Write-Output = "Success."
    exit 0 # Sends a Exit code 0 (Success) to Intune.
}