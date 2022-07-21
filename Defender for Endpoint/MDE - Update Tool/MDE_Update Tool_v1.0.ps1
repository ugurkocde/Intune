# Author: Ugur Koc
# Created: Init 21.07.2022
# Version: 1.0
# Blogpost: https://ugurkoc.de/microsoft-defender-for-endpoint-mde-update-tool/
# Website: ugurkoc.de
# Twitter: @ugurkocde


$version = "Version: 1.0"
$author = "Ugur Koc"

Add-Type -AssemblyName PresentationFramework

# XAML file
$xamlFile = @'
<Window x:Class="Defender_GUI.MainWindow"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
        xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
        xmlns:local="clr-namespace:Defender_GUI"
        mc:Ignorable="d"
        ResizeMode="NoResize"
        Title="Microsoft Defender Update Tool" Height="500" Width="900">
    <Grid>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="101*"/>
            <ColumnDefinition Width="124*"/>
        </Grid.ColumnDefinitions>
        <Grid.RowDefinitions>
            <RowDefinition Height="97*"/>
            <RowDefinition Height="170*"/>
        </Grid.RowDefinitions>

        <Border BorderBrush="Black" BorderThickness="1" HorizontalAlignment="Left" Height="100" Margin="24,0,0,0" VerticalAlignment="Center" Width="315" Grid.Row="1"/>


        <Border BorderBrush="Black" BorderThickness="1" HorizontalAlignment="Left" Height="139" Margin="24,120,0,0" Grid.RowSpan="2" VerticalAlignment="Top" Width="315"/>


        <Border BorderBrush="Black" BorderThickness="2,2,2,2" HorizontalAlignment="Left" Height="90" Margin="348,120,0,0" VerticalAlignment="Top" Width="516" Grid.RowSpan="2" Grid.ColumnSpan="2"/>


        <Border BorderBrush="Black" BorderThickness="2,2,2,2" HorizontalAlignment="Left" Height="90" Margin="348,50,0,0" VerticalAlignment="Top" Width="516" Grid.Row="1" Grid.ColumnSpan="2"/>


        <Border BorderBrush="Black" BorderThickness="2,2,2,2" HorizontalAlignment="Left" Height="97" Margin="349,146,0,0" VerticalAlignment="Top" Width="516" Grid.Row="1" Grid.ColumnSpan="2"/>
        <Button x:Name="signature_update_button" Content="Update Signature Version" HorizontalAlignment="Left" Margin="290,141,0,0" VerticalAlignment="Top" Width="160" Background="#FFF1EC63" Height="41" FontWeight="Bold" Grid.RowSpan="2" Grid.Column="1" BorderBrush="Black">
            <Button.Effect>
                <DropShadowEffect/>
            </Button.Effect>
        </Button>
        <Button x:Name="platform_update_button" Content="Update Platform Version" HorizontalAlignment="Left" Margin="289,76,0,0" VerticalAlignment="Top" Width="159" Background="#FFA6EDA0" Height="43" FontWeight="Bold" Grid.Row="1" Grid.Column="1" BorderBrush="Black">
            <Button.Effect>
                <DropShadowEffect/>
            </Button.Effect>
        </Button>
        <Button x:Name="engine_update_button" Content="Update Engine Version" HorizontalAlignment="Left" Margin="291,171,0,0" VerticalAlignment="Top" Width="160" Background="#FFA7BEF5" Height="47" FontWeight="Bold" Grid.Row="1" Grid.Column="1" BorderBrush="Black">
            <Button.Effect>
                <DropShadowEffect/>
            </Button.Effect>
        </Button>
        <TextBlock HorizontalAlignment="Left" Margin="228,7,0,0" TextWrapping="Wrap" VerticalAlignment="Top" FontSize="32" Grid.ColumnSpan="2" FontWeight="Bold"><Run Text="Microsoft Defender"/><Run Text=" for Endpoint (MDE) "/><Run Text=" "/></TextBlock>
        <TextBlock HorizontalAlignment="Left" Margin="358,131,0,0" TextWrapping="Wrap" VerticalAlignment="Top" RenderTransformOrigin="0.449,-0.94" FontSize="14" Grid.ColumnSpan="2" Height="19"><Run Language="de-de" Text="Signature Version on this device: "/></TextBlock>
        <TextBlock HorizontalAlignment="Left" Margin="358,165,0,0" TextWrapping="Wrap" VerticalAlignment="Top" RenderTransformOrigin="0.449,-0.94" FontSize="14" Grid.RowSpan="2" Grid.ColumnSpan="2" Height="20"><Run Text="Signature Version "/><Run Language="de-de" Text="from Microsoft"/><Run Text=": "/></TextBlock>
        <TextBlock HorizontalAlignment="Left" Margin="24,140,0,0" TextWrapping="Wrap" VerticalAlignment="Top" Grid.Column="1" Height="17"/>
        <TextBlock x:Name="signature_version_device" HorizontalAlignment="Left" Margin="174,128,0,0" TextWrapping="Wrap" Text="TextBlock" VerticalAlignment="Top" FontSize="16" FontWeight="Bold" Grid.Column="1" Height="22"/>
        <TextBlock x:Name="signature_version_microsoft" HorizontalAlignment="Left" Margin="174,163,0,0" TextWrapping="Wrap" Text="TextBlock" VerticalAlignment="Top" FontSize="16" RenderTransformOrigin="0.502,0.378" FontWeight="Bold" Grid.RowSpan="2" Grid.Column="1" Height="22"/>
        <TextBlock HorizontalAlignment="Left" Margin="355,64,0,0" TextWrapping="Wrap" VerticalAlignment="Top" RenderTransformOrigin="0.449,-0.94" Grid.Row="1" FontSize="14" Grid.ColumnSpan="2" Width="197" Height="19"><Run Text="Platform "/><Run Text="Version on this device: "/></TextBlock>
        <TextBlock HorizontalAlignment="Left" Margin="355,95,0,0" TextWrapping="Wrap" VerticalAlignment="Top" RenderTransformOrigin="0.449,-0.94" Grid.Row="1" FontSize="14" Grid.ColumnSpan="2" Width="203" Height="19"><Run Language="de-de" Text="Platform"/><Run Text=" Version "/><Run Text="from Microsoft"/><Run Text=": "/></TextBlock>
        <TextBlock x:Name="platform_version_device" HorizontalAlignment="Left" Margin="174,63,0,0" TextWrapping="Wrap" Text="TextBlock" VerticalAlignment="Top" FontSize="16" FontWeight="Bold" Grid.Row="1" Grid.Column="1" Width="73" Height="22"/>
        <TextBlock x:Name="platform_version_microsoft" HorizontalAlignment="Left" Margin="174,94,0,0" TextWrapping="Wrap" Text="TextBlock" VerticalAlignment="Top" FontSize="16" FontWeight="Bold" Grid.Row="1" Grid.Column="1" Width="73" Height="22"/>
        <TextBlock HorizontalAlignment="Left" Margin="357,161,0,0" TextWrapping="Wrap" VerticalAlignment="Top" RenderTransformOrigin="0.449,-0.94" Grid.Row="1" FontSize="14" Grid.ColumnSpan="2" Height="21"><Run Language="de-de" Text="Engine"/><Run Text=" Version on this device: "/></TextBlock>
        <TextBlock HorizontalAlignment="Left" Margin="357,193,0,0" TextWrapping="Wrap" VerticalAlignment="Top" RenderTransformOrigin="0.449,-0.94" Grid.Row="1" FontSize="14" Grid.ColumnSpan="2" Height="21"><Run Language="de-de" Text="Engine"/><Run Text=" Version "/><Run Text="from Microsoft"/><Run Text=": "/></TextBlock>
        <TextBlock x:Name="engine_version_device" HorizontalAlignment="Left" Margin="175,160,0,0" TextWrapping="Wrap" Text="TextBlock" VerticalAlignment="Top" FontSize="16" FontWeight="Bold" Grid.Row="1" Grid.Column="1" Height="24"/>
        <TextBlock x:Name="engine_version_microsoft" HorizontalAlignment="Left" Margin="175,192,0,0" TextWrapping="Wrap" Text="TextBlock" VerticalAlignment="Top" FontSize="16" RenderTransformOrigin="0.457,0.519" FontWeight="Bold" Grid.Row="1" Grid.Column="1" Height="23"/>
        <Button x:Name="show_mde_status_button" Content="Show MDE Status" HorizontalAlignment="Left" Margin="32,105,0,0" VerticalAlignment="Top" Background="White" BorderBrush="White" Grid.Row="1" Height="25" Width="102" FontWeight="Bold" FontStyle="Italic"/>
        <Button x:Name="start_quickscan_button" Content="Start QuickScan" HorizontalAlignment="Left" Margin="214,105,0,0" VerticalAlignment="Top" BorderBrush="White" Background="White" Grid.Row="1" Height="25" Width="97" FontWeight="Bold" FontStyle="Italic"/>
        <Button x:Name="open_mde_portal_button" Content="Open MDE Portal" HorizontalAlignment="Left" Margin="32,136,0,0" VerticalAlignment="Top" BorderBrush="White" Background="White" Grid.Row="1" Height="25" Width="102" FontWeight="Bold" FontStyle="Italic"/>
        <TextBlock HorizontalAlignment="Left" Margin="47,55,0,0" TextWrapping="Wrap" VerticalAlignment="Top" FontSize="25" Grid.Column="1"><Run Language="de-de" Text="- "/><Run Text="Update Tool"/><Run Language="de-de" Text=" -"/></TextBlock>
        <TextBlock x:Name="devicename_text" HorizontalAlignment="Left" Margin="32,127,0,0" TextWrapping="Wrap" VerticalAlignment="Top" FontWeight="Bold"><Run Language="de-de" Text="DEVICENAME"/></TextBlock>
        <TextBlock x:Name="time_and_date_text" HorizontalAlignment="Left" Margin="31,150,0,0" TextWrapping="Wrap" VerticalAlignment="Top" FontWeight="Bold" RenderTransformOrigin="0.654,0.535"><Run Language="de-de" Text="TIME AND DATE"/></TextBlock>

        <Button x:Name="update_all_button" Content="Update All" HorizontalAlignment="Left" Margin="193,209,0,0" VerticalAlignment="Top" Width="146" Background="#FFEA8D8D" Height="30" FontWeight="Bold" Grid.Row="1" BorderBrush="Black">
            <Button.Effect>
                <DropShadowEffect/>
            </Button.Effect>
        </Button>
        <Button x:Name="engine_reload_button" Content="Refresh Data" HorizontalAlignment="Left" Margin="350,224,0,0" VerticalAlignment="Top" Width="68" Height="18" BorderBrush="Black" Background="White" FontSize="10" Grid.Row="1" Grid.ColumnSpan="2"/>
        <Button x:Name="microsoft_documentation_button" Content="-&gt; Microsoft Documentation" HorizontalAlignment="Left" Margin="24,18,0,0" VerticalAlignment="Top" Background="White" BorderBrush="White" Height="20" FontStyle="Italic"/>
        <Button x:Name="defender_changelog_button" Content="-&gt; Defender Changelog" HorizontalAlignment="Left" Margin="24,38,0,0" VerticalAlignment="Top" Height="24" Background="White" BorderBrush="White" FontStyle="Italic"/>
        <Button x:Name="tool_description_button" Content="-&gt; Tool Description" HorizontalAlignment="Left" Margin="24,63,0,0" VerticalAlignment="Top" Height="20" BorderBrush="White" Background="White" FontStyle="Italic"/>
        <Button x:Name="github_button" Content="-&gt; Github" HorizontalAlignment="Left" Margin="24,88,0,0" VerticalAlignment="Top" Height="20" Background="White" BorderBrush="White" FontStyle="Italic"/>
        <Button x:Name="signature_reload_button" Content="Refresh Data" HorizontalAlignment="Left" Margin="350,22,0,0" VerticalAlignment="Top" Width="68" Height="17" BorderBrush="Black" Background="White" FontSize="10" Grid.Row="1" Grid.ColumnSpan="2"/>
        <Button x:Name="platform_reload_button" Content="Refresh Data" HorizontalAlignment="Left" Margin="350,122,0,0" VerticalAlignment="Top" Width="68" Height="17" BorderBrush="Black" Background="White" FontSize="10" Grid.Row="1" Grid.ColumnSpan="2"/>
        <Button x:Name="start_fullscan_button" Content="Start FullScan" HorizontalAlignment="Left" Margin="214,135,0,0" VerticalAlignment="Top" Background="White" Grid.Row="1" Height="25" Width="86" FontWeight="Bold" FontStyle="Italic" BorderBrush="White"/>
        <TextBox x:Name="output_text" HorizontalAlignment="Left" Margin="32,168,0,0" Grid.Row="1" TextWrapping="Wrap" VerticalAlignment="Top" Width="299" Height="26" FontWeight="Normal" BorderThickness="2,2,2,2" BorderBrush="White" FontSize="14" Background="White" TextAlignment="Center" Foreground="Red"/>
        <TextBlock x:Name="last_updated_text" HorizontalAlignment="Left" Margin="32,7,0,0" TextWrapping="Wrap" VerticalAlignment="Top" FontWeight="Bold" RenderTransformOrigin="0.529,0.924" Grid.Row="1"><Run Language="de-de" Text="Last Updated"/></TextBlock>
        <TextBlock x:Name="realtimeprotection_text" HorizontalAlignment="Left" Margin="32,28,0,0" TextWrapping="Wrap" VerticalAlignment="Top" FontWeight="Bold" Grid.Row="1"><Run Language="de-de" Text="RealtimeProtection"/></TextBlock>
        <TextBlock x:Name="reboot_required_text" HorizontalAlignment="Left" Margin="32,49,0,0" TextWrapping="Wrap" VerticalAlignment="Top" FontWeight="Bold" Grid.Row="1"><Run Language="de-de" Text="Reboot Required"/></TextBlock>
        <TextBlock x:Name="antivirus_enabled_text" HorizontalAlignment="Left" Margin="32,69,0,0" TextWrapping="Wrap" VerticalAlignment="Top" FontWeight="Bold" Grid.Row="1"><Run Language="de-de" Text="Antivirus Enabled"/></TextBlock>
        <TextBlock x:Name="currentuser_text" HorizontalAlignment="Left" Margin="202,127,0,0" TextWrapping="Wrap" VerticalAlignment="Top" FontWeight="Bold"><Run Language="de-de" Text="CurrentUser"/></TextBlock>
        <Button x:Name="refresh_all_button" Content="Refresh all data" HorizontalAlignment="Left" Margin="27,209,0,0" VerticalAlignment="Top" Width="154" Background="#FF4DE648" Height="30" FontWeight="Bold" Grid.Row="1" BorderBrush="Black">
            <Button.Effect>
                <DropShadowEffect/>
            </Button.Effect>
        </Button>
        <TextBlock x:Name="version_text" Grid.Column="1" HorizontalAlignment="Left" Margin="406,267,0,0" TextWrapping="Wrap" Text="TextBlock" VerticalAlignment="Top" Grid.Row="1"/>
        <TextBlock x:Name="Author_text" Grid.Column="1" HorizontalAlignment="Left" Margin="418,248,0,0" TextWrapping="Wrap" Text="TextBlock" VerticalAlignment="Top" Grid.Row="1"/>


    </Grid>
