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



# TODO:
List important variables from ScriptVariables.ps1
#>

param(
	# Windows Editions
	[Parameter(Mandatory=$true)]
	[ValidateSet(
		"Core",
		"CoreN",
		"Professional",
		"ProfessionalN",
		"CoreSingleLanguage",
		"ProfessionalWorkstation",
		"ProfessionalEducation",
		"Education",
		"Enterprise",
		"ServerRdsh",
		"IoTEnterprise",
		"ProfessionalWorkstationN",
		"ProfessionalEducationN",
		"EducationN",
		"EnterpriseN"
	)]
	$WindowsEditions,
	# TODO: Using this for our own install.wim files.
	# So i can have admin WIM (RSAT), business WIM, LP WIM and personal WIM files.
	$CustomWIMFileName = "install.wim"
)

# I put this here in case we need this
# Althoug a requirement is to have version 5.0
#if (!($PSScriptRoot)) {
#    $PSScriptRoot = (Split-Path $MyInvocation.MyCommand.Path)
#}

#Start-Transcript -Path "$env:TEMP\w10iso_uuploader_$(Get-Date -Format "yyMMdd-HHmmss.fffffff").txt"

#region Import Scripts
Write-Verbose "Importing additional functionalities" -Verbose
$ScriptImportFolder = "$PSScriptRoot\Scripts"
Get-ChildItem -Path $ScriptImportFolder -Filter "*.ps1" | ForEach-Object {
	Write-Verbose "+ $($_.Name)" -Verbose
	. $_.FullName
}
$IncludedFunctionNames = @("Clear-MountPath")
$IncludedFunctionNames | ForEach-Object {
	if(!(Get-Command -Name "$_")) {
		Write-Host "Function `"$_`" not found." -ForegroundColor Red
		return
	}
}
#endregion Import Script

#region Test for folders and stuff
if(!(Test-Path -Path $UUP_ISOMountPath -ErrorAction SilentlyContinue)) {
	$null = New-Item -ItemType Directory -Path $UUP_ISOMountPath -Verbose
}
#endregion

#region Wim Information
$ExtractedISO_WIMFile = Get-ChildItem -Path $UUP_AriaBaseDir -Recurse -ErrorAction SilentlyContinue | Where-Object { !$PSIsContainer -and $_.Name -match "install[.]wim" }
$ExtractedISO_WIMFullFileName = $ExtractedISO_WIMFile.FullName
$ExtractedISO_Path = Split-Path $ExtractedISO_WIMFile.FullName

if(!$ExtractedISO_Path) {
	Write-Host "[$(_LINE_)] And now we do not have the extracted ISO folder. Please take a look if SkipISO has been selected (you know, the *.ini)." -ForegroundColor Red
	Stop-Transcript
	return
}

# TODO: USE THIS!
# Copying this somewhere, so we can BUILD our own install.wim files
if(!(Test-Path -Path "$UUP_TempFolder\install.wim")) {
	Write-Verbose "[$(_LINE_)] " -Verbose

	# TODO: Remove the file later, or just the temp folder
	$null = Copy-Item -Path "$ExtractedISO_WIMFullFileName" -Destination "$UUP_TempFolder\install_standard.wim" -Verbose
}

$ExtractedISO_WIMInfo = Get-WIMInfo -SourcePath $ExtractedISO_Path
$ExtractedISO_WIMEditions = $ExtractedISO_WIMInfo.Edition 

Write-Host "[$(_LINE_)] Indizies on the image '$ExtractedISO_WIMFullFileName':"
$ExtractedISO_WIMInfo | Format-Table
#endregion WIM Information

# Core only exists once
if( ($ExtractedISO_WIMEditions -notmatch "Core") -and ($WindowsEditions -match "Core") ) {
	Write-Host "[$(_LINE_)] We can not add Core-versions ($($WindowsEditions -join ", ")) when Core|CoreN have been removed from the image." -BackgroundColor Black -ForegroundColor Red
	return
}

# TODO: Make copy of WIM?
# TODO: Create folders first

# only remove editions if installation succeeded.
$EditionInstalledCount = 0

# LOOP: Add Editions to WIM
# Removing double entries (what's the point anyway?)
$EditionCounter = 0
$WindowsEditions_Install = $WindowsEditions | Select-Object -Unique
foreach($Edition in $WindowsEditions_Install) {
	$EditionCounter++
	
	# Is there a better version comparing these editions?
	# Set-WindowsEdition will only set the edition if it exists
	# and (e.g.) Enterprise does not exist on CoreN.
	$EditionLastCharacter = $Edition[$Edition.Length - 1]
	$ISOWimInfoLastChar = $ExtractedISO_WIMInfo | Where-Object { $_.Edition[$_.Edition.Length -1] -ceq $EditionLastCharacter }

	if(!$ISOWimInfoLastChar) {
		Write-Verbose "[$(_LINE_)] [$EditionCounter/$($WindowsEditions_Install.Count)] Version cannot be installed, version mismatch. EditionChar: '$EditionLastCharacter' | WIMLastChar: '$ISOWimInfoLastChar' (Editions on WIM: $($ExtractedISO_WIMInfo.Edition -join ", "))" -Verbose
		Write-Host "[$(_LINE_)] To install '$Edition' we need an edition with '$EditionLastCharacter'." -BackgroundColor Black -ForegroundColor Red

		#$EditionInstalledSuccessful = $false
		#return
	} else {



		# Dism /Image:C:\test\offline /Get-CurrentEdition
		# Dism /Image:C:\test\offline /Set-Edition:Professional
		# Dism /MountDir:C:\test\offline /Unmount-Image /Commit
		if($ExtractedISO_WIMEditions -notcontains $Edition) {
			Write-Verbose "[$(_LINE_)] [$EditionCounter/$($WindowsEditions_Install.Count)] Adding Edition '$Edition'" -Verbose

			$MountingIndexInfo    = $ISOWimInfoLastChar | Select-Object -First 1
			$MountingIndexNumber  = $MountingIndexInfo.Index
			$MountingIndexArch    = $MountingIndexInfo.Architecture
			$MountingIndexEdition = $MountingIndexInfo.Edition
			$MountingIndexName    = $MountingIndexInfo.Name

			# Mount index
			Write-Verbose "[$(_LINE_)] Mounting '$ExtractedISO_WIMFullFileName' to '$UUP_ISOMountPath'." -Verbose
			DISM /Mount-Wim /WimFile:$ExtractedISO_WIMFullFileName /Index:$MountingIndexNumber /MountDir:$UUP_ISOMountPath /Quiet /NoRestart /English /LogPath:$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_mount_os.log
			DismLog -ExitCode $LASTEXITCODE -Operation "Mount: $ExtractedISO_WIMFullFileName`:$MountingIndexNumber | $UUP_ISOMountPath" -Line $(_LINE_)
			
			# Problem with error on mount needs to be fixed.
			# Unmounting in same progress.
			if($LASTEXITCODE) {
				Write-Host "[$(_LINE_)] LASTEXITCODE: $LASTEXITCODE" -BackgroundColor Black -ForegroundColor Red
				Write-Verbose "[$(_LINE_)] Please fix errors and re-start. Unmounting Image." -Verbose
				DISM /UnMount-Wim /MountDir:$UUP_ISOMountPath /Discard /English /LogPath:$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_unmount_os.log
				DismLog -ExitCode $LASTEXITCODE -Operation "Unmount: $ExtractedISO_WIMFullFileName`:$MountingIndexNumber | $UUP_ISOMountPath" -Line $(_LINE_)
				return
			}

			# Change version/edition and key of index
			$EditionKeyInfo = $WindowsKeyInformation | Where-Object { $_.Edition -eq $Edition }
			Write-Verbose "[$(_LINE_)] Installed Edition: $( (Get-WindowsEdition -Path $UUP_ISOMountPath).Edition ) | Possible Editions (on target): $( (Get-WindowsEdition -Path $UUP_ISOMountPath -Target).Edition -join ", " )" -Verbose
			#Get-WindowsEdition -Path $UUP_ISOMountPath
			#Write-Host "[$(_LINE_)] Changing Windows Edition from '$MountingIndexName' to '$($EditionKeyInfo.Name)' ($Edition)"
			#$null = Set-WindowsEdition -Edition $Edition -Path $UUP_ISOMountPath -Verbose # /ProductKey:
			#Get-WindowsEdition -Path $UUP_ISOMountPath
			#Write-Host "[$(_LINE_)] Installing generic key '$($EditionKeyInfo.GenKey)' for '$($EditionKeyInfo.Name)'"
			#$null = Set-WindowsProductKey -ProductKey $EditionKeyInfo.GenKey -Path $UUP_ISOMountPath -Verbose
			#Get-WindowsEdition -Path $UUP_ISOMountPath
			Write-Host "[$(_LINE_)] Changing Windows Edition from '$MountingIndexName' ($MountingIndexEdition) to '$($EditionKeyInfo.Name)' ($Edition) with key '$($EditionKeyInfo.GenKey)'."
			DISM /Image:$UUP_ISOMountPath /Set-Edition:$Edition /ProductKey:$($EditionKeyInfo.GenKey) /AcceptEULA /Quiet /NoRestart /LogPath:$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_edition.log
			DismLog -ExitCode $LASTEXITCODE -Operation "Edition and Key: $ExtractedISO_WIMFullFileName`:$MountingIndexNumber | $UUP_ISOMountPath | $Edition | $($EditionKeyInfo.GenKey)" -Line $(_LINE_)
			Write-Host "Edition: $((Get-WindowsEdition -Path $UUP_ISOMountPath).Edition)" -BackgroundColor Black -ForegroundColor Cyan
			
			# Problem with error on set-edition needs to be fixed.
			# Unmounting in same progress.
			if($LASTEXITCODE) {
				Write-Host "[$(_LINE_)] LASTEXITCODE: $LASTEXITCODE" -BackgroundColor Black -ForegroundColor Red
				Write-Verbose "[$(_LINE_)] Please fix errors and re-start. Unmounting Image." -Verbose
				DISM /UnMount-Wim /MountDir:$UUP_ISOMountPath /Discard /English /LogPath:$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_unmount_os.log
				DismLog -ExitCode $LASTEXITCODE -Operation "Unmount: $ExtractedISO_WIMFullFileName`:$MountingIndexNumber | $UUP_ISOMountPath" -Line $(_LINE_)
				return
			}

			# Customizations and stuff?
			# Customizing the editions in here might be to complicated.
			# Adding them in a different step!?

			# Dismount and save the changed image
			#DISM /UnMount-Wim /MountDir:$UUP_ISOMountPath /Commit /English /LogPath:$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_unmount_os.log
			#DISM /UnMount-Wim /MountDir:$UUP_ISOMountPath /Discard /English /LogPath:$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_unmount_os.log
			#Dism /Commit-Image /MountDir:$UUP_ISOMountPath /CheckIntegrity /Append
			if(Test-Path -Path "$ExtractedISO_Path\install_$Edition.wim") {
				$null = Remove-Item -Path "$ExtractedISO_Path\install_$Edition.wim" -Verbose
			}

			# DISM needs to commit the edition change
			Write-Verbose "[$(_LINE_)] Commit change on '$Edition'." -Verbose
			Dism /Commit-Image /MountDir:$UUP_ISOMountPath /English /Quiet /NoRestart /LogPath:$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_commit.log
			DismLog -ExitCode $LASTEXITCODE -Operation "Commit: $ExtractedISO_WIMFullFileName`:$MountingIndexNumber | $UUP_ISOMountPath" -Line $(_LINE_)
			Write-Host "Edition: $((Get-WindowsEdition -Path $UUP_ISOMountPath).Edition)" -BackgroundColor Black -ForegroundColor Cyan

			# fi imgex use this. This way is way to comlicated !?
			Write-Verbose "[$(_LINE_)] Saving in temp ('install_$Edition.wim')." -Verbose
			Dism /Export-Image /SourceImageFile:$ExtractedISO_WIMFullFileName /SourceIndex:$MountingIndexNumber /DestinationImageFile:"$ExtractedISO_Path\install_$Edition.wim" /DestinationName:"$($EditionKeyInfo.Name) ($MountingIndexArch)" /Compress:max /Bootable /CheckIntegrity /NoRestart /Quiet /English /LogPath:$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_export_os.log
			DismLog -ExitCode $LASTEXITCODE -Operation "Export: $ExtractedISO_WIMFullFileName`:$MountingIndexNumber | $UUP_ISOMountPath" -Line $(_LINE_)
			Write-Host "Edition: $((Get-WindowsEdition -Path $UUP_ISOMountPath).Edition)" -BackgroundColor Black -ForegroundColor Cyan
			
			Write-Verbose "[$(_LINE_)] Unmounting '$UUP_ISOMountPath'." -Verbose
			DISM /UnMount-Wim /MountDir:$UUP_ISOMountPath /Discard /Quiet /NoRestart /English /LogPath:$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_unmount_os.log
			DismLog -ExitCode $LASTEXITCODE -Operation "Unmount: $ExtractedISO_WIMFullFileName`:$MountingIndexNumber | $UUP_ISOMountPath" -Line $(_LINE_)

			Write-Verbose "[$(_LINE_)] Mounting '$ExtractedISO_Path\install_$Edition.wim' to '$UUP_ISOMountPath'." -Verbose
			DISM /Mount-Wim /WimFile:"$ExtractedISO_Path\install_$Edition.wim" /Index:1 /MountDir:$UUP_ISOMountPath /NoRestart /Quiet /English /LogPath:$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_mount_os.log
			DismLog -ExitCode $LASTEXITCODE -Operation "Mount: $ExtractedISO_WIMFullFileName`:$MountingIndexNumber | $UUP_ISOMountPath" -Line $(_LINE_)
			Write-Host "Edition: $((Get-WindowsEdition -Path $UUP_ISOMountPath).Edition)" -BackgroundColor Black -ForegroundColor Cyan

			Write-Verbose "[$(_LINE_)] Saving in normal ('install.wim')." -Verbose
			Dism /Export-Image /SourceImageFile:"$ExtractedISO_Path\install_$Edition.wim" /SourceIndex:$MountingIndexNumber /DestinationImageFile:$ExtractedISO_WIMFullFileName /DestinationName:"$($EditionKeyInfo.Name) ($MountingIndexArch)" /NoRestart /Quiet /English /LogPath:$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_export_os.log
			DismLog -ExitCode $LASTEXITCODE -Operation "Export: $ExtractedISO_WIMFullFileName`:$MountingIndexNumber | $UUP_ISOMountPath" -Line $(_LINE_)
			Write-Host "Edition: $((Get-WindowsEdition -Path $UUP_ISOMountPath).Edition)" -BackgroundColor Black -ForegroundColor Cyan
			
			Write-Verbose "[$(_LINE_)] Unmounting '$UUP_ISOMountPath'." -Verbose
			DISM /UnMount-Wim /MountDir:$UUP_ISOMountPath /Discard /Quiet /NoRestart /English /LogPath:$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_unmount_os.log
			DismLog -ExitCode $LASTEXITCODE -Operation "Unmount: $ExtractedISO_WIMFullFileName`:$MountingIndexNumber | $UUP_ISOMountPath" -Line $(_LINE_)
			
			if(Test-Path -Path "$ExtractedISO_Path\install_$Edition.wim") {
				$null = Remove-Item -Path "$ExtractedISO_Path\install_$Edition.wim" -Verbose
			}
			
			# Rename the new windows edition to what it actually is.
			#wimlibex rename edition
			#imagex /info img_file [img_number or img_name] [new_name/edition] [new_desc]
			#imagex /info install.wim 1 "$Edition" "$($EditionKeyInfo.Name)"
			#Dism /Export-Image /SourceImageFile:install.wim /SourceIndex:$MountingIndexNumber /DestinationImageFile:install_$Edition.wim /DestinationName:"$($EditionKeyInfo.Name)"

			# Check for multiple ExitCodes
			if($LASTEXITCODE -eq 0) {
				$EditionInstalledCount++
				Write-Host "LASTEXITCODE: $LASTEXITCODE" -ForegroundColor DarkGray
			} else {
				Write-Host "LASTEXITCODE: $LASTEXITCODE" -BackgroundColor Black -ForegroundColor Red
			}
		} else {
			$EditionInstalledCount++
			Write-Host "[$(_LINE_)] [$EditionCounter/$($WindowsEditions_Install.Count)] '$Edition' exists on image." -ForegroundColor DarkGray
		} # /end if edition already there
	} # /end last char comparison
} # /end install editions

