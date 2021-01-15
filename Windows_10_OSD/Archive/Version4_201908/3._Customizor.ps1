##Requires -RunAsAdministrator
##Requires -Version 5.0

<#
I decieded to make it the "clean" way, not the chaotic one i usually take.
So i will customize the Windows 10 editions in this part of the script.

Steps:
- Patch the loaded index
- inject LP if needed
- inject other needed features
- unmount everything!

TODO: Copy LPs in sxs?
TODO: Copy tools into ISO folder!
#>
[CmdLetBinding()] # Adding -Verbose as an "option"
param(
	$CustomWIMFileName,
	#$Languages = "en-us",
	#$Languages,
	# TEST ON MUI SYSTEM: Can we selectd default if more than one installed?
	$Languages = ([CultureInfo]::InstalledUICulture | Select-Object -First 1).Name.ToLower(),
	#$FODs = "RSAT",
	$FODs,
	# Enable Optional Features
	$EnabledOptionalFeatures = @(
		"NetFx3" # This can always be removed. NetFX needs source files though...
		"Microsoft-Hyper-V-All"
		"TelnetClient"
		"Containers-DisposableClientVM" # Windows-Sandbox
		#"NTVDM"
	),
	$DisableOptionalFeatures = @(
		# WannaCry and other RansomWare could use SMBv1 for their needs.
		# EVERYONE should get rid of this!
		"SMB1Protocol"
		# I would like to remove the Internet Explorer, but I guess I will
		# have to keep it for things like "Invoke-WebRequest"
		#"Internet-Explorer-Optional-amd64" # Internet-Explorer-Optional*
	),
	[switch]$SkipUpdates,
	[switch]$SkipFeatures, # Features and LPs included
	[switch]$SkipFODs,
	[switch]$SkipLPs,
	[switch]$SkipCustomization,
	# CUSTOMIZATION VARIABLES
	[switch]$SkipCustom_AppXRemoval,
	# Like TelnetClient (see above)
	[switch]$SkipCustom_AddFeatures,
	# Like SMBv1 (see above)
	[switch]$SkipCustom_RemoveFeatures,
	[switch]$SkipCustom_StartLayout,
	[switch]$SkipIncludingAdditionalFiles
)

# I put this here in case I need this
# Althoug a requirement is to have version 5.0
#if (!($PSScriptRoot)) {
#	$PSScriptRoot = (Split-Path $MyInvocation.MyCommand.Path)
#}

Start-Transcript -Path "$env:TEMP\w10iso_customizor_$(Get-Date -Format "yyMMdd-HHmmss.fffffff").txt"

# Logging the time the script started.
# In the end I will compare the starttime with the endtime.
$StartTime = Get-Date
Write-Host "STEP3: Started at $(Get-Date -Format "dd.MM.yy HH:mm:ss")"


#region Import Scripts
# ########################################## #
#               IMPORT REGION
# ########################################## #