</Window>



'@

#create window
$inputXML = $xamlFile
$inputXML = $inputXML -replace 'mc:Ignorable="d"', '' -replace "x:N", 'N' -replace '^<Win.*', '<Window'
[XML]$XAML = $inputXML

#Read XAML
$reader = (New-Object System.Xml.XmlNodeReader $xaml)
try {
    $window = [Windows.Markup.XamlReader]::Load( $reader )
} catch {
    Write-Warning $_.Exception
    throw
}

# Create variables based on form control names.
# Variable will be named as 'var_<control name>'
$xaml.SelectNodes("//*[@Name]") | ForEach-Object {
    #"trying item $($_.Name)";
    try {
        Set-Variable -Name "var_$($_.Name)" -Value $window.FindName($_.Name) -ErrorAction Stop
    } catch {
        throw
   }
}

Get-Variable var_*

## Check Signature Version Start ##



# Check current version from Microsoft

$website = Invoke-WebRequest -Uri https://www.microsoft.com/en-us/wdsi/definitions/antimalware-definition-release-notes -UseBasicParsing

$Pattern = '<span id="(?<dropdown>.*)" tabindex=(?<tabindex>.*) aria-label=(?<arialabel>.*) versionid=(?<versionid>.*)>(?<version>.*)</span>'

