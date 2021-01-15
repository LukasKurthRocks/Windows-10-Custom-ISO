##Requires -RunAsAdministrator
##Requires -Version 5.0

param(
	$Languages = "de-de|sv-se|en-us|fr-fr|hu-hu",
	#$Languages = "sv-se",
	#$Languages,
	$FODs = "RSAT",
	#$FODs,
	#[switch]$ListAllFeatures
	[switch]$SkipCustomization,
	[switch]$SkipUpdates
)

# If needed for older Scripts ($PSScriptRoot is > v3)
#if (!($PSScriptRoot)) {
#	$PSScriptRoot = (Split-Path $MyInvocation.MyCommand.Path)
#}

Start-Transcript -Path "$env:TEMP\w10iso_fodinjector_$(Get-Date -Format "yyMMdd-HHmmss.fffffff").txt"

$StartTime = Get-Date
Write-Host "STEP2: Started at $(Get-Date -Format "dd.MM.yy HH:mm:ss")"

#region Import Scripts
Write-Verbose "Importing additional functionalities" -Verbose
$IncludeScriptPath = "$PSScriptRoot\include"
Get-ChildItem -Path $IncludeScriptPath -Filter "*.ps1" | ForEach-Object {
	Write-Verbose "+ $($_.Name)" -Verbose
	. $_.FullName
}
$IncludedFunctionNames = @("Test-URI", "Get-Handle")
$IncludedFunctionNames | ForEach-Object {
	if (!(Get-Command -Name "$_")) {
		Write-Host "Function `"$_`" not found." -ForegroundColor Red
		return
	}
}
#endregion Import Scripts

Write-Host "[$(_LINE_)] INFO: You can watch the DISM progress in '$UUP_FolderTemp\logs'." -BackgroundColor Black -ForegroundColor Cyan

#region CleanUp Mounted Paths
#TODO: $OverrideMountPath
#TODO: function ScriptStopped(){}
UnmountRegistry -OfflineRegistry "Registry::HKEY_LOCAL_MACHINE\OFFLINE"
Clear-MountPath -MountPath $UUP_ISOMountPath
#endregion CleanUp Mounted Paths

#
# So we have to check for the created ISO folder.
# We might have to check multiple locations.
#

# this is the path, if we would have moved.
# i am keeping this, but might not even use it again. We will see...
$AddtionalFeaturesPath = "$PSScriptRoot\data\Additional"
if (!(Test-Path -LiteralPath $AddtionalFeaturesPath)) {
	Write-Host "[$(_LINE_)] '$AddtionalFeaturesPath' not existing? Let's see." -BackgroundColor Black -ForegroundColor Yellow
	
	$AddtionalFeaturesPath = $UUP_DUMP_Aria_UUPs_Additional
	if (!(Test-Path -Path $AddtionalFeaturesPath)) {
		Write-Host "[$(_LINE_)] '$AddtionalFeaturesPath' not existing either. How can this be? Please check the scripts!" -BackgroundColor Black -ForegroundColor Red
		Stop-Transcript
		return
	}
}

Write-Verbose "[$(_LINE_)] Ok. Working with '$AddtionalFeaturesPath'" -Verbose

# First thing: Might need to check if we have an ISO, an extracted ISO path, or something else
# Going with the extracted ISO path.

if (!(Test-Path $UUP_FolderTemp)) {
	Write-Host "[$(_LINE_)] Sorry. Working with temp path for now, but '$UUP_FolderTemp' does not exist." -ForegroundColor Red
	Stop-Transcript
	return
}

# Adding this in the extracted ISO path.
$ExtractedISOFolders = Get-ChildItem -Path "$UUP_FolderTemp" -Recurse -ErrorAction SilentlyContinue | Where-Object { !$PSIsContainer -and $_.Name -match "install[.]wim" }
if (!$ExtractedISOFolders) {
	Write-Host "[$(_LINE_)] And now we do not have the extracted ISO folder. Please take a look if SkipISO has been selected (you know, the *.ini)." -ForegroundColor Red
	#$Error
	Stop-Transcript
	return
}

$FeatureFiles = Get-ChildItem -Path $AddtionalFeaturesPath -Recurse

# TODO: WriteProgress??
# TODO: Saving DISM in CSV or TXT??
# Hm, This can take a while. There are some files if you have selected more than one language.
# But i do not have a mathed to check for Capability Names otherwise.
# They could have at least but the RSAT in the cab file name, but... nah.
if (Test-Path -Path "$AddtionalFeaturesPath\DISM_Information.csv") {
	Write-Host "[$(_LINE_)] Importing saved DISM informations."
	$CapabilityInformations = Import-Csv -Path "$AddtionalFeaturesPath\DISM_Information.csv" -Delimiter ";" -Encoding UTF8
}
else {
	Write-Host "[$(_LINE_)] Gathering cabinet informations of $($FeatureFiles.Count) files (started @ $(Get-Date -Format "HH:mm:ss"))."
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
			$CapabilityInformation | Add-Member -MemberType NoteProperty -Name "CapabilityName" -Value $CapabilityName -Verbose
			$CapabilityInformation | Add-Member -MemberType NoteProperty -Name "FullName" -Value $CapabilityPath -Verbose
			$CapabilityInformation | Add-Member -MemberType NoteProperty -Name "AlternativeFullName" -Value $null -Verbose
			$CapabilityInformations += $CapabilityInformation
		}
	}

	$CapabilityInformations | Export-Csv -Path "$AddtionalFeaturesPath\DISM_Information.csv" -Delimiter ";" -Encoding UTF8 -NoTypeInformation
	Write-Host "[$(_LINE_)] Finished gathering of informations (finished @ $(Get-Date -Format "HH:mm:ss"))."
}

#$LanguageFeature_Files = $CapabilityInformations | Where-Object { ($_.CapabilityName -match "Language[.]UI") -and ($_.CapabilityName -match "$Languages") }
if ($Languages -and ![String]::IsNullOrEmpty($Languages) -and ![String]::IsNullOrEmpty($Languages)) {
	$LanguageFeature_Files = $CapabilityInformations | Where-Object { ($_.CapabilityName -match "Language") -and ($_.CapabilityName -match "$Languages") }
}
if ($FODs -and ![String]::IsNullOrEmpty($FODs) -and ![String]::IsNullOrEmpty($FODs)) {
	$OtherFeature_Files = $CapabilityInformations | Where-Object { ($_.CapabilityName -match "$FODs") }
}
if (!$LanguageFeature_Files) {
	Write-Host "[$(_LINE_)] No language feature found for '$Languages'." -BackgroundColor Black -ForegroundColor Red
}
if (!$OtherFeature_Files) {
	Write-Host "[$(_LINE_)] No features found for '$FODs'."  -BackgroundColor Black -ForegroundColor Red
}
if ($SkipUpdates) {
	# this is not neccessary bu recommended.
	Write-Host "[$(_LINE_)] Skipped injecting Updates." -BackgroundColor Black -ForegroundColor Yellow
}
if ($SkipCustomization) {
	# this is not neccessary!
	Write-Host "[$(_LINE_)] Skipped customization of Windows." -BackgroundColor Black -ForegroundColor Yellow
}
if (!$LanguageFeature_Files -and !$OtherFeature_Files -and $SkipCustomization -and $SkipUpdates) {
	Write-Host "[$(_LINE_)] Script finished, as there is nothing to do here." -ForegroundColor Red
	Stop-Transcript
	return
}

$InstallWIM_Directory = $ExtractedISOFolders.Directory
$InstallWIM_Location = "$InstallWIM_Directory\install.wim"
$WIMInfo = DISM /Get-WimInfo /WimFile:"$InstallWIM_Location" /English
if (!$WIMInfo) {
	Write-Host "[$(_LINE_)] No Windows Image File (WIM) Information" -ForegroundColor Red
	Stop-Transcript
	return
}

Write-Host "" # empty line
$IndexNumbers = $WIMInfo | Select-String "Index" | ForEach-Object {
	"$_".Split(":").Trim()[1]
}

$DISMSuccessRateLogFile = "$UUP_FolderTemp\logs\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_successrate.log"

# Lazy Additional Dism Logging Function
function DismLog {
	param(
		$ExitCode,
		$Operation,
		$Line
	)

	if (!(Test-Path -Path $DISMSuccessRateLogFile)) {
		"DISM Logging started. See '$UUP_FolderTemp\logs' for more informations. These logs will be purged on the next iteration." | `
			Out-File -LiteralPath $DISMSuccessRateLogFile -Encoding UTF8 -Append
	}
	
	# Format saved: dd.MM.yyyy
	Write-Verbose "[$Line] DISM exited with 'LASTEXITCODE': $ExitCode (0x$([System.Convert]::ToString($LASTEXITCODE, 16)))" -Verbose
	"[$(Get-Date -Format "HH:mm:ss")] [$Line] DISM Exited: $ExitCode`t$Operation" | Out-File -LiteralPath $DISMSuccessRateLogFile -Encoding UTF8 -Append
}

