#Requires -RunAsAdministrator
#Requires -Version 5.0

<#
Sooooooooooooooooo, here we go...
We want to call this script multiple times.

We created the first ISO "folder" from a windows 10 version in the first script.
So we can copy the WIM and modify this file for the Windows-Compilation-ISO we need.

First these things from the Readme.md:

- Business ISO
-> Enterprise (Updates Only)
-> Enterprise with RSAT (Admins Only) => Implementing RSAT in SCCM
-> Enterprise with all LanguagePacks we COULD need => Implementing LPs in SCCM like the ones for office16.
	EITHER only for Sticks
	OR in SCCM, so we have all LPs an every machine!

- Private ISO
-> Home, Pro, Enterprise and Education
-> Office and Windows Activation

- ALL
-> UUP Update files
-> Customization

Thought about how i would like to add stuff.
I guess i need to install and remove the index first.

INFO: There are these edition specific esd files:
Q: How can we possibly implement those?
A: I do not know. Will not integrate those anyway.
- microsoft-windows-editionspecific-core-package.esd
- microsoft-windows-editionspecific-coren-package.esd
- microsoft-windows-editionspecific-professional-package.esd
- microsoft-windows-editionspecific-professional-wow64-package.esd
- microsoft-windows-editionspecific-professionaln-package.esd
- microsoft-windows-editionspecific-cloude-package.esd
- microsoft-windows-editionspecific-clouden-package.esd
- microsoft-windows-editionspecific-corecountryspecific-package.esd
- microsoft-windows-editionspecific-enterpriseeval-package.esd
- microsoft-windows-editionspecific-enterpriseg-package.esd
- microsoft-windows-editionspecific-enterprisegn-package.esd
- microsoft-windows-editionspecific-enterpriseneval-package.esd


# TODO:
List important variables from ScriptVariables.ps1
#>

param(
	# Windows Editions - 17 Possible to install
	[Parameter(Mandatory = $true)]
	[ValidateSet(
		"Core",
		"CoreN",
		"CoreSingleLanguage",
		"Professional",
		"ProfessionalN",
		"ProfessionalSingleLanguage",
		"ProfessionalCountrySpecific",
		"ProfessionalEducation",
		"ProfessionalEducationN",
		"ProfessionalWorkstation",
		"ProfessionalWorkstationN",
		"Education",
		"EducationN",
		"Enterprise",
		"EnterpriseN",
		"IoTEnterprise",
		"ServerRdsh"
		<# <OTHER VERSIONS>
		# S-version can not be installed, s-mode can be activated in reg
		# via "WindowsLockdownTrialMode". Looks like KIOSK mode.
		#"WINDOWS_S" # There is no S version? Only s-mode since 1803?
		#"Starter",
		#"StarterN",
		#"CoreCountrySpecific",
		#"CoreConnected",
		#"CoreConnectedN",
		#"CoreConnectedCountrySpecific",
		#"CoreConnectedSingleLanguage",
		#"CoreARM",
		#"ProfessionalStudent",
		#"ProfessionalStudentN",
		#"ProfessionalS",
		#"ProfessionalSN",
		#"ProfessionalWMC",
		#"EnterpriseS",
		#"EnterpriseSN",
		#"EnterpriseG",
		#"EnterpriseGN", # Chinese Government Edition
		#"EnterpriseEval",
		#"EnterpriseNEval",
		#"EnterpriseSEval",
		#"EnterpriseSNEval",
		#"EnterpriseSubscription",
		#"EnterpriseSubscriptionN",
		#"IoTEnterpriseS",
		#"ServerRdshCore",
		#"Cloud",
		#"CloudE",
		#"CloudEN",
		#"Andromeda", # Mobile OS
		#"OneCoreUpdateOS",
		#"IoTUAP",
		#"Holographic", # VR System
		#"PPIPro",
		#"Embedded",
		#"EmbeddedAutomotive",
		#"EmbeddedE",
		#"EmbeddedIndustry",
		#"EmbeddedIndustryA",
		#"EmbeddedIndustryE",
		#"EmbeddedEval",
		#"EmbeddedEEval",
		#"EmbeddedIndustryEval",
		#"EmbeddedIndustryEEval",
		#"MobileCore"
		#>
	)]
	$WindowsEditions,
	# TODO: Using this for our own install.wim files.
	# So i can have admin WIM (RSAT), business WIM, LP WIM and personal WIM files.
	$CustomWIMFileName,
	$WIMDescriptionSuffix,
	[switch]$OverrideLocalCopy,
	[switch]$DoNotRemoveLocalCopy,
	
	# TODO: Use this, as we might wan't to add another version to it!?
	#[switch]$AppendExisting
	# Using this, so we can add multiple versions of an edition
	[switch]$NoUniqueEditions
)