$AllMatches = ($website | Select-String $Pattern -AllMatches).Matches

$SignatureVersionList = foreach ($group in $AllMatches)
{
    [PSCustomObject]@{
        'version' = ($group.Groups.Where{$_.Name -like 'version'}).Value
    }
}

$SignatureCurrentVersion = $SignatureVersionList | Select-Object -First 1
$CurrentVersionMicrosoft = $SignatureCurrentVersion.version

# Check current version from Device

#$CurrentVersionDevice = (Get-MpComputerStatus).AntivirusSignatureVersion

## Check Signature Version End ##


## Check Platform & Engine Version Start ##

# Check current version from Microsoft

$Platformwebsite = Invoke-WebRequest -Uri https://docs.microsoft.com/en-us/microsoft-365/security/defender-endpoint/manage-updates-baselines-microsoft-defender-antivirus -UseBasicParsing

$PlatformPattern = "Platform: <strong>(?<Platform>.*)</strong><br>"

$PlatformMatches = ($Platformwebsite | Select-String $PlatformPattern -AllMatches).Matches

$PlatformVersionList = foreach ($group in $PlatformMatches)
{
    [PSCustomObject]@{
        'Platform_Version' = ($group.Groups.Where{$_.Name -like 'Platform'}).Value
    }
}

