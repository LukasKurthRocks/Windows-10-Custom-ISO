#Requires -Version 3.0

# Modify Windows Terminal Profiles
# Set Backgrounds?
# Modify PowerShell profiles (set-theme)
#iex "& { $(irm https://aka.ms/install-powershell.ps1) } -UseMSI"
#https://www.hanselman.com/blog/HowToMakeAPrettyPromptInWindowsTerminalWithPowerlineNerdFontsCascadiaCodeWSLAndOhmyposh.aspx

function Copy-PowerShellProfiles {
    [CmdLetBinding()]
    param()

    if (!$profile) {
        Write-Host "Unkown error with your profile variable: $profile" -BackgroundColor Black -ForegroundColor Red
        return
    }

    $ProfilesPath = "$PSScriptRoot\Profiles"
    $BasicPowerShellProfileName = Split-Path $profile -Leaf # Different for different powershell sessions
    $DestinationPoshProfile = $profile

    if (!(Test-Path "$DestinationPoshProfile")) {
        if (!(Test-Path -Path (Split-Path $profile))) {
            $null = New-Item -Path (Split-Path $profile) -ItemType Directory
        }
        Copy-Item -Path "$ProfilesPath\$BasicPowerShellProfileName" -Destination "$DestinationPoshProfile" -Verbose:$VerbosePreference
    }

    Write-Host "Done Importing Profile '$BasicPowerShellProfileName'"
}

function Import-TerminalPictures {
    # Start and Modify PowerShell
    $TerminalPictures = "$PSScriptRoot\TerminalPictures"
    $UserPicturesPath = "$env:USERPROFILE\Pictures"
    
    if (!(Test-Path "$TerminalPictures" -ErrorAction SilentlyContinue)) {
        Write-Host "Terminal pictures not found" -BackgroundColor Black -ForegroundColor Red
        return
    }
    if (!(Test-Path "$UserPicturesPath" -ErrorAction SilentlyContinue)) {
        Write-Host "User pictures folder not found" -BackgroundColor Black -ForegroundColor Red
        return
    }
    
    ROBOCOPY $TerminalPictures $UserPicturesPath /COPYALL /E /R:5 /W:10 /TEE

    Write-Host "Done Importing!"
}

function Install-TerminalPrerequisites {
    <#
    Windows 10 < 1903 kann man nicht vorbereiten. 10240 (1507) hat viele Probleme.
    Kann Nuget nicht mehr laden, PackageProvider Installieren geht auch nicht etc...

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $wc = New-Object System.Net.WebClient
    $wc.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials

    Register-PackageSource -Name MyNuGet -Location https://www.nuget.org/api/v2 -ProviderName NuGet -Force -Verbose
    #>

    if (!(Get-PackageProvider -Name "NuGet")) {
        Install-PackageProvider -Name "NuGet" -MinimumVersion 2.8.5.201 -Force
    }
    if (!(Get-PSRepository -Name "PSGallery")) {
        Register-PSRepository -Name "PSGallery" -SourceLocation "https://www.powershellgallery.com/api/v2/" -InstallationPolicy Trusted
    }

    if (!(Get-Module -Name "posh-git" -ListAvailable -ErrorAction SilentlyContinue)) {
        Install-Module "posh-git" -Scope CurrentUser
    }
    if (!(Get-Module -Name "oh-my-posh" -ListAvailable -ErrorAction SilentlyContinue)) {
        Install-Module "oh-my-posh" -Scope CurrentUser
    }

    # This has to be placed into powershell profile
    Set-Theme Agnoster
    
    Write-Host "Done Installing Prerequisites"
}

function Copy-WindowsTerminalProfiles {
    [CmdLetBinding()]
    param()

    $SavedSettingsFile = "$PSScriptRoot\Profiles\settings.json"
    if (!(Test-Path "$SavedSettingsFile" -ErrorAction SilentlyContinue)) {
        Write-Host "Settings file '$SavedSettingsFile' not found." -BackgroundColor Black -ForegroundColor Red
        return
    }

    $WindowsTerminalSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    $WTProfileExists = Test-Path -Path "$WindowsTerminalSettingsPath" -ErrorAction SilentlyContinue
    if ($WTProfileExists) {
        $CanOverwriteWTProfile = (Read-Host -Prompt "File '$WindowsTerminalSettingsPath' does exist. Do you want to overwrite it? [y]").ToLower() -eq "y"
    }
    if (!$WTProfileExists -or $CanOverwriteWTProfile) {
        Copy-Item -Path "$SavedSettingsFile" -Destination "$WindowsTerminalSettingsPath"
    }
    
    $WindowsTerminalPreviewSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json"
    $WTPreviewProfileExists = Test-Path -Path "$WindowsTerminalPreviewSettingsPath" -ErrorAction SilentlyContinue
    if ($WTPreviewProfileExists) {
        $CanOverwriteWTPreviewProfile = (Read-Host -Prompt "File '$WindowsTerminalPreviewSettingsPath' does exist. Do you want to overwrite it? [y]").ToLower() -eq "y"
    }
    if (!$WTPreviewProfileExists -or $CanOverwriteWTPreviewProfile) {
        Copy-Item -Path "$SavedSettingsFile" -Destination "$WindowsTerminalPreviewSettingsPath"
    }

    Write-Host "Done Importing Profile '$SavedSettingsFile'"
}

Copy-PowerShellProfiles

#$OSReleaseID = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\" -Name ReleaseID).ReleaseId
$OSBuildNum = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\' -Name CurrentBuild).CurrentBuild
if ($OSBuildNum -ge 18362) {
    if (!(Get-AppxPackage | Where-Object { $_.Name -match "Terminal" })) {
        Write-Warning "Windows Terminal needs to be installed. Please visit 'https://aka.ms/terminal' to install it. Press enter when done."
        $null = Read-Host
    }
    
    # Get-AppXPackage *WindowsStore* -AllUsers | Foreach {Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml"} 

    Import-TerminalPictures
    Install-TerminalPrerequisites
    Copy-WindowsTerminalProfiles
}