# =========================================
#         Functions and Variables
# =========================================
Write-Verbose "Importing additional functionalities"
$ScriptImportFolder = "$PSScriptRoot\Scripts"
Get-ChildItem -Path $ScriptImportFolder -Filter "*.ps1" | ForEach-Object {
	Write-Verbose "+ $($_.Name)"
	. $_.FullName
}
$IncludedFunctionNames = @("Clear-MountPath")
$IncludedFunctionNames | ForEach-Object {
	if (!(Get-Command -Name "$_")) {
		Write-Host "Function `"$_`" not found." -ForegroundColor Red
		return
	}
}


# =========================================
#           DISM Functionality
# =========================================
# If I have 1000 lines I do not want to display [0] and [1000].
#$SCRIPT_LinesTotalString = "" + ($MyInvocation.MyCommand.ScriptBlock | Measure-Object -Line).Lines


# =========================================
#           Additional FOD Files
# =========================================
$FeatureFiles = Get-ChildItem -Path $UUP_AriaAdditionalFODs -Recurse

# $CapabilityInformations is preloaded in "ScriptFunctions;
# But in most cases this might not be filled with data.
if (!(Test-Path -Path "$UUP_AriaAdditionalFODs\DISM_Information.csv") -or !$CapabilityInformations) {
	Write-Host "[$(_LINE_)] Gathering cabinet informations of $($FeatureFiles.Count) files (Started: $(Get-Date -Format "HH:mm:ss"))."
	$CapabilityInformations = @()
	$FeatureFiles | ForEach-Object {
		$CapabilityInformation = [PSCustomObject]@{}
		#Write-Host "." -NoNewline # "Progress"
		$CapabilityPath = $_.FullName
		#Write-Host "> $CapabilityPath" -ForegroundColor Magenta
		
		$CapabilityString = DISM /Online /Get-PackageInfo /PackagePath:$CapabilityPath /English | Select-String "Capability"
		if ($CapabilityString) {
			$CapabilityName = "$CapabilityString".Split(":")[1].Trim()

			#Write-Host "> $CapabilityName" -ForegroundColor Cyan
			$CapabilityInformation | Add-Member -MemberType NoteProperty -Name "CapabilityName" -Value $CapabilityName -Verbose:$VerbosePreference
			$CapabilityInformation | Add-Member -MemberType NoteProperty -Name "FullName" -Value $CapabilityPath -Verbose:$VerbosePreference
			$CapabilityInformation | Add-Member -MemberType NoteProperty -Name "AlternativeFullName" -Value $null -Verbose:$VerbosePreference
			$CapabilityInformations += $CapabilityInformation
		}
	}

	$CapabilityInformations | Export-Csv -Path "$UUP_AriaAdditionalFODs\DISM_Information.csv" -Delimiter ";" -Encoding UTF8 -NoTypeInformation
	Write-Host "[$(_LINE_)] Finished gathering of informations (Finished: $(Get-Date -Format "HH:mm:ss"))."
}

# =========================================
#   Settings.ini; RegistrySettings.csv & RemoveApps.txt
# =========================================

# Different settings like 'disabling' OneDrive.
# For more informations see ScriptVariables.ps1
if (!$CUSTOM_Settings -or ($CUSTOM_Settings.Count -eq 0)) {
	$CUSTOM_Settings = Get-IniFile -FilePath "$CUSTOM_SettingFile" -Verbose:$false
}
# Registry settings like "LaunchTo" (QuickAccess => ThisPC)
# For more informations see ScriptVariables.ps1
if (!$CUSTOM_RegistryValues -or ($CUSTOM_RegistryValues.Count -eq 0)) {
	$CUSTOM_RegistryValues = Import-Csv -Path $CUSTOM_RegistryFile -Delimiter ";" -Encoding UTF8
}
# The apps to remove from the image.
# For more informations see ScriptVariables.ps1
if (!$CUSTOM_AppRemoveList -or ($CUSTOM_AppRemoveList.Count -eq 0)) {
	$CUSTOM_AppRemoveList = Get-Content -Path $CUSTOM_RemoveAppsFile -Encoding UTF8 | Where-Object { $_ -and !$_.StartsWith("#") }
}
#endregion Import Script

#region Test for folders and stuff
# ########################################## #
#                TEST REGION
# ########################################## #
# Does not need to be ROCKING.wim.
if ($CustomWIMFileName) {
	$WIM_ExportedFileName = $CustomWIMFileName
	$WIM_ExportedFilePath = "$UUP_TempFolder\$WIM_ExportedFileName"
}

if (!(Test-Path -Path $WIM_ExportedFilePath)) {
	Write-Host "[$(_LINE_)] No image found to modify." -ForegroundColor Red
	return
}

Write-Host "[$(_LINE_)] Indizies on the image '$WIM_ExportedFilePath':"
$WIMImageInformation = Get-WimInfo -SourceWim $WIM_ExportedFilePath -Verbose:$false
$WIMImageInformation | Format-Table -AutoSize -Wrap

$WIMInstalledLanguages = $WIMImageInformation.Languages -replace " [(]Default[)]" -replace ", ", "|"

# Load all language files
if ($Languages -and ![String]::IsNullOrEmpty($Languages) -and ![String]::IsNullOrEmpty($Languages)) {
	# Capability matching "Language", the selected Languages bot NOT the already installed Languages.
	$LanguageFeature_Files = $CapabilityInformations | Where-Object { ($_.CapabilityName -match "Language") -and ($_.CapabilityName -match "$Languages") -and ($_.CapabilityName -notmatch "$WIMInstalledLanguages") }
}
# Load all files that have been requested in FOD
if ($FODs -and ![String]::IsNullOrEmpty($FODs) -and ![String]::IsNullOrEmpty($FODs)) {
	$OtherFeature_Files = $CapabilityInformations | Where-Object { ($_.CapabilityName -match "$FODs") }

	# I don't want to install features for a language not meant to be on the image.
	if ($Languages -and ![String]::IsNullOrEmpty($Languages) -and ![String]::IsNullOrEmpty($Languages)) {
		# Loop through all files
		foreach ($tFeature in  $OtherFeature_Files) {
			# If the capability name is like 'de-de' or 'mn-mong-cn'
			# (Do not even know if mongolian can be added...).
			# Save all except the found on in the same array.
			if (($tFeature.CapabilityName -match "([~][\w]{2}[-][\w]{2}[~])|([~][\w]{2}[-][\w]{4}[-][\w]{2}[~])") -and ($tFeature.CapabilityName -notmatch "$Languages")) {
				$OtherFeature_Files = $OtherFeature_Files | Where-Object { $_ -ne $tFeature }
			}
		}
	}
}

# Check if languages exists.
if ($Languages -and !$LanguageFeature_Files -and !$SkipLPs) {
	Write-Warning -Message ("[$(_LINE_)] Language(s) selected, but $($LanguageFeature_Files.Count) implementable files have been found for selection: '$Languages'. " + `
			"There might be no files if you have already implemented some languages (implemented language(s): '$WIMInstalledLanguages') OR " + `
			"the language to install is your default/main language (OS language: '$OSMainLang')? There might not be other LanguageFeature files than.")
}
if ($FODs -and !$OtherFeature_Files -and !$SkipFeatures) {
	Write-Warning -Message ("[$(_LINE_)] No features found for '$FODs'.")
}

# Searching for the nasic installation wim. I haven't saved it, I need to search again.
# In Step 2 I wanted to search for the ISO, but it should be extracted anyways, so why searching for that.
# Replaced "$InstallWIM_Directory" ($InstallWIM_Directory\sxs\) => $LatestWindowsImagePath
$LatestWindowsImageFile = Get-ChildItem -Path $UUP_AriaBaseDir -Recurse -ErrorAction SilentlyContinue | Where-Object { !$PSIsContainer -and $_.Name -match "install[.]wim" } | Sort-Object -Property LastWriteTime -Descending | Select-Object -First 1
#$LatestWindowsImageName = $LatestWindowsImageFile.Name
$LatestWindowsImageFullName = $LatestWindowsImageFile.FullName
$LatestWindowsImagePath = Split-Path $LatestWindowsImageFullName

#$LatestWindowsImagePath_SXSFolder = "$LatestWindowsImagePath\sxs"

# I have ISOPATH>source>install.wim. So I have to get the Dir of install.wim and than the name of that parent.
$ISOPathFullName = $LatestWindowsImageFile.Directory.Parent.FullName
#$ISOPathName = $LatestWindowsImageFile.Directory.Parent.Name

# C:\$ROCKS.UUP\aria\18362.1.190318-1202.19H1_RELEASE_CLIENTMULTI_X64FRE_DE-DE\sources
#$LatestWindowsImagePath
#endregion

# If there are languagepacks and updates, I should also update the boot.wim file.
$ProcessingImageFiles = @("$WIM_ExportedFilePath")
if (!$SkipBOOTWIM) {
	$ProcessingImageFiles += "$LatestWindowsImagePath\boot.wim"
}
#$ProcessingImageFiles = @("$WIM_ExportedFilePath", "$LatestWindowsImagePath\boot.wim")
$ProcessingImageFiles | ForEach-Object {
	$WIM_ExportedFilePath = $_
	$WIM_ExportedFileNameWithoutExtension = [System.IO.Path]::GetFileNameWithoutExtension($WIM_ExportedFilePath)
	$WIM_ExportedFileNameEQBoot = ($WIM_ExportedFileNameWithoutExtension -eq "boot")
	#$WIM_ExportedFileName = [System.IO.Path]::GetFileName($WIM_ExportedFilePath)
	#$WIM_ExportedFileExtension = [System.IO.Path]::GetExtension($WIM_ExportedFilePath)
	
	Write-Host "[$(_LINE_)] Processing image file '$WIM_ExportedFilePath'"

	# Some features and customizations are not applicable on the boot.wim
	if ($WIM_ExportedFileNameEQBoot) {
		$SkipCustom_AppXRemoval = $true
		$SkipCustom_StartLayout = $true
		# $SkipIncludingAdditionalFiles = $true # after loop!!
	}

	$WIMInfo = DISM /Get-WimInfo /WimFile:"$WIM_ExportedFilePath" /English /LogPath:$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_imageinfo.log
	if (!$WIMInfo) {
		Write-Host "[$(_LINE_)] No Windows Image File (WIM) Information" -BackgroundColor Black -ForegroundColor Red
		Stop-Transcript
		return
	}

	Write-Host "" # Empty Line
	$IndexNumbers = $WIMInfo | Select-String "Index" | ForEach-Object {
		"$_".Split(":").Trim()[1]
	}

	#DEBUG
	#$IndexNumbers = $IndexNumbers | Select-Object -First 1
	#/DEBUG

	Write-Verbose "[$(_LINE_)] Processing all $($IndexNumbers.Count) selected indizies."
	foreach ($Index in $IndexNumbers) {
		Write-Host "[$(_LINE_)] ======================================"
		Write-Host "[$(_LINE_)]           Mounting Index $Index/$($IndexNumbers.Count)"
		Write-Host "[$(_LINE_)] ======================================"

		# Should not be called, but if errors occour and I kinda "have to" delete the folder
		# I will re-create the folder. Calling this on every indey to be sure.
		if (!(Test-Path -Path $UUP_IMGMountPath)) {
			$null = New-Item -ItemType Directory -Path $UUP_IMGMountPath
		}

		# Mounting Image
		Write-Verbose "[$(_LINE_)] Mounting '$WIM_ExportedFilePath' to '$UUP_IMGMountPath'."
		DISM /Mount-Wim /WimFile:$WIM_ExportedFilePath /Index:$Index /MountDir:$UUP_IMGMountPath /Quiet /NoRestart /English /LogPath:$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_mount_os_i$Index.log
		DismLog -ExitCode $LASTEXITCODE -Operation "Mount: $WIM_ExportedFilePath`:$Index | $UUP_IMGMountPath" -Line $(_LINE_)
	
		# Problem with error on mounting needs to be fixed. Unmounting in same progress.
		# One thing that COULD be skipped is "-1052638937 (0xc1420127)" / Message: 'The specified image in the specified wim is already mounted for read/write access.'.
		if ($LASTEXITCODE -ne 0) {
			Write-Host "[$(_LINE_)] LASTEXITCODE: $LASTEXITCODE (0x$([System.Convert]::ToString($LASTEXITCODE, 16))). Please fix errors and re-start. Unmounting Image." -BackgroundColor Black -ForegroundColor Red

			# The reg might have been loaded.
			# Keys are saved in ScriptFunctions.ps1
			Get-Variable -Name "CUSTOM_Reg*" | ForEach-Object {
				$tVarValue = $_.Value
				if (Test-Path -Path "Registry::HKEY_LOCAL_MACHINE\$tVarValue") {
					UnmountRegistry -OfflineRegistry "Registry::HKEY_LOCAL_MACHINE\$tVarValue"
				}
			}
			ScriptCleanUP -MountPath $UUP_IMGMountPath -ClearAllMountedFolders -ClearRegistryHives

			# Unmounting IMGFolder and Cleaning up stale files
			DISM /UnMount-Wim /MountDir:$UUP_IMGMountPath /Discard /English /LogPath:$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_unmount_os_i$Index.log
			DISM /CleanUp-Wim /English /LogPath:$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_cleanup_os_i$Index.log
			DismLog -ExitCode $LASTEXITCODE -Operation "Unmount: $WIM_ExportedFilePath`:$MountingIndexNumber | $UUP_IMGMountPath" -Line $(_LINE_)
			return
		}

		#region Updates
		if (!$SkipUpdates) {
			Write-Host "[$(_LINE_)] Processing updates"

			# Getting the updates I just downloaded.
			# MAYBE I can also implement updates from SCCM or WSUS?
			if (Test-Path -Path $UUP_AriaUUPs) {
				$Counter_Updates = 0 # Only Display
				$UpdateArray = Get-ChildItem -Path $UUP_AriaUUPs -Filter "*KB*" | Sort-Object -Property Name
				$UpdateArray | ForEach-Object {
					$UpdateName = $_.Name # CAB Name
					$UpdatePath = $_.FullName
					$Counter_Updates++

					# Splitting the information I get from the /Get-PackageInfo;
					# So I have the real package name and description.
					$DISMInfo = [PSCustomObject]@{}
					$DISMBaseInfo = DISM /Image:$UUP_IMGMountPath /Get-PackageInfo /PackagePath:$UpdatePath /NoRestart /English /LogPath:$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_checkpack_i$Index`_$UpdateName.log
					if ($LASTEXITCODE -ne 0) {
						Write-Host "[$(_LINE_)] LASTEXITCODE: '$LASTEXITCODE' (0x$([System.Convert]::ToString($LASTEXITCODE, 16)))." -BackgroundColor Black -ForegroundColor Red
					}
					$DISMBaseInfo | ForEach-Object {
						if ($_ -like "*:*") {
							$Split = ($_ -split ":", 2).Trim()

							if ($DISMInfo | Get-Member -Name "$($Split[0])") {
								$DISMInfo."$($Split[0])" = $Split[1]
							}
							else {
								$DISMInfo | Add-Member -MemberType NoteProperty -Name "$($Split[0])" -Value $Split[1]
							}
						}
						else {
							# only empty lines, nevermind
						}
					}
					$dPackageID = $DISMInfo."Package Identity"
					$dPackageDesc = $DISMInfo.Description

					# If "Package Identity" has no value, I need to set another name.
					$UpdatePackageName = $UpdateName
					if ($dPackageID) {
						$UpdatePackageName = "$dPackageID | $dPackageDesc"
					}
					else {
						Write-Verbose "[$(_LINE_)] Could not find 'Package Identity'. So '$UpdatePackageName' will be used as package name."
					}
				
					# I have no other way of checking for dependencies or if these packages can be applied.
					Write-Host "[$(_LINE_)] Package $Counter_Updates/$($UpdateArray.Count): Adding '$UpdatePackageName' (Started: $(Get-Date -Format "HH:mm:ss"))"
					$null = DISM /Image:$UUP_IMGMountPath /Add-Package /PackagePath:$UpdatePath /Quiet /NoRestart /English /LogPath:$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_addpack_i$Index`_$UpdateName.log
					DismLog -ExitCode $LASTEXITCODE -Operation "Add: $UpdatePackageName" -Line $(_LINE_)
				
					# -2146498530 (0x800f081e) = Smothing like 'The package Package_for_OasisAsset is not applicable to the image'.
					# 2 (0x80070002) = ERROR_FILE_NOT_FOUND; This might not always be true.
					if ($LASTEXITCODE -ne 0) {
						Write-Host "[$(_LINE_)] LASTEXITCODE: '$LASTEXITCODE' (0x$([System.Convert]::ToString($LASTEXITCODE, 16)))." -BackgroundColor Black -ForegroundColor Red
					}
					#else {
					#	Write-Host "[$(_LINE_)] LASTEXITCODE: '$LASTEXITCODE' (0x$([System.Convert]::ToString($LASTEXITCODE, 16)))."
					#}

					# I do not really care if updates are not getting installed.
					# WSUS and SCCM will get them for me ;-)
					# Just displaying why THIS package did not get installed.
					if ($UpdatePackageName -match "OASIS") {
						#Expand -F:* $UpdateName.cab 'C:\$ROCKS.UUP\aria\UUPs\$UpdateName\' # create folder
						Write-Verbose "[$(_LINE_)] This MIGHT be a VR Update. Is 'Analog.Holographic' installed?"
					
						# Analog.Holographic.Desktop~~~~0.0.1.0
						$Cap = ("" + (DISM /Image:$UUP_IMGMountPath /Get-Capabilities /LimitAccess | Select-String "Anal")) | Select-Object -First 1
						if ($Cap) {
							$CapName = "$Cap".Split(":")[1].Trim()
							$IsPresent = ("" + (Dism /Image:$UUP_IMGMountPath /Get-CapabilityInfo /CapabilityName:$CapName /English | Select-String "State")).Split(":")[1].Trim()
							Write-Verbose "[$(_LINE_)] > '$CapName': $IsPresent"
						}
						else {
							Write-Verbose "[$(_LINE_)] Could not find 'Anal*'-Capability in mountpath."
						}
					}
				} # /end update array loop
			
				#region RESETBASE
				# Is reset base after updates required? Let's test that and then do it.
				# TODO: Test if I need to create a function for this!?
				Write-Verbose "[$(_LINE_)] CleanUp /Analyze of '$UUP_IMGMountPath' (Started: $(Get-Date -Format "HH:mm:ss"))."
				$DISM_CUResult = DISM /Image:$UUP_IMGMountPath /Cleanup-Image /AnalyzeComponentStore /English /LogPath:$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_cleanup_image_analyze_i$Index.log

				# Error on CleanUp /Analyze needs to be fixed.
				# Unmounting in same progress.
				if ($LASTEXITCODE -ne 0) {
					Write-Host "[$(_LINE_)] LASTEXITCODE: $LASTEXITCODE (0x$([System.Convert]::ToString($LASTEXITCODE, 16))). Please fix errors and re-start. Unmounting Image." -BackgroundColor Black -ForegroundColor Red
					DISM /UnMount-Wim /MountDir:$UUP_IMGMountPath /Discard /English /LogPath:$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_unmount_os_i$Index.log
					DismLog -ExitCode $LASTEXITCODE -Operation "Unmount: $WIM_OriginalFilePath`:$MountingIndexNumber | $UUP_IMGMountPath" -Line $(_LINE_)
					return
				}

				# Component Store Cleanup Recommended : Yes
				if (!$DISM_CUResult) {
					Write-Host "[$(_LINE_)] Nothing recommended? I don't think so ($DISM_CUResult)." -BackgroundColor Black -ForegroundColor Red
					return
				}
				#$DISM_CURecommended = ($DISM_CUResult | Select-String "Component Store Cleanup Recommended").ToString().Split(":")[1].Trim() -eq "Yes"
				if ($DISM_CURecommendedBool) {
					Write-Host "[$(_LINE_)] CleanUp of '$UUP_IMGMountPath' because of recommendation `"$DISM_CURecommendedBool`" (Started: $(Get-Date -Format "HH:mm:ss"))."
					DISM /Image:$UUP_IMGMountPath /Cleanup-Image /StartComponentCleanup /ResetBase /SPSuperseded /Quiet /NoRestart /English /LogPath:$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_cleanup_i$Index.log
				}
				else {
					Write-Verbose "[$(_LINE_)] No need for CleanUp of '$UUP_IMGMountPath'."
				}
				#endregion RESETBASE
			} # /end if update path exists
		} # /end skip updates
		#endregion

		#DISM /Image:$UUP_IMGMountPath /Cleanup-Image /ScanHealth /English /LogPath:$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_scanhealth_i$Index.log
		#DISM /Image:$UUP_IMGMountPath /Cleanup-Image /StartComponentCleanup /ResetBase /SPSuperseded /English  /LogPath:$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_cleanup.log
		#Dism /Commit-Image /MountDir:$UUP_IMGMountPath /English /Quiet /NoRestart /LogPath:$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_commit.log

		#region Features
		if (!$SkipFeatures) {
			# either here or after the language apply step.
			# does only work for the setup/PE index.
			if ($Languages) {
				# $WIM_ExportedFileNameEQBoot because we only need this in boot.wim
				if (!$SkipBOOTWIM -and $WIM_ExportedFileNameEQBoot) {
					Write-Host "[$(_LINE_)] Setting setup language to '$OSMainLang'"
					#$LanguageFeature_Files | Where-Object { ($_.CapabilityName -match "$OSMainLang") }
					"Dism /image:$UUP_IMGMountPath /Set-SetupUILang:$OSMainLang /Distribution:$UUP_IMGMountPath /Quiet /NoRestart /English /LogPath:$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_setuplang_$($_.CapabilityName).log"
					Dism /image:$UUP_IMGMountPath /Set-SetupUILang:$OSMainLang /Distribution:$UUP_IMGMountPath /Quiet /NoRestart /English /LogPath:$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_setuplang_$($_.CapabilityName).log
				}
			}

			# If the array.count -eq 0 it will loop anyway.
			# So checking for ALL information we have :=)
			if ($Languages -and $LanguageFeature_Files -and !$SkipLPs) {
				Write-Host "[$(_LINE_)] Processing $($LanguageFeature_Files.Count) LanguagePack files for '$Languages'"

				# Adding all LanguagePacks selected and available
				if ($LanguageFeature_Files) {
					$LanguageFeature_Files | ForEach-Object {
						# I need to have a variable for the language packs rename part.
						# Language features only getting added if they are named correctly (*rolling eyes*).
						# $FeatureFullAlternativeName: Need this if I want to copy the renamed feature file.
						# EITHER we alreasdy have this name, OR I set it below when renaming.
						if ($_.AlternativeFullName -and (Test-Path -Path $_.AlternativeFullName)) {
							Write-Verbose "[$(_LINE_)] '$($_.AlternativeFullName)' exists."
							$FeatureFullName = $_.AlternativeFullName
							$FeatureFullAlternativeName = $_.AlternativeFullName
						}
						elseif (Test-Path -Path $_.FullName -ErrorAction SilentlyContinue) {
							Write-Verbose "[$(_LINE_)] '$($_.FullName)' exists."
							$FeatureFullName = $_.FullName
							$FeatureFullAlternativeName = $_.AlternativeFullName
						}
						else {
							Write-Host "[$(_LINE_)] Neither '$($_.FullName)' nor '$($_.AlternativeFullName)' found. Plase take a look if one of those files exists." -BackgroundColor Black -ForegroundColor Red
							return
						}

						Write-Host "[$(_LINE_)] Adding: '$($_.CapabilityName)'"
						DISM /Image:$UUP_IMGMountPath /Add-Package /PackagePath:$FeatureFullName /IgnoreCheck /Quiet /NoRestart /English /LogPath:$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_addpack_$($_.CapabilityName).log
						DismLog -ExitCode $LASTEXITCODE -Operation "Add: $FeatureFullName" -Line $(_LINE_)

						# DISM is such a pussy. It cannot add the language file if some 'words' are missing!?
						# So I try to add these to the filename and re-run DISM with the new name.
						# Error Code is -2146498529 (decimal) / 0x800F081F (hex).
						if ($LASTEXITCODE -eq "-2146498529") {
							# Renaming those files:
							#microsoft-windows-languagefeatures-basic-fr-fr-package-amd64
							#microsoft-windows-languagefeatures-handwriting-fr-fr-package-amd64
							#microsoft-windows-languagefeatures-texttospeech-fr-fr-package-amd64
							Write-Host "[$(_LINE_)] DISM returned error code '$LASTEXITCODE' (0x$([System.Convert]::ToString($LASTEXITCODE, 16))). I'll have to try the rename trick." -BackgroundColor Black -ForegroundColor Red
			
							# microsoft-windows-languagefeatures-texttospeech-fr-fr-package-amd64.cab
							$tFileName = Split-Path $_.FullName -Leaf
							$tFilePath = Split-Path $_.FullName

							# In case I would have "cab" and/or "esd".
							# Grabbing filename without extension and the extension itself.
							# microsoft-windows-languagefeatures-texttospeech-fr-fr-package-amd64
							$tFileExtension = [System.IO.Path]::GetExtension($tFileName)
							$tFileNameOnly = [System.IO.Path]::GetFileNameWithoutExtension($tFileName)

							# Splitting the base filename, so I can build the string myself.
							$tSplittedFileName = $tFileNameOnly -split "-"

							# Building new file name: <microsoft-windows-languagefeatures-texttospeech-de-de-package~value~amd64~~.cab/.esd>
							# Length is 8, array starts at 0, so -2.
							$newFileName = $tSplittedFileName[0..($tSplittedFileName.Length - 2)] -join "-"
							$newFileName += "~31bf3856ad364e35~"
							$newFileName += $tSplittedFileName[$tSplittedFileName.Length - 1] # amd64
							$newFileName += "~~"
							$newFileName += $tFileExtension # .cab/.esd

							# This SHOULD NEVER break, as I have both filenames.
							# If the alternative filename does not exist, I select the original FullName.
							# (There would be somthing wrong, if none of them exists).
							try {
								$CapabilityInformations | Where-Object { $_.FullName -eq $FeatureFullName } | ForEach-Object {
									Write-Verbose "[$(_LINE_)] Changing CSV information..."
									#$_.FullName = "$tFilePath\$newFileName"
									$_.AlternativeFullName = "$tFilePath\$newFileName"
									#$FeatureFullAlternativeName = "$tFilePath\$newFileName"
								}
								$CapabilityInformations | Export-Csv -Path "$UUP_AriaAdditionalFODs\DISM_Information.csv" -Delimiter ";" -Encoding UTF8 -NoTypeInformation
							}
							catch {
								Write-Host "[$(_LINE_)] Error: $($_.Exception.Message)" -BackgroundColor Black -ForegroundColor Red
								return
							}

							# Rename cab and re-run DISM process.
							# Should i possibly add the "/quiet" and "/norestart" although it's offline injection!?
							try {
								Write-Verbose "[$(_LINE_)] Renaming '$FeatureFullName' => '$newFileName'"
								Rename-Item -LiteralPath $FeatureFullName -NewName "$newFileName" -ErrorAction Stop -Verbose:$VerbosePreference
				
								Write-Host "[$(_LINE_)] Adding renamed '$newFileName'"
								DISM /Image:$UUP_IMGMountPath /Add-Package /PackagePath:"$($tFilePath)\$newFileName" /IgnoreCheck /Quiet /NoRestart /English /LogPath:$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_addpack_$([System.IO.Path]::GetFileNameWithoutExtension($newFileName)).log
								DismLog -ExitCode $LASTEXITCODE -Operation "Add: $($tFilePath)\$newFileName" -Line $(_LINE_)
							}
							catch {
								Write-Host "[$(_LINE_)] Error: $($_.Exception.Message)" -BackgroundColor Black -ForegroundColor Red
								return
							}
						} # /end rename "trick"
						elseif ($LASTEXITCODE -eq "2") {
							Write-Host "[$(_LINE_)] DISM returned error code '$LASTEXITCODE' (0x$([System.Convert]::ToString($LASTEXITCODE, 16))). File not found!? (FeaturePack: $FeatureFullName)." -BackgroundColor Black -ForegroundColor Red
						}
						#else {
						#	Write-Host "[$(_LINE_)] LASTEXITCODE: '$LASTEXITCODE' (0x$([System.Convert]::ToString($LASTEXITCODE, 16)))."
						#}

						# For multi-image ISO. So I might add it to a OS later.
						Write-Verbose "[$(_LINE_)] REMOVE?: '$FeatureFullAlternativeName' vs. '$FeatureFullName' vs. $($_.AlternativeFullName)" -Verbose
						if ($FeatureFullAlternativeName -and ![String]::IsNullOrWhiteSpace($FeatureFullAlternativeName)) {
							$null = Copy-Item -Path "$FeatureFullAlternativeName" -Destination "$LatestWindowsImagePath\sxs" -Force
						}
						else {
							$null = Copy-Item -Path "$FeatureFullName" -Destination "$LatestWindowsImagePath\sxs" -Force
						}

						#$LatestWindowsImagePath
					} # /end language loop
				} # /end if language exists

				# TODO: TESTING NEEDED
				# Returned: YES
				Write-Verbose "[$(_LINE_)] TEST_LANG: CleanUp /Analyze of '$UUP_IMGMountPath' (Started: $(Get-Date -Format "HH:mm:ss"))."
				#DISM /Image:$UUP_IMGMountPath /Cleanup-Image /AnalyzeComponentStore /English /LogPath:$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_cleanup_image_analyze_i$Index.log
				ResetBase -Line "$(_LINE_)"
			} # /end language skip

			# Might be better after applying the languages.
			# TODO: Testing this.
			if ($Languages) {
				if (!$SkipBOOTWIM -and $WIM_ExportedFileNameEQBoot) {
					Write-Host "[$(_LINE_)] Setting setup language to '$OSMainLang'"
					#$LanguageFeature_Files | Where-Object { ($_.CapabilityName -match "$OSMainLang") }
					"Dism /image:$UUP_IMGMountPath /Set-SetupUILang:$OSMainLang /Distribution:$UUP_IMGMountPath /Quiet /NoRestart /English /LogPath:$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_setuplang_$($_.CapabilityName).log"
					Dism /image:$UUP_IMGMountPath /Set-SetupUILang:$OSMainLang /Distribution:$UUP_IMGMountPath /Quiet /NoRestart /English /LogPath:$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_setuplang_$($_.CapabilityName).log
				}
			}

			# Should I possibly count for errors?
			# "Normally" the only dism command failing are the one where packages without languages getting applied (or at least try to).
			# But they are getting apllied with the language selected, so I do not care for that errors anyway.
			# Strange "error": even if the $OtherFeature_Files.Count eq 0, it will loop the array (so !$Skip is not enough).
			# 13.08.2019 - Found another problem (detailed information here: https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/features-on-demand-v2--capabilities):
			# Starting with 1809 there are packages morphed together (feature plus language) and then there are the ones separated (like here, mostly).
			# It seems they get added, but not "really". Only /Add-Capability seems to do it correctly.
			# WWWWWWWHHHHHHHYYYYYYYYYYYYYYYYYYYYYYYYYYYY?????
			# Check This file: https://uupdump.ml/findfiles.php?id=2dbea21e-0a44-4747-a2ee-416eecf243ad&q=microsoft-windows-dns-tools-fod-package-amd64.cab
			# So i tested this and the file i get from the online variant (DISM /Online /Add-Capability /CapabilityName:Rsat.Dns.Tools~~~~0.0.1.0).
			# FileSize of link is 95.39 KiB. The one i downloaded is 1.21MB (Microsoft-Windows-DNS-Tools-FoD-Package~31bf3856ad364e35~amd64~~.cab).
			# So I can not add this in here. YOU have to download this crap. Pah.
			# You can rename LanguagePacks (as mentioned here: https://www.ntlite.com/community/index.php?threads/how-to-add-integrate-language-pack-language-feature-pack-into-a-iso-via-ntlite.978/#post-10097).
			if ($FODs -and !$SkipFODs -and $($OtherFeature_Files.Count -gt 0)) {
				# TODO: I have to test if these features get ACTIVATED!?
				Write-Host "[$(_LINE_)] Processing $($OtherFeature_Files.Count) FeaturesOnDemand for '$FODs'"
			
				#Write-Warning -Message ("[$(_LINE_)] There might be some features that do NOT get installed/implemented. " + `
				#	"RSAT for example has problems installing some tools not containing the language tag.")
			
				Write-Warning -Message ("[$(_LINE_)] I could not get this to work properly; The DISM command succeeds, but when installed I STILL have to download them. " + `
						"Some file size for these RSAT features are not even the right size. Language packs are working though. " + `
						"Tipp: Run 'Add-WindowsCapability -Online -Name RSAT*' and catch the files downloaded in C:\Windows\SoftwareDistribution\Download\!")
				Write-Host "Skipping Feature implementation here." -BackgroundColor DarkRed -ForegroundColor White
				return

				# Adding them RSAT and FOD packages.
				# Some might not be added, but that should not be the problem.
				$FeatureCount = 0
				$OtherFeature_Files | ForEach-Object {
					$FeatureCount++

					# I need to have a variable for the FOD packs rename part.
					# Some FOD features might only be added if they are named correctly.
					if ($_.AlternativeFullName -and (Test-Path -Path $_.AlternativeFullName)) {
						Write-Verbose "[$(_LINE_)] '$($_.AlternativeFullName)' exists."
						$FeatureFullName = $_.AlternativeFullName
					}
					elseif (Test-Path -Path $_.FullName -ErrorAction SilentlyContinue) {
						Write-Verbose "[$(_LINE_)] '$($_.FullName)' exists."
						$FeatureFullName = $_.FullName
					}
					else {
						Write-Host "[$(_LINE_)] Neither '$($_.FullName)' nor '$($_.AlternativeFullName)' found. Plase take a look if one of those files exists." -BackgroundColor Black -ForegroundColor Red
						return
					}
					$FeatureCapabilityName = $_.CapabilityName
					$FeatureCapabilityNameWithoutLanguage = $_.CapabilityName -replace "$Languages"
					$FeatureFolder = Split-Path $FeatureFullName

					#Write-Verbose "[$(_LINE_)] Adding: '$FeatureCapabilityName'"
					#Write-Host "[$(_LINE_)] [$FeatureCount/$($OtherFeature_Files.Count)] Adding: '$FeatureCapabilityName'"
					$NumberOfFeatures = $OtherFeature_Files.Count
					Write-Host "[$(_LINE_)] [$("$FeatureCount".PadLeft("$NumberOfFeatures".Length, "0"))/$NumberOfFeatures] Adding: '$FeatureCapabilityName'"
					DISM /Image:$UUP_IMGMountPath /Add-Package /PackagePath:$FeatureFullName /IgnoreCheck /Quiet /NoRestart /English /LogPath:$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_addpack_$FeatureCapabilityName.log
					DismLog -ExitCode $LASTEXITCODE -Operation "Add: $FeatureFullName" -Line $(_LINE_)
				
					if ($LASTEXITCODE -eq "2") {
						Write-Host "[$(_LINE_)] DISM returned error code '$LASTEXITCODE' (0x$([System.Convert]::ToString($LASTEXITCODE, 16))). File not found!? (FeaturePack: $FeatureFullName)." -BackgroundColor Black -ForegroundColor Red
					}
					elseif ($LASTEXITCODE -eq "87") {
						Write-Host "[$(_LINE_)] DISM returned error code '$LASTEXITCODE' (0x$([System.Convert]::ToString($LASTEXITCODE, 16))). There is some information missing (FeaturePack: '$FeatureFullName' " `
							"| Commands: /Image:$UUP_IMGMountPath /Add-Package /PackagePath:'$FeatureFullName' /IgnoreCheck /Quiet /NoRestart /English /LogPath:$UUP_LoggingPath\dism_addpack_$FeatureCapabilityName.log)." -BackgroundColor Black -ForegroundColor Red
					}
					elseif ($LASTEXITCODE -eq "-2146498219") {					
						Write-Host "[$(_LINE_)] DISM returned '$LASTEXITCODE' (0x$([System.Convert]::ToString($LASTEXITCODE, 16)), CBS_E_INVALID_PACKAGE_REQUEST_ON_MULTILINGUAL_FOD). (FeaturePack: $FeatureFullName)." -BackgroundColor Black -ForegroundColor Red
					}
					elseif ($LASTEXITCODE -eq "-2146498529") {
						Write-Host "[$(_LINE_)] DISM returned error code '$LASTEXITCODE' (0x$([System.Convert]::ToString($LASTEXITCODE, 16)), CBS_E_SOURCE_MISSING). Could not add package (FeaturePack: $FeatureFullName)." -BackgroundColor Black -ForegroundColor Red
					
						# Somehow DISM looks for the FOD file name, so we can test if we can rename the FOD cabinet file.
						# LLDP worked, do not know if this does not work with other cabinets.
						# Message from DISM log: Failed to open response file: \\?\C:\$ROCKS.UUP\aria\UUPs\Additional\Microsoft-Windows-LLDP-Tools-FoD-Package~31bf3856ad364e35~amd64~~.cab
						# Original FileName: microsoft-windows-lldp-tools-fod-package-amd64.cab
						# Renamed  FileName: Microsoft-Windows-LLDP-Tools-FoD-Package~31bf3856ad364e35~amd64~~.cab
						Write-Host "[$(_LINE_)] I'll have to try the rename trick and see if that works." -BackgroundColor Black -ForegroundColor Red
			
						#microsoft-windows-lldp-tools-fod-package-amd64.cab
						$tFileName = Split-Path $_.FullName -Leaf
						$tFilePath = Split-Path $_.FullName

						# In case I would have "cab" and/or "esd".
						# Grabbing filename without extension and the extension itself.
						#microsoft-windows-lldp-tools-fod-package-amd64
						$tFileExtension = [System.IO.Path]::GetExtension($tFileName)
						$tFileNameOnly = [System.IO.Path]::GetFileNameWithoutExtension($tFileName)

						# Splitting the base filename, so I can build the string myself.
						$tSplittedFileName = $tFileNameOnly -split "-"

						# Building new file name: <microsoft-windows-lldp-tools-fod-package~value~amd64~~.cab/.esd>
						# Length is 8, array starts at 0, so -2.
						$newFileName = $tSplittedFileName[0..($tSplittedFileName.Length - 2)] -join "-"
						$newFileName += "~31bf3856ad364e35~"
						$newFileName += $tSplittedFileName[$tSplittedFileName.Length - 1] # amd64
						$newFileName += "~~"
						$newFileName += $tFileExtension # .cab/.esd

						# This SHOULD NEVER break, as I have both filenames.
						# If the alternative filename does not exist, I select the original FullName.
						# (There would be somthing wrong, if none of them exists).
						try {
							$CapabilityInformations | Where-Object { $_.FullName -eq $FeatureFullName } | ForEach-Object {
								Write-Verbose "[$(_LINE_)] Changing CSV information..."
								$_.AlternativeFullName = "$tFilePath\$newFileName"
							}
							$CapabilityInformations | Export-Csv -Path "$UUP_AriaAdditionalFODs\DISM_Information.csv" -Delimiter ";" -Encoding UTF8 -NoTypeInformation
						}
						catch {
							Write-Host "[$(_LINE_)] Error: $($_.Exception.Message)" -BackgroundColor Black -ForegroundColor Red
							return
						}

						# Rename cab and re-run DISM process.
						# Should i possibly add the "/quiet" and "/norestart" although it's offline injection!?
						try {
							Write-Verbose "[$(_LINE_)] Renaming '$FeatureFullName' => '$newFileName'"
							Rename-Item -LiteralPath $FeatureFullName -NewName "$newFileName" -ErrorAction Stop -Verbose:$VerbosePreference
				
							Write-Verbose "[$(_LINE_)] Adding: '$FeatureCapabilityName' (Renamed to '$newFileName')"
							DISM /Image:$UUP_IMGMountPath /Add-Package /PackagePath:"$($tFilePath)\$newFileName" /IgnoreCheck /Quiet /NoRestart /English /LogPath:$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_addpack_renamed_$FeatureCapabilityName.log
							DismLog -ExitCode $LASTEXITCODE -Operation "Add: $($tFilePath)\$newFileName" -Line $(_LINE_)
						}
						catch {
							Write-Host "[$(_LINE_)] Error: $($_.Exception.Message)" -BackgroundColor Black -ForegroundColor Red
							return
						}
					} # /end language trick

					Write-Host "$FeatureFolder" -ForegroundColor Cyan
					Write-Host "DISM /Image:$UUP_IMGMountPath /Add-Capability /CapabilityName:$FeatureCapabilityNameWithoutLanguage /Source:$FeatureFolder /LimitAccess /LogPath:$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_addcap_$FeatureCapabilityName.log" -ForegroundColor Cyan
					DISM /Image:$UUP_IMGMountPath /Add-Capability /CapabilityName:$FeatureCapabilityNameWithoutLanguage /Source:$FeatureFolder /LogPath:$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_addcap_$FeatureCapabilityName.log
					DismLog -ExitCode $LASTEXITCODE -Operation "AddC: $FeatureFullName" -Line $(_LINE_)
				} # /end FODs loop

				# TODO: TESTING NEEDED
				# Returned also YES
				Write-Verbose "[$(_LINE_)] TEST_FODs: CleanUp /Analyze of '$UUP_IMGMountPath' (Started: $(Get-Date -Format "HH:mm:ss"))."
				#DISM /Image:$UUP_IMGMountPath /Cleanup-Image /AnalyzeComponentStore /English /LogPath:$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_cleanup_image_analyze_i$Index.log
				ResetBase -Line "$(_LINE_)"
			} # /end if FODs exists
		} # /end FOD skip
		#endregion Features
	
		#region Customization
		if (!$SkipCustomization) {
			Write-Host "[$(_LINE_)] Image Customization" -ForegroundColor Cyan

			<#
				# TODO: I HAVE TO TEST WHY THIS IS HAPPENING AT HOME!
				# I had the problem, that renaming worked at work, but not at home.
				# Added ACL, maybe i should remove this afterwards.
				#
				# Main Difference:
				# - Inside of Hyper-V, not on machine
				# - Home OS is Windows 10 (1809) Pro (With Hyper-V-VM on 1903 Enterprise)
				# - Work OS is Windows 10 (1809) Enterprise
			#>
			
			#region Remove OneDrive
			# Renaming OneDrive Setup exe
			# OneDrive Setup Hook for users is removed in REG\DEFAULT region
			if ($CUSTOM_Settings.Removals.RemoveOneDrive -eq 1) {
				Write-Host "[$(_LINE_)] Removing OneDrive Setup"
				@(
					"$UUP_IMGMountPath\Windows\System32\OneDriveSetup.exe"
					"$UUP_IMGMountPath\Windows\SysWOW64\OneDriveSetup.exe"
				) | ForEach-Object {
					# I might want to rename another setup, who knows.
					$OneDriveSetupPath = $_
					$OneDriveSetupName = [System.IO.Path]::GetFileNameWithoutExtension($OneDriveSetupPath)

					if (Test-Path -Path $OneDriveSetupPath -ErrorAction SilentlyContinue) {
						try {
							# Access Denied-Error not thrown to catch. Stop SHOULD work...
							$null = Rename-Item -Path $OneDriveSetupPath -NewName "$OneDriveSetupName.bck" -Force -Verbose:$VerbosePreference -ErrorAction Stop
						}
						catch {
							#Write-Host "Force rename here, as i could not find out the problem." -BackgroundColor DarkRed -ForegroundColor White
							Write-Host "[$(_LINE_)] =====================================" -BackgroundColor DarkRed -ForegroundColor White
							Write-Host "[$(_LINE_)] Force rename of one drive setup file." -BackgroundColor DarkRed -ForegroundColor White
							Write-Host "[$(_LINE_)] =====================================" -BackgroundColor DarkRed -ForegroundColor White
								
							$Acl = Get-ACL $OneDriveSetupPath
								
							# "Administrators" is language specific, BUT
							# S-1-5-32-544 should ALWAYS be the same over all languages!
							$Group = New-Object System.Security.Principal.NTAccount((Get-LocalGroup -SID S-1-5-32-544).Name) # ("Vordefiniert", "Administratoren")
							$User = New-Object System.Security.Principal.NTAccount($env:USERNAME)
								
							# Set admin group as owner and grant group and user full access role
							$ACL.SetOwner($Group) # Admin group or actual user?
							$Acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($User, "FullControl", "Allow")))
							$Acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($Group, "FullControl", "Allow")))

							Set-Acl $OneDriveSetupPath $Acl

							# This WILL HAVE TO work!
							$null = Rename-Item -Path $OneDriveSetupPath -NewName "onedrivesetup.bck" -Force
						}
					}
				}
			}
			#endregion

			#region RemoveBloatware
			if (!$SkipCustom_AppXRemoval) {
				# App-List from: https://github.com/W4RH4WK/Debloat-Windows-10
				# Exported the list to \Customize\RemoveApps.txt. Comments were skipped.
				Write-Host "[$(_LINE_)] Remove AppX Stuff" -ForegroundColor Yellow

				# Count just for me displaying the removals left
				$Count_AppRemoval = 0
				#$CUSTOM_AppRemoveList
				#foreach ($app in $apps) {}
				$NumberOfApps = $CUSTOM_AppRemoveList.Count
				if ($CUSTOM_AppRemoveList -and ($NumberOfApps -gt 0)) {
					foreach ($app in $CUSTOM_AppRemoveList) {
						$Count_AppRemoval++
						Write-Host "[$(_LINE_)] [$("$Count_AppRemoval".PadLeft("$NumberOfApps".Length, "0"))/$NumberOfApps] Push removal of '$app'" -ForegroundColor DarkGray

						try {
							# All Users (-AllUsers) do not exist in mounted images.
							#Get-AppxPackage -Name $app -PackageTypeFilter | Remove-AppxPackage -AllUsers

							$null = Get-AppXProvisionedPackage -Path $UUP_IMGMountPath -Verbose:$false -ErrorVariable $AppxError1 | Where-Object DisplayName -eq $app | Remove-AppxProvisionedPackage -ErrorVariable $AppxError2 -Verbose:$false
							if ($LASTEXITCODE -ne 0) {
								Write-Host "[$(_LINE_)] LASTEXITCODE: '$LASTEXITCODE' (0x$([System.Convert]::ToString($LASTEXITCODE, 16)), $AppxError1, $AppxError2)." -BackgroundColor Black -ForegroundColor Red
							}
						}
						catch {
							Write-Host "[$(_LINE_)] Error: $($_.Exception.Message)" -BackgroundColor Black -ForegroundColor Red
						}
						
						# Manual via GridView!
						#Get-AppxProvisionedPackage -Path $UUP_IMGMountPath | Out-GridView -PassThru | Remove-AppxProvisionedPackage
					} # /end of app loop
				}
				else {
					Write-Warning -Message "[$(_LINE_)] No apps defined for removal. Skipping process. $($CUSTOM_AppRemoveList.Count)"
				}
			}
			else {
				Write-Host "[$(_LINE_)] AppX Removal skipped." -ForegroundColor DarkGray
			} # /end of !$SkipAppXRemoval
						
			#endregion RemoveBloatware

			#region Registry
			if (!$SkipRegTweaks) {
				<#
					German explanation for these registry keys:
					https://www.windowspro.de/wolfgang-sommergut/registry-offline-bearbeiten-regeditexe-powershell
					[...] und wechselt auf dem Laufwerk des ausgeschalteten Windows in das Verzeichnis \windows\system32\config.
					Die Dateien SOFTWARE, SYSTEM und SAM repr�sentieren die Datenbanken f�r HKLM\Software, HKLM\System und HKLM\Sam.
					DEFAULT steht f�r HKCU\Default und NTUSER.DAT f�r HKEY_CURRENT_USER.
				
					So, These hives can be loaded:
					- REG LOAD HKLM\DEFUSER "$UUP_IMGMountPath\Users\default\ntuser.dat"
					- reg load HKLM\OFFLINE "$UUP_IMGMountPath\Windows\System32\Config\SOFTWARE"
					- reg load HKLM\OFFLINE "$UUP_IMGMountPath\Windows\System32\Config\DEFAULT"
					- reg load HKLM\OFFLINE "$UUP_IMGMountPath\Windows\System32\Config\DRIVERS"
					- reg load HKLM\OFFLINE "$UUP_IMGMountPath\Windows\System32\Config\SAM"
					- reg load HKLM\OFFLINE "$UUP_IMGMountPath\Windows\System32\Config\SYSTEM"
				
					INFO on Registry Keys (and GPO): https://getadmx.com/?Category=Windows_10_2016

					- Moved the Set-RegistryValue function to ScriptFunctions.ps1

					Had to use dark mode in here, as AutoUnattended.xaml seems wrong:
					<Themes>
						<WindowColor>Automatic</WindowColor>
						<SystemUsesLightTheme>false</SystemUsesLightTheme>
						<UWPAppsUseLightTheme>false</UWPAppsUseLightTheme>
					</Themes>
				#>
			
				# Keys are in ScriptVariables.ps1
				Write-Host "[$(_LINE_)] Processing offline registry (See '$CUSTOM_RegistryFile' for content)." -ForegroundColor Cyan
			
				#################################
				###       DEFAULT USER        ###
				#################################

				#region NTUSERDAT
				if (Test-Path -Path "$UUP_IMGMountPath\Users\default\ntuser.dat") {
					Write-Verbose "[$(_LINE_)] '$UUP_IMGMountPath\Users\default\ntuser.dat' found."

					$DEFAULTValues = $CUSTOM_RegistryValues | Where-Object { ($_.Type -match "DEFAULT") -and ($_.Enabled -eq "True") }

					if ($DEFAULTValues) {
						Write-Host "[$(_LINE_)] Applying custom registry keys to 'HKLM:\$CUSTOM_RegistryDefaultUserTEMP'"

						$null = REG LOAD "HKLM\$CUSTOM_RegistryDefaultUserTEMP" "$UUP_IMGMountPath\Users\default\ntuser.dat"

						if (Test-Path -Path "HKLM:\$CUSTOM_RegistryDefaultUserTEMP") {
							$DEFAULTValues | ForEach-Object {
								$tRegPath = $_.Path
								$tRegKey = $_.Key
								$tRegValue = $_.Value
								$tRegValueType = $_.ValueType
								#$tRegDesc = $_.Description
						
								# Check if the OneDrive Key is set.
								# Someone might want to install OneDrive.
								if ( ($tRegKey -ne "DisableFileSyncNGSC") -or (($tRegKey -eq "DisableFileSyncNGSC") -and ($CUSTOM_Settings.Removals.RemoveOneDrive -eq 1)) ) {
									Set-RegistryValue -Path "HKLM:\$CUSTOM_RegistryDefaultUserTEMP\$tRegPath" -Name $tRegKey -Value $tRegValue -ValueType $tRegValueType
								}
							}
						}
						else {
							Write-Host "[$(_LINE_)] HKLM:\$CUSTOM_RegistryDefaultUserTEMP not found" -BackgroundColor Black -ForegroundColor Red
						}			

						UnmountRegistry -OfflineRegistry "Registry::HKEY_LOCAL_MACHINE\$CUSTOM_RegistryDefaultUserTEMP"
					}
					else {
						Write-Verbose "[$(_LINE_)] '$UUP_IMGMountPath\Users\default\ntuser.dat' found, but nothing to add."
					}
				}
				else {
					Write-Host "[$(_LINE_)] '$UUP_IMGMountPath\Users\default\ntuser.dat' not found." -BackgroundColor Black -ForegroundColor Red
				}
				#endregion NTUSERDAT

				#################################
				###       DEFAULT HIVE        ###
				#################################

				#region DEFAULT
				if (Test-Path -Path "$UUP_IMGMountPath\Windows\System32\Config\DEFAULT") {
					Write-Verbose "[$(_LINE_)] '$UUP_IMGMountPath\Windows\System32\Config\DEFAULT' found."

					$DEFAULTValues = $CUSTOM_RegistryValues | Where-Object { ($_.Type -match "DEFAULT") -and ($_.Enabled -eq "True") }

					if ($DEFAULTValues) {
						Write-Host "[$(_LINE_)] Applying custom registry keys to 'HKLM:\$CUSTOM_RegistryDefaultSystemTEMP'"

						$null = REG LOAD "HKLM\$CUSTOM_RegistryDefaultSystemTEMP" "$UUP_IMGMountPath\Windows\System32\Config\DEFAULT"

						if (Test-Path -Path "HKLM:\$CUSTOM_RegistryDefaultSystemTEMP") {
							$DEFAULTValues | ForEach-Object {
								$tRegPath = $_.Path
								$tRegKey = $_.Key
								$tRegValue = $_.Value
								$tRegValueType = $_.ValueType
								#$tRegDesc = $_.Description
						
								# Check if the OneDrive Key is set.
								# Someone might want to install OneDrive.
								if ( ($tRegKey -ne "DisableFileSyncNGSC") -or (($tRegKey -eq "DisableFileSyncNGSC") -and ($CUSTOM_Settings.Removals.RemoveOneDrive -eq 1)) ) {
									# setting verbose in case this did not get called??
									Set-RegistryValue -Path "HKLM:\$CUSTOM_RegistryDefaultSystemTEMP\$tRegPath" -Name $tRegKey -Value $tRegValue -ValueType $tRegValueType
								}
							}
						}
						else {
							Write-Host "[$(_LINE_)] HKLM:\$CUSTOM_RegistryDefaultSystemTEMP not found" -BackgroundColor Black -ForegroundColor Red
						}			

						UnmountRegistry -OfflineRegistry "Registry::HKEY_LOCAL_MACHINE\$CUSTOM_RegistryDefaultSystemTEMP"
					}
					else {
						Write-Verbose "[$(_LINE_)] '$UUP_IMGMountPath\Windows\System32\Config\DEFAULT' found, but nothing to add."
					}
				}
				else {
					Write-Host "[$(_LINE_)] '$UUP_IMGMountPath\Windows\System32\Config\DEFAULT' not found." -BackgroundColor Black -ForegroundColor Red
				}
				#endregion DEFAULT
			
				#################################
				###       SOFTWARE HIVE       ###
				#################################

				#region HKLM\SOFTWARE
				if (Test-Path -Path "$UUP_IMGMountPath\Windows\System32\Config\SOFTWARE") {
					Write-Verbose "[$(_LINE_)] '$UUP_IMGMountPath\Windows\System32\Config\SOFTWARE' found."

					$SOFTWAREValues = $CUSTOM_RegistryValues | Where-Object { ($_.Type -match "SOFTWARE") -and ($_.Enabled -eq "True") }

					if ($SOFTWAREValues) {
						Write-Host "[$(_LINE_)] Applying custom registry keys to 'HKLM:\$CUSTOM_RegistrySoftwareTEMP'"

						$null = REG LOAD "HKLM\$CUSTOM_RegistrySoftwareTEMP" "$UUP_IMGMountPath\Windows\System32\Config\SOFTWARE"

						if (Test-Path -Path "HKLM:\$CUSTOM_RegistrySoftwareTEMP") {
							$SOFTWAREValues | ForEach-Object {
								$tRegPath = $_.Path
								$tRegKey = $_.Key
								$tRegValue = $_.Value
								$tRegValueType = $_.ValueType
								#$tRegDesc = $_.Description

								# Check if the OneDrive Key is set.
								# Someone might want to install OneDrive.
								if ( ($tRegKey -ne "DisableFileSyncNGSC") -or (($tRegKey -eq "DisableFileSyncNGSC") -and ($CUSTOM_Settings.Removals.RemoveOneDrive -eq 1)) ) {
									Set-RegistryValue -Path "HKLM:\$CUSTOM_RegistrySoftwareTEMP\$tRegPath" -Name $tRegKey -Value $tRegValue -ValueType $tRegValueType
								}
							}
						}
						else {
							Write-Host "[$(_LINE_)] HKLM:\$CUSTOM_RegistrySoftwareTEMP not found" -BackgroundColor Black -ForegroundColor Red
						}			

						UnmountRegistry -OfflineRegistry "Registry::HKEY_LOCAL_MACHINE\$CUSTOM_RegistrySoftwareTEMP"
					}
					else {
						Write-Verbose "[$(_LINE_)] '$UUP_IMGMountPath\Windows\System32\Config\SOFTWARE' found, but nothing to add."
					}
				}
				else {
					Write-Host "[$(_LINE_)] '$UUP_IMGMountPath\Windows\System32\Config\SOFTWARE' not found." -BackgroundColor Black -ForegroundColor Red
				}
				#endregion HKLM\SOFTWARE

				#################################
				###        SYSTEM HIVE        ###
				#################################
			
				#region HKLM\SYSTEM
				# "New Network Found" could bet set here, but this was not working for me.
				# Did this via unattended.xml, source: https://community.spiceworks.com/topic/1368478-windows-10-mdt-network-discovery
				if (Test-Path -Path "$UUP_IMGMountPath\Windows\System32\Config\SYSTEM") {
					Write-Verbose "[$(_LINE_)] '$UUP_IMGMountPath\Windows\System32\Config\SYSTEM' found."

					$SYSTEMValues = $CUSTOM_RegistryValues | Where-Object { ($_.Type -match "SYSTEM") -and ($_.Enabled -eq "True") }

					if ($SYSTEMValues) {
						Write-Host "[$(_LINE_)] Applying custom registry keys to 'HKLM:\$CUSTOM_RegistrySystemTEMP'"

						$null = REG LOAD "HKLM\$CUSTOM_RegistrySystemTEMP" "$UUP_IMGMountPath\Windows\System32\Config\SYSTEM"

						if (Test-Path -Path "HKLM:\$CUSTOM_RegistrySystemTEMP") {
							$SYSTEMValues | ForEach-Object {
								$tRegPath = $_.Path
								$tRegKey = $_.Key
								$tRegValue = $_.Value
								$tRegValueType = $_.ValueType
								#$tRegDesc = $_.Description
						
								# Check if the OneDrive Key is set.
								# Someone might want to install OneDrive.
								if ( ($tRegKey -ne "DisableFileSyncNGSC") -or (($tRegKey -eq "DisableFileSyncNGSC") -and ($CUSTOM_Settings.Removals.RemoveOneDrive -eq 1)) ) {
									Set-RegistryValue -Path "HKLM:\$CUSTOM_RegistrySystemTEMP\$tRegPath" -Name $tRegKey -Value $tRegValue -ValueType $tRegValueType
								}
							}
						}
						else {
							Write-Host "[$(_LINE_)] HKLM:\$CUSTOM_RegistrySystemTEMP not found" -BackgroundColor Black -ForegroundColor Red
						}			

						UnmountRegistry -OfflineRegistry "Registry::HKEY_LOCAL_MACHINE\$CUSTOM_RegistrySystemTEMP"
					}
					else {
						Write-Verbose "[$(_LINE_)] '$UUP_IMGMountPath\Windows\System32\Config\SYSTEM' found, but nothing to add."
					}
				}
				else {
					Write-Host "[$(_LINE_)] There are not registry values to apply to '$UUP_IMGMountPath\Windows\System32\Config\SYSTEM'." -BackgroundColor Black -ForegroundColor Red
				}
				#endregion HKLM\SYSTEM
			} # /end !$SkipRegTweaks
			#endregion Registry
												
			# Adding features with Source could result in a DISM command not being executed
			# as there is a "pending command" that needs to be finished first.
			# DISM won't tell, but i guess it's the package that DISM needs to add to the index.

			#Write-Host "[$(_LINE_)] DISM Cleanup" -ForegroundColor Yellow
			#DISM.exe /English /Image:$UUP_IMGMountPath /Cleanup-Image /StartComponentCleanup /ResetBase

			#region RESETBASE after Custom
			# Is reset base after updates required? Let's test that and then do it.
			# TODO: Test if I need to create a function for this!?
			Write-Verbose "[$(_LINE_)] CleanUp /Analyze of '$UUP_IMGMountPath' (Started: $(Get-Date -Format "HH:mm:ss"))."
			$DISM_CUResult = DISM /Image:$UUP_IMGMountPath /Cleanup-Image /AnalyzeComponentStore /English /LogPath:$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_cleanup_image_analyze_i$Index.log
		
			# Error on CleanUp /Analyze needs to be fixed.
			# Unmounting in same progress.
			if ($LASTEXITCODE -ne 0) {
				Write-Host "[$(_LINE_)] LASTEXITCODE: $LASTEXITCODE (0x$([System.Convert]::ToString($LASTEXITCODE, 16))). Please fix errors and re-start. Unmounting Image." -BackgroundColor Black -ForegroundColor Red
				DISM /UnMount-Wim /MountDir:$UUP_IMGMountPath /Discard /English /LogPath:$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_unmount_os_i$Index.log
				DismLog -ExitCode $LASTEXITCODE -Operation "Unmount: $WIM_OriginalFilePath`:$MountingIndexNumber | $UUP_IMGMountPath" -Line $(_LINE_)
				return
			}

			# Component Store Cleanup Recommended : Yes
			if (!$DISM_CUResult) {
				Write-Host "[$(_LINE_)] Nothing recommended? I don't think so ($DISM_CUResult)." -ForegroundColor Red
				return
			}
			#$DISM_CURecommended = ($DISM_CUResult | Select-String "Component Store Cleanup Recommended").ToString().Split(":")[1].Trim() -eq "Yes"
			if ($DISM_CURecommendedBool) {
				Write-Host "[$(_LINE_)] CleanUp of '$UUP_IMGMountPath' because of recommendation `"$DISM_CURecommendedBool`" (Started: $(Get-Date -Format "HH:mm:ss"))."
				DISM /Image:$UUP_IMGMountPath /Cleanup-Image /StartComponentCleanup /ResetBase /SPSuperseded /Quiet /NoRestart /English /LogPath:$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_cleanup_i$Index.log
			}
			else {
				Write-Verbose "[$(_LINE_)] No need for CleanUp of '$UUP_IMGMountPath'."
			}
			#endregion RESETBASE after Custom

			# Just in case it is still pending
			$Count_Cleanup = 0
			#Dism /English /Image:$UUP_IMGMountPath /Cleanup-Image /StartComponentCleanup /ResetBase
			while ($Result = Dism /Image:$UUP_IMGMountPath /Get-Features /Format:Table /English | Select-String "pending") {
				$Count_Cleanup++
				Write-Verbose "[$(_LINE_)] Waiting for pending dism command (Message: '$Result')"
				Start-Sleep -Seconds 2

				if ($Count_Cleanup -ge $DEF_MAX_ITERATIONS) {
					break
				}
			}

			#region SetupFeatures
			if (!$SkipFeatures) {
				if (!$SkipCustom_RemoveFeatures) {
					Write-Host "[$(_LINE_)] Removing $($SkipCustom_RemoveFeatures.Count) features"

					# Removing Features not needed.
					# See params for standard features I like to remove.
					$CustomFeatureCount = 0
					foreach ($tFeature in $DisableOptionalFeatures) {
						$CustomFeatureCount++

						if ($null = Get-WindowsOptionalFeature -Path $UUP_IMGMountPath -FeatureName $tFeature -Verbose:$false) {
							Write-Host "[$(_LINE_)] [$CustomFeatureCount/$($DisableOptionalFeatures.Count)] Removing Feature '$tFeature'"
							try {
								# Enabling Features uses Source when nothing found.
								# Source only contains "Internet Explorer" and ".NETFx3.5"
								$null = Disable-WindowsOptionalFeature -Path $UUP_IMGMountPath -FeatureName $tFeature -Verbose:$false -LogPath "$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_optionalfeature_d_i$Index.log"
								Write-Verbose "[$(_LINE_)] 'LASTEXITCODE': $LASTEXITCODE (0x$([System.Convert]::ToString($LASTEXITCODE, 16)))"
								if ($LASTEXITCODE -ne 0) {
									Write-Host "[$(_LINE_)] 'LASTEXITCODE': $LASTEXITCODE (0x$([System.Convert]::ToString($LASTEXITCODE, 16)))" -BackgroundColor Black -ForegroundColor Red
								}

								$Success = $true
							}
							catch {
								# NetFX might not work (needs files)
								Write-Host "[$(_LINE_)] Error trying to remove feature '$tFeature': $($_.Exception.Message)" -BackgroundColor Black -ForegroundColor Red
							}
						}
						else {
							Write-Host "[$(_LINE_)] No feature '$tFeature' found to remove. Might be better than expected." -BackgroundColor Black -ForegroundColor Red
							$null = Get-WindowsOptionalFeature -Path $UUP_IMGMountPath -FeatureName "*$tFeature*" -ErrorAction SilentlyContinue -Verbose:$false # want to see if something can be found.
						}
					}
				}

				if (!$SkipCustom_AddFeatures) {
					# These are features I like a lot.
					# Some of them might not be added in Home or Pro.
					Write-Host "[$(_LINE_)] Adding features"

					# See the params for features.
					$CustomFeatureCount = 0
					foreach ($tFeature in $EnabledOptionalFeatures) {
						$CustomFeatureCount++

						if ($null = Get-WindowsOptionalFeature -Path $UUP_IMGMountPath -FeatureName $tFeature -Verbose:$false) {
							Write-Host "[$(_LINE_)] [$CustomFeatureCount/$($EnabledOptionalFeatures.Count)] Adding: '$tFeature'"
							try {
								# Enabling Features uses Source when nothing found.
								# Source from ISO only contains "Internet Explorer" and ".NETFx3.5"
								$null = Enable-WindowsOptionalFeature -Path $UUP_IMGMountPath -FeatureName $tFeature -Source "$LatestWindowsImagePath\sxs" -Verbose:$false -LogPath "$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_optionalfeature_e_i$Index.log"
								Write-Verbose "[$(_LINE_)] 'LASTEXITCODE': $LASTEXITCODE (0x$([System.Convert]::ToString($LASTEXITCODE, 16)))"
								if ($LASTEXITCODE -ne 0) {
									Write-Host "[$(_LINE_)] 'LASTEXITCODE': $LASTEXITCODE (0x$([System.Convert]::ToString($LASTEXITCODE, 16)))" -BackgroundColor Black -ForegroundColor Red
								}

								# I could also just add the package, to have the POSSIBILITY of enabling this feature...
								#DISM /Image:$UUP_IMGMountPath /Enable-Feature /FeatureName:NetFx3 /All /LimitAccess /Source:"$IMAGE_DriveLetter`:\sources\sxs"
								#DISM /Image:$UUP_IMGMountPath /Add-Capability /CapabilityName:NetFx3~~~~ /Source:"$IMAGE_DriveLetter`:\sources\sxs"
								#DISM /Image:$UUP_IMGMountPath /Add-Package /PackagePath:"$IMAGE_DriveLetter`:\sources\sxs\*$tFeature*.cab
								$Success = $true
							}
							catch {
								# NetFX might not work (needs files)
								Write-Host "[$(_LINE_)] Error while adding Feature '$tFeature' with optional Source '$LatestWindowsImagePath\sxs': $($_.Exception.Message)" -BackgroundColor Black -ForegroundColor Red
							}

							# Should never be run as the PowerShell-Command does everything needed.
							# If the command was not successfull, DISM will be run.
							if (!$Success) {
								try {
									Write-Verbose "[$(_LINE_)] DISM /Image:$UUP_IMGMountPath /Enable-Feature /FeatureName:$tFeature /All /LimitAccess /Source:$LatestWindowsImagePath\sxs"
									DISM /Image:$UUP_IMGMountPath /Enable-Feature /FeatureName:$tFeature /All /LimitAccess /Source:$LatestWindowsImagePath\sxs
									# TODO: Log Error Code
								}
								catch {
									Write-Host "[$(_LINE_)] Error while adding Feature '$tFeature' with DISM: $($_.Exception.Message)" -BackgroundColor Black -ForegroundColor Red
								}
							}
						}
						else {
							# To verify, that this will never be shown make sure that the "OptionalFeature" does exist!
							Write-Host "[$(_LINE_)] No feature `"$tFeature`" found." -ForegroundColor Red
							$null = Get-WindowsOptionalFeature -Path $UUP_IMGMountPath -FeatureName "*$tFeature*" -ErrorAction SilentlyContinue -Verbose:$false # want to see if something can be found.
						}
					} # /end foreach loop
				} # /end if add feature
			} # /end Custom Features
			#endregion SetupFeatures

			# 
			# RSAT has moved. Cya.
			#

			#region StartMenu
			if (!$SkipCustom_StartLayout) {
				Write-Host "[$(_LINE_)] Injecting pre-created StartMenuLayout.xml"

				#$LayoutFile = "$PSScriptRoot\Includence\tools\00._Scripts\StartMenu\CustomStartMenuLayout.xml"
				$LayoutFile = "$PSScriptRoot\Customizations\01._ImageImport\tools\00._Scripts\StartMenu\CustomStartMenuLayout.xml"
				if (Test-Path -Path $LayoutFile) {
					# This does not seem to work properly for Mounted Images
					# "did not resolve to a file" or similar errors. Copying instead.
					#Import-StartLayout -LayoutPath $LayoutFile -MountPath "$UUP_IMGMountPath\" -Verbose:$VerbosePreference
					$null = Copy-Item -LiteralPath $LayoutFile -Destination "$UUP_IMGMountPath\Users\Default\AppData\Local\Microsoft\Windows\Shell\LayoutModification.xml" -Force -Verbose:$VerbosePreference
				}
				else {
					Write-Host "[$(_LINE_)] File `"$LayoutFile`" not found. No start menu to apply." -ForegroundColor Red
				}
			}
			#endregion StartMenu

			<#
				I could do some finalize stuff for the image in "$UUP_IMGMountPath\Windows\Setup\Scripts\SetupComplete.cmd".
				More like adding that to the AutoUnattend.xml file (RunSynchronousCommand).

				Also also there are the "DefaultAppAssociations";
				But I have not installed any software in the image (use case!) so this might not be a good option.
				We have SCCM, so i know ways to handle it here. And i don't think it's vital for private users.
				Added PatchMyPC inside \InsertImage. Anyone can edit the config of that, so you can install standard software after install.

				#Write-Host "+Default Apps" -ForegroundColor Yellow
				#Dism /English /Image:$UUP_IMGMountPath /Get-DefaultAppAssociations
				# Hm, maybe: Dism /English /Online /Export-DefaultAppAssociations:"F:\AppAssociations.xml"
				# Dism /English /Image:$UUP_IMGMountPath /Get-DefaultAppAssociations
				# Dism /English /Image:$UUP_IMGMountPath /Remove-DefaultAppAssociations
				# Dism /English /Image:$UUP_IMGMountPath /Import-DefaultAppAssociations:F:\AppAssociations.xml
			#>

			# I could test for resetbase here, but we already did this.
			# Most of the time I tested this it was not neccessary.

			# TODO: REMOVE ME!?
			Write-Verbose "[$(_LINE_)] TEST_CUSTOM_END: CleanUp /Analyze of '$UUP_IMGMountPath' (Started: $(Get-Date -Format "HH:mm:ss"))."
			#DISM /Image:$UUP_IMGMountPath /Cleanup-Image /AnalyzeComponentStore /English /LogPath:$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_cleanup_image_analyze_i$Index.log
			ResetBase -Line "$(_LINE_)"
		}
		#endregion Customization
	
		#region Final Unmount and Cleanup
		Write-Host "[$(_LINE_)] Unmount and CleanUp (Started: $(Get-Date -Format "HH:mm:ss"))"

		# Unmount and cleanup
		Write-Verbose "[$(_LINE_)] Unmounting '$UUP_IMGMountPath'."
		DISM /UnMount-Wim /MountDir:$UUP_IMGMountPath /Commit /Quiet /NoRestart /English /LogPath:$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_unmount_os_i$Index.log
		DismLog -ExitCode $LASTEXITCODE -Operation "UnMount" -Line $(_LINE_)

		# Clean image leftovers
		Write-Verbose "[$(_LINE_)] CleanUp leftover or stale DISM files."
		DISM /CleanUp-Wim /Quiet /NoRestart /English /LogPath:$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_cleanup_os_i$Index.log
		DismLog -ExitCode $LASTEXITCODE -Operation "CleanUp" -Line $(_LINE_)
		#endregion Final Unmount and Cleanup

		# Check for multiple ExitCodes
		if ($LASTEXITCODE -eq 0) {
			#$WIM_InstallationCount++
			Write-Host "[$(_LINE_)] LASTEXITCODE: $LASTEXITCODE (0x$([System.Convert]::ToString($LASTEXITCODE, 16)))" -ForegroundColor DarkGray
		}
		else {
			Write-Host "[$(_LINE_)] LASTEXITCODE: $LASTEXITCODE (0x$([System.Convert]::ToString($LASTEXITCODE, 16)))" -BackgroundColor Black -ForegroundColor Red
		}
	} # /end index loop
} # /end image file loop

# Copy files to implement into ISO in the extracted ISO path.
if (!$SkipIncludingAdditionalFiles) {
	# Want something in the ISO? Place it inside of \Includence
	# Autounattended.xml and InstallDrive.tag will be in there!
	Write-Host "[$(_LINE_)] Adding content to ISO" -ForegroundColor Yellow
	ROBOCOPY $CUSTOM_ImportFolder $ISOPathFullName /E /R:1 /W:10 /TEE /Log+:"$env:TEMP\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_robocopy.log"
}

$EndTime = Get-Date
Write-Host "STEP3: Ended at $(Get-Date -Format "dd.MM.yy HH:mm:ss")"

$TimeSpan = (New-TimeSpan -Start $StartTime -End $EndTime) -join ";"
Write-Host "STEP3: Duration: $TimeSpan"

ScriptCleanUP -StopTranscript