# Define parameters
$Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Advanced Threat Protection\DeviceTagging" # Dont change this.
$Tag = "VIP" # Fill in a device Tag you like. VIP is just an example.
$Name = "Group" # Dont change this.
$Value = (Get-ItemProperty $Path).Group

if ($Value -ne $Tag) {
    Write-Output = "Key does not exist in the registry of the device. Starting remediation script ..."
    exit 1 # Sends Exit code 1 (Error) to Intune and runs the remediation script.
} else {
    Write-Output = "Folder does exist and Registry Key is correct. Nothing has to be done."
    exit 0 # Sends a Exit code 0 (Success) to Intune. The remediation script doesn´t have to be run.
}