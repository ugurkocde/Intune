<#

Author: Ugur Koc
Initial Release: 07/29/2022
Last Update: 08/01/2022

.SYNOPSIS
Downloads a Application and converts it to a, ready to upload, .intunewin File.

.DESCRIPTION
This tool is for everybody that works with deployments of Applications in Intune. 
This will help you to automate the process of downloading the newest version of a application and then converty it automatically to a ready-to-deploy .intunewin file.

I have also written a blog post for a better explanation of what this tool can do how it works: 


.NOTES
This is a very early version that will be constantly updated with new features (and bug fixes).
#>

## GUI START ##
Add-Type -AssemblyName PresentationFramework

# XAML file
$xamlFile = @'
<Window x:Class="WingetForIntune.MainWindow"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
        xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
        xmlns:local="clr-namespace:WingetForIntune"
        mc:Ignorable="d"
        ResizeMode="NoResize"
        Title="winget2intunewin" Height="420" Width="720">
    <Grid>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="65*"/>
            <ColumnDefinition Width="854*"/>
            <ColumnDefinition Width="0*"/>
        </Grid.ColumnDefinitions>
        <Grid.RowDefinitions>
            <RowDefinition Height="39*"/>
            <RowDefinition Height="28*"/>
        </Grid.RowDefinitions>
        <Rectangle HorizontalAlignment="Left" Height="86" Margin="24,224,0,0" Stroke="Black" VerticalAlignment="Top" Width="264" Grid.RowSpan="2" Grid.ColumnSpan="2"/>
        <Rectangle HorizontalAlignment="Left" Height="86" Margin="24,129,0,0" Stroke="Black" VerticalAlignment="Top" Width="264" Grid.ColumnSpan="2"/>
        <TextBox x:Name="app_search_input_box" HorizontalAlignment="Left" Margin="43,172,0,0" TextWrapping="Wrap" Text="" VerticalAlignment="Top" Width="131" Height="20" Grid.ColumnSpan="2"/>
        <Button x:Name="app_search_button" Content="Search" HorizontalAlignment="Left" Margin="143,163,0,0" VerticalAlignment="Top" Width="76" Height="38" BorderBrush="Black" Background="#FF89FF55" FontWeight="Bold" Grid.Column="1">
            <Button.Effect>
                <DropShadowEffect/>
            </Button.Effect>
        </Button>
        <TextBox x:Name="output_box" HorizontalAlignment="Left" Margin="256,141,0,0" TextWrapping="WrapWithOverflow" VerticalAlignment="Top" Width="380" Height="187" VerticalScrollBarVisibility="Auto" Grid.RowSpan="2" HorizontalScrollBarVisibility="Visible" IsReadOnly="True" Grid.Column="1"/>
        <Label Content="WinGet:" HorizontalAlignment="Left" Margin="178,77,0,0" VerticalAlignment="Top" Grid.Column="1" Height="26" Width="56" FontWeight="Bold" RenderTransformOrigin="0.711,0.511"/>
        <Label Content="Run-As-Admin:" HorizontalAlignment="Left" Margin="321,77,0,0" VerticalAlignment="Top" Grid.Column="1" Height="26" Width="103" FontWeight="Bold"/>
        <Button x:Name="download_button" Content="3. Download App &amp; Create IntuneWin" HorizontalAlignment="Left" Margin="24,99,0,0" VerticalAlignment="Top" Width="264" RenderTransformOrigin="-0.388,6.498" Height="39" Grid.Row="1" Background="#FFFF7777" FontWeight="Bold" Grid.ColumnSpan="2" BorderBrush="Black">
            <Button.Effect>
                <DropShadowEffect/>
            </Button.Effect>
        </Button>
        <Button x:Name="open_folder_button" Content="Open Folder" HorizontalAlignment="Left" Margin="471,113,0,0" VerticalAlignment="Top" Height="25" Width="104" Grid.Row="1" Grid.Column="1" Background="#FFF9F581" BorderBrush="Black">
            <Button.Effect>
                <DropShadowEffect/>
            </Button.Effect>
        </Button>
        <Button x:Name="open_mem_portal" Content="Open Endpoint Manager Portal" HorizontalAlignment="Left" Margin="256,113,0,0" VerticalAlignment="Top" Width="205" Height="25" RenderTransformOrigin="0.53,-1.318" Grid.Row="1" Grid.Column="1" Background="#FFF9F581" BorderBrush="Black">
            <Button.Effect>
                <DropShadowEffect/>
            </Button.Effect>
        </Button>
        <Button x:Name="winget_status_button" Content="Button" HorizontalAlignment="Left" Margin="234,80,0,0" VerticalAlignment="Top" Background="White" BorderBrush="White" Foreground="Black" Grid.Column="1" Height="20" Width="77"/>
        <Button x:Name="admin_status_button" Content="Button" HorizontalAlignment="Left" Margin="426,80,0,0" VerticalAlignment="Top" Background="White" BorderBrush="White" Foreground="Black" Grid.Column="1" Height="20" Width="40"/>
        <Label Content="Log" HorizontalAlignment="Left" Margin="282,112,0,0" VerticalAlignment="Top" Width="41" Height="36" HorizontalContentAlignment="Center" FontSize="16" Foreground="Black" Grid.Column="1"/>
        <Rectangle HorizontalAlignment="Left" Height="2" Margin="325,129,0,0" Stroke="#FF8A8A8A" VerticalAlignment="Top" Width="311" Grid.Column="1"/>
        <Rectangle HorizontalAlignment="Left" Height="2" Margin="256,129,0,0" Stroke="#FF8A8A8A" VerticalAlignment="Top" Width="23" RenderTransformOrigin="0.517,-0.48" Grid.Column="1"/>
        <Label Content="winget2intunewin" HorizontalAlignment="Left" Margin="178,-4,0,0" VerticalAlignment="Top" FontSize="36" Height="64" Grid.Column="1" Width="329"/>
        <TextBox x:Name="app_id_input" HorizontalAlignment="Left" Margin="43,45,0,0" TextWrapping="Wrap" VerticalAlignment="Top" Width="131" HorizontalScrollBarVisibility="Auto" Height="20" Grid.Row="1" Grid.ColumnSpan="2"/>
        <Button x:Name="save_id_button" Content="Save ID" HorizontalAlignment="Left" Margin="144,36,0,0" VerticalAlignment="Top" Width="75" Height="37" Grid.Row="1" FontWeight="Bold" Background="#FFA7BEF5" Grid.Column="1" BorderBrush="Black">
            <Button.Effect>
                <DropShadowEffect/>
            </Button.Effect>
        </Button>
        <Label Content="1. Search Application" HorizontalAlignment="Left" Margin="64,130,0,0" VerticalAlignment="Top" FontSize="16" FontWeight="Bold" Width="184" HorizontalContentAlignment="Center" Grid.ColumnSpan="2" Height="31"/>
        <Label Content="2. Enter the Application ID" HorizontalAlignment="Left" Margin="41,224,0,0" VerticalAlignment="Top" FontSize="16" Width="230" FontWeight="Bold" HorizontalContentAlignment="Center" Grid.RowSpan="2" Grid.ColumnSpan="2" Height="31"/>
        <Button x:Name="microsoft_documentation_button" Content="-&gt; Microsoft Documentation" HorizontalAlignment="Left" Margin="24,63,0,0" VerticalAlignment="Top" Background="White" BorderBrush="White" Height="20" FontStyle="Italic" Grid.ColumnSpan="2" Width="151"/>
        <Button x:Name="winget_github_button" Content="-&gt; WinGet Github" HorizontalAlignment="Left" Margin="24,83,0,0" VerticalAlignment="Top" Height="24" Background="White" BorderBrush="White" FontStyle="Italic" Grid.ColumnSpan="2" Width="98"/>
        <Button x:Name="tool_description_button" Content="-&gt; Tool Description" HorizontalAlignment="Left" Margin="24,18,0,0" VerticalAlignment="Top" Height="20" BorderBrush="White" Background="White" FontStyle="Italic" Grid.ColumnSpan="2" Width="104"/>
        <Button x:Name="winget2intunewin_github_button" Content="-&gt; Winget2IntuneWin Github" HorizontalAlignment="Left" Margin="24,41,0,0" VerticalAlignment="Top" Height="20" Background="White" BorderBrush="White" FontStyle="Italic" Grid.ColumnSpan="2" Width="157"/>
        <Label Content="Number of supported Applications: " HorizontalAlignment="Left" Margin="202,48,0,0" VerticalAlignment="Top" Grid.Column="1" Height="26" Width="200"/>
        <TextBox x:Name="number_of_apps_text" HorizontalAlignment="Left" Margin="396,52,0,0" TextWrapping="Wrap" Text="TextBox" VerticalAlignment="Top" Width="70" BorderBrush="White" Grid.Column="1" Height="18"/>
        <TextBox x:Name="Version_text" Grid.Column="1" HorizontalAlignment="Left" Margin="569,41,0,0" TextWrapping="Wrap" Text="TextBox" VerticalAlignment="Top" Width="76" BorderBrush="White" RenderTransformOrigin="0.501,-0.055"/>
        <TextBox x:Name="Author_text" Grid.Column="1" HorizontalAlignment="Left" Margin="569,18,0,0" TextWrapping="Wrap" Text="TextBox" VerticalAlignment="Top" Width="61" BorderBrush="White"/>
        <Button x:Name="open_logs_button" Grid.Column="1" Content="Log" HorizontalAlignment="Left" Margin="587,113,0,0" Grid.Row="1" VerticalAlignment="Top" Height="25" Width="49" Background="#FFF9F581" BorderBrush="Black">
            <Button.Effect>
                <DropShadowEffect/>
            </Button.Effect>
        </Button>
        <Rectangle Grid.Column="1" HorizontalAlignment="Left" Height="1" Margin="174,45,0,0" Stroke="Black" VerticalAlignment="Top" Width="61" Fill="Black"/>
        <Rectangle Grid.Column="1" HorizontalAlignment="Left" Height="1" Margin="264,45,0,0" Stroke="Black" VerticalAlignment="Top" Width="208" Fill="Black"/>
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