# I put this here in case we need this
# Althoug a requirement is to have version 5.0
#if (!($PSScriptRoot)) {
#	$PSScriptRoot = (Split-Path $MyInvocation.MyCommand.Path)
#}

Start-Transcript -Path "$env:TEMP\w10iso_edcreator_$(Get-Date -Format "yyMMdd-HHmmss.fffffff").txt"

$StartTime = Get-Date
Write-Host "STEP2: Started at $(Get-Date -Format "dd.MM.yy HH:mm:ss")"

#region Import Scripts
Write-Verbose "Importing additional functionalities" -Verbose
$ScriptImportFolder = "$PSScriptRoot\Scripts"
Get-ChildItem -Path $ScriptImportFolder -Filter "*.ps1" | ForEach-Object {
	Write-Verbose "+ $($_.Name)" -Verbose
	. $_.FullName
}
$IncludedFunctionNames = @("Clear-MountPath")
$IncludedFunctionNames | ForEach-Object {
	if (!(Get-Command -Name "$_")) {
		Write-Host "Function `"$_`" not found." -ForegroundColor Red
		return
	}
}
#endregion Import Script

Write-Host "[$(_LINE_)] Gathering informations first."

#region Test for folders and stuff
if (!(Test-Path -Path $UUP_IMGMountPath -ErrorAction SilentlyContinue)) {
	$null = New-Item -ItemType Directory -Path $UUP_IMGMountPath -Verbose
}
if (!(Test-Path -Path $UUP_ISOMountPath -ErrorAction SilentlyContinue)) {
	$null = New-Item -ItemType Directory -Path $UUP_ISOMountPath -Verbose
}
if (!(Test-Path -Path $UUP_LoggingPath -ErrorAction SilentlyContinue)) {
	$null = New-Item -ItemType Directory -Path $UUP_LoggingPath -Verbose
}
# Does not need to be ROCKING.wim.
if ($CustomWIMFileName) {
	$WIM_ExportedFileName = $CustomWIMFileName
	$WIM_ExportedFilePath = "$UUP_TempFolder\$WIM_ExportedFileName"
}
#endregion

# Comparing if these versions already installed.
if (Test-Path -Path $WIM_ExportedFilePath) {
	$Difference = Compare-Object -ReferenceObject $WindowsEditions -DifferenceObject (Get-WIMInfo -SourceWIM $WIM_ExportedFilePath).Edition -PassThru

	$DifferenceOLD = $Difference | Where-Object { $_.SideIndicator -contains "=>" }
	$DifferenceNEW = $Difference | Where-Object { $_.SideIndicator -contains "<=" }

	if ($DifferenceNEW) {
		Write-Host "[$(_LINE_)] There are versions to extract: $($DifferenceNEW -join ",")." -ForegroundColor Yellow
	}
	if ($DifferenceOLD) {
		Write-Host "[$(_LINE_)] More versions that needed on the image: $($DifferenceOLD -join ",")." -ForegroundColor Red
		
		# This script is base on the export function
		# Need ro re-do this script if this happens.
		if ($CustomWIMFileName) {
			$WIM_ExportedFileName = $CustomWIMFileName
			$WIM_ExportedFilePath = "$UUP_TempFolder\$WIM_ExportedFileName"
		}
		$null = Remove-Item -Path $WIM_ExportedFilePath -Verbose
	}
	if (!$Difference) {
		Write-Host "[$(_LINE_)] All needed versions seem to be present. Nothing to add." -ForegroundColor DarkGray

		# The WIM with changed indizies might still exist.
		if (Test-Path -Path $WIM_OriginalFilePath) {
			$null = Remove-Item -Path $WIM_OriginalFilePath -Verbose
		}

		ScriptCleanUP -StopTranscript
		return
	}
}

#region WIM or ISO
# Search for latest install.wim or *.ISO.
$LatestWindowsImageFile = Get-ChildItem -Path $UUP_AriaBaseDir -Recurse -ErrorAction SilentlyContinue | Where-Object { !$PSIsContainer -and $_.Name -match "install[.]wim|[.]ISO" } | Sort-Object -Property LastWriteTime -Descending | Select-Object -First 1
$LatestWindowsImageName = $LatestWindowsImageFile.Name
$LatestWindowsImageFullName = $LatestWindowsImageFile.FullName
$LatestWindowsImagePath = Split-Path $LatestWindowsImageFullName
if ([System.IO.Path]::GetExtension($LatestWindowsImageName) -eq ".ISO") {
 # $UUP_IMGMountPath, $UUP_ISOMountPath
	Write-Verbose "[$(_LINE_)] NOT YET IMPLEMENTED: 'Mounting ISO and working with install.wim'." -Verbose
	return
	#$ISO = Mount-DiskImage -ImagePath $LatestWindowsImageFullName -PassThru -ErrorAction Ignore -Verbose -StorageType ISO #-NoDriveLetter
	#Get-Volume -DiskImage $ISO
	#$LatestWindowsImageFile = Get-ChildItem -Path $x -Recurse -ErrorAction SilentlyContinue | Where-Object { !$PSIsContainer -and $_.Name -match "install[.]wim" }
	#$LatestWindowsImageName     = $LatestWindowsImageFile.Name
	#$LatestWindowsImageFullName = $LatestWindowsImageFile.FullName
	#Dismount-DiskImage -ImagePath "C:\FILE.ISO"
}
else {
	$null = Remove-Item -Path $UUP_ISOMountPath -Verbose
}

if (!$LatestWindowsImagePath) {
	Write-Host "[$(_LINE_)] And now we do not have the extracted ISO folder. Please take a look if SkipISO has been selected (you know, the *.ini)." -ForegroundColor Red
	Stop-Transcript
	return
}
#endregion WIM or ISO

#region local WIM copy
# Copying this somewhere, so we can build our own install.wim files.
if ($OverrideLocalCopy -or !(Test-Path -Path $WIM_OriginalFilePath)) {
	Write-Verbose "[$(_LINE_)] Creating copy of '$WIM_OriginalFileName'." -Verbose
	$null = Copy-Item -Path $LatestWindowsImageFullName -Destination $WIM_OriginalFilePath -Verbose
}
#endregion local WIM copy

#region info from WIM
# Reading the informations from the WIM file.
$LatestWindowsImage_WIMInfo = Get-WIMInfo -SourceWIM $WIM_OriginalFilePath
$LatestWindowsImage_WIMEditions = $LatestWindowsImage_WIMInfo.Edition
if (Test-Path -Path $WIM_ExportedFilePath -ErrorAction SilentlyContinue) {
	$ExportedWindowsImage_WIMInfo = Get-WIMInfo -SourceWIM $WIM_ExportedFilePath
	$ExportedWindowsImage_WIMEditions = $ExportedWindowsImage_WIMInfo.Edition
}

# Printing this info
Write-Host "[$(_LINE_)] Indizies on the image '$WIM_OriginalFilePath':"
$LatestWindowsImage_WIMInfo | Format-Table -AutoSize
if (Test-Path -Path $WIM_ExportedFilePath -ErrorAction SilentlyContinue) {
	Write-Host "[$(_LINE_)] Indizies on the image '$WIM_ExportedFilePath':"
	$ExportedWindowsImage_WIMInfo | Format-Table -AutoSize
}

# Core only exists once
if ( ($LatestWindowsImage_WIMEditions -notcontains "Core") -and ($WindowsEditions -contains "Core") ) {
	Write-Verbose "[$(_LINE_)] TIPP: This script changes the editions. The original install.wim might be corrupted if run mutliple times without removing. Use -OverrideLocalCopy for overwriting file." -Verbose
	Write-Host "[$(_LINE_)] We can not add Core-versions ($($WindowsEditions -join ", ")) when Core|CoreN have been removed from the image." -BackgroundColor Black -ForegroundColor Red
	return
}
#endregion info from WIM

$WindowsEditions_Install = $WindowsEditions | Select-Object -Unique:$(!$NoUniqueEditions)
foreach ($Edition in $WindowsEditions_Install) {
	$WIM_LoopEditionCounter++

	Write-Host "[$(_LINE_)] ################################"
	Write-Host "[$(_LINE_)] [$WIM_LoopEditionCounter/$($WindowsEditions_Install.Count)] Processing $Edition"
	Write-Host "[$(_LINE_)] ################################"
	
	# NOTE: Wanted to check for Core/CoreN version here, but thats crap.
	# Just catching the error in the error codes / tcf blocks.
	
	# Small problem: How do i check for the version needed to mount?
	# N needs N version
	
	# Is selected version like "CoreN" or "EnterpriseN"?
	# Might change in future releases, who knows.
	# Versions on STANDARD image are ALWAYS: Core|CoreN|Pro|ProN
	# Why should the possibly change this?
	#$EditionLastCharacter = $Edition[$Edition.Length - 1] # N
	if ($Edition[$Edition.Length - 1] -ceq "N") {
		# Is there a N-version on the image?
		if ($EditionBasedImageInfo = $LatestWindowsImage_WIMInfo | Where-Object { $_.Edition[$_.Edition.Length - 1] -ceq "N" }) {
			$MountingIndexInfo = $EditionBasedImageInfo | Select-Object -First 1
			$MountingIndexNumber = $MountingIndexInfo.Index
			$MountingIndexArch = $MountingIndexInfo.Architecture
			$MountingIndexEdition = $MountingIndexInfo.Edition
			$MountingIndexName = $MountingIndexInfo.Name
		}
		else {
			Write-Host "[$(_LINE_)] There is no N-version on the image (Editions: $($LatestWindowsImage_WIMEditions -join ", "))." -BackgroundColor Black -ForegroundColor Red
			continue
		}
	}
 else {
		# Is there a NON N-version on the image?
		if ($EditionBasedImageInfo = $LatestWindowsImage_WIMInfo | Where-Object { $_.Edition[$_.Edition.Length - 1] -cne "N" }) {
			$MountingIndexInfo = $EditionBasedImageInfo | Select-Object -First 1
			$MountingIndexNumber = $MountingIndexInfo.Index
			$MountingIndexArch = $MountingIndexInfo.Architecture
			$MountingIndexEdition = $MountingIndexInfo.Edition
			$MountingIndexName = $MountingIndexInfo.Name
		}
		else {
			Write-Host "[$(_LINE_)] There is only N-version on the image (Editions: $($LatestWindowsImage_WIMEditions -join ", "))." -BackgroundColor Black -ForegroundColor Red
			continue
		}
	} # /end check for N versions (why MS?)
	
	# New Image already has 'Edition'!?
	# Maybe i should add a -Force option, in case we WANT to have multiple versions.
	if (Test-Path -Path $WIM_ExportedFilePath -ErrorAction SilentlyContinue) {
		if ( (Get-WIMInfo -SourceWIM $WIM_ExportedFilePath).Edition -contains $Edition ) {
			$WIM_InstallationCount++
			Write-Verbose "[$(_LINE_)] '$WIM_ExportedFilePath' already containing '$Edition'." -Verbose
			#continue

			# only next if unique did not get skipped.
			if (!$NoUniqueEditions) {
				continue
			}
		}
	}

	# Starting with our 'create editions' crap ;-)
	if (!$WIM_ExportedFilePath -or ($ExportedWindowsImage_WIMEditions -notcontains $Edition)) {
		# Using this for testing.
		#Write-Host "Edition: $((Get-WindowsEdition -Path $UUP_IMGMountPath).Edition)" -BackgroundColor Black -ForegroundColor Cyan

		# Mount index
		Write-Verbose "[$(_LINE_)] Mounting '$WIM_OriginalFilePath' to '$UUP_IMGMountPath'." -Verbose
		DISM /Mount-Wim /WimFile:$WIM_OriginalFilePath /Index:$MountingIndexNumber /MountDir:$UUP_IMGMountPath /Quiet /NoRestart /English /LogPath:$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_mount_os.log
		DismLog -ExitCode $LASTEXITCODE -Operation "Mount: $LatestWindowsImageFullName`:$MountingIndexNumber | $UUP_IMGMountPath" -Line $(_LINE_)

		# Problem with error on mounting needs to be fixed.
		# Unmounting in same progress.
		if ($LASTEXITCODE -ne 0) {
			Write-Host "[$(_LINE_)] LASTEXITCODE: $LASTEXITCODE (0x$([System.Convert]::ToString($LASTEXITCODE, 16))). Please fix errors and re-start. Unmounting Image." -BackgroundColor Black -ForegroundColor Red
			ScriptCleanUP -MountPath $UUP_IMGMountPath -ClearAllMountedFolders -ClearRegistryHives
			DISM /UnMount-Wim /MountDir:$UUP_IMGMountPath /Discard /English /LogPath:$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_unmount_os.log
			DismLog -ExitCode $LASTEXITCODE -Operation "Unmount: $WIM_OriginalFilePath`:$MountingIndexNumber | $UUP_IMGMountPath" -Line $(_LINE_)
			return
		}

		# get product key and names from edition
		$Edition_KeyInformationData = $WindowsKeyInformation | Where-Object { $_.Edition -eq $Edition }
		$Edition_Key = $Edition_KeyInformationData.GenKey
		$Edition_Name = $Edition_KeyInformationData.Name

		# What do I append if no unique editions have been selected?
		# Maybe I just add noting for now. Same names should not be a problem.
		if (!$NoUniqueEditions) {
			$Edition_Name += ""
		}
		if ($WIMDescriptionSuffix) {
			$WIMDescriptionSuffix += " "
		}

		# Architecture Name
		$Edition_NewName = "$Edition_Name $WIMDescriptionSuffix($MountingIndexArch)"

		# Might use this, but with the "Set-Edition" we can also "rename" the index.
		# More useful that thought ;-)
		#if((Get-WindowsEdition -Path $UUP_IMGMountPath).Edition -ne $Edition) {}

		Write-Verbose "[$(_LINE_)] Installed Edition: $( (Get-WindowsEdition -Path $UUP_IMGMountPath).Edition ) | Possible Editions (on target): $( (Get-WindowsEdition -Path $UUP_IMGMountPath -Target).Edition -join ", " )" -Verbose
		Write-Host "[$(_LINE_)] Changing Windows Edition from '$MountingIndexName' ($MountingIndexEdition) to '$Edition_NewName' ($Edition) with key '$Edition_Key'."
		DISM /Image:$UUP_IMGMountPath /Set-Edition:$Edition /ProductKey:$Edition_Key /AcceptEULA /Quiet /NoRestart /LogPath:$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_edition.log
		DismLog -ExitCode $LASTEXITCODE -Operation "Edition and Key: $WIM_ExportedFileName`:$MountingIndexNumber | $UUP_IMGMountPath | $Edition | $Edition_Key" -Line $(_LINE_)
		
		# Problem with error on set-edition needs to be fixed.
		# Unmounting in same progress.
		if ($LASTEXITCODE -ne 0) {
			Write-Host "[$(_LINE_)] LASTEXITCODE: $LASTEXITCODE (0x$([System.Convert]::ToString($LASTEXITCODE, 16))). Please fix errors and re-start. Unmounting Image." -BackgroundColor Black -ForegroundColor Red
			DISM /UnMount-Wim /MountDir:$UUP_IMGMountPath /Discard /English /LogPath:$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_unmount_os.log
			DismLog -ExitCode $LASTEXITCODE -Operation "Unmount: $WIM_OriginalFilePath`:$MountingIndexNumber | $UUP_IMGMountPath" -Line $(_LINE_)
			return
		}

		# DISM needs to commit the edition change
		Write-Verbose "[$(_LINE_)] Commit change on '$Edition'." -Verbose
		Dism /Commit-Image /MountDir:$UUP_IMGMountPath /English /Quiet /NoRestart /LogPath:$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_commit.log
		DismLog -ExitCode $LASTEXITCODE -Operation "Commit: $LatestWindowsImageFullName`:$MountingIndexNumber | $UUP_IMGMountPath" -Line $(_LINE_)

		Write-Host "[$(_LINE_)] Exporting to '$WIM_ExportedFileName'."

		# Exporting our save image to another wim file
		Write-Verbose "[$(_LINE_)] Saving in '$WIM_ExportedFileName'." -Verbose
		Dism /Export-Image /SourceImageFile:$WIM_OriginalFilePath /SourceIndex:$MountingIndexNumber /DestinationImageFile:$WIM_ExportedFilePath /DestinationName:"$Edition_NewName" /Compress:max /Bootable /CheckIntegrity /NoRestart /Quiet /English /LogPath:$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_export_os.log
		DismLog -ExitCode $LASTEXITCODE -Operation "Export: $WIM_OriginalFileName`:$MountingIndexNumber | $UUP_IMGMountPath" -Line $(_LINE_)
		# Description is still wrong.
		# Sue this instead: imagex /info img_file [img_number or img_name] [new_name/edition] [new_desc]
		$ImageX = (Get-ChildItem -Path $UUP_AriaBinaryDir -Filter "*imagex.exe" | Select-Object -First 1).FullName
		"$ImageX /info `"$WIM_ExportedFilePath`" `"$Edition_NewName`" `"$Edition_NewName`" `"$Edition_NewName`" (IMAGEX [FLAGS] /INFO img_file [img_number | img_name] [new_name] [new_desc])"
		#Start-Process -FilePath $ImageX -ArgumentList "/info $WIM_ExportedFilePath"
		Start-Process -FilePath $ImageX -ArgumentList "/info $WIM_ExportedFilePath `"$Edition_NewName`" `"$Edition_NewName`" `"$Edition_NewName`"" -Wait -NoNewWindow -Verbose

		# Removing the install.wim mount.
		Write-Verbose "[$(_LINE_)] Unmounting '$UUP_IMGMountPath'." -Verbose
		DISM /UnMount-Wim /MountDir:$UUP_IMGMountPath /Discard /Quiet /NoRestart /English /LogPath:$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_unmount_os.log
		DismLog -ExitCode $LASTEXITCODE -Operation "Unmount: $WIM_OriginalFilePath`:$MountingIndexNumber | $UUP_IMGMountPath" -Line $(_LINE_)
		
		# Check for multiple ExitCodes
		if ($LASTEXITCODE -eq 0) {
			$WIM_InstallationCount++
			Write-Host "[$(_LINE_)] LASTEXITCODE: $LASTEXITCODE (0x$([System.Convert]::ToString($LASTEXITCODE, 16)))" -ForegroundColor DarkGray
		}
		else {
			Write-Host "[$(_LINE_)] LASTEXITCODE: $LASTEXITCODE (0x$([System.Convert]::ToString($LASTEXITCODE, 16)))" -BackgroundColor Black -ForegroundColor Red
		}
	}
 else {
		$WIM_InstallationCount++
		Write-Host "[$(_LINE_)] [$WIM_InstallationCount/$($WindowsEditions_Install.Count)] '$Edition' exists on image." -ForegroundColor DarkGray
	} # /end if edition already there
} # /end "installing" loop

# Check if all editions have been installed.
# This is just a number check ;-)
if ($WIM_InstallationCount -eq $WindowsEditions_Install.Count) {
	Write-Verbose "[$(_LINE_)] Looks like all editions have been installed/exported." -Verbose
}
else {
	Write-Host "[$(_LINE_)] Installation of editions had some errors. We are not removing the other ones. Please fix this first." -BackgroundColor Black -ForegroundColor Red
	return
}

#region remove local WIM copy
# Switch, so we can mess around with it.
if (!$DoNotRemoveLocalCopy) {
	# This .wim has changed index:1 and index:2.
	# Can not be used for something else...
	$null = Remove-Item -Path $WIM_OriginalFilePath -Verbose
}
#endregion remove local WIM copy

$EndTime = Get-Date
Write-Host "STEP2: Ended at $(Get-Date -Format "dd.MM.yy HH:mm:ss")"

$TimeSpan = (New-TimeSpan -Start $StartTime -End $EndTime) -join ";"
Write-Host "STEP2: Duration: $TimeSpan"

ScriptCleanUP -StopTranscript