$CurrentPlatformVersion = $PlatformVersionList | Select-Object -First 1

$CurrentPlatformVersionMicrosoft = $CurrentPlatformVersion.Platform_Version

# Check current version from Device

#$CurrentPlatformVersionDevice = (Get-MpComputerStatus).AMProductVersion


$EnginePattern = "Engine: <strong>(?<Engine>.*)</strong><br>"

$EngineMatches = ($Platformwebsite | Select-String $EnginePattern -AllMatches).Matches

$EngineVersionList = foreach ($group in $EngineMatches)
{
    [PSCustomObject]@{
        'Engine_Version' = ($group.Groups.Where{$_.Name -like 'Engine'}).Value
    }
}

$CurrentEngineVersion = $EngineVersionList | Select-Object -First 1

$CurrentEngineVersionMicrosoft = $CurrentEngineVersion.Engine_Version


#$CurrentEngineVersionDevice = (Get-MpComputerStatus).AMEngineVersion

# functions:

function update-signature-info {
    $SignatureCurrentVersion = $SignatureVersionList | Select-Object -First 1
    $CurrentVersionMicrosoft = $SignatureCurrentVersion.version
    $CurrentVersionDevice = (Get-MpComputerStatus).AntivirusSignatureVersion
}

function update-platform-info {
    $CurrentPlatformVersion = $PlatformVersionList | Select-Object -First 1
    $CurrentPlatformVersionMicrosoft = $CurrentPlatformVersion.Platform_Version
    $CurrentPlatformVersionDevice = (Get-MpComputerStatus).AMProductVersion
}

