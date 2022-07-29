$Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Advanced Threat Protection\DeviceTagging"
$Tag = ""
$Name = "Group"

$Value = (Get-ItemProperty $Path).Group

if ($Value -ne $Tag) {
    Write-Output = "Folder does not exist and will be created ..."
    New-Item -Path $Path -Force
    Write-Output = "Set Registry Key ..."
    Set-ItemProperty -Path $Path -Name $Name -Value $Tag -Force
} else {
    Write-Output = "Folder does exist and Registry Key is correct."
}