# Looping through all the indiezes inside of the windows image (WIM)
#$IndexNumbers | Select -First 1 | ForEach-Object {}
$IndexNumbers | ForEach-Object {
	Write-Host "[$(_LINE_)]======================================"
	Write-Host "[$(_LINE_)]          Mounting Index $_           "
	Write-Host "[$(_LINE_)]======================================"

	# Create temp iso folder
	#$tImageIndexMountPath = "$UUP_FolderTemp\ROCKS.ISOFOLDER"
	$tImageIndexMountPath = $UUP_ISOMountPath
	if (!(Test-Path -Path $tImageIndexMountPath)) {
		$null = New-Item -ItemType Directory -Path $tImageIndexMountPath -Verbose # -WhatIf
	}
	if (!(Test-Path -Path "$UUP_FolderTemp\logs")) {
		$null = New-Item -ItemType Directory -Path "$UUP_FolderTemp\logs" -Verbose
	}
 else {
		# flush them logs
		Get-ChildItem -Path "$UUP_FolderTemp\logs" -Filter "*.log" | ForEach-Object {
			$tLogFullName = $_.FullName
			$CheckCount = 0
			while ($CheckCount -lt 5) {
				try {
					Remove-Item -Path $tLogFullName -Verbose -ErrorAction Stop
					$CheckCount = 10
				}
				catch {
					Write-Host "[$(_LINE_)] Error removing '$tLogFullName': $($_.Exception.Message)" -BackgroundColor Black -ForegroundColor Red
					Write-Host "Trying to close handle on '$tLogFullName'"
					FindAndClose-Handle -SearchString $tLogFullName -Verbose
				}
				$CheckCount++
			}
		}
	}

	# Mounting Image
	DISM /Mount-Wim /WimFile:$InstallWIM_Location /Index:$_ /MountDir:$tImageIndexMountPath /English /LogPath:$UUP_FolderTemp\logs\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_mount_os_i$_.log
	DismLog -ExitCode $LASTEXITCODE -Operation "Mount: $InstallWIM_Location`:$_ | $tImageIndexMountPath" -Line $(_LINE_)
	#DISM /Image:C:\`$ROCKS.UUP\ROCKS.ISO /CleanUp-Image /RestoreHealth /English
	#DismLog -ExitCode $LASTEXITCODE -Operation "CleanUp + RestoreHealth" -Line _LINE_

	# Getting Information
	#DISM /Image:$tImageIndexMountPath /Get-Packages /English /LogPath:$UUP_FolderTemp\logs\$sDISMLogPrefix`_dism_packages.log
	#DismLog -ExitCode $LASTEXITCODE -Operation "Packages" -Line _LINE_

	# PowerShell might loop this, even if empty
	if ($LanguageFeature_Files) {
		# Adding all LanguagePacks selected and available
		$LanguageFeature_Files | ForEach-Object {
			# We need to have a variable for the language packs rename part.
			# Language features only getting added if they are named correctly (*rolling eyes*).
			if ($_.AlternativeFullName -and (Test-Path -Path $_.AlternativeFullName)) {
				Write-Verbose "[$(_LINE_)] '$($_.AlternativeFullName)' exists." -Verbose
				$FeatureFullName = $_.AlternativeFullName
			}
			elseif (Test-Path -Path $_.FullName -ErrorAction SilentlyContinue) {
				Write-Verbose "[$(_LINE_)] '$($_.FullName)' exists." -Verbose
				$FeatureFullName = $_.FullName
			}
			else {
				Write-Host "[$(_LINE_)] Neither '$($_.FullName)' nor '$($_.AlternativeFullName)' found. Plase take a look if one of those files exists." -BackgroundColor Black -ForegroundColor Red
				return
			}

			Write-Verbose "[$(_LINE_)] Adding $($_.CapabilityName)" -Verbose
			DISM /Image:$tImageIndexMountPath /Add-Package /PackagePath:$FeatureFullName /ignorecheck /English /LogPath:$UUP_FolderTemp\logs\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_addpack_$($_.CapabilityName).log # /quiet /norestart
			DismLog -ExitCode $LASTEXITCODE -Operation "Add: $FeatureFullName" -Line $(_LINE_)

			# DISM is such a pussy. It cannot add the language file if some 'words' are missing!?
			# So we try to add these to the filename and re-run DISM with the new name.
			# Error Code is -2146498529 (decimal) / 0x800F081F (hex).
			if ($LASTEXITCODE -eq "-2146498529") {
				# Renaming those files:
				#microsoft-windows-languagefeatures-basic-fr-fr-package-amd64
				#microsoft-windows-languagefeatures-handwriting-fr-fr-package-amd64
				#microsoft-windows-languagefeatures-texttospeech-fr-fr-package-amd64
				Write-Host "[$(_LINE_)] DISM returned error code '$LASTEXITCODE' (0x$([System.Convert]::ToString($LASTEXITCODE, 16))). We have to try the rename trick." -BackgroundColor Black -ForegroundColor Red
			
				# microsoft-windows-languagefeatures-texttospeech-fr-fr-package-amd64.cab
				$tFileName = Split-Path $_.FullName -Leaf
				$tFilePath = Split-Path $_.FullName

				# In case we would have "cab" and/or "esd".
				# Grabbing filename without extension and the extension itself.
				# microsoft-windows-languagefeatures-texttospeech-fr-fr-package-amd64
				$tFileExtension = [System.IO.Path]::GetExtension($tFileName)
				$tFileNameOnly = [System.IO.Path]::GetFileNameWithoutExtension($tFileName)

				# Splitting the base filename, so we can build the string ourself.
				$tSplittedFileName = $tFileNameOnly -split "-"

				# Building new file name: <microsoft-windows-languagefeatures-texttospeech-de-de-package~value~amd64~~.cab/.esd>
				# Length is 8, array starts at 0, so -2.
				$newFileName = $tSplittedFileName[0..($tSplittedFileName.Length - 2)] -join "-"
				$newFileName += "~31bf3856ad364e35~"
				$newFileName += $tSplittedFileName[$tSplittedFileName.Length - 1] # amd64
				$newFileName += "~~"
				$newFileName += $tFileExtension # .cab/.esd

				# This SHOULD NEVER break, as we have both filenames.
				# If the alternative filename does not exist, we select the original FullName.
				# (There would be somthing wrong, if none of them exists).
				try {
					$CapabilityInformations | Where-Object { $_.FullName -eq $FeatureFullName } | ForEach-Object {
						Write-Verbose "[$(_LINE_)] Changing CSV information..." -Verbose
						#$_.FullName = "$tFilePath\$newFileName"
						$_.AlternativeFullName = "$tFilePath\$newFileName"
					}
					$CapabilityInformations | Export-Csv -Path "$AddtionalFeaturesPath\DISM_Information.csv" -Delimiter ";" -Encoding UTF8 -NoTypeInformation
				}
				catch {
					Write-Host "[$(_LINE_)] Error: $($_.Exception.Message)" -BackgroundColor Black -ForegroundColor Red
					return
				}

				# Rename cab and re-run DISM process.
				# Should i possibly add the "/quiet" and "/norestart" although it's offline injection!?
				try {
					Write-Verbose "[$(_LINE_)] Renaming '$FeatureFullName' => '$newFileName'" -Verbose
					Rename-Item -LiteralPath $FeatureFullName -NewName "$newFileName" -ErrorAction Stop -Verbose
				
					Write-Verbose "[$(_LINE_)] Adding renamed '$newFileName'" -Verbose
					DISM /Image:$tImageIndexMountPath /Add-Package /PackagePath:"$($tFilePath)\$newFileName" /ignorecheck /English /LogPath:$UUP_FolderTemp\logs\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_addpack_$([System.IO.Path]::GetFileNameWithoutExtension($newFileName)).log
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
		} # /end language loop
	} # /end if language exists

	if ($OtherFeature_Files) {
		# Adding them RSAT and FOD packages is not as complicated as adding the LPs.
		# Some might not be added, but that should not be the problem.
		# TODO: Test this in an installation!!
		$OtherFeature_Files | ForEach-Object {
			$FeatureFullName = $_.FullName

			Write-Verbose "[$(_LINE_)] Adding $($_.CapabilityName)" -Verbose
			DISM /Image:$tImageIndexMountPath /Add-Package /PackagePath:$FeatureFullName /ignorecheck /English /LogPath:$UUP_FolderTemp\logs\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_addpack_$($_.CapabilityName).log
			DismLog -ExitCode $LASTEXITCODE -Operation "Add: $FeatureFullName" -Line $(_LINE_)
			if ($LASTEXITCODE -eq "2") {
				Write-Host "[$(_LINE_)] DISM returned error code '$LASTEXITCODE' (0x$([System.Convert]::ToString($LASTEXITCODE, 16))). File not found!? (FeaturePack: $FeatureFullName)." -BackgroundColor Black -ForegroundColor Red
			}
			elseif ($LASTEXITCODE -eq "-2146498529") {
				Write-Host "[$(_LINE_)] DISM returned error code '$LASTEXITCODE' (0x$([System.Convert]::ToString($LASTEXITCODE, 16))). Could not add package (FeaturePack: $FeatureFullName)." -BackgroundColor Black -ForegroundColor Red
			}
			elseif ($LASTEXITCODE -eq "87") {
				Write-Host "[$(_LINE_)] DISM returned error code '$LASTEXITCODE' (0x$([System.Convert]::ToString($LASTEXITCODE, 16))). There is some information missing (FeaturePack: '$FeatureFullName' " `
					"| Commands: /Image:$tImageIndexMountPath /Add-Package /PackagePath:'$FeatureFullName' /ignorecheck /English)." -BackgroundColor Black -ForegroundColor Red
			}
		} # /end FODs loop
	} # /end if FODs exists

	#region Updates
	if (!$SkipUpdates) {
		# Getting the updates I just downloaded.
		# MAYBE I can also implement updates from SCCM or WSUS?
		if (Test-Path -Path $UUP_DUMP_Aria_UUPs) {
			$Counter_Updates = 0 # Only Display
			$UpdateArray = Get-ChildItem -Path $UUP_DUMP_Aria_UUPs -Filter "*KB*" | Sort-Object -Property Name
			$UpdateArray | ForEach-Object {
				$UpdateName = $_.Name # CAB Name
				$UpdatePath = $_.FullName
				$Counter_Updates++

				$DISMInfo = [PSCustomObject]@{}
				$DISMBaseInfo = DISM /Image:$tImageIndexMountPath /Get-PackageInfo /PackagePath:$UpdatePath /English /LogPath:$UUP_FolderTemp\logs\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_checkpack_$UpdateName.log
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

				$UpdatePackageName = $UpdateName
				if ($dPackageID) {
					$UpdatePackageName = "$dPackageID | $dPackageDesc"
				}
				
				# i do not know how to test for aplicability yet...
				Write-Verbose "[$(_LINE_)] Package $Counter_Updates/$($UpdateArray.Count): Adding '$UpdatePackageName'" -Verbose
				#/IgnoreCheck
				DISM /Image:$tImageIndexMountPath /Add-Package /PackagePath:$UpdatePath /NoRestart /English /LogPath:$UUP_FolderTemp\logs\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_addpack_$UpdateName.log
				DismLog -ExitCode $LASTEXITCODE -Operation "Add: $UpdatePackageName" -Line $(_LINE_)

				# I do not really care if updates are not getting installed.
				# WSUS and SCCM will get them for me ;-)
				# Just displaying why THIS package did not get installed.
				if ($UpdatePackageName -match "OASIS") {
					#Expand -F:* $UpdateName.cab 'C:\$ROCKS.UUP\aria\UUPs\$UpdateName\' # create folder
					Write-Verbose "[$(_LINE_)] This might be a VR Update. Is 'Analog.Holographic' installed?" -Verbose
					
					# Analog.Holographic.Desktop~~~~0.0.1.0
					$CapName = ("" + (DISM /Image:$tImageIndexMountPath /Get-Capabilities /LimitAccess | Select-String "Anal")).Split(":")[1].Trim()
					$IsPresent = ("" + (Dism /Image:$tImageIndexMountPath /Get-CapabilityInfo /CapabilityName:$CapName /English | Select-String "State")).Split(":")[1].Trim()
					Write-Verbose "[$(_LINE_)] > '$CapName': $IsPresent" -Verbose
				}
			} # /end update array loop
		} # /end if update path exists
	} # /end skip updates
	#endregion Updates

	#region Customization
	# TODO: Copied from somwhere. We might have to split this too!?
	if (!$SkipCustomization) {
		# TODO: RENAME
		$MountPath = $UUP_ISOMountPath
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
		Write-Host "[$(_LINE_)] Removing OneDrive Setup" -ForegroundColor Yellow
		@(
			"$MountPath\Windows\System32\OneDriveSetup.exe"
			"$MountPath\Windows\SysWOW64\OneDriveSetup.exe"
		) | ForEach-Object {
			# I might want to rename another setup, who knows.
			$OneDriveSetupPath = $_
			$OneDriveSetupName = [System.IO.Path]::GetFileNameWithoutExtension($OneDriveSetupPath)

			if (Test-Path -Path $OneDriveSetupPath -ErrorAction SilentlyContinue) {
				try {
					# Access Denied-Error not thrown to catch. Stop SHOULD work...
					$null = Rename-Item -Path $OneDriveSetupPath -NewName "$OneDriveSetupName.bck" -Force -Verbose -ErrorAction Stop
				}
				catch {
					Write-Host "=======================================================" -BackgroundColor DarkRed -ForegroundColor White
					Write-Host "Force rename here, as i could not find out the problem." -BackgroundColor DarkRed -ForegroundColor White
					Write-Host "=======================================================" -BackgroundColor DarkRed -ForegroundColor White
								
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
		#endregion

		#region RemoveBloatware
		if (!$SkipAppXRemoval) {
			# From: https://github.com/W4RH4WK/Debloat-Windows-10
			Write-Host "[$(_LINE_)] Remove AppX Stuff" -ForegroundColor Yellow
			$apps = @(
				# default Windows 10 apps
				"Microsoft.3DBuilder"
				"Microsoft.Appconnector"
				"Microsoft.BingFinance"
				"Microsoft.BingNews"
				"Microsoft.BingSports"
				"Microsoft.BingTranslator"
				"Microsoft.BingWeather"
				#"Microsoft.FreshPaint"
				"Microsoft.Microsoft3DViewer"
				"Microsoft.MicrosoftOfficeHub"
				"Microsoft.MicrosoftSolitaireCollection"
				"Microsoft.MicrosoftPowerBIForWindows"
				"Microsoft.MinecraftUWP"
				#"Microsoft.MicrosoftStickyNotes"
				"Microsoft.NetworkSpeedTest"
				"Microsoft.Office.OneNote"
				#"Microsoft.OneConnect"
				"Microsoft.People"
				"Microsoft.Print3D"
				"Microsoft.SkypeApp"
				"Microsoft.Wallet"
				#"Microsoft.Windows.Photos"
				"Microsoft.WindowsAlarms"
				#"Microsoft.WindowsCalculator"
				"Microsoft.WindowsCamera"
				"microsoft.windowscommunicationsapps"
				"Microsoft.WindowsMaps"
				"Microsoft.WindowsPhone"
				"Microsoft.WindowsSoundRecorder"
				#"Microsoft.WindowsStore"
				"Microsoft.XboxApp"
				"Microsoft.XboxGameOverlay"
				"Microsoft.XboxGamingOverlay"
				"Microsoft.XboxSpeechToTextOverlay"
				"Microsoft.Xbox.TCUI"
				"Microsoft.ZuneMusic"
				"Microsoft.ZuneVideo"
    
				# Threshold 2 apps
				"Microsoft.CommsPhone"
				"Microsoft.ConnectivityStore"
				"Microsoft.GetHelp"
				"Microsoft.Getstarted"
				"Microsoft.Messaging"
				"Microsoft.Office.Sway"
				"Microsoft.OneConnect"
				"Microsoft.WindowsFeedbackHub"

				# Creators Update apps
				"Microsoft.Microsoft3DViewer"
				#"Microsoft.MSPaint"

				#Redstone apps
				"Microsoft.BingFoodAndDrink"
				"Microsoft.BingTravel"
				"Microsoft.BingHealthAndFitness"
				"Microsoft.WindowsReadingList"

				# Redstone 5 apps
				"Microsoft.MixedReality.Portal"
				"Microsoft.ScreenSketch"
				"Microsoft.XboxGamingOverlay"
				"Microsoft.YourPhone"

				# non-Microsoft
				"9E2F88E3.Twitter"
				"PandoraMediaInc.29680B314EFC2"
				"Flipboard.Flipboard"
				"ShazamEntertainmentLtd.Shazam"
				"king.com.CandyCrushSaga"
				"king.com.CandyCrushSodaSaga"
				"king.com.BubbleWitch3Saga"
				"king.com.*"
				"ClearChannelRadioDigital.iHeartRadio"
				"4DF9E0F8.Netflix"
				"6Wunderkinder.Wunderlist"
				"Drawboard.DrawboardPDF"
				"2FE3CB00.PicsArt-PhotoStudio"
				"D52A8D61.FarmVille2CountryEscape"
				"TuneIn.TuneInRadio"
				"GAMELOFTSA.Asphalt8Airborne"
				#"TheNewYorkTimes.NYTCrossword"
				"DB6EA5DB.CyberLinkMediaSuiteEssentials"
				"Facebook.Facebook"
				"flaregamesGmbH.RoyalRevolt2"
				"Playtika.CaesarsSlotsFreeCasino"
				"A278AB0D.MarchofEmpires"
				"KeeperSecurityInc.Keeper"
				"ThumbmunkeysLtd.PhototasticCollage"
				"XINGAG.XING"
				"89006A2E.AutodeskSketchBook"
				"D5EA27B7.Duolingo-LearnLanguagesforFree"
				"46928bounde.EclipseManager"
				"ActiproSoftwareLLC.562882FEEB491" # next one is for the Code Writer from Actipro Software LLC
				"DolbyLaboratories.DolbyAccess"
				"SpotifyAB.SpotifyMusic"
				"A278AB0D.DisneyMagicKingdoms"
				"WinZipComputing.WinZipUniversal"
				"CAF9E577.Plex"  
				"7EE7776C.LinkedInforWindows"
				"613EBCEA.PolarrPhotoEditorAcademicEdition"
				"Fitbit.FitbitCoach"
				"DolbyLaboratories.DolbyAccess"
				"Microsoft.BingNews"
				"NORDCURRENT.COOKINGFEVER"

				# apps which cannot be removed using Remove-AppxPackage
				#"Microsoft.BioEnrollment"
				#"Microsoft.MicrosoftEdge"
				#"Microsoft.Windows.Cortana"
				#"Microsoft.WindowsFeedback"
				#"Microsoft.XboxGameCallableUI"
				#"Microsoft.XboxIdentityProvider"
				#"Windows.ContactSupport"

				# apps which other apps depend on
				"Microsoft.Advertising.Xaml"
			)

			# Count just for me displaying the removals left
			$Count_AppRemoval = 0
			foreach ($app in $apps) {
				$Count_AppRemoval++
				Write-Host "[$(_LINE_)] [$Count_AppRemoval/$($Apps.Count)] Push removal of `"$app`"" -ForegroundColor DarkGray

				try {
					#Get-AppxPackage -Name $app -PackageTypeFilter | Remove-AppxPackage -AllUsers

					# All Users (-AllUsers) does not exist in MountedImages
					$null = Get-AppXProvisionedPackage -Path $MountPath | Where-Object DisplayName -eq $app | Remove-AppxProvisionedPackage
				}
				catch {
					Write-Host "[$(_LINE_)] Error: $($_.Exception.Message)" -ForegroundColor Red
				}
						
				# Manual via GridView!
				#Get-AppxProvisionedPackage -Path $MountPath | Out-GridView -PassThru | Remove-AppxProvisionedPackage
			} # /end of app loop
		} # /end of !$SkipAppXRemoval
						
		#endregion RemoveBloatware

		#region Registry
		if (!$SkipRegTweaks) {
			<# These hives can be loaded:
				# REG LOAD HKLM\DEFUSER "$MountPath\Users\default\ntuser.dat"
				# reg load HKLM\OFFLINE "$MountPath\Windows\System32\Config\SOFTWARE"
				# reg load HKLM\OFFLINE "$MountPath\Windows\System32\Config\DEFAULT"
				# reg load HKLM\OFFLINE "$MountPath\Windows\System32\Config\DRIVERS"
				# reg load HKLM\OFFLINE "$MountPath\Windows\System32\Config\SAM"
				# reg load HKLM\OFFLINE "$MountPath\Windows\System32\Config\SYSTEM"
				#
				# INFO: https://getadmx.com/?Category=Windows_10_2016
			#>
			function Set-RegistryValue {
				param($Path, $Name, $Value)

				# create "directory"
				if (!(Test-Path $Path)) { $null = New-Item -ItemType Directory -Force -Path $Path }
	
				# also testing if key exists
				$exists = Get-ItemProperty -Path "$Path" -Name "$Name" -ErrorAction SilentlyContinue
				if (($null -ne $exists) -and ($exists.Length -ne 0)) {
					try {
						$null = Set-ItemProperty $Path $Name $Value -Force -Verbose
					}
					catch {
						Write-Host "[$(_LINE_)] Error while Set-Item: $($_.Exception.Message)" -ForegroundColor Red
					}
					#return $true
				}
				else {
					try {
						$null = New-ItemProperty -Path "$Path" -Name "$Name" -Value $Value -Verbose
					}
					catch {
						Write-Host "[$(_LINE_)] Error while New-Item: $($_.Exception.Message)" -ForegroundColor Red
					}
					#return $false
				}
			}

			<#
				# DEFAULT USER HIVES!
				# Had to use dark mode in here, as AutoUnattended.xaml seems wrong:
				<Themes>
					<WindowColor>Automatic</WindowColor>
					<SystemUsesLightTheme>false</SystemUsesLightTheme>
					<UWPAppsUseLightTheme>false</UWPAppsUseLightTheme>
				</Themes>
				# TODO: Test @ work!
			#>

			#region NTUSERDAT
			# Maybe export to separate PS1?
			Write-Host "[$(_LINE_)] Load offline registry" -ForegroundColor Cyan
			<#
				# https://www.windowspro.de/wolfgang-sommergut/registry-offline-bearbeiten-regeditexe-powershell
				# [...] und wechselt auf dem Laufwerk des ausgeschalteten Windows in das Verzeichnis \windows\system32\config.
				# Die Dateien SOFTWARE, SYSTEM und SAM repr�sentieren die Datenbanken f�r HKLM\Software, HKLM\System und HKLM\Sam.
				# DEFAULT steht f�r HKCU\Default und NTUSER.DAT f�r HKEY_CURRENT_USER.
			#>
			if (Test-Path -Path "$MountPath\Users\default\ntuser.dat") {
				Write-Verbose "[$(_LINE_)] `"$MountPath\Users\default\ntuser.dat`" found." -Verbose

				# no return, could catch $LASTEXITCODE
				$null = REG LOAD HKLM\OFDEFUSR "$MountPath\Users\default\ntuser.dat"
							
				if (Test-Path -Path "HKLM:\OFDEFUSR") {
					# QuickEdit
					Set-RegistryValue -Path "HKLM:\OFDEFUSR\Console" -Name "QuickEdit" -Value 1

					# Explorer Tweaks
					Set-RegistryValue -Path "HKLM:\OFDEFUSR\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "LaunchTo" -Value 1          # QuickAccess => ThisPC
					Set-RegistryValue -Path "HKLM:\OFDEFUSR\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Value 1            # Show hidden files and folders
					Set-RegistryValue -Path "HKLM:\OFDEFUSR\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 0       # Show File Extensions
					Set-RegistryValue -Path "HKLM:\OFDEFUSR\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "AutoCheckSelect" -Value 1   # File Checkboxes
					Set-RegistryValue -Path "HKLM:\OFDEFUSR\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Start_ShowMyGames" -Value 0 # Don't add a Games shortcut to the start menu

					# DARK MODE FTW
					# Info: Looks like the dark mode settings get a reset after logon. Dunno why, and i don't want to search for this. Implemented a script for this.
					Set-RegistryValue -Path "HKLM:\OFDEFUSR\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "AppsUseLightTheme" -Value 0    # Does not work, gets a reset...
					Set-RegistryValue -Path "HKLM:\OFDEFUSR\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "SystemUsesLightTheme" -Value 0 # Dark Settings + Dark Explorer
								
					# Hide Taskbar Cortana on Default User
					Set-RegistryValue -Path "HKLM:\OFDEFUSR\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" -Name "SearchboxTaskbarMode" -Value 0

					# Startmenu and TaskBar Hacks - Part 1
					Set-RegistryValue -Path "HKLM:\OFDEFUSR\SOFTWARE\Policies\Microsoft\Windows\Explorer" -Name "NoPinningStoreToTaskbar" -Value 1 # Remove Windows Store from TaskBar
					Set-RegistryValue -Path "HKLM:\OFDEFUSR\SOFTWARE\Policies\Microsoft\Windows\Explorer" -Name "HideRecentlyAddedApps" -Value 1   # hide "recently added" in startmenu
					Set-RegistryValue -Path "HKLM:\OFDEFUSR\SOFTWARE\Policies\Microsoft\Windows\Explorer" -Name "HidePeopleBar" -Value 1           # hide contacts/people bar
																	
					# Startmenu and TaskBar Hacks - Part 2
					Set-RegistryValue -Path "HKLM:\OFDEFUSR\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoAutoTrayNotify" -Value 1        # Show All Symbols on Taskbar
					Set-RegistryValue -Path "HKLM:\OFDEFUSR\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoStartMenuMorePrograms" -Value 2 # Collapse Start Menu
					Set-RegistryValue -Path "HKLM:\OFDEFUSR\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoDesktopCleanupWizard" -Value 1  # No "Desktop Cleanup Wizard"
					Set-RegistryValue -Path "HKLM:\OFDEFUSR\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoInternetIcon" -Value 1          # No IE Icon
								
					# Disable People Bar
					Set-RegistryValue -Path "HKLM:\OFDEFUSR\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People" -Name "PeopleBand" -Value 0
					Set-RegistryValue -Path "HKLM:\OFDEFUSR\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People" -Name "TaskbarCapacity" -Value 0

					# Remove OneDriveSetup Hook
					if (Get-ItemProperty -Path "HKLM:\OFDEFUSR\Software\Microsoft\Windows\CurrentVersion\Run\" -Name "OneDrive" -ErrorAction SilentlyContinue) {
						$null = Remove-ItemProperty -Path "HKLM:\OFDEFUSR\Software\Microsoft\Windows\CurrentVersion\Run\" -Name "OneDrive" -ErrorAction SilentlyContinue -Verbose
					}

					# Add Office Dark Mode
					Set-RegistryValue -Path "HKLM:\OFDEFUSR\SOFTWARE\Microsoft\Office\16.0\Common" -Name "UI Theme" -Value 4
				}
				else {
					Write-Host "[$(_LINE_)] HKLM:\OFDEFUSR not found" -ForegroundColor Red
				}

				UnmountRegistry -OfflineRegistry "Registry::HKEY_LOCAL_MACHINE\OFDEFUSR"
			}
			else {
				Write-Host "[$(_LINE_)] `"$MountPath\Users\default\ntuser.dat`" not found." -ForegroundColor Red
			}
			#endregion NTUSERDAT

			#region DEFAULT
			# ntusers.dat for quick changes, this here is for HKEY_USERS\.DEFAULT
			if (Test-Path -Path "$MountPath\Windows\System32\Config\DEFAULT") {
				Write-Verbose "[$(_LINE_)] `"$MountPath\Windows\System32\Config\DEFAULT`" found." -Verbose

				$null = REG LOAD HKLM\OFDEFUSR "$MountPath\Windows\System32\Config\DEFAULT"
							
				if (Test-Path -Path "HKLM:\OFDEFUSR") {
					# QuickEdit
					Set-RegistryValue -Path "HKLM:\OFDEFUSR\Console" -Name "QuickEdit" -Value 1
									
					# Explorer Tweaks
					Set-RegistryValue -Path "HKLM:\OFDEFUSR\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "LaunchTo" -Value 1          # QuickAccess => ThisPC
					Set-RegistryValue -Path "HKLM:\OFDEFUSR\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Value 1            # Show hidden files and folders
					Set-RegistryValue -Path "HKLM:\OFDEFUSR\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 0       # Show File Extensions
					Set-RegistryValue -Path "HKLM:\OFDEFUSR\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "AutoCheckSelect" -Value 1   # File Checkboxes
					Set-RegistryValue -Path "HKLM:\OFDEFUSR\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Start_ShowMyGames" -Value 0 # Don't add a Games shortcut to the start menu

					# DARK MODE FTW
					# Info: Looks like the dark mode settings get a reset after logon (Default setting is right).
					# Dunno why, and i don't want to search for this (another key?). Implemented a script in \tools for this.
					Set-RegistryValue -Path "HKLM:\OFDEFUSR\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "AppsUseLightTheme" -Value 0    # Does not work, gets a reset...
					Set-RegistryValue -Path "HKLM:\OFDEFUSR\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "SystemUsesLightTheme" -Value 0 # Dark Settings + Dark Explorer

					# Hide Taskbar Cortana on Default User
					Set-RegistryValue -Path "HKLM:\OFDEFUSR\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" -Name "SearchboxTaskbarMode" -Value 0	

					# Startmenu and TaskBar Hacks - Part 1
					Set-RegistryValue -Path "HKLM:\OFDEFUSR\SOFTWARE\Policies\Microsoft\Windows\Explorer" -Name "NoPinningStoreToTaskbar" -Value 1 # Remove Windows Store from TaskBar
					Set-RegistryValue -Path "HKLM:\OFDEFUSR\SOFTWARE\Policies\Microsoft\Windows\Explorer" -Name "HideRecentlyAddedApps" -Value 1   # hide "recently added" in startmenu
					Set-RegistryValue -Path "HKLM:\OFDEFUSR\SOFTWARE\Policies\Microsoft\Windows\Explorer" -Name "HidePeopleBar" -Value 1           # hide contacts/people bar
																	
					# Startmenu and TaskBar Hacks - Part 2
					Set-RegistryValue -Path "HKLM:\OFDEFUSR\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoAutoTrayNotify" -Value 1        # Show All Symbols on Taskbar
					Set-RegistryValue -Path "HKLM:\OFDEFUSR\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoStartMenuMorePrograms" -Value 2 # Collapse Start Menu
					Set-RegistryValue -Path "HKLM:\OFDEFUSR\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoDesktopCleanupWizard" -Value 1  # No "Desktop Cleanup Wizard"
					Set-RegistryValue -Path "HKLM:\OFDEFUSR\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoInternetIcon" -Value 1          # No IE Icon

					# Disable People Bar
					Set-RegistryValue -Path "HKLM:\OFDEFUSR\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People" -Name "PeopleBand" -Value 0
					Set-RegistryValue -Path "HKLM:\OFDEFUSR\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People" -Name "TaskbarCapacity" -Value 0
								
					# Remove OneDriveSetup Hook
					if (Get-ItemProperty -Path "HKLM:\OFDEFUSR\Software\Microsoft\Windows\CurrentVersion\Run\" -Name "OneDrive" -ErrorAction SilentlyContinue) {
						$null = Remove-ItemProperty -Path "HKLM:\OFDEFUSR\Software\Microsoft\Windows\CurrentVersion\Run\" -Name "OneDrive" -ErrorAction SilentlyContinue -Verbose
					}

					# Add Office Dark Mode
					Set-RegistryValue -Path "HKLM:\OFDEFUSR\SOFTWARE\Microsoft\Office\16.0\Common" -Name "UI Theme" -Value 4
				}
				else {
					Write-Host "[$(_LINE_)] HKLM:\OFDEFUSR not found" -ForegroundColor Red
				}

				UnmountRegistry -OfflineRegistry "Registry::HKEY_LOCAL_MACHINE\OFDEFUSR"
			}
			else {
				Write-Host "[$(_LINE_)] `"$MountPath\Windows\System32\Config\DEFAULT`" not found." -ForegroundColor Red
			}
			#endregion DEFAULT

			<#
				# SOFTWARE HIVE
			#>

			#region HKLM\SOFTWARE
			if (Test-Path -Path "$MountPath\Windows\System32\Config\SOFTWARE") {
				Write-Verbose "[$(_LINE_)] `"$MountPath\Windows\System32\Config\SOFTWARE`" found." -Verbose
				$null = reg load HKLM\OFFLINE "$MountPath\Windows\System32\Config\SOFTWARE"

				if (Test-Path -Path "HKLM:\OFFLINE") {
					#$tReg = "HKLM:\OFFLINE\Policies\Microsoft\WindowsStore"
					#if (!(Test-Path $tReg)) {New-Item -ItemType Directory -Force -Path $tReg}
					#Set-ItemProperty "HKLM:\OFFLINE\Policies\Microsoft\WindowsStore" "AutoDownload" 2

					# Windows Store Auto Download (2 = always off; 4 = always on; delete = user choice)
					Set-RegistryValue -Path "HKLM:\OFFLINE\Policies\Microsoft\WindowsStore" -Name "AutoDownload" -Value 2

					# Prevents "Suggested Applications" returning
					#$tReg = "HKLM:\OFFLINE\Policies\Microsoft\Windows\CloudContent"
					#if (!(Test-Path $tReg)) {New-Item -ItemType Directory -Force -Path $tReg}
					#Set-ItemProperty "HKLM:\OFFLINE\Policies\Microsoft\Windows\CloudContent" "DisableWindowsConsumerFeatures" 1
					Set-RegistryValue -Path "HKLM:\OFFLINE\Policies\Microsoft\Windows\CloudContent" -Name "DisableWindowsConsumerFeatures" -Value 1

					#;When opening files with an unknown extension, dont prompt to 'Look for an app in the Store'
					Set-RegistryValue -Path "HKLM:\OFFLINE\Policies\Microsoft\Windows\Explorer" -Name "NoUseStoreOpenWith" -Value 1

					# No info like "new app x has been installed"
					Set-RegistryValue -Path "HKLM:\OFFLINE\Policies\Microsoft\Windows\Explorer" -Name "NoNewAppAlert" -Value 1
									
					# 4 = Download And Install, 3 Download, 2 = CheckOnly, 1 = NoCheck
					#Set-RegistryValue -Path "HKLM:\OFFLINE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto" -Name "AUOptions" -Value 3

					# ShutUp Cortana
					$tReg = "HKLM:\OFFLINE\Policies\Microsoft\Windows\Windows Search"
					#if (!(Test-Path $tReg)) {New-Item -ItemType Directory -Force -Path $tReg}
					#Set-ItemProperty "HKLM:\OFFLINE\Policies\Microsoft\Windows\Windows Search" "AllowCortana" 0
					Set-RegistryValue -Path $tReg -Name "AllowCortana" -Value 0
					Set-RegistryValue -Path $tReg -Name "AllowCortanaAboveLock" -Value 0
					Set-RegistryValue -Path $tReg -Name "BingSearchEnabled" -Value 0
					Set-RegistryValue -Path $tReg -Name "ConnectedSearchUseWeb" -Value 0
					Set-RegistryValue -Path $tReg -Name "DisableWebSearch" -Value 1
								
					$tReg = "HKLM:\OFFLINE\Microsoft\Windows Search"
					#if (!(Test-Path $tReg)) {New-Item -ItemType Directory -Force -Path $tReg}
					#Set-ItemProperty "HKLM:\OFFLINE\Microsoft\Windows Search" "AllowCortana" 0
					Set-RegistryValue -Path $tReg -Name "AllowCortana" -Value 0
					Set-RegistryValue -Path $tReg -Name "AllowCortanaAboveLock" -Value 0
					Set-RegistryValue -Path $tReg -Name "BingSearchEnabled" -Value 0
					Set-RegistryValue -Path $tReg -Name "ConnectedSearchUseWeb" -Value 0
					Set-RegistryValue -Path $tReg -Name "DisableWebSearch" -Value 1

					# No UAC prompt
					Set-RegistryValue -Path "HKLM:\OFFLINE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLUA" -Value 0
					Set-RegistryValue -Path "HKLM:\OFFLINE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin" -Value 0

					# Disable Logon Microsoft Message
					Set-RegistryValue -Path "HKLM:\OFFLINE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableFirstLogonAnimation" -Value 0
					Set-RegistryValue -Path "HKLM:\OFFLINE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "EnableFirstLogonAnimation" -Value 0

					# Start Menu Tweaks
					Set-RegistryValue -Path "HKLM:\OFFLINE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoStartMenuMorePrograms" -Value 2 # Collapse Start Menu

					# ?? Only when config in Computer Configuration >> Administrative Templates >> Start Menu and Taskbar.
					Set-RegistryValue -Path "HKLM:\OFFLINE\Policies\Microsoft\Windows\Explorer" -Name "HideRecentlyAddedApps" -Value 1 # Hide "Recently Added Apps" from Start Menu

					# Disable OneDrive FileSync
					Set-RegistryValue -Path "HKLM:\OFFLINE\Wow6432Node\Policies\Microsoft\Windows\OneDrive" -Name "DisableFileSyncNGSC" -Value 1
				}
				else {
					Write-Host "[$(_LINE_)] HKLM:\OFFLINE not found" -ForegroundColor Red
				}
							
				UnmountRegistry -OfflineRegistry "Registry::HKEY_LOCAL_MACHINE\OFFLINE"
			}
			else {
				Write-Host "[$(_LINE_)] `"$MountPath\Windows\System32\Config\SOFTWARE`" not found." -ForegroundColor Red
			}
			#endregion HKLM\SOFTWARE

			<#
				# SYSTEM HIVE
			#>

			#region HKLM\SYSTEM
			# Did this via unattended.xml, source: https://community.spiceworks.com/topic/1368478-windows-10-mdt-network-discovery
			$SkipREG_SYSTEM = $true
			if (!$SkipREG_SYSTEM) {
				if (Test-Path -Path "$MountPath\Windows\System32\Config\SYSTEM") {
					Write-Verbose "[$(_LINE_)] `"$MountPath\Windows\System32\Config\SYSTEM`" found." -Verbose
					$null = reg load HKLM\OFFLINE "$MountPath\Windows\System32\Config\SYSTEM"

					if (Test-Path -Path "HKLM:\OFFLINE") {
						# "New Network Found" Window Prompt

						<#
							# These settings do not work. If set, the windows setup will
							# never finish (BSOD: CONFIG INITIALIZATION FAILED).
						#>

						try {
							$null = New-Item -Path "HKLM:\OFFLINE\CurrentControlSet\Control\Network\NewNetworkWindowOff" -ItemType Directory -Force -Verbose
						}
						catch {
							Write-Host "Error with NewNetworkOff: $($_.Exception.Message)" -ForegroundColor Red
						}

						# ControlSet001 is loaded as "CurrentControlSet", this might be another problem.
						try {
							$null = New-Item -Path "HKLM:\OFFLINE\ControlSet001\Control\Network\NewNetworkWindowOff" -ItemType Directory -Force -Verbose
						}
						catch {
							Write-Host "Error with NewNetworkOff: $($_.Exception.Message)" -ForegroundColor Red
						}
								
						# This is just for me, so i can check in regedit if everything went fine.
						#Read-Host -Prompt "Safety Prompt"
					}
					else {
						Write-Host "[$(_LINE_)] HKLM:\OFFLINE not found" -ForegroundColor Red
					}
							
					UnmountRegistry -OfflineRegistry "Registry::HKEY_LOCAL_MACHINE\OFFLINE"
				}
				else {
					Write-Host "[$(_LINE_)] `"$MountPath\Windows\System32\Config\SYSTEM`" not found." -ForegroundColor Red
				}
			}
			else {
				Write-Host "[$(_LINE_)] Skipped REG_SYSTEM" -ForegroundColor Yellow
			}
			#endregion HKLM\SYSTEM
		} # /end !$SkipRegTweaks
		#endregion Registry
												
		<#
			# Adding features with Source could result in a DISM command not being executed
			# as there is a "pending command" that needs to be finished first.
			# DISM won't tell, but i guess it's the package that DISM needs to add to the index.
			# 
			# So, adding features is the LAST task. Huh.
			# If there is a way to add it without major saving stuff TELL ME!
		#>
		Write-Host "[$(_LINE_)] DISM Cleanup" -ForegroundColor Yellow
		DISM.exe /English /Image:$MountPath /Cleanup-Image /StartComponentCleanup /ResetBase

		# Just in case it is still pending
		$Count_Cleanup = 0
		while ($Result = Dism /English /Image:$MountPath /Cleanup-Image /StartComponentCleanup /ResetBase | Select-String "pending") {
			$Count_Cleanup++
			Write-Host "[$(_LINE_)] Waiting for pending dism command ($Result)"
			Start-Sleep -Seconds 2

			if ($Count_Cleanup -ge $DEF_MAX_ITERATIONS) {
				break
			}
		}

		#region SetupFeatures
		if (!$SkipFeatures) {
			Write-Host "[$(_LINE_)] Remove Features" -ForegroundColor Yellow

			<#
				# Features to remove.
				# - Nobody should use SMB1 anyway (can always re-add via optionalfeatures)
				# - I would like to remove the IE, but i might have to use it for stuff like IWR/CURL
			#>
			$featuresRemove = @(
				"SMB1Protocol"
				#"Internet-Explorer-Optional-amd64" # Internet-Explorer-Optional*
			)
			# TODO: Replace with foreach!
			$featuresRemove | ForEach-Object {
				$tFeature = $_
				if ($null = Get-WindowsOptionalFeature -Path $MountPath -FeatureName $tFeature) {
					Write-Host "[$(_LINE_)] Removing Feature `"$tFeature`"" -ForegroundColor Yellow
					try {
						# Enabling Features uses Source when nothing found.
						# Source only contains "Internet Explorer" and ".NETFx3.5"
						$null = Disable-WindowsOptionalFeature -Path $MountPath -FeatureName $tFeature

						#$Success = $true
					}
					catch {
						# NetFX might not work (needs files)
						Write-Host "[$(_LINE_)] Error trying to remove feature '$tFeature': $($_.Exception.Message)" -ForegroundColor Red
					}
				}
				else {
					Write-Host "[$(_LINE_)] No feature `"$tFeature`" found to remove. Might be better than expected." -ForegroundColor Red
					$null = Get-WindowsOptionalFeature -Path $MountPath -FeatureName "*$tFeature*" -ErrorAction SilentlyContinue # want to see if something can be found.
				}
			}

			# The features ME likes alot !?
			Write-Host "[$(_LINE_)] Add Features" -ForegroundColor Yellow
			$featuresAdd = @(
				"NetFx3" # just in case, we can always remove this. NetFX needs source files though...
				"Microsoft-Hyper-V-All"
				"TelnetClient"
				"Containers-DisposableClientVM" # Windows-Sandbox
				#"NTVDM"
			)
			$featuresAdd | ForEach-Object {
				$tFeature = $_
				if ($null = Get-WindowsOptionalFeature -Path $MountPath -FeatureName $tFeature) {
					Write-Host "[$(_LINE_)] Adding feature `"$tFeature`"" -ForegroundColor Yellow
					try {
						# Enabling Features uses Source when nothing found.
						# Source from ISO only contains "Internet Explorer" and ".NETFx3.5"
						$null = Enable-WindowsOptionalFeature -Path $MountPath -FeatureName $tFeature -Source "$InstallWIM_Directory\sxs"

						# We also just add the package, to have the POSSIBILITY of enabling this feature...
						#DISM /Image:$MountPath /Enable-Feature /FeatureName:NetFx3 /All /LimitAccess /Source:"$IMAGE_DriveLetter`:\sources\sxs"
						#DISM /Image:$MountPath /Add-Capability /CapabilityName:NetFx3~~~~ /Source:"$IMAGE_DriveLetter`:\sources\sxs"
						#DISM /Image:$MountPath /Add-Package /PackagePath:"$IMAGE_DriveLetter`:\sources\sxs\*$tFeature*.cab
						$Success = $true
					}
					catch {
						# NetFX might not work (needs files)
						Write-Host "[$(_LINE_)] Error while adding Feature '$tFeature' with optional Source '$InstallWIM_Directory\sxs': $($_.Exception.Message)" -ForegroundColor Red
					}

					# Should never be run as the PowerShell-Command does everything needed.
					# If the command was not successfull, DISM will be run.
					if (!$Success) {
						try {
							Write-Verbose "[$(_LINE_)] DISM /Image:$MountPath /Enable-Feature /FeatureName:$tFeature /All /LimitAccess /Source:$IMAGE_DriveLetter`:\sources\sxs" -Verbose
							DISM /Image:$MountPath /Enable-Feature /FeatureName:$tFeature /All /LimitAccess /Source:$IMAGE_DriveLetter`:\sources\sxs
							# TODO: Log Error Code
						}
						catch {
							Write-Host "[$(_LINE_)] Error while adding Feature '$tFeature' with DISM: $($_.Exception.Message)" -ForegroundColor Red
						}
					}
				}
				else {
					# To verify, that this will never be shown make sure that the "OptionalFeature" does exist!
					Write-Host "[$(_LINE_)] No feature `"$tFeature`" found." -ForegroundColor Red
					$null = Get-WindowsOptionalFeature -Path $MountPath -FeatureName "*$tFeature*" -ErrorAction SilentlyContinue # want to see if something can be found.
				}
			}
		}
		#endregion SetupFeatures
						
		# RSAT added before

		#region StartMenu
		if (!$SkipStartLayout) {
			#$LayoutFile = "$PSScriptRoot\Includence\tools\00._Scripts\StartMenu\CustomStartMenuLayout.xml"
			$LayoutFile = "$PSScriptRoot\w10_customize\01._InsertInImage\tools\00._Scripts\StartMenu\CustomStartMenuLayout.xml"
			if (Test-Path -Path $LayoutFile) {
				# This does not seem to work properly for Mounted Images
				# "did not resolve to a file" or similar errors. Copying instead.
				#Import-StartLayout -LayoutPath $LayoutFile -MountPath "$MountPath\" -Verbose
				$null = Copy-Item -LiteralPath $LayoutFile -Destination "$MountPath\Users\Default\AppData\Local\Microsoft\Windows\Shell\LayoutModification.xml" -Force -Verbose
			}
			else {
				Write-Host "File `"$LayoutFile`" not found. No start menu to apply." -ForegroundColor Red
			}
		}
		#endregion StartMenu

		<#
			# Could also add Language Packs here. Have to look out for them.
			# DISK Space is too low for now *sad*.
			# 
			# Also i could do some finalize stuff for the image in
			# "$MountPath\Windows\Setup\Scripts\SetupComplete.cmd".
			# More like adding that to the AutoUnattend.xml file (RunSynchronousCommand)
			# 
			# Also also there are the DefaultAppAssociations.
			# We haven't installed any software in the image (use case!),
			# so this might not be a good option.
			# We have SCCM, so i know ways to handle it here.
			# And i don't think it's vital for private users.
			# 
			#Write-Host "+Default Apps" -ForegroundColor Yellow
			#Dism /English /Image:$MountPath /Get-DefaultAppAssociations
			# Hm, maybe: Dism /English /Online /Export-DefaultAppAssociations:"F:\AppAssociations.xml"
			# Dism /English /Image:$MountPath /Get-DefaultAppAssociations
			# Dism /English /Image:$MountPath /Remove-DefaultAppAssociations
			# Dism /English /Image:$MountPath /Import-DefaultAppAssociations:F:\AppAssociations.xml
		#>
	}
	#endregion Customization
	
	#JIC
	UnmountRegistry -OfflineRegistry "Registry::HKEY_LOCAL_MACHINE\OFFLINE"

	# Unmount and cleanup
	DISM /UnMount-Wim /MountDir:$tImageIndexMountPath /Commit /English /LogPath:$UUP_FolderTemp\logs\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_unmount_os.log
	DismLog -ExitCode $LASTEXITCODE -Operation "UnMount" -Line $(_LINE_)
	
	# Clean Image
	DISM /CleanUp-Wim /English /LogPath:$UUP_FolderTemp\logs\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_cleanup_os.log
	DismLog -ExitCode $LASTEXITCODE -Operation "CleanUp" -Line $(_LINE_)

	# Remove temporary extracted ISO folder
	if (Test-Path -Path $tImageIndexMountPath) {
		#FindAndClose-Handle -SearchString "" -WhatIf
		$null = Remove-Item -Path $tImageIndexMountPath -Verbose -Recurse
	}
} # /end wim-image index number loop

#region Final Customization
if (!$SkipCustomization) {
	# TODO: Change variables $ImageInsertPath, $ImageInsertDestination, $InstallWIM_Directory...
	$ImageInsertPath = "$PSScriptRoot\w10_customize\01._InsertInImage"
	$ImageInsertDestination = Split-Path $InstallWIM_Directory

	# /MIR = /E (Unterverzeichnisse) und /PURGE (L�schen im Ziel)
	Robocopy $ImageInsertPath $ImageInsertDestination /COPYALL /E /R:5 /W:10 /LOG:"$env:TEMP\robcopy_$(Get-Date -Format "yyMMdd-HHmmss.fffffff").log" /TEE
}
#endregion Final Customization

#region CleanUp Mounted Paths
#TODO: $OverrideMountPath
#TODO: function ScriptStopped(){}
UnmountRegistry -OfflineRegistry "Registry::HKEY_LOCAL_MACHINE\OFFLINE"
Clear-MountPath -MountPath $UUP_ISOMountPath
#endregion CleanUp Mounted Paths

$EndTime = Get-Date
Write-Host "STEP2: Ended at $(Get-Date -Format "dd.MM.yy HH:mm:ss")"

$TimeSpan = (New-TimeSpan -Start $StartTime -End $EndTime) -join ";"
Write-Host "STEP2: Duration: $TimeSpan"

Stop-Transcript