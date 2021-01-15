# With Help from:
# https://portableapps.com/node/1124
# https://www.sandboxie.com/StartCommandLine

# PS < 3.0
#if (!$PSScriptRoot) {
#    $PSScriptRoot = Split-Path -Path $MyInvocation.MyCommand.Source
#}

$SandboxieInstaller = Get-ChildItem "$PSScriptRoot\Sandboxie\*Install*.exe"
$ApplicationSaveFolder = "C:\_temp"
$LogFolder = "$ApplicationSaveFolder\Logs"

if ($ApplicationSaveFolder -and (!(Test-Path -Path $ApplicationSaveFolder))) {
    $null = New-Item -ItemType Directory -Path $ApplicationSaveFolder -Force
}
if ($LogFolder -and (!(Test-Path -Path $LogFolder))) {
    $null = New-Item -ItemType Directory -Path $LogFolder -Force
}

Start-Transcript -Path "$LogFolder\$(Get-Date -Format "yyMMddHHmmss")_$($MyInvocation.MyCommand.Name).log"

Write-Host "Started: $(Get-Date -Format "dd.MM.yy HH:mm:ss.ffffff")"

function RemoveIfExists {
    param (
        $SandboxieInstaller
    )

    if (Get-Process PatchMyPC.exe -ErrorAction SilentlyContinue) {
        Get-Process PatchMyPC.exe | Stop-Process -Force
    }

    Write-Host "De-register Sandboxie"
    Get-ChildItem -Path $env:TMP -Recurse | Where-Object { ($_.PSIsContainer) -and ($_.Name -match "sandboxie") } | ForEach-Object {
        $Proc = Start-Process -FilePath $SandboxieInstaller.FullName -ArgumentList "/remove /S /D=$($_.FullName)" -Wait -PassThru
        Write-Host "Exited with `"$($Proc.ExitCode)`"" -ForegroundColor DarkGray
        
        Write-Host "Waiting for sandboxie removal"
        Start-Sleep -Seconds 10
    }

    Get-ChildItem -Path $env:TMP -Recurse | Where-Object { $_.FullName -match "pmpcs" } | ForEach-Object {
        Remove-Item -Path $_.FullName -Recurse -Force
    }

    Write-Host "Kill Sandboxie Service"
    #sc.exe stop Sandbox
    if (Get-Service Sbiesvc -ErrorAction SilentlyContinue) {
        sc.exe stop Sbiesvc
        Get-Service Sbiesvc | Stop-Service
        #Get-Service Sbiesvc | Remove-Service # PowerShell 6.0
        sc.exe delete Sbiesvc
    }
    if (Get-Service Sandbox -ErrorAction SilentlyContinue) {
        Get-Service Sandbox | Stop-Service
        #Get-Service Sandbox | Remove-Service # PowerShell 6.0
        sc.exe delete Sandbox
    }
    Get-Process Control.exe -ErrorAction SilentlyContinue | Stop-Process -Force
    
    if (Test-Path "$env:TMP\Sandbox") {
        Remove-Item "$env:TMP\Sandbox" -Recurse -Force
    }
    if (Test-Path "$env:SystemRoot\Sandboxie.ini") {
        Remove-Item "$env:SystemRoot\Sandboxie.ini" -Force
    }
}

Write-Host "Removal of existent files and services" -ForegroundColor Cyan
RemoveIfExists -SandboxieInstaller $SandboxieInstaller

function Get-RandomLetters {
    param (
        [int]$Num
    )

    -join ((65..90) + (97..122) | Get-Random -Count $Num | ForEach-Object { [char]$_ })
}

# we have a random folder with custom chars we can search for.
$RunningFolder = "$env:TMP\$(Get-RandomLetters -Num 10)pmpcs$(Get-RandomLetters -Num 10)"

# Sandboxie Settings INI, this time no UTF8
# We need this because we generate the TMP folder.
#Write-Host ".ini" -ForegroundColor DarkGray
@("
[GlobalSettings]

Template=7zipShellEx
Template=WindowsRasMan
Template=WindowsLive
Template=OfficeLicensing
BoxRootFolder=%tmp%

[DefaultBox]

ConfigLevel=7
AutoRecover=y
BlockNetworkFiles=y
Template=qWave
Template=WindowsFontCache
Template=BlockPorts
Template=LingerPrograms
Template=Chrome_Phishing_DirectAccess
Template=Firefox_Phishing_DirectAccess
Template=AutoRecoverIgnore
RecoverFolder=%{374DE290-123F-4565-9164-39C4925E467B}%
RecoverFolder=%Personal%
RecoverFolder=%Favorites%
RecoverFolder=%Desktop%
BorderColor=#00FFFF,ttl
Enabled=n
ClosedKeyPath=\REGISTRY\MACHINE\Computer\HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion

[UserSettings_0D2C022F]

SbieCtrl_UserName=kurth
SbieCtrl_ShowWelcome=n
SbieCtrl_NextUpdateCheck=1551954211
SbieCtrl_UpdateCheckNotify=n
SbieCtrl_AutoApplySettings=y
SbieCtrl_WindowCoords=113,257,1237,551
SbieCtrl_ActiveView=40021
SbieCtrl_EnableLogonStart=n
SbieCtrl_EnableAutoStart=n
SbieCtrl_AddDesktopIcon=y
SbieCtrl_AddQuickLaunchIcon=y
SbieCtrl_AddContextMenu=y
SbieCtrl_AddSendToMenu=y
SbieCtrl_ProcessViewColumnWidths=250,70,300
SbieCtrl_BoxExpandedView=DefaultBox,Restricted

[Restricted]

Enabled=y
ConfigLevel=7
AutoRecover=y
BlockNetworkFiles=y
Template=AutoRecoverIgnore
Template=Firefox_Phishing_DirectAccess
Template=Chrome_Phishing_DirectAccess
Template=LingerPrograms
Template=BlockPorts
Template=WindowsFontCache
Template=qWave
RecoverFolder=%Desktop%
RecoverFolder=%Favorites%
RecoverFolder=%Personal%
RecoverFolder=%{374DE290-123F-4565-9164-39C4925E467B}%
BorderColor=#00FFFF,ttl
ClosedKeyPath=patchmypc.exe,\REGISTRY\MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall
AutoRecoverIgnore=%Desktop%\PatchingApplications\PatchMyPC\PatchMyPCITProCache
OpenFilePath=C:\Users\Kurth\Desktop\PatchingApplications\PatchMyPC\PatchMyPCITProCache
OpenFilePath=$RunningFolder\PatchMyPC\PatchMyPCITProCache"
) | Out-File -FilePath "$PSScriptRoot\Sandboxie\Sandboxie.ini" #-Encoding UTF8

$PMPC_Settings = @("; Options
Chk_Options_AppendComputerNameToLog
;Chk_Options_AutoCloseAppsBeforeUpdate
Chk_Options_AutoStartUpdateOnOpen
;Chk_Options_CreateDesktopShortcuts
;Chk_Options_CreateRestorePoint
;Chk_Options_DisableAutoUpdatingAllApps
;Chk_Options_DisableLogFile
Chk_Options_DisablePatchMyPCSelfUpdater
Chk_Options_DisableSilentInstallOfApps
Chk_Options_DontDeleteAppInstallers
Chk_Options_DownloadOnlyMode
;Chk_Options_EnablePatchMyPCBetas
Chk_Options_EnableVerboseLogging
Chk_Options_Install32BitWhenAvailable
;Chk_Options_MinimizeToTrayWhenClosed
;Chk_Options_MinimizeToTrayWhenMinimized
;Chk_Options_MinimizeWhenPerformingUpdates
;Chk_Options_RestartAfterUpdateProcess
;Chk_Options_ShutdownAfterUpdateProcess

; Plugins and Runtimes
;Chk_ADBLockIE
;Chk_AdobeAir
;Chk_AdobeFlashActiveX
;Chk_AdobeFlashPlugin
;Chk_AdobeShockwave
Chk_Java8x64
Chk_Java8x86
Chk_Java9x64
Chk_NETFramework
Chk_Silverlight

; Browsers
;Chk_Brave
Chk_GoogleChrome
;Chk_Maxthon
Chk_MozillaFirefox
Chk_MozillaFirefoxESR
Chk_Opera
;Chk_PaleMoon
;Chk_Vivaldi
;Chk_Waterfox

;Multimedia
;Chk_AIMP
;Chk_AmazonMusic
Chk_AppleiTunes
;Chk_Audacity
;Chk_Foobar2000
;Chk_GOMPlayer
;Chk_jetAudioBasic
;Chk_Klite
;Chk_MediaInfo
;Chk_MediaMonkey
;Chk_MP3Tag
;Chk_MPC
;Chk_MPCBE
;Chk_MusicBee
;Chk_PotPlayer
;Chk_RealPlayer
;Chk_SMPlayer
;Chk_StereoscopicPlayer
Chk_VLCPlayer
;Chk_WinAMP

; File Archivers
Chk_7Zip
;Chk_Bandizip
;Chk_PeaZip
;Chk_Winrar
;Chk_WinZIP

; Utilities
;Chk_8GadgetPack
;Chk_AdvancedIPScanner
;Chk_AdvancedSystemCare
;Chk_AdvancedUninstallerPRO
;Chk_AngryIPScanner
;Chk_AuslogicsDiskDefrag
;Chk_autohotkey
;Chk_AutoRunOrganizer
;Chk_BleachBit
;Chk_BOINC
;Chk_CamStudio
;Chk_CCleaner
Chk_ClassicShell
;Chk_CopyHandler
;Chk_DoNotSpy10
;Chk_Eraser
;Chk_Everything
;Chk_Fiddler
;Chk_GlaryUtilities
Chk_Greenshot
;Chk_HashTab
;Chk_HostsMan
;Chk_HotspotShield
;Chk_IObitUninstaller
;Chk_IoloSystemMechanic
;Chk_LogitechSetPoint
;Chk_MultiCommander
;Chk_Nmap
;Chk_NVDAScreenReader
Chk_OpenVPN
;Chk_PicPick
;Chk_PrivacyEraser
;Chk_PrivaZer
;Chk_ProcessHacker
;Chk_ProcessLasso
;Chk_ProtonVPN
;Chk_PureSync
;Chk_RDCMan
;Chk_RegistryLife
;Chk_RegOrganizer
;Chk_Revo
;Chk_SABnzbd
;Chk_SFXMaker
;Chk_ShareX
;Chk_SimpleSystemTweaker
;Chk_SmartDefrag
;Chk_SoftOrganizer
;Chk_StartupDelayer
;Chk_SubtitleEdit
;Chk_SUMo
;Chk_SyncBackFree
;Chk_TeraCopy
Chk_TreeSizeFree
;Chk_UltraDefrag
;Chk_UltraSearch
;Chk_Unchecky
Chk_Unlocker
;Chk_WhoCrashed
;Chk_WinaeroTweaker
;Chk_WindowsRepair
;Chk_WinMerge
;Chk_WinUAE
;Chk_WiseCare365
;Chk_WiseDiskCleaner
;Chk_WiseDriverCare
;Chk_WiseFolderHider
;Chk_WiseProgramUninstall
;Chk_WiseRegistryCleaner
;Chk_Zotero

; Hardware Tools
;Chk_CoreTemp
;Chk_CPUZ
;Chk_CrystalDiskInfo
;Chk_CrystalDiskMark
;Chk_DiskCheckup
Chk_DriverBooster
;Chk_DriverEasy
;Chk_HWiNFO32
;Chk_HWiNFO64
;Chk_HWMonitor
;Chk_MSIAfterburner

; Documents
Chk_AdobeReader
;Chk_Calibre
;Chk_ComicRack
;Chk_CutePDFWriter
;Chk_Evernote
;Chk_FoxitReader
;Chk_LibreOffice
;Chk_OpenOffice
Chk_PDFCreator
;Chk_PDFedit
;Chk_PDFSamBasic
;Chk_PDFViewer
;Chk_PDFXChangeEditor
;Chk_PNotes
;Chk_SumatraPDF
;Chk_WPSOffice

; Media Tools
;Chk_Avidemux
;Chk_CDBurnerXP
;Chk_Etcher
;Chk_ExactAudioCopy
;Chk_ForMatFactory
;Chk_FreemakeVideoConverter
;Chk_FreeStudio
;Chk_HandBrake
;Chk_Imgburn
;Chk_Lightworks
;Chk_LMMS
;Chk_MagicISOCHK
;Chk_MKVToolNix
;Chk_MusicBrainzPicard
Chk_OBSStudio
;Chk_OpenShot
;Chk_XMediaRecode
;Chk_XnView
;Chk_XnViewMP

; Messaging
;Chk_DavMail
;Chk_Discord
;Chk_eMClient
;Chk_Gpg4win
;Chk_Mailbird
;Chk_Mumble
;Chk_Pidgin
;Chk_Skype
;Chk_TeamSpeak
;Chk_Telegram
;Chk_Thunderbird
;Chk_Viber
Chk_WhatsApp
;Chk_YahooMessenger

; Developer
;Chk_Atom
;Chk_Brackets
;Chk_CMake
;Chk_Codeblocks
;Chk_CoreFTP
;Chk_EditPadLite
;Chk_FileZilla
;Chk_Freeplane
;Chk_Frhed
;Chk_Git
;Chk_GitHubDesktop
;Chk_JAVAJDK8
;Chk_JAVAJDK8x64
;Chk_JAVAJDK9x64
Chk_NotePad
;chk_NoteTabLight
;Chk_Putty
;Chk_RStudio
;Chk_SanBoxie
;Chk_SpeedCrunch
;Chk_TortoiseSVN
Chk_VisualStudioCode
;Chk_WinDirStat
;Chk_WinSCP
;Chk_Wireshark

; Microsoft Visual C++ Runtimes
Chk_Redist2005x64
Chk_Redist2005x86
Chk_Redist2008x64
Chk_Redist2008x86
Chk_Redist2010x64
Chk_Redist2010x86
Chk_Redist2012x64
Chk_Redist2012x86
Chk_Redist2013x64
Chk_Redist2013x86
Chk_Redist2017x64
Chk_Redist2017x86

; Sharing
;Chk_AnyDesk
;Chk_Ares
;Chk_BitTorrent
;Chk_Dropbox
;Chk_eMule
;Chk_GoogleDrive
Chk_Icloud
;Chk_mRemoteNG
;Chk_Nextcloud
Chk_OneDrive
;Chk_OwnCloud
;Chk_QBTorrent
;Chk_ResilioSync
Chk_TeamViewer
;Chk_Utorrent
;Chk_VirtualBox
;Chk_VMwareHC
;Chk_VNCServer
;Chk_VNCViewer
;Chk_Vuze
;Chk_Windscribe

; Graphics
;Chk_Blender
;Chk_FastStoneImageViewer
;Chk_Gimp
;Chk_ImageGlass
;Chk_Inkscape
;Chk_IrFanView
;Chk_LibreCAD
;Chk_Paint
;Chk_Zoner

; Security

;Chk_360TotalSecurity
;Chk_AvastAntivirus
;Chk_AVG
;Chk_BitdefenderAR
;Chk_Cybereason
;Chk_EMET
;Chk_GlassWire
;Chk_IObitMalwareFighter
;Chk_KasperskyFree
Chk_KeePass
;Chk_Malwarebytes
;Chk_MalwareBytesAntiExploit
;Chk_MSEAntivirus
;Chk_Panda
;Chk_RogueKiller
;Chk_Spybot
;Chk_SUPERAntiSpyware

; Miscellaneous
;Chk_GoogleEarth
;Chk_MyPhoneExplorer
;Chk_SamsungKies
;Chk_SonyPC
;Chk_WorldWideTelescope

; Gaming
;Chk_GOGGalaxy
;Chk_NvidiaPhysX
;Chk_Orgin
;Chk_RazerCortex
;Chk_Steam
;Chk_Uplay

; Portable Apps
;Chk_PortableAdwCleaner
;Chk_PortableAeroAdmin
;Chk_PortableAnyDeskPortable
;Chk_PortableASSSDBenchmark
;Chk_PortableBitdefenderUSB
;Chk_PortableCCleaner
;Chk_PortableChromeCleanup
;Chk_PortableComboFix
;Chk_PortableDDU
;Chk_PortableDefraggler
;Chk_PortableDesktopOK
;Chk_PortableDesktopOKx64
;Chk_PortableDOSBox
;Chk_PortableDShutdown
;Chk_PortableGeekUninstaller
;Chk_PortableGPUZ
;Chk_PortableInSpectre
;Chk_PortableKasperskyTDSSKiller
;Chk_PortableNETFrameworkRepairTool
;Chk_PortableOOShutUp
;Chk_PortableRecuva
;Chk_PortableRKill
;Chk_PortableRogueKillerx64
;Chk_PortableRogueKillerx86
;Chk_PortableRufus
;Chk_PortableSpeccy
;Chk_PortableSpeedyFox
;Chk_PortableSubtitleWorkshop
;Chk_PortableSysinternalsSuite
;Chk_PortableTorBrowser
;Chk_PortableUltimateWindowsTweaker
;Chk_PortableWindowsRepair
;Chk_PortableWindowsUpdateMiniTool
;Chk_PortableWSUSOfflineUpdates
")

Copy-Item -Path "$PSScriptRoot\PatchMyPC" -Destination "$RunningFolder\PatchMyPC" -Recurse -Force

#regedit /s Sanboxie+.reg

Write-Host "'Installing' Sandboxie locally @ '$RunningFolder\sandboxie'"
Copy-Item "$PSScriptRoot\Sandboxie\Sandboxie.ini" "$env:SystemRoot\"
Start-Process -FilePath $SandboxieInstaller.FullName -ArgumentList "/install /S /D=$RunningFolder\sandboxie" -Wait -PassThru
#sc.exe start Sandbox
sc.exe create Sbiesvc binpath=$RunningFolder\sandboxie\SbieDrv.sys type=kernel start=auto error=normal DisplayName=Sbiesvc
sc.exe start Sbiesvc

Write-Host "Running Patcher 32" -ForegroundColor Cyan
$PMPC_Settings | Out-File -FilePath "$RunningFolder\PatchMyPC\PatchMyPC.ini" -Encoding UTF8
$Proc = Start-Process -FilePath "$RunningFolder\sandboxie\Start.exe" -ArgumentList "/silent /wait /box:RESTRICTED `"$RunningFolder\PatchMyPC\PatchMyPC.exe`" /s /auto" -Wait -PassThru -Verbose
Write-Host "Exited with `"$($Proc.ExitCode)`"" -ForegroundColor DarkGray

Write-Host "Running Patcher 64" -ForegroundColor Cyan
$PMPC_Settings -replace "Chk_Options_Install32BitWhenAvailable", ";Chk_Options_Install32BitWhenAvailable" | Out-File -FilePath "$RunningFolder\PatchMyPC\PatchMyPC.ini" -Encoding UTF8
$Proc = Start-Process -FilePath "$RunningFolder\sandboxie\Start.exe" -ArgumentList "/silent /wait /box:RESTRICTED `"$RunningFolder\PatchMyPC\PatchMyPC.exe`" /s /auto" -Wait -PassThru -Verbose
Write-Host "Exited with `"$($Proc.ExitCode)`"" -ForegroundColor DarkGray

Write-Host "Moving Files" -ForegroundColor Cyan
if (Test-Path -Path "$RunningFolder\PatchMyPC\PatchMyPCITProCache") {
    Get-ChildItem -Path "$RunningFolder\PatchMyPC\PatchMyPCITProCache" -Recurse | Where-Object { !$_.PSIsContainer } | ForEach-Object {
        if ($_.FullName -match "x86") {
            $tDestFolder = "C:\_temp\x86"
            if (!(Test-Path -Path $tDestFolder)) {
                $null = New-Item -Path $tDestFolder -ItemType Directory -Force
            }
            Copy-Item -Path $_.FullName -Destination "$tDestFolder\" -Force -Verbose    
        }
        elseif ($_.FullName -match "x64") {
            $tDestFolder = "C:\_temp\x64"
            if (!(Test-Path -Path $tDestFolder)) {
                $null = New-Item -Path $tDestFolder -ItemType Directory -Force
            }
            Copy-Item -Path $_.FullName -Destination "$tDestFolder\" -Force -Verbose   
        }
        else {
            Copy-Item -Path $_.FullName -Destination "C:\_temp" -Force -Verbose
        }
        Remove-Item -Path $_.FullName -Verbose -Force
    }
    #Copy-Item -Path "$RunningFolder\PatchMyPC\PatchMyPCITProCache\*" -Destination "C:\_temp\x86" -Recurse -Force
}
else {
    Write-Host "Path not found: '$RunningFolder\PatchMyPC\PatchMyPCITProCache'"
}

Write-Host "Removal of existent files and services" -ForegroundColor Cyan
RemoveIfExists -SandboxieInstaller $SandboxieInstaller

if (Test-Path -Path $RunningFolder) {
    Remove-Item -Path $RunningFolder -Recurse -Force 
}

Write-Host "Ended: $(Get-Date -Format "dd.MM.yy HH:mm:ss.ffffff")"
Stop-Transcript