function update-engine-info {
    $CurrentEngineVersion = $EngineVersionList | Select-Object -First 1
    $CurrentEngineVersionMicrosoft = $CurrentEngineVersion.Engine_Version
    $CurrentEngineVersionDevice = (Get-MpComputerStatus).AMEngineVersion
}


## Check Platform & Engine Version End ##

$signaturdata = @(
    $var_signature_reload_button.Add_Click({
        $CurrentVersionDeviceReload = (Get-MpComputerStatus).AntivirusSignatureVersion
        $var_signature_version_device.Text = "$CurrentVersionDeviceReload"
        $var_output_text.text = "Signature Info updated."
    })
)

$var_signature_update_button.Add_Click({
    $var_output_text.text = "Starting Signature Update"
    Start-Process PowerShell -Argumentlist "Update-MpSignature -Verbose 4>&1; Read-Host -Prompt 'Press Enter to exit'"
    
    #[System.Windows.MessageBox]::Show('Signature Update Successfull')
})

$platformdata = @(
    $var_platform_reload_button.Add_Click({
        $CurrentPlatformVersionDeviceReload = (Get-MpComputerStatus).AMProductVersion
        $var_platform_version_device.Text = "$CurrentPlatformVersionDeviceReload"
        $var_output_text.text = "Platform Info updated."
    })
)


