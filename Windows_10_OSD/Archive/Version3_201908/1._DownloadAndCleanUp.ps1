##Requires -RunAsAdministrator
##Requires -Version 5.0

#
# Short information: I had to split this. We have to run through different steps.
# One step depending on the user choosing some options (business or private).
# But this is a good way to just use the CustomVariables.ps1
#
# - Expand-Archive has been introduced in PS5.0
#

#
# 29.07.2019 - Notices some problems creating the first ISO.
# There were 3 Pro versions, 2 N-versions - titled without N AND without the updates,
# 1 normal version - titled with N AND with the updates - Crazy.
# I assume the converter got confused with something.
# So i decieded to redo the download:
# - I do not have to download the language specific aria zips.
# - I just download the language files with the additional files (is the same process anyways).
#

# TODO: Rename Variables (duh')

param(
	# only useed for parameter. not quite useful.
	[ValidateSet("amd64", "arm64", "x86")]
	$OSArch = $env:PROCESSOR_ARCHITECTURE,
	#$URIRequestString = "Windows 10 Insider $OSArch",
	$URIRequestString = "Feature $OSArch",
	[switch]$DisplaySelectionGUI,
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

Start-Transcript -Path "$env:TEMP\w10iso_uuploader_$(Get-Date -Format "yyMMdd-HHmmss.fffffff").txt"

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
function CleanUp-Script {
	# Remove existing mount dirs
	& {
		$tMountDirLine = dism /get-mountedwiminfo /english | Select-String "Mount Dir"
		$dummy, $MountDir = ("" + $tMountDirLine) -split ":", 2
		if ($MountDir) {
			Write-Verbose "Removing Mount Dir `"$MountDir`"." -Verbose
			$MountDir = $MountDir.Trim()
			DISM /Unmount-Wim /MountDir:$MountDir /Discard
		}
	}

	# stop transcription
	Stop-Transcript
}
#endregion Import Scripts

#region Clean Mounted Paths
& {
	$tMountDirLine = dism /get-mountedwiminfo /english | Select-String "Mount Dir"
	$dummy, $MountDir = ("" + $tMountDirLine) -split ":", 2
	if ($MountDir) {
		$MountDir = $MountDir.Trim()
		DISM /Unmount-Wim /MountDir:$MountDir /Discard
	}
}
#endregion

# The Get-WebTable stuff does not work with PowerShell core this way.
try {
	[Microsoft.PowerShell.Commands.HtmlWebResponseObject]$null
}
catch {
	Write-Host "Sorry, do not have some good CORE-functions for this. I need the HTML Table, and i am not messing around with [XML]`$Request.Content. Too dumb for this." -ForegroundColor Red -BackgroundColor Black
	return
}

$UUP_DUMP_URI = "https://uupdump.ml/"
$UUP_DUMP_FeatureRequestURI = "https://uupdump.ml/known.php?q=$URIRequestString"
# KNWON BUILDS = https://uupdump.ml/known.php

#region TempFolder CleanUp and Creation
# We do not want to remove the folder if it exists.
# Also the folder does not get removed in the end.
if (! ($SkipRemoveUUPFolder -and (Test-Path -Path $UUP_DUMP_Aria_UUPs)) ) {
	$UUP_FolderTemp = "$env:SystemDrive\`$ROCKS.UUP"
	try {
		if ((Test-Path -Path $UUP_FolderTemp) -and !$KeepUUPTemp) {
			Get-ChildItem -Path $UUP_FolderTemp -Recurse -ErrorAction Stop | ForEach-Object {
				Remove-Item -Path $_.FullName -Recurse -Confirm:$false
			}
			Remove-Item -Path $UUP_FolderTemp -Recurse -Force
		}
	}
 catch {
		Write-Host "[$(_LINE_)] Could not begin. Might need to restart system." -ForegroundColor Red
		return
	}

	if (!(Test-Path -Path $UUP_FolderTemp -ErrorAction SilentlyContinue)) {
		$null = New-Item $UUP_FolderTemp -ItemType Directory
		(get-item $UUP_FolderTemp).Attributes += 'Hidden'
	}
 else {
		if (!$KeepUUPTemp) {
			Write-Host "[$(_LINE_)] Could not remove temp folder." -ForegroundColor Red
			return
		}
	}
}
#endregion TempFolder CleanUp and Creation

$UUP_DUMP_Aria = "$UUP_FolderTemp\aria"

#$UUP_DUMP_Folder = "$PSScriptRoot\UUPDump\UUPs"
#$UUP_DUMP_Aria = "$PSScriptRoot\UUPDump\aria"
$UUP_DUMP_Aria_UUPs = "$UUP_DUMP_Aria\UUPs"
#$UUP_DUMP_Aria_UUPs_Sorted = "$UUP_DUMP_Aria_UUPs\Sorted"
#$UUP_DUMP_Aria_UUPs_Sorted_FODs = "$UUP_DUMP_Aria_UUPs_Sorted\FODs"
#$UUP_DUMP_Aria_UUPs_Sorted_LPs = "$UUP_DUMP_Aria_UUPs_Sorted\LPs"
$UUP_DUMP_Temp = "$UUP_FolderTemp\temp"

if (!(Test-Path -Path $UUP_DUMP_Temp)) {
	$null = New-Item -Path $UUP_DUMP_Temp -ItemType Directory
}

# specific user agent?
# arch is: x86, amd64, arm64

<#
 We need to have the "id" WITHOUT catching another curl.
 So i just search for my regex, select the first object
 and substring the URL.

 ./selectlang.php?id=91712d02-7dcf-478a-acfc-6e4c474fc754

 We cannot parse this in XML.
 There IS indeed a tool, that can "prettify" this, but... naaaah...
 [xml]([System.Net.WebUtility]::HtmlDecode($Request.Content))

 Saved Regex for URI: "=([\d\D]*)$"
#>
$ProgressPreference = 'SilentlyContinue' # FASTER!!!
# TODO: Move somewhere!
# TODO: Compare with LanguageCSV?
$MainLang = ([CultureInfo]::InstalledUICulture | Select-Object -First 1).Name
if ($OverrideMainLanguage) {
	$MainLang = $OverrideMainLanguage
}

# uupdump download options:
# - Browse list of files
# https://uupdump.ml/get.php?id=91712d02-7dcf-478a-acfc-6e4c474fc754&pack=de-de&edition=0
# - Download using aria 2
# https://uupdump.ml/get.php?id=91712d02-7dcf-478a-acfc-6e4c474fc754&pack=de-de&edition=0&autodl=1
# - Download using aria 2 + convert
# https://uupdump.ml/get.php?id=91712d02-7dcf-478a-acfc-6e4c474fc754&pack=de-de&edition=0&autodl=2
# - Download using aria 2 + convert + virtual editions (nope)
# - Catching jQuery window??
# https://uupdump.ml/get.php?id=91712d02-7dcf-478a-acfc-6e4c474fc754&pack=de-de&edition=0&autodl=3

#region DownloadTest
# On 24.07.2019 i tried to download the current list and another entry appeared with
# No possible download option. So i have to check for download link first i guess,...
# or skip to the next possible download option.
# We should possibly NEVER skip this.
if (!$SkipDownloadTest) {
	# Adding the ability to have the "user" (mostly me) select a Windows 10 release.
	# But i will have to have the CLI version for "Automation" purposes.
	if ($DisplaySelectionGUI) {
		Write-Verbose "[$(_LINE_)] Retrieving new releases for '$URIRequestString' ..." -Verbose
		try {
			$BuildRequest = Invoke-WebRequest -Uri https://uupdump.ml/known.php?q=$URIRequestString
			$BuildRequestTable = Get-WebTable -WebRequest $BuildRequest -TableNumber 0
		}
		catch {
			Write-Host "[$(_LINE_)] Could not retrieve table from request. Error `"$($_.Exception.Message)`"" -ForegroundColor Red
		}

		# Users CAN input the wrong request string.
		if (!$BuildRequestTable) {
			Write-Host "[$(_LINE_)] Nothing found. Please choose another RequestURI" -ForegroundColor Red
			CleanUp-Script
			return
		}

		# GridView only if more than one entry
		# If single entry, that is the entry we need.
		# Implemented a conter to stop if tries are reached.
		$SelectCounter = 3
		while ($SelectCounter -gt 0) {
			if ($BuildRequestTable.Count -gt 1) {
				$BuildSelection = $BuildRequestTable | Out-GridView -Title "Windows 10 UUP Releases" -OutputMode Single -Verbose
			}
			elseif ( ($BuildRequestTable.Count -eq 0) -or (!$BuildRequestTable.Count) ) {
				$BuildSelection = $BuildRequestTable
			}

			# User HAS TO select.
			if (!$BuildSelection) {
				Write-Host "[$(_LINE_)] Abortion is not supported. If you don't want to use the GUI dont select the switch for it, or have a clear RequestURI as we do not need to display a GUI for one result. Try -URIRequestString 'feature'." -ForegroundColor Red
				CleanUp-Script
				return
			}
			Write-Host "[$(_LINE_)] Selected: `"$($BuildSelection.Build)`" with ID: `"$($BuildSelection."Update ID")`""

			$DUMPY = $BuildSelection."Update ID"

			# Duplicate of the code down below, but i cannot merge them together properly
			# Have added a GUI message anyways, that does not need to be displayed on CLI.
			try {
				$Request_StatusCode = (Invoke-WebRequest -Uri  "https://uupdump.ml/selectedition.php?id=$DUMPY&pack=$MainLang" -UseBasicParsing).StatusCode
				Write-Verbose "[$(_LINE_)] '$DUMPY' Returned status code '$Request_StatusCode'" -Verbose

				$DUMP_ID = $DUMPY
				$SelectCounter = 0
			}
			catch {
				$eMessage = $_.Exception.Message
				Write-Host "[$(_LINE_)] 'https://uupdump.ml/selectedition.php?id=$DUMPY&pack=$MainLang' >> There is no language selection for this link... ($eMessage)" -ForegroundColor Red
				$null = [System.Windows.Forms.MessageBox]::Show(`
						"There is no language selection for this BuildID. Please select correct Windows 10 release.`n" +
					"Error: `"$eMessage`"`n`n" +
					"ID:`t$DUMPY`n" +
					"Lang:`t$MainLang`n" +
					"https://uupdump.ml/selectedition.php?id=$DUMPY&pack=$MainLang",
				
					"Error downloading language package (#$(_LINE_))", `
						[System.Windows.Forms.MessageBoxButtons]::OKCancel, [System.Windows.Forms.MessageBoxIcon]::Warning)
				$SelectCounter--
			}
		} # /end while SelectCounter

		if (($SelectCounter -le 0) -and (!$DUMP_ID)) {
			Write-Host "[$(_LINE_)] Had your chance. Please try again later." -ForegroundColor Red
			CleanUp-Script
			return
		}
	}
 else {
		Write-Verbose "[$(_LINE_)] Request `"$UUP_DUMP_FeatureRequestURI`"" -Verbose
		$Request = Invoke-WebRequest -Uri $UUP_DUMP_FeatureRequestURI

		# Extract generic ids from links.
		# /get.php?id=91712d02-7dcf-478a-acfc-6e4c474fc754&pack=0&edition=0
		$DUMP_IDs = & {
			# Not here. Thats what the $URIRequestString is for!
			#$Request.Links | Where-Object { $_.outerHTML -match "(?=.*1903)(?=.*amd64)" }
			$Request.Links | Select-Object -Property * | Where-Object { $_.href -match "id[=]" } | ForEach-Object {
				$H = $_.href; $I = $H.IndexOf("=") + 1; $H.substring($I, $H.length - $I)
			}
		}

		Write-Verbose "[$(_LINE_)] Downloading aria." -Verbose

		# Remember: Do NOT use 'ForEach-Object' if you want to break out of that loop!
		foreach ($DUMPY in $DUMP_IDs) {
			# return first successfull id
			# skipping until finding one.
			try {
				$Request_StatusCode = (Invoke-WebRequest -Uri  "https://uupdump.ml/selectedition.php?id=$DUMPY&pack=$MainLang" -UseBasicParsing).StatusCode
				Write-Verbose "[$(_LINE_)] '$DUMPY' Returned status code '$Request_StatusCode'" -Verbose

				$DUMP_ID = $DUMPY
				break
			}
			catch {
				$eMessage = $_.Exception.Message
				if ($eMessage -like "*(429)*") {
					Write-Host "[$(_LINE_)] 'https://uupdump.ml/selectedition.php?id=$DUMPY&pack=$MainLang' >> Too many requests? Looks like we will have to wait a while... ($eMessage)" -ForegroundColor Red
					break
				}
				else {
					Write-Host "[$(_LINE_)] 'https://uupdump.ml/selectedition.php?id=$DUMPY&pack=$MainLang' >> Trying next one... ($eMessage)" -ForegroundColor DarkGray
				}
			}
		}

		# if none of them has been successful break this script.
		if (!$DUMP_ID) {
			Write-Host "[$(_LINE_)] No feature id found. Please leave the area." -ForegroundColor Red
			return
		}
	} # /end if GUI/NoGUI
} # /end SkipDownloadTest
#endregion DownloadTest

#region Download
# Had to test a lot, so we 'might' need to skip the donwload region
if (!$SkipDownload) {
	$MainLang = ("" + $MainLang).ToLower()

	Write-Host "[$(_LINE_)] Downloading aria packages..."

	# First downloading package with more batch files, so we have them.
	# Have to download "normal" package afterwards, so the converter batch does not run (inside aria script).
	# Extracting and starting of converting will be done later.
	# ALSO: We don't have to use the pack=0 (all languages).
	# Will download languages down here somewhere.
	#Invoke-WebRequest -Uri "https://uupdump.ml/get.php?id=$DUMP_ID&pack=0&edition=0&autodl=2" -UseBasicParsing -OutFile "$UUP_DUMP_Temp\aria_base.zip" -Verbose
	Invoke-WebRequest -Uri "https://uupdump.ml/get.php?id=$DUMP_ID&pack=$MainLang&edition=0&autodl=2" -UseBasicParsing -OutFile "$UUP_DUMP_Temp\aria_base.zip" -Verbose
	
	Write-Verbose "[$(_LINE_)] Expanding Archive." -Verbose
	if ($PSVersionTable.PSVersion.Major -ge 5) {
		Expand-Archive -Path "$UUP_DUMP_Temp\aria_base.zip" -DestinationPath "$UUP_DUMP_Aria" -Force -Verbose
	}
 else {
		Write-Verbose "[$(_LINE_)] Ignoring Archive-Extraction in PSVersion.Major below version 5. Please upgrade your Windows Management Framework. Thanks." -Verbose
		return
		#Add-Type -AssemblyName System.IO.Compression.FileSystem
		#[System.IO.Compression.ZipFile]::ExtractToDirectory($UUP_DUMP_Temp\aria.zip, $UUP_DUMP_Aria)
	}

	# Make no sense here. After we have extracted the .7z file in another step,
	# we can copy the converterConfig. We may have to check the file for changes.
	#$null = Copy-Item "$PSScriptRoot\ConvertConfig.ini" -Destination "$UUP_DUMP_Aria\files\" -Verbose

	# Download files with aria for each language.
	<#
	$OnlyLanguageEx.split("|") | ForEach-Object {
		$tLang = $_.ToLower()
		Write-Host "[$(_LINE_)] Downloading for language `"$($tLang)`""
		try {
			Invoke-WebRequest -Uri "https://uupdump.ml/get.php?id=$DUMP_ID&pack=$tLang&edition=0&autodl=1" -UseBasicParsing -OutFile "$UUP_DUMP_Temp\aria.zip" -Verbose
		} catch {
			Write-Host "[$(_LINE_)] Could not get current file list from 'https://uupdump.ml/get.php?id=$DUMP_ID&pack=$tLang&edition=0&autodl=1': $($_.Exception.Message)" -ForegroundColor Red
		}

		Write-Verbose "[$(_LINE_)] Expanding Archive." -Verbose
		Expand-Archive -Path "$UUP_DUMP_Temp\aria.zip" -DestinationPath $UUP_DUMP_Aria -Force -Verbose

		#$null = Copy-Item "$PSScriptRoot\ConvertConfig.ini" -Destination "$UUP_DUMP_Aria\files\" -Verbose

		Write-Verbose "[$(_LINE_)] RUN CMD> Aria" -Verbose
		Get-ChildItem -Path "$UUP_DUMP_Aria\aria*.cmd" | ForEach-Object {
			#Invoke-Item -Path $_.FullName -Verbose # -WhatIf
			$Process = Start-Process "cmd" -ArgumentList "/c $($_.FullName)" -Wait -NoNewWindow
			$Process.ExitCode
		}
	} # /end language split
	#>

	# Download only the main language files first.
	Write-Host "[$(_LINE_)] Downloading for language `"$($MainLang)`""
	try {
		Invoke-WebRequest -Uri "https://uupdump.ml/get.php?id=$DUMP_ID&pack=$MainLang&edition=0&autodl=1" -UseBasicParsing -OutFile "$UUP_DUMP_Temp\aria.zip" -Verbose
	}
 catch {
		Write-Host "[$(_LINE_)] Could not get current file list from 'https://uupdump.ml/get.php?id=$DUMP_ID&pack=$MainLang&edition=0&autodl=1': $($_.Exception.Message)" -ForegroundColor Red
	}

	Write-Verbose "[$(_LINE_)] Expanding Archive." -Verbose
	if ($PSVersionTable.PSVersion.Major -ge 5) {
		Expand-Archive -Path "$UUP_DUMP_Temp\aria.zip" -DestinationPath $UUP_DUMP_Aria -Force -Verbose
	}
 else {
		Write-Verbose "[$(_LINE_)] Ignoring Archive-Extraction in PSVersion.Major below version 5. Please upgrade your Windows Management Framework. Thanks." -Verbose
		return
		#[System.IO.Compression.ZipFile]::ExtractToDirectory($UUP_DUMP_Temp\aria.zip, $UUP_DUMP_Aria)
	}
	
	# Make no sense here. After we have extracted the .7z file in another step,
	# we can copy the converterConfig. We may have to check the file for changes.
	#$null = Copy-Item "$PSScriptRoot\ConvertConfig.ini" -Destination "$UUP_DUMP_Aria\files\" -Verbose

	Write-Verbose "[$(_LINE_)] RUN CMD> Aria" -Verbose
	Get-ChildItem -Path "$UUP_DUMP_Aria\aria*.cmd" | ForEach-Object {
		#Invoke-Item -Path $_.FullName -Verbose # -WhatIf
		$Process = Start-Process "cmd" -ArgumentList "/c $($_.FullName)" -Wait -NoNewWindow
		$Process.ExitCode
	}
}
#endregion Download

$UPDUMP_AriaUUPs_AllFiles = Get-ChildItem -Path "$UUP_DUMP_Aria_UUPs" -Recurse | Where-Object { $_.FullName -notmatch '00._Archive' }

#region Windows Updates Remove & Investigations
<#
 Had to do some investigations...
 It seems that there is a problem with the update process.
 I might have do this on my own. Good that i have split thos processes already.

 Without Updates we have this:
	Index Name              Edition       Architecture Version    Build Level Languages
	----- ----              -------       ------------ -------    ----- ----- ---------
	1     Windows 10 Home   Core          x64          10.0.18362 1     0     de-DE (Default)
	2     Windows 10 Pro    Professional  x64          10.0.18362 1     0     de-DE (Default)
	3     Windows 10 Home N CoreN         x64          10.0.18362 1     0     de-DE (Default)
	4     Windows 10 Pro N  ProfessionalN x64          10.0.18362 1     0     de-DE (Default)

 With Updates we have this:
	Index Name              Edition       Architecture Version    Build Level Languages
	----- ----              -------       ------------ -------    ----- ----- ---------
	1     Windows 10 Home   Core          x64          10.0.18362 267   0     de-DE (Default)
	2     Windows 10 Home N CoreN         x64          10.0.18362 267   0     de-DE (Default)
	3     Windows 10 Pro    ProfessionalN x64          10.0.18362 1     0     de-DE (Default)
	4     Windows 10 Pro N  Professional  x64          10.0.18362 267   0     de-DE (Default)
	5     Windows 10 Pro    ProfessionalN x64          10.0.18362 1     0     de-DE (Default)
 
 Note: As you can see, the Pro versions get messed up. First thought the information could just be messed up.
 Installed Index 3 as a Test and it was indeed "Windows 10 Pro N", so Description and Name are false.
 In addition there are 5 index, and there should not.

 So what i do now: Create the base ISO, and do my stuff.
#>

#Write-Verbose "[$(_LINE_)] REMOVE ME: Removing KB Files as they take too long to implement." -Verbose
#$UPDUMP_AriaUUPs_AllFiles | Where-Object { $_.FullName -like "*windows*kb*.cab" } | ForEach-Object {
#	Remove-Item -Path $_.FullName -Verbose
#}
#endregion Windows Updates Remove & Investigations

#region MOVE NON MAIN CORE FILES
# TODO: Rename!!!
# TODO: Remove if not needed anymore...
$UPDUMP_AriaUUPs_CoreProfFiles = $UPDUMP_AriaUUPs_AllFiles | Where-Object { ($_.Name -match "^(core|professional)") -and ($_.Name -notmatch "$MainLang") }
if ($UPDUMP_AriaUUPs_CoreProfFiles) {
	# TODO: We need to move the core and professional esd files before we can convert the iso.
	# These esd files are for main ISO installation media and have multiple versions of "Windows 10 Home" etc.
	# They cannot all be added to the WIM, so we skip these files (do we need them anyway??)
	$UUPDUMP_AriaUUPs_ArchiveFolder = "$UUP_DUMP_Aria_UUPs\00._Archive"
	if (!(Test-Path -Path $UUPDUMP_AriaUUPs_ArchiveFolder)) {
		$null = New-Item -Path $UUPDUMP_AriaUUPs_ArchiveFolder -ItemType Directory
	}

	Write-Host "[$(_LINE_)] Moving `"non-systemlanguage`" core/pro ESDs"
	$UPDUMP_AriaUUPs_CoreProfFiles | ForEach-Object {
		$FileName = $_.Name

		Copy-Item -Path $_.FullName -Destination "$UUPDUMP_AriaUUPs_ArchiveFolder\$FileName" -Verbose
		Remove-Item -Path $_.FullName -Verbose
		#Move-Item -Path $_.FullName -Destination "$UUPDUMP_AriaUUPs_ArchiveFolder\$FileName" -Verbose
	}
}
#endregion MOVE NON MAIN CORE FILES

#region FOD Download
# RSAT/FOD and LanguagePacks do not get included inside of the ISO/WIM.
# So we will have to implement that later.
# Here we have to download these cab files
if (!$SkipFODDownload) {
	# So we move them FODs in a subfolder.
	# Couldn't be implemented in ConvertUUP anyways.
	$UUP_DUMP_Aria_UUPs_Additional = "$UUP_DUMP_Aria_UUPs\Additional"
	if (!(Test-Path -Path $UUP_DUMP_Aria_UUPs_Additional)) {
		$null = New-Item -Path $UUP_DUMP_Aria_UUPs_Additional -ItemType Directory
	}

	# If there are no files, we will download them.
	# Checked for fod or other names before, but they could not work properly.
	#if(!($UPDUMP_AriaUUPs_AllFiles | Where-Object { ($_.Name -match "[-]fod[-]") -and ($_.Name -notlike "*microsoft-onecore-applicationmodel-sync-desktop-fod-package*") }))
	if ( (Get-ChildItem -Path $UUP_DUMP_Aria_UUPs_Additional -Recurse).Count -eq 0 ) {
		Write-Host "[$(_LINE_)] Haven't found any FOD packages" -ForegroundColor Yellow -BackgroundColor Black

		$Request = Invoke-WebRequest -Uri "https://uupdump.ml/findfiles.php?id=$DUMP_ID" -UseBasicParsing -Verbose

		# Creating a list with additional files from Links.
		# All cabinet files are included.
		$AdditionalFiles = & {
			# ? {$_.href -match "cab|esd" -and ($_.href -notmatch "[=](core|profess)") } | select href
			$Request.Links | Where-Object { ($_.href -match "cab|esd") -and ($_.href -notmatch "[=](core|profess)") } | ForEach-Object {
				# remove "getfile.php?id=" from the url, we just need the filenames
				$Link = $_.href
				$DelimiterPosition = $Link.IndexOf("file=") + 5
				#$FileName = 
				$FileName = $Link.substring($DelimiterPosition, $Link.length - $DelimiterPosition)
				$_ | Add-Member -MemberType NoteProperty -Name "Name" -Value $FileName
				$_
			}
		} # /end collecting additional files
	
		# ([\w]{2}[-][\w]{2}[.])
		# ([-][\w]{2}[-][\w]{2}[.-])
		# "de-DE" or "es-latn-de" ending with . or -
		# ([-][\w]{2}[-][\w]{2}[.-])|([-][\w]{2}[-][\w]{4}[-][\w]{2}[.-])
		$AdditionalFilesWithLangCode = $AdditionalFiles | Where-Object { $_.Name -match "([-][\w]{2}[-][\w]{2}[.-])|([-][\w]{2}[-][\w]{4}[-][\w]{2}[.-])" }
		$AdditionalFilesWithRexCode = $AdditionalFilesWithLangCode | Where-Object { $_.Name -match $OnlyLanguageEx }
		$LocalAdditionalFiles = $UPDUMP_AriaUUPs_AllFiles | Where-Object { $AdditionalFilesWithRexCode.Name -contains $_.Name }
	
		#$AdditionalFilesWithLangCode | Select Name
		$AdditionalFilesWithoutLanguage = $AdditionalFiles | Where-Object { ($AdditionalFilesWithLangCode.Name -notcontains $_.Name) -and ($_.Name -notmatch "languagefeatures|taiwan") }
		$LocalAdditionalFilesNonLanguage = $UPDUMP_AriaUUPs_AllFiles | Where-Object { $AdditionalFilesWithoutLanguage.Name -contains $_.Name }

		# no remaining jobs open!
		Get-Job | Remove-Job -Force
	
		$MaxThreads = 20
		$SleepTimer = 500
		$MaxWaitAtEnd = 600
		$i = 0

		# We have defined languages at start and now we download files specific to that defined languages
		Write-Host "[$(_LINE_)] Downloading additional files for defined languages '$OnlyLanguageEx'"
		$AdditionalFilesWithRexCode | Where-Object { $LocalAdditionalFiles.Name -notcontains $_.Name } | ForEach-Object {
			$FileName = $_.Name
			$HREF = $_.href -replace "./"
			Write-Verbose "[$(_LINE_)] Download: $FileName" -Verbose

			# Loop threads running
			While ($(Get-Job -state running).count -ge $MaxThreads) {
				Start-Sleep -Milliseconds $SleepTimer
			}

			$tURI = "$UUP_DUMP_URI$HREF"

			# Some test-uris have lost ping
			# Here is my check to prevent losing a file.
			$ReCheckCount = 3 # Someone might lose a ping...
			while ($ReCheckCount -gt 0) {
				if (Test-URI -Uri $tURI) {
					$tDownloadFilePath = "$UUP_DUMP_Aria_UUPs_Additional\$FileName"

					# File-Check
					if (!(Test-Path -Path $tDownloadFilePath -ErrorAction SilentlyContinue)) {
						#Write-Host "`"$tDownloadFilePath`" loading..." -ForegroundColor Yellow
						#Invoke-WebRequest -Uri $tURI -UseBasicParsing -OutFile $tDownloadFilePath -Verbose

						Start-Job { Invoke-WebRequest $using:tURI -Method Get -OutFile $using:tDownloadFilePath -UserAgent FireFox } | Out-Null
					}
					else {
						Write-Host "[$ReCheckCount] `"$FilePath`"" -ForegroundColor Green
					}
					$ReCheckCount = 0 # bye
				}
				else {
					Write-Host "[$ReCheckCount] $tURI" -ForegroundColor Red
					#Write-Host "`"$tURI`"" -ForegroundColor Red
					$ReCheckCount--
				}
			}
			
		} # /end download additional files for language


		<#
		$AdditionalFilesWithRexCode | Where-Object { $LocalAdditionalFiles.Name -notcontains $_.Name } | ForEach-Object {
			$FileName = $_.Name
			$HREF = $_.href -replace "./"
			Write-Verbose "Download: $FileName" -Verbose
			Invoke-WebRequest -Uri "$UUP_DUMP_URI$HREF" -UseBasicParsing -OutFile "$UUP_DUMP_Aria_UUPs\$FileName" -Verbose
		}
		#>
	
		# At least we now download all files WITHOUT lang code that exists in all files list...
		Write-Host "[$(_LINE_)] Downloading additional files left..."
		$AdditionalFilesWithoutLanguage | Where-Object { $LocalAdditionalFilesNonLanguage.Name -notcontains $_.Name } | ForEach-Object {
			$FileName = $_.Name
			$HREF = $_.href -replace "./"
			Write-Verbose "[$(_LINE_)] Download: $FileName" -Verbose

			# Loop threads running
			While ($(Get-Job -state running).count -ge $MaxThreads) {
				Start-Sleep -Milliseconds $SleepTimer
			}

			$tURI = "$UUP_DUMP_URI$HREF"
			
			# Some test-uris have lost ping
			# Here is my check to prevent losing a file.
			$ReCheckCount = 3 # Someone might lose a ping...
			while ($ReCheckCount -gt 0) {
				if (Test-URI -uri $tURI) {
					$tDownloadFilePath = "$UUP_DUMP_Aria_UUPs_Additional\$FileName"

					# File-Check
					if (!(Test-Path -Path $tDownloadFilePath -ErrorAction SilentlyContinue)) {
						#Write-Host "`"$tDownloadFilePath`" loading..." -ForegroundColor Yellow
						#Invoke-WebRequest -Uri $tURI -UseBasicParsing -OutFile $tDownloadFilePath -Verbose

						Start-Job { Invoke-WebRequest $using:tURI -Method Get -OutFile $using:tDownloadFilePath -UserAgent FireFox } | Out-Null
					}
					else {
						Write-Host "[$(_LINE_)] `"$FilePath`"" -ForegroundColor Green
					}
					$ReCheckCount = 0
				}
				else {
					Write-Host "[$(_LINE_)] $tURI" -ForegroundColor Red
					$ReCheckCount--
				}
			}
		}

		<#
		$AdditionalFilesWithoutLanguage | Where-Object { $LocalAdditionalFilesNonLanguage.Name -notcontains $_.Name } | ForEach-Object {
			$FileName = $_.Name
			$HREF = $_.href -replace "./"
			Write-Verbose "Download: $FileName" -Verbose
			Invoke-WebRequest -Uri "$UUP_DUMP_URI$HREF" -UseBasicParsing -OutFile "$UUP_DUMP_Aria_UUPs\$FileName" -Verbose
		}
		#>

		# Waiting for jobs to complete
		Write-Host "[$(_LINE_)] Waiting on running jobs"
		$Complete = Get-date
		While ($(Get-Job -State Running).count -gt 0) {
			$JobsStillRunning = ""
			ForEach ($System  in $(Get-Job -state running)) { $JobsStillRunning += ", $($System.name)" }
			$JobsStillRunning = $JobsStillRunning.Substring(2)
			#Write-Host "[$(_LINE_)] $($(Get-Job -State Running).count) threads remaining ($JobsStillRunning)"
			If ($(New-TimeSpan $Complete $(Get-Date)).totalseconds -ge $MaxWaitAtEnd) { "Killing all jobs still running . . ."; Get-Job -State Running | Remove-Job -Force }
			Start-Sleep -Milliseconds $SleepTimer
		}
 
		Write-Host "[$(_LINE_)] Receiving all jobs"
		ForEach ($Job in Get-Job) {
			#Receive-Job $Job
			$null = $Job | Wait-Job
		}
	} # /end count of additional files (and then download)
} # /end skip fod download
#endregion

#region ConvertUUP
# Invoking the ConvertUUP.bat. This will create the ISO for us.
# We cannot inject the LPs or RSAT this way, but we have SCCM, so who cares.
if (!$SkipUUPConvert) {
	Get-ChildItem -Path "$UUP_DUMP_Aria\files\*.7z" | ForEach-Object {
		$DestinationFolder = "$UUP_DUMP_Aria\files\" + $_.BaseName

		$Process = Start-Process "$UUP_DUMP_Aria\files\7zr.exe" -ArgumentList "x -y $($_.FullName) -o`"$DestinationFolder`"" -Wait -WindowStyle Minimized
		$Process.ExitCode

		#$ExtractedFiles = Get-ChildItem -Path $DestinationFolder -Recurse

		# /MIR = /E (Unterverzeichnisse) und /PURGE (L�schen im Ziel)
		RoboCopy $DestinationFolder $UUP_DUMP_Aria /COPYALL /E /R:5 /W:10 /LOG:"$env:TEMP\robcopy_$(Get-Date -Format "yyMMdd-HHmmss.fffffff").log" /TEE
	}

	# Running this is a capsulated ScriptBlock.
	# We do not need those values and results.
	& {
		# "Just" a quick test to see if config has changed.
		# If numbers of lines do NOT match, i compare the content and see if there is a new value/key.
		$ConvertConfigContent_Archive = Get-Content -LiteralPath "$UUP_DUMP_Aria\ConvertConfig.ini"
		$ConvertConfigContent_Custom = Get-Content -LiteralPath "$PSScriptRoot\ConvertConfig.ini"
		$LinesArchiveConfig = ($ConvertConfigContent_Archive | Measure-Object).Count
		$LinesCustomConfig = ($ConvertConfigContent_Custom  | Measure-Object).Count
		if ($LinesArchiveConfig -ne $LinesCustomConfig) {
			Write-Verbose "[$(_LINE_)] CenvertConfig.ini might have been changed ($LinesArchiveConfig/$LinesCustomConfig)."
			$ConvertConfigComparison = Compare-Object -ReferenceObject $LinesArchiveConfig -DifferenceObject $LinesCustomConfig
			$ComparisonInputObjects = $ConvertConfigComparison.InputObject
		
			# when there is just some other value there are two values
			# but when there is a new entry, there is inly one value.
			$NewConfigEntries = $ComparisonInputObjects | ForEach-Object { $a, $b = "$_" -split "=", 2; $a } | Group-Object | Where-Object { $_.Count -lt 2 }
			if ($NewConfigEntries) {
				$NewConfigEntries | ForEach-Object {
					$entry = $_.Name
					$entryCompare = $ConvertConfigComparison | Where-Object { $_.InputObject -match $entry }
					if ($entryCompare.SideIndicator -eq "<=") {
						Write-Host "New entry in '$UUP_DUMP_Aria\ConvertConfig.ini': '$entry'" -ForegroundColor Yellow
					}
					elseif ($entryCompare.SideIndicator -eq "=>") {
						Write-Host "New entry in '$PSScriptRoot\ConvertConfig.ini': '$entry'" -ForegroundColor Yellow
					}
					else {
						# dunno how anyone should get here
						Write-Host "Error fetching entries. ($entry|$entryCompare)"
					}
				}
			}
			else {
				Write-Host "No new entries in configs found. Might be just a line number mismatch." -ForegroundColor Yellow
			}

			Write-Host "To let you choose what to do we will wait ~20 seconds." -BackgroundColor Black -ForegroundColor Cyan
			Start-Sleep -Seconds 20
		} # /end if lines not match
	}

	# Copying ConvertConfig into where the convert script lies.
	# Might will have to check for changes regularyly.
	$null = Copy-Item "$PSScriptRoot\ConvertConfig.ini" -Destination "$UUP_DUMP_Aria" -Verbose

	Write-Verbose "[$(_LINE_)] RUN CMD> UUP-Convert" -Verbose
	Get-ChildItem -Path "$UUP_DUMP_Aria\convert-UUP*.cmd" | ForEach-Object {
		#Invoke-Item -Path $_.FullName -Verbose # -WhatIf
		$Process = Start-Process "cmd" -ArgumentList "/c $($_.FullName)" -Wait -NoNewWindow
		$Process.ExitCode
	}

	# Hm, might want to add this to the end.
	#call create_virtual_editions.cmd autowim
} # /end SkipUUP
#endregion ConvertUUP

#region Remove UUP
# We can acutally run the "create_virtual_editions.cmd" separately
# So we remove only the big UUP files first
if (!$SkipRemoveUUPFolder) {
	try {
		if ((Test-Path -Path $UUP_DUMP_Aria_UUPs)) {
			Get-ChildItem -Path $UUP_DUMP_Aria_UUPs -Recurse -ErrorAction Stop | ForEach-Object {
				Remove-Item -Path $_.FullName -Recurse -Confirm:$false
			}
			Remove-Item -Path $UUP_DUMP_Aria_UUPs -Recurse -Force
		}
	}
 catch {
		Write-Host "[$(_LINE_)] Exception while removing: $($_.Exception.Message)." -ForegroundColor Red
		#return
	}
}
#endregion Remove UUP

#region InjectISO
# Due to different setting the user might set,
# this has to be done in a separate PS1.
# But i can handle that.
#endregion InjectISO

#region
# change files, move files
# and remove all files afterward.
#endregion

#Stop-Transcript
CleanUp-Script