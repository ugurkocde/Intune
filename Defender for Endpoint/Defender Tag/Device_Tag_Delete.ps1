$Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Advanced Threat Protection\DeviceTagging" # Dont change this.
$Tag = "" # Should be blank, if you want no device tag.
$Name = "Group" # Dont change this.

Set-ItemProperty -Path $Path -Name $Name -Value $Tag -Force