$var_platform_update_button.Add_Click({
    # Install PSWindowsUpdate Module

    $ResultPlatform = [System.Windows.MessageBox]::Show('You need to run this tool as a Admin to Update the Defender Platform Version. Do you want to proceed?', 'Confirm', 'YesNo','Warning')

    if ($ResultPlatform -eq "Yes") {
                Start-Process PowerShell -Argumentlist 'if (Get-Module -ListAvailable -Name PSWindowsUpdate) {
                    Write-Host "PSWindowsUpdate Module exists."
                    Import-Module -Name PSWindowsUpdate
                    Write-Host "PSWindowsUpdate Module imported into the POSH session."
                } else {
                    Write-Host "PSWindowsUpdate Module does not exist. Installing ..."
                    Install-Module -Name PSWindowsUpdate -Force -Verbose
                    Write-Host "Finished installing PSWindowsUpdate Module"
                }; 
                Install-WindowsUpdate -KBArticleID KB4052623 -AcceptAll -Verbose'
                $var_output_text.text = "Platform Version updated."
    } else {
        $var_output_text.text = "Platform Version not updated."
    }

    <# Start-Process PowerShell -Argumentlist 'if (Get-Module -ListAvailable -Name PSWindowsUpdate) {
                                            Write-Host "Module exists."
                                            Import-Module -Name PSWindowsUpdate
                                            Write-Host "Module imported into the POSH session."
                                        } else {
                                            Write-Host "Module does not exist."
                                            Install-Module -Name PSWindowsUpdate -Force -Verbose
                                        }; 
                                        Install-WindowsUpdate -KBArticleID KB4052623 -AcceptAll -Verbose' #>

    # Check for all available updates: Get-WUList -MicrosoftUpdate

    # Install-WindowsUpdate -KBArticleID KB4052623 -AcceptAll -Verbose
    #[System.Windows.MessageBox]::Show('Platform Update Successfull')
})

$enginedata = @(
    $var_engine_reload_button.Add_Click({
        $CurrentEngineVersionDeviceReload = (Get-MpComputerStatus).AMEngineVersion
        $var_engine_version_device.Text = "$CurrentEngineVersionDeviceReload"
        $var_output_text.text = "Engine Info updated."
    })
)