if($EditionInstalledCount -eq $WindowsEditions_Install.Count) {
	Write-Verbose "[$(_LINE_)] Looks like all editions have been installed." -Verbose
} else {
	Write-Host "[$(_LINE_)] Installation of editions had some errors. We are not removing the other ones. Please fix this first." -BackgroundColor Black -ForegroundColor Red
	return
}

# LOOP: Remove Editions from WIM
$EditionCounter = 0
$WindowsEditions_Remove = $ExtractedISO_WIMInfo.Edition | Where-Object { $WindowsEditions -notcontains $_ }

# remove the indizies counting backwards
for($i = $WindowsEditions_Remove.Count; $i -gt 0; $i--) {
	$EditionCounter++

	# cannot remove last anyway, but who cares
	if($WindowsEditions_Remove.Count -gt 1) {
		$Edition = $WindowsEditions_Remove[$i-1]
	} else {
		$Edition = $WindowsEditions_Remove
	}
	Write-Verbose "[$(_LINE_)] [$EditionCounter/$($WindowsEditions_Remove.Count)] Started Removing Edition '$Edition'" -Verbose
		
	<#
	Index        : 4
	Name         : Windows 10 Pro N
	Edition      : ProfessionalN
	Architecture : x64
	Version      : 10.0.18362
	Build        : 1
	Level        : 0
	Languages    : de-DE (Default)
	#>
	$ImageInfo = $ExtractedISO_WIMInfo | Where-Object { $_.Edition -eq $Edition }
	if($ImageInfo) {
		$Imageinfo | ForEach-Object {
			if((Get-WIMInfo -SourcePath $ExtractedISO_Path).Edition.Count -eq 1) {
				Write-Host "Cannot remove last index."
			} else {
				$tIndex   = $_.Index
				$tEdition = $_.Edition

				Write-Verbose "[$(_LINE_)] [$EditionCounter/$($WindowsEditions_Remove.Count)] Removing '$tEdition'." -Verbose
				DISM /Delete-Image /ImageFile:"$ExtractedISO_WIMFullFileName" /Index:$tIndex /NoRestart /Quiet /English /LogPath:$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_delete_index_$tIndex.log
				DismLog -ExitCode $LASTEXITCODE -Operation "Export: $ExtractedISO_WIMFullFileName`:$MountingIndexNumber | $UUP_ISOMountPath" -Line $(_LINE_)
			}
		}
	} else {
		Write-Host "[$(_LINE_)] No ImageInfo for $Edition"
	}
}

ScriptCleanUP #-StopTranscript
# /END FOR PART #2

# patch winrm?
# adding windows index N only when N left?