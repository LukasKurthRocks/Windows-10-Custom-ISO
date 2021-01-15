##Requires -RunAsAdministrator
##Requires -Version 5.0

# INFO: Expand Archive introduced in PS5.0

param(
	#[ValidateSet("amd64","arm64","x86")]
	#$OSArch = $env:PROCESSOR_ARCHITECTURE,
	#$URIRequestString = "Windows 10 Insider*$OSArch",
	$OnlyLanguageEx = "de-DE|sv-SE|hu-HU|fr-FR|en-US",
	# for example "de-DE"
	$OverrideMainLanguage,
	[switch]$IgnoreFreeSpaceCheck,
	[switch]$SkipDownload,
	# We can skip this on private. FODs like RSAT
	# are only needed in business environments.
	[switch]$SkipFODDownload,
	# If we don't want to remove the UUP Folder.
	# Get's removed anyway if -KeepUUPTemp not selected.
	[switch]$SkipRemoveUUPFolder,
	# UUPConvert will create the ISO for us.
	[switch]$SkipUUPConvert,
	# This is for file movement in general, not only ISO.
	[Alias("SkipEndFileMove")]
	[switch]$SkipISOMove,
	[switch]$KeepUUPTemp
	#$UUPDownloadFolder = "$PSScriptRoot\UUPs"
)

# If needed for older Scripts ($PSScriptRoot is > v3)
#if (!($PSScriptRoot)) {
#	$PSScriptRoot = (Split-Path $MyInvocation.MyCommand.Path)
#}

#region Import Scripts
Write-Verbose "Importing additional functionalities" -Verbose
$IncludeScriptPath = "$PSScriptRoot\include"
Get-ChildItem -Path $IncludeScriptPath -Filter "*.ps1" | ForEach-Object {
	Write-Verbose "+ $($_.Name)" -Verbose
	. $_.FullName
}
$IncludedFunctionNames = @("Test-URI")
$IncludedFunctionNames | ForEach-Object {
	if (!(Get-Command -Name "$_")) {
		Write-Host "Function `"$_`" not found." -ForegroundColor Red
		return
	}
}
#endregion Import Scripts

#region InjectISO
# Due to different setting the user might set,
# this has to be done in a separate PS1.
# But i can handle that.
#endregion InjectISO

#region Move files
if (!$SkipISOMove) {
	Write-Host "[$(_LINE_)] Done with UUP. Moving important files back to folder."

	# creating data folder if not existing
	# robocopy could create this, but we want to have it clean.
	$UUP_DataFolder = "$PSScriptRoot\data"
	if (!(Test-Path -Path $UUP_DataFolder)) {
		$null = New-Item -Path $UUP_DataFolder -ItemType Directory
	}

	# /MIR = /E (Unterverzeichnisse) und /PURGE (L�schen im Ziel)
	RoboCopy $UUP_DUMP_Aria_UUPs_Additional "$UUP_DataFolder\Additional" /MOV /E /R:5 /W:10 /LOG:"$env:TEMP\robcopy_$(Get-Date -Format "yyMMdd-HHmmss.fffffff").log" /TEE

	Get-ChildItem -Path $UUP_DUMP_Aria -Filter "*.ISO" | ForEach-Object {
		$FileName = $_.Name
		Copy-Item -Path $_.FullName -Destination "$UUP_DataFolder\$FileName" -Verbose
		Remove-Item -Path $_.FullName -Verbose
	}

	# Copied from above.
	# Move cab and esd with set "Capability Name".
	# RSAT already moved, so just moving LPs.
	Write-Verbose "$UUP_DUMP_Aria_UUPs\*" -Verbose
	#$CabinetFiles = Get-ChildItem -Path "$UUP_DUMP_Aria_UUPs\*","$UUPDUMP_AriaUUPs_ArchiveFolder\*" -Include @("*.cab","*.esd") 
	$CabinetFiles = Get-ChildItem -Path "$UUP_DUMP_Aria_UUPs\*" -Include @("*.cab", "*.esd") -Recurse
	if ($CabinetFiles) {
		$CabinetFiles | ForEach-Object {
			# Reading the cab info. this might take a while...
			# Capability Identity : Rsat.DHCP.Tools~~~de-DE~0.0.1.0
			$CapabilityString = DISM /Online /Get-PackageInfo /PackagePath:$($_.FullName) /English | Select-String "Capability"
		
			# Split Name 'Capability Identity : Rsat.DHCP.Tools~~~de-DE~0.0.1.0'
			$CapabilityString = & {
				$cTemp = $CapabilityString
				$CSplit = "$cTemp".Split(":").Trim()
				if ($CSplit -and $CSplit.Count -ge 1) {
					$CSplit[1..($CSplit.Count)] -join " "
				}
				else {
					$cTemp
				}
			}

			# in case this messes up while looping we remove the variable.
			# Could also re-set this variable...
			Remove-Variable Destination -Force -Verbose -ErrorAction SilentlyContinue
			if ($CapabilityString -match "Language[.]") {
				$Destination = "$UUP_DataFolder\LPs"
				if (!(Test-Path -Path $Destination)) {
					$null = New-Item -Path $Destination -ItemType Directory
				}
			}

			# only move when capability has been found.
			if ($Destination) {
				Write-Host "[$(_LINE_)] Moving `"$CapabilityString`""
				$FileName = $_.Name
				Copy-Item -Path $_.FullName -Destination "$Destination\$FileName" -Verbose
				#Remove-Item -Path $_.FullName -Verbose
			}
			else {
				Write-Host "[$(_LINE_)]`"$CapabilityString`" not matching ($($_.Name))."
			}
		} # /end Cabinet Loop
	} # /end if cabinet
} # /end skip
#endregion Move files

#region EndRemoveTemp
# Remove the temp folder in the end.
if (!$KeepUUPTemp) {
	try {
		if ((Test-Path -Path $UUP_FolderTemp)) {
			Get-ChildItem -Path $UUP_FolderTemp -Recurse -ErrorAction Stop | ForEach-Object {
				Remove-Item -Path $_.FullName -Recurse -Confirm:$false
			}
			Remove-Item -Path $UUP_FolderTemp -Recurse -Force
		}
	}
 catch {
		Write-Host "[$(_LINE_)] Exception while removing: $($_.Exception.Message)." -ForegroundColor Red
		return
	}
}
#endregion EndRemoveTemp