#Get-Variable var_*

$var_Author_text.Text = "Ugur Koc"
$var_Version_text.Text  = "Version 0.2"

$global:progressPreference = 'silentlyContinue'

# TimeStamp Function #
function Get-TimeStamp {
    return "[{0:HH:mm:ss}]" -f (Get-Date)
}

# Create Main Folder Start #

$winget2intunewin_path = "C:\winget2intunewin\"
If(!(test-path -PathType container $winget2intunewin_path))
{
    New-Item -ItemType Directory -Path $winget2intunewin_path -Force
}
$var_output_box.AppendText("$(Get-TimeStamp) Main Folder: $winget2intunewin_path")

# Create Main Folder End #

# Log Function #
function Write-Log
{
    Param
    (
        $text
    )

    "$text" | out-file "c:\winget2intunewin\log.txt" -Append
}

Write-Log -text "--- Starting Logging: $(Get-TimeStamp) ---"

# IntuneWinAppUtil Start #
$intunewin_fullpath = "C:\winget2intunewin\IntuneWinAppUtil.exe"

If(!(test-path $intunewin_fullpath)) 
{
    $var_output_box.AppendText("`r`n$(Get-TimeStamp) Could not find IntuneWinAppUtil. Downloading now ...")
    Write-Log -text "`r`n$(Get-TimeStamp) Could not find IntuneWinAppUtil. Downloading now ..."
    Invoke-WebRequest -Uri "https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/raw/master/IntuneWinAppUtil.exe" -OutFile "C:\winget2intunewin\IntuneWinAppUtil.exe"
    $var_output_box.AppendText("`r`n$(Get-TimeStamp) Download finished.")
    Write-Log -text "$(Get-TimeStamp) Download finished."
} else {
    $var_output_box.AppendText("`r`n$(Get-TimeStamp) IntuneWinAppUtil already exits.")
    Write-Log -text "`r`n$(Get-TimeStamp) IntuneWinAppUtil already exits."
}

# IntuneWinAppUtil End #

## Winget Download Start ##
$winget_download_url = "https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"

$winget_setupfile_path = "C:\winget2intunewin\winget.msixbundle"

$Check_Package =  (Get-AppPackage -Name *Microsoft.DesktopAppInstaller*).Status

if ($Check_Package -eq "Ok" ) {
    $var_winget_status_button.Content = "Installed"
    $var_winget_status_button.Fontweight = "Bold"
    $var_winget_status_button.Foreground = "#00a300"
    $var_output_box.AppendText("`r`n$(Get-TimeStamp) WinGet is installed.")
    Write-Log -text "$(Get-TimeStamp) WinGet is installed."
} else {
    $var_admin_status_button.Content = "Not Installed"
    $var_admin_status_button.Fontweight = "Bold"
    $var_admin_status_button.Foreground = "#a30000"
    $var_output_box.AppendText("`r`n$(Get-TimeStamp) WinGet is not installed. Installing now ...")
    Write-Log -text "$(Get-TimeStamp) WinGet is installed."
    $winget_tool_download = Invoke-WebRequest -Uri $winget_download_url -OutFile $winget_setupfile_path
    $var_output_box.AppendText("`r`n$(Get-TimeStamp) WinGet download finished ...")
    Write-Log -text "$(Get-TimeStamp) WinGet download finished ..."
    Add-AppPackage -Path $winget_setupfile_path
    $var_output_box.AppendText("`r`n$(Get-TimeStamp) WinGet is installed ...")
    Write-Log -text "$(Get-TimeStamp) WinGet is installed ..."
}

