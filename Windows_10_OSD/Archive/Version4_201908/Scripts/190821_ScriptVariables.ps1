# Declaration of variables I might need.

# Basic PowerShell
# A progress bar can slowdown the process of downloading a file via CURL/IWR.
$ProgressPreference = "SilentlyContinue" # Standard = "Continue"

# Windows main system language.
# Use param to override this!
$OSMainLang = ([CultureInfo]::InstalledUICulture | Select-Object -First 1).Name.ToLower()

# I put this here in case we need this
# Althoug a requirement is to have version 5.0
# Needed this here as $PSScriptRoot is NOT the root of the project (duh')
if (!($PSScriptRoot)) {
	$PSScriptRoot = (Split-Path $MyInvocation.MyCommand.Path)
}
$DUMMY_SubScriptRoot = Split-Path $PSScriptRoot

# Folder for moving created and downloaded files back for user.
$LocalDataFolder = "$DUMMY_SubScriptRoot\Data"
$LocalScriptsFolder = "$DUMMY_SubScriptRoot\Scripts"
$LocalFilesFolder = "$DUMMY_SubScriptRoot\Files"

# ConvertConfig.ini
$LocalConvertConfig = "$LocalFilesFolder\ConvertConfig.ini"

#################################
###           Debug           ###
#################################
#$StartTranscript = $true # How should this work?

#################################
###         UUP Vars          ###
#################################

$UUP_DownloadURI = "https://uupdump.ml"
$UUP_DownloadRequestURI = "$UUP_DownloadURI/known.php?q="

# Temporary working folder.
# Make sure to add attribute "hidden".
$UUP_WorkingFolder = "$env:SystemDrive\`$ROCKS.UUP"

## ARIA DOWNLOADER ##
$UUP_AriaBaseDir = "$UUP_WorkingFolder\aria"
$UUP_AriaBinaryDir = "$UUP_AriaBaseDir\bin"
$UUP_AriaFiles = "$UUP_AriaBaseDir\files"
$UUP_7zExec = "$UUP_AriaFiles\7zr.exe"
$UUP_AriaUUPs = "$UUP_AriaBaseDir\UUPs"
$UUP_AriaAdditionalFODs = "$UUP_AriaUUPs\Additional" # RSAT, FODs, etc...

## ConvertConfig.ini
$UUP_ConvertConfig = "$UUP_AriaBaseDir\ConvertConfig.ini"
$UUP_ConvertConfBatch = "$UUP_AriaBaseDir\convert-UUP*.cmd"

## Logs for DISM and others
$UUP_LoggingPath = "$UUP_WorkingFolder\logs"

# might be removed!
# was for the movement of the core language files
# I am not downloading them anymore, so why bother?
$UUP_AriaArchivedFeatures = "$UUP_AriaUUPs\00._Archive" # For core/prof of langs

# Folder for extracting aria temporary
# Using this for multiple aria versions (with UUP).
$UUP_TempFolder = "$UUP_WorkingFolder\temp"

# Different MountPaths
$UUP_ISOMountPath = "$UUP_WorkingFolder\ROCKS.ISOFOLDER"
$UUP_IMGMountPath = "$UUP_WorkingFolder\ROCKS.IMGFOLDER"

#################################
###       /end UUP Vars       ###
#################################

#################################
###         WIM Vars          ###
#################################

# It is shorter to EXPORT to own wim files, than adding and removing iniezies with edition names.
$WIM_OriginalSearchFolder = $UUP_AriaBaseDir # ISO or Folder have to be in here
$WIM_OriginalFileName = "install.wim" # When copied from the ISO or path.
$WIM_ExportedFileName = "ROCKING.wim" # For our own, get's overidden anyway.
$WIM_OriginalFilePath = "$UUP_TempFolder\$WIM_OriginalFileName"
$WIM_ExportedFilePath = "$UUP_TempFolder\$WIM_ExportedFileName"
$WIM_ExtractISO = $false # We can have an ISO, or an extracted folder (or the aria script skipped ISO creation).
#$WIM_CreateISOExec = "<CREATEISO>" # When we create the ISO (TODO: See ClickMe.ps1)

# Could also be declared in WIM script
$WIM_InstallationCount = 0
$WIM_LoopEditionCounter = 0

#################################
###       /end WIM Vars       ###
#################################

#################################
###       Customization       ###
#################################

# Folders
$CUSTOM_AllFolder = "$DUMMY_SubScriptRoot\Customizations"
$CUSTOM_ImportFolder = "$CUSTOM_AllFolder\01._ImageImport"
$CUSTOM_CustomizeFolder = "$CUSTOM_AllFolder\02._Customizations"

# Files
$CUSTOM_SettingFile = "$CUSTOM_CustomizeFolder\Settings.ini"
$CUSTOM_RegistryFile = "$CUSTOM_CustomizeFolder\RegistrySettings.csv"
$CUSTOM_RemoveAppsFile = "$CUSTOM_CustomizeFolder\RemoveApps.txt"

# Loading in step 3
$CUSTOM_Settings = @{}
$CUSTOM_RegistryValues = @{}
$CUSTOM_AppRemoveList = @{}

$CUSTOM_RegistryDefaultUserTEMP = "OFDEFUSR"
$CUSTOM_RegistryDefaultSystemTEMP = "OFDEFUSR"
$CUSTOM_RegistrySoftwareTEMP = "OFFLINE"
#$CUSTOM_RegistryDriversTEMP       = "OFFLINE"
#$CUSTOM_RegistrySamTEMP           = "OFFLINE"
$CUSTOM_RegistrySystemTEMP = "OFFLINE"

#################################
###       /end Customs        ###
#################################

# See script functions for this.
$DISMSuccessRateLogFile = "$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_successrate.log"

# Windows Server, 7 & 8: https://docs.microsoft.com/en-us/windows-server/get-started/kmsclientkeys
if (Test-Path -Path "$LocalFilesFolder\WindowsGenericKeys.csv") {
	$WindowsKeyInformation = Import-Csv -Path "$LocalFilesFolder\WindowsGenericKeys.csv" -Delimiter ";" -Encoding UTF8
}

# Load all stored languages.
# If one is missing you can add it yourself or contact me.
if (Test-Path -Path "$LocalFilesFolder\ISOLanguageList.csv") {
	$ISOLanguages = Import-Csv -Path "$LocalFilesFolder\ISOLanguageList.csv" -Delimiter ";" -Encoding UTF8
}

# stored dism informations
if (Test-Path -Path "$UUP_AriaAdditionalFODs\DISM_Information.csv") {
	$CapabilityInformations = Import-Csv -Path "$UUP_AriaAdditionalFODs\DISM_Information.csv" -Delimiter ";" -Encoding UTF8
}