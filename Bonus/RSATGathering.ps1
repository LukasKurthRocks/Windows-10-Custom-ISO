# Order Table
# Version   Codename    Marketing Name          Build   Done
# 1507      Threshold 1 N/A                     10240   No
# 1511      Threshold 2 November Update         10586   No
# 1607      Redstone 1  Anniversary Update      14393   No
# 1703      Redstone 2  Creators Update         15063   No
# 1709      Redstone 3  Fall Creators Update    16299   No
# 1803      Redstone 4  April 2018 Update       17134   No
# 1809      Redstone 5  October 2018 Update     17763   No
# 1903      19H1        May 2019 Update         18362   No
# 1909      19H2        November 2019 Update    18363   No
# 2004      20H1        May 2020 Update         19041   No
# 20H2      20H2        TBA                     19042   No
# Dev Channel                                   20201   No!?

# Some Links
# https://github.com/DeploymentResearch/DRFiles/blob/master/Scripts/Create-WS2019RefImage.ps1 (Server 2019 Reference Image with W10 + PowerShell)
#https://www.osdeploy.com/
# https://deploymentresearch.com/using-osd-builder-to-create-a-multi-language-windows-10-image/ (OSDBuilder MultiLanguage Image)
# https://win10.guru/patching-windows-install-image-with-osdbuilder/ (OSDBuilder Example)
# http://www.edugeek.net/forums/windows-10/165029-how-get-rid-candy-crush-soda-saga-other-windows-10-start-menu-junk-good-20.html (Remove Stuff OSDBuilder)
# https://www.powershellgallery.com/packages/OSBuilder/18.12.5.0/Content/Public%5CGet-OSBuilderUpdates.ps1 (OSDBuilder FOD Download?)
#https://www.vcloudinfo.com/2019/01/how-to-install-windows-10-1809-features.html
# https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/features-on-demand-non-language-fod
# https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/features-on-demand-language-fod
# Others
# https://www.bleepingcomputer.com/news/microsoft/install-windows-10-updates-manually-with-this-open-source-tool/
# https://github.com/DavidXanatos/wumgr

# Ideas
# Create Windows 10 Surface Image?
#Requires -RunAsAdministrator
<#
Robocopy useful cmd arguments
R:[n]   - Retry x times
W:[n]   - Wait for retry in x seconds
E       - Copy +subfolders (no permissions)
PURGE   - Remove folders in source
MIR     - Mirror directories; like /e and /purge (+ permissions)
MT:[n]  - Multithreading, standard = 8 threads
MOV     - MOVES all files and removes them from source
MOVE    - MOVES all files +directories and removes them from source
ETA     - shows eta of files arriving
V       - Verbose output, show skipped files
LOG     - Path to the LogFile
UNILOG  - Path to the Unicode Logfile
TEE     - Show status when having LogFile...

NP      - No Progress (100%)
NJH     - No Job Header
NJS     - No Job Summary
NDL     - No directory listing
NFL     - No file listing

D Data
A Attributes
T Time stamps
S NTFS access control list (ACL)
O Owner information
U Auditing information

COPY:DAT - Copying files with attributes and timestamp.
SEC      - COPY:DATS
COPYALL  - COPY:DATSOU
NOCOPY   - No file information (useful when /purge)
#>

[CmdLetBinding()]
param(
    $FeatureRex = "RSAT|de-de|en-us|hu-hu|sv-se|nl-nl|fr-fr"
)

# Test mit 1507/1511 => Nur Image oder gehts auch mit Windows/DISM!?
# Vars
$Folder = "$PSScriptRoot\SD_Copy"
$LoggingFolder = "$Folder\Logs"
$SDFolderOld = "$Folder\files.old"
#

if (!(Test-Path -Path $LoggingFolder -ErrorAction SilentlyContinue)) {
    $null = New-Item -Path $LoggingFolder -ItemType Directory
}
Start-Transcript -Path "$LoggingFolder\$(Get-Date -Format "yyMmdd-HHmmss")_pstransscript.log"

# DEBUG
$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"

Write-Host "Disabling WSUS server usage ..."
            
# Registry Windows Update Options | https://docs.microsoft.com/de-de/security-updates/windowsupdateservices/18127499
Set-ItemProperty -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU -Name UseWUServer -Value 0 # Skip WUServer; Using MS Servers
Set-ItemProperty -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU -Name AllowMUUpdateService -Value 1 # Also install microsoft products
Set-ItemProperty -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU -Name AUOptions -Value 3 # 3 = Automatically download and notify of installation.
Set-ItemProperty -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU -Name NoAutoRebootWithLoggedOnUsers -Value 1 # 1 = Logged-on user gets to choose whether or not to restart his or her computer.

# Re-enabling service when disabled on machines
Write-Verbose "Stopping services ... (use something like 'psexec -s \\$env:COMPUTERNAME cmd /c taskkill /F /FI `"SERVICES eq wuauserv`"' when services are not responsing)"
Get-Service wuauserv -Verbose:$false | Where-Object { $_.StartType -eq "Disabled" } | Set-Service -StartupType Manual -Verbose:$VerbosePreference
Get-Service wuauserv, TrustedInstaller, msiserver, cryptsvc, AppIDSvc, BITS -Verbose:$false | Stop-Service -Force -Verbose:$VerbosePreference

Write-Verbose "Moving SoftwareDistribution folders ..."
Robocopy "$env:windir\SoftwareDistribution" "$SDFolderOld\sodi.old" /MIR /R:5 /W:5 /NJS /NJH /NDL
Robocopy "$env:windir\system32\catroot2" "$SDFolderOld\cat2.old" /MIR /R:5 /W:5 /NJS /NJH /NDL

Restart-Service wuauserv -Verbose:$VerbosePreference

$RoboLog = "$(Get-Date -Format "yyMMdd_HHmmss")_RoboLog.log"
$DISMLog = "$(Get-Date -Format "yyMMdd_HHmmss")_DISMOps_WarnErr.log"

# Get-WindowsCapability -Name RSAT* -Online | Select-Object -Property DisplayName, State
$MissingCapabilities = @()
$MissingCapabilities += Get-WindowsCapability -Online -Verbose:$false | Where-Object { $_.Name -match $FeatureRex -and $_.State -ne "Installed" }

# OS Build number, to copy feature files for multiple systems
$OSBuild = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\" -Name ReleaseID).ReleaseId
$Bittage = (Get-CIMInstance Win32Processor).AddressWidth
$MissingCapabilities | ForEach-Object {
    $CapabilityName = $_.Name

    Write-Host "## Missing: $CapabilityName ##" -ForegroundColor Cyan

    #Add-WindowsCapability -Online -Name "$CapabilityName"
    #Start-Process Dism -ArgumentList "/Online /English /Get-Capabilities /LogPath:$LoggingFolder\$DISMLog /LogLevel:2" -WindowStyle Hidden -PassThru
    Start-Process Dism -ArgumentList "/Online /English /Add-Capability /CapabilityName:$CapabilityName /LogPath:$LoggingFolder\$DISMLog /LogLevel:2" -WindowStyle Hidden # -PassThru

    # as long as there is a dism process running
    Write-Verbose "[$(Get-Date -Format "HH:mm:ss")] DISM running for $CapabilityName, starting robocopy ..."
    while(Get-Process DISM -ErrorAction SilentlyContinue) {
        # copy files to desktop folder
        #Write-Verbose "[$(Get-Date -Format "HH:mm:ss")] DISM running for $CapabilityName, starting robocopy ..."
        $null = Robocopy "$env:windir\SoftwareDistribution" "$Folder\files\$OSBuild\$Bittage" /E /R:0 /W:0 /V /Unilog+:"$LoggingFolder\$RoboLog" /NDL /NP /ETA
        Start-Sleep -MilliSeconds 500
    }
}

# Get-WindowsCapability -Online | Where-Object { $_.Name -match "RSAT|Lang" -and $_.Name -notmatch "de-de" -and $_.State -eq "Installed" } | $null = Remove-WindowsCapability -Online -Verbose
# Get-WindowsCapability -Online | Where-Object { $_.Name -match "de-de" -and $_.State -ne "Installed" } | Add-WindowsCapability -Online -Verbose

# LPs etc. Set-WinUILanguageOverride <xx-xx> (where xx-xx is your language culture)

# Removing stuff from debloater/Warhawk scripts

Stop-Transcript