## Winget Download End ##

# Check if running with priveleged rights
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$check_admin_priv = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

$var_output_box.AppendText("`r`n$(Get-TimeStamp) Checking if this tool is runned with administrative privileges.")

if ($check_admin_priv -eq "True") {
    $var_output_box.AppendText("`r`n$(Get-TimeStamp) Tool is running with administrative privileges.")
    Write-Log -text "$(Get-TimeStamp) Tool is running with administrative privileges."
    $var_admin_status_button.Content = "Yes"
    $var_admin_status_button.Fontweight = "Bold"
    $var_admin_status_button.Foreground = "#00a300"
} else {
    $var_output_box.AppendText("`r`n$(Get-TimeStamp) Please restart this tool with administrative privileges.")
    Write-Log -text "$(Get-TimeStamp) Please restart this tool with administrative privileges."
    $var_admin_status_button.Content = "No"
    $var_admin_status_button.Fontweight = "Bold"
    $var_admin_status_button.Foreground = "#a30000"
}

# Define Buttons

$var_app_search_button.Add_Click{
    $AppName = $var_app_search_input_box.Text
    if ([string]::IsNullOrWhiteSpace($AppName) -eq "True") {
        $var_output_box.AppendText("`r`n$(Get-TimeStamp) Please search for a Application in the first Step")
    } else {
        $var_output_box.AppendText("`r`n$(Get-TimeStamp) Searching $AppName with WinGet in a new Powershell Window.")
        Write-Log -text "$(Get-TimeStamp) Searching $AppName with WinGet in a new Powershell Window."
        $winget_search = (Start-Process PowerShell -Argumentlist "Write-Host 'Copy the ID from the Application you want to download and convert:'`n`n;Write-Host ""`n;winget search --name $AppName;Read-Host -Prompt '`nPress Enter to exit after you copied the ID'" -Wait)
        $path = "C:\winget2intunewin\" + "$AppName" -replace '\s',''
        If(!(test-path -PathType container $path))
        {
            New-Item -ItemType Directory -Path $path -Force
        }    

        # Delete all old files in this folder. IntuneWinAppUtil will package all files present in this specific appfolder. Thats why it has to be empty or the intunewin file will be broken.
        If(test-path -PathType container $path)
        {
            Get-ChildItem -Path $path -File | Remove-Item -Verbose
            Write-Log -text "$(Get-TimeStamp) Deleted old files in the $AppName - Folder"
        }   
    }   
    $var_output_box.ScrollToEnd()
}


$var_save_id_button.Add_Click{
    $winget_id = $var_app_id_input.Text

    if ([string]::IsNullOrWhiteSpace($winget_id) -eq "True") {
        $var_output_box.AppendText("`r`n$(Get-TimeStamp) Please copy and paste a Application ID from the first Step")
    } else {
        $var_output_box.AppendText("`r`n$(Get-TimeStamp) Successfully saved the following Application ID: $winget_id") 
        Write-Log -text "$(Get-TimeStamp) Successfully saved the following Application ID: $winget_id"
    }   
    $var_output_box.ScrollToEnd()
}