$var_engine_update_button.Add_Click({
    # Install PSWindowsUpdate Module

    $ResultEngine = [System.Windows.MessageBox]::Show('You need to run this tool as a Admin to Update the Defender Engine Version. Do you want to proceed?', 'Confirm', 'YesNo','Warning')

    if ($ResultEngine -eq "Yes") {
                Start-Process PowerShell -Argumentlist 'if (Get-Module -ListAvailable -Name PSWindowsUpdate) {
                    Write-Host "PSWindowsUpdate Module exists."
                    Import-Module -Name PSWindowsUpdate
                    Write-Host "PSWindowsUpdate Module imported into the POSH session."
                } else {
                    Write-Host "PSWindowsUpdate Module does not exist. Installing ..."
                    Install-Module -Name PSWindowsUpdate -Force -Verbose
                    Write-Host "Finished installing PSWindowsUpdate Module"
                }; 
                Install-WindowsUpdate -KBArticleID KB4052623 -AcceptAll -Verbose'
                $var_output_text.text = "Engine Version updated."
    } else {
        $var_output_text.text = "Engine Version not updated."
    }

<# 
    Start-Process PowerShell -Argumentlist 'if (Get-Module -ListAvailable -Name PSWindowsUpdate) {
                                                Write-Host "Module exists."
                                                Import-Module -Name PSWindowsUpdate
                                                Write-Host "Module imported into the POSH session."
                                            } else {
                                                Write-Host "Module does not exist."
                                                Install-Module -Name PSWindowsUpdate -Force -Verbose
                                            }; 
                                            Install-WindowsUpdate -KBArticleID KB4052623 -AcceptAll -Verbose' #>

    # Check for all available updates: Get-WUList -MicrosoftUpdate

    #[System.Windows.MessageBox]::Show('Engine Update Successfull')
})

$CurrentVersionDevice = (Get-MpComputerStatus).AntivirusSignatureVersion
$var_signature_version_device.Text = "$CurrentVersionDevice"

$CurrentVersionMicrosoft = $SignatureCurrentVersion.version
$var_signature_version_microsoft.Text = "$CurrentVersionMicrosoft"


$CurrentPlatformVersionDevice = (Get-MpComputerStatus).AMProductVersion
$var_platform_version_device.Text = "$CurrentPlatformVersionDevice"

$CurrentPlatformVersionMicrosoft = $CurrentPlatformVersion.Platform_Version
$var_platform_version_microsoft.Text = "$CurrentPlatformVersionMicrosoft"


$CurrentEngineVersionDevice = (Get-MpComputerStatus).AMEngineVersion
$var_engine_version_device.Text = "$CurrentEngineVersionDevice"

$CurrentEngineVersionMicrosoft = $CurrentEngineVersion.Engine_Version
$var_engine_version_microsoft.Text = "$CurrentEngineVersionMicrosoft"

$var_microsoft_documentation_button.Add_Click({
    $microsoft_documentation1 = "https://docs.microsoft.com/en-us/microsoft-365/security/defender-endpoint/manage-updates-baselines-microsoft-defender-antivirus?ocid=cx-kb-mocamp&view=o365-worldwide"
    $microsoft_documentation2 = "https://support.microsoft.com/en-us/topic/update-for-microsoft-defender-antimalware-platform-kb4052623-92e21611-8cf1-8e0e-56d6-561a07d144cc"
    $links = ("$microsoft_documentation1", "$microsoft_documentation2")

    foreach($url in $links){
        Start-Process $url
    }
})

$var_defender_changelog_button.Add_Click({
    Start-Process "https://www.microsoft.com/en-us/wdsi/definitions/antimalware-definition-release-notes"
})

$var_tool_description_button.Add_Click({
    Start-Process "https://ugurkoc.de/microsoft-defender-for-endpoint-mde-update-tool/"
})

$var_github_button.Add_Click({
    Start-Process "https://github.com/ugurkocde/Intune/tree/main/Defender%20for%20Endpoint/MDE%20-%20Update%20Tool"
})


$CurrentUser = ((Get-WMIObject -ClassName Win32_ComputerSystem).Username).Split('\')[1]
$var_currentuser_text.text = "Current User: " + "$CurrentUser"

$datetime = Get-Date -Format "dddd MM/dd/yyyy"

$var_time_and_date_text.Text = "Current Date: " + "$datetime"

$ComputerInfo = Get-CimInstance -ClassName Win32_ComputerSystem
$ComputerName = $ComputerInfo.Name

$var_devicename_text.Text = "Devicename: " + "$ComputerName"

$var_show_mde_status_button.Add_Click({
    Start-Process PowerShell -Argumentlist "Get-Mpcomputerstatus | Format-List | Out-String; Read-Host -Prompt 'Press Enter to exit'"    
    #$MDEStatus = Get-Mpcomputerstatus | Format-List | Out-String
    $var_output_text.Text = "Opening MDE Status"
})

$var_start_fullscan_button.Add_Click({
    $var_output_text.Text = "Starting Full Scan"
    $StartFullScan = Start-Process PowerShell -Argumentlist "Start-MpScan -ScanType FullScan -Verbose; Read-Host -Prompt 'Press Enter to exit'"
    $var_output_text.Text = "Full Scan is running."
})

$var_start_quickscan_button.Add_Click({
    #Start-MpScan -ScanType QuickScan
    $StartQuickScan = Start-Process PowerShell -Argumentlist "Start-MpScan -ScanType QuickScan -Verbose; Read-Host -Prompt 'Press Enter to exit'"
    $var_output_text.Text = "Quick Scan is running."
})

$var_open_mde_portal_button.Add_Click({
    $var_output_text.Text = "Opening MDE Portal at security.microsoft.com"
    Start-Process "https://security.microsoft.com"
})

$var_refresh_all_button.Add_Click({
    $signaturdata
    $platformdata
    $enginedata
    $var_output_text.Text = "Reloading of all versions finished."
})

$var_update_all_button.Add_Click({
    Start-Process PowerShell -Argumentlist 'if (Get-Module -ListAvailable -Name PSWindowsUpdate) {
        Write-Output "PSWindowsUpdate Module exists."
        Import-Module -Name PSWindowsUpdate
        Write-Output "PSWindowsUpdate Module imported into the POSH session."
    } else {
        Write-Output "PSWindowsUpdate Module does not exist. Installing ..."
        Install-Module -Name PSWindowsUpdate -Force -Verbose
        Write-Output "Finished installing PSWindowsUpdate Module"
    }; 
    Install-WindowsUpdate -KBArticleID KB4052623 -AcceptAll -Verbose
    Write-Output "Finished installing Platform and Engine Update. Starting Signature Update process ... "
    Update-MpSignature -Verbose
    Write-Output "Finished installing Signature Version."
    Read-Host -Prompt ''Press Enter to exit'''
})

$Last_Updated = (Get-MpComputerStatus).AntispywareSignatureLastUpdated
$var_last_updated_text.text = "Last Update Scan: " + "$Last_Updated"

$realtime_protection = (Get-MpComputerStatus).RealTimeProtectionEnabled
$var_realtimeprotection_text.text = "Realtime Protection Enabled: " + "$realtime_protection"

$reboot_required = (Get-MpComputerStatus).RebootRequired
$var_reboot_required_text.text = "Reboot required: " + "$reboot_required"

$antivirus_enabled = (Get-MpComputerStatus).AntivirusEnabled
$var_antivirus_enabled_text.text = "Antivirus Enabled: " + "$antivirus_enabled"

$var_version_text.text = "$version"
$var_author_text.text = "$author"

$Null = $window.ShowDialog()