$var_download_button.Add_Click{
    $AppName = $var_app_search_input_box.Text
    $var_output_box.AppendText("`r`n$(Get-TimeStamp) Application to download: $AppName")
    Write-Log -text "$(Get-TimeStamp) Application to download: $AppName"
    $winget_id = $var_app_id_input.Text -replace '\s',''
    $path = "C:\winget2intunewin\" + "$AppName" -replace '\s',''
    $var_output_box.AppendText("`r`n$(Get-TimeStamp) Download Folder: $path")

    $winget_show = winget show --id $winget_id | findstr ".exe .msi" | Select-String -Pattern "http" | Out-String

    $download_url = $winget_show.split(":")[1] + ":" + $winget_show.split(":")[2] | Out-String

    $download_url_trim = $download_url.Trim("`r","`n"," ")
    $var_output_box.AppendText("`r`n$(Get-TimeStamp) Download URL: $download_url_trim") 
    Write-Log -text "$(Get-TimeStamp) Download URL: $download_url_trim"

    $download_app_extension = $download_url_trim.Substring($download_url_trim.Length - 4)

    $download_app_filename = $AppName + $download_app_extension -replace '\s',''
    $var_output_box.AppendText("`r`n$(Get-TimeStamp) Filename: $download_app_filename") 
    Write-Log -text "$(Get-TimeStamp) Filename: $download_app_filename"

    $setupfile_path = $path + "\" + $download_app_filename
    
    $var_output_box.AppendText("`r`n$(Get-TimeStamp) Starting the download of $AppName")
    Write-Log -text "$(Get-TimeStamp) Starting download of $AppName"

    $download_app_job = @{
        Name                 = 'DownloadJob'
        ScriptBlock          = {$ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -Uri $args[0] -OutFile $args[1]}
    }

    Start-Job @download_app_job -Argumentlist $download_url_trim, $setupfile_path

    while ((Get-Job -Name 'DownloadJob').State -eq 'Running') {
        $download_size_progress = $((Get-ChildItem $setupfile_path).Length)/1MB
        Write-Log -text "$(Get-TimeStamp) Download in progress: $([math]::round($download_size_progress,2)) MB"
        sleep 1
    }

    if((Get-Job -Name 'DownloadJob').State -eq 'Completed'){
        $download_size_final = $((Get-ChildItem $setupfile_path).Length)/1MB
        Test-Path -Path $setupfile_path
        $var_output_box.AppendText("`r`n$(Get-TimeStamp) Finished downloading $AppName$download_app_extension. Size: $([math]::round($download_size_final,2)) MB")
        Write-Log -text "$(Get-TimeStamp) Finished downloading $AppName$download_app_extension. Size: $([math]::round($download_size_final,2)) MB"
        
        # Open Output Folder after completing download.
        $outputfolder_path = "C:\winget2intunewin\" + "$AppName" -replace '\s',''
        Start-Process $outputfolder_path
    }

    $intunewin_path = (Get-ChildItem "C:\winget2intunewin\" | Where-Object {$_.name -like "IntuneWinAppUtil.exe"}).Name

    $run = "& .\$intunewin_path -c $path -s $setupfile_path -o $outputfolder_path"
    
    $var_output_box.AppendText("`r`n$(Get-TimeStamp) Creating IntuneWin: Started")
    Write-Log -text "$(Get-TimeStamp) Creating IntuneWin: Started"

    # Create Intunewin File out of the downloaded executable from the steps before
    $create_intunewin_app = (Start-Process PowerShell -windowstyle hidden -Argumentlist "cd 'C:\winget2intunewin\'; $run" -Wait)

    $var_output_box.AppendText("`r`n$(Get-TimeStamp) Creating IntuneWin: Finished")
    Write-Log -text "$(Get-TimeStamp) Creating IntuneWin: Finished"

    $var_output_box.AppendText("`r`n$(Get-TimeStamp) Opening Output Folder")
    
    $var_output_box.ScrollToEnd()

    Start-Process $outputfolder_path
}

$var_number_of_apps_text.Text = "3600+"

$var_open_mem_portal.Add_Click{
    Start-Process "https://endpoint.microsoft.com/#blade/Microsoft_Intune_DeviceSettings/AppsWindowsMenu/windowsApps"
}

$var_open_folder_button.Add_Click{
    Start-Process "C:\winget2intunewin\"
}

$var_tool_description_button.Add_Click{
    Start-Process "https://ugurkoc.de/winget2intunewin-automatically-create-applications-for-microsoft-intune/"
}

$var_winget2intunewin_github_button.Add_Click{
    Start-Process "https://github.com/ugurkocde/Intune/tree/main/winget2intunewin"
}

$var_microsoft_documentation_button.Add_Click{
    Start-Process "https://docs.microsoft.com/en-us/windows/package-manager/winget/"
}

$var_winget_github_button.Add_Click{
    Start-Process "https://github.com/microsoft/winget-cli"
}

$var_open_logs_button.Add_Click{
    Start-Process "c:\winget2intunewin\log.txt"
}

$Null = $window.ShowDialog()