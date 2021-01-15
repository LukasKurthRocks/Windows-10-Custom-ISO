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

#region Clean Mounted Paths

#endregion

#Start-Transcript -Path "$env:TEMP\loader_windows10uup_$(Get-Date -Format "yyMMdd-HHmmss.fffffff").txt"
#Stop-Transcript

# The Get-WebTable stuff does not work with PowerShell core this way.
try {
	[Microsoft.PowerShell.Commands.HtmlWebResponseObject]$null
}
catch {
	Write-Host "Sorry, do not have some good CORE-functions for this. I need the HTML Table, and i am not messing around with [XML]`$Request.Content. Too dumb for this." -ForegroundColor Red -BackgroundColor Black
	return
}

$UUP_DUMP_URI = "https://uupdump.ml/"
$UUP_DUMP_FeatureRequestURI = "https://uupdump.ml/known.php?q=feature"
# KNWON BUILDS = https://uupdump.ml/known.php

#region TempFolder CleanUp and Creation
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
	Write-Verbose "[$(_LINE_)] Request `"$UUP_DUMP_FeatureRequestURI`"" -Verbose
	$Request = Invoke-WebRequest -Uri $UUP_DUMP_FeatureRequestURI

	# Extract generic ids from links.
	# /get.php?id=91712d02-7dcf-478a-acfc-6e4c474fc754&pack=0&edition=0
	$DUMP_IDs = & {
		$Request.Links | Where-Object { $_.outerHTML -match "(?=.*1903)(?=.*amd64)" } | Select-Object -Property * | ForEach-Object {
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
}
#endregion DownloadTest

#region Download
# Had to test a lot, so we 'might' need to skip the donwload region
if (!$SkipDownload) {
	Write-Host "[$(_LINE_)] Downloading aria packages..."

	# downloading package with converter cmds...
	Invoke-WebRequest -Uri "https://uupdump.ml/get.php?id=$DUMP_ID&pack=0&edition=0&autodl=2" -UseBasicParsing -OutFile "$UUP_DUMP_Temp\aria_base.zip" -Verbose

	#Add-Type -AssemblyName System.IO.Compression.FileSystem
	#[System.IO.Compression.ZipFile]::ExtractToDirectory($UUP_DUMP_Temp\aria.zip, $UUP_DUMP_Aria)
	Write-Verbose "[$(_LINE_)] Expanding Archive." -Verbose
	Expand-Archive -Path "$UUP_DUMP_Temp\aria_base.zip" -DestinationPath "$UUP_DUMP_Aria" -Force -Verbose

	#$null = Copy-Item "$PSScriptRoot\ConvertConfig.ini" -Destination "$UUP_DUMP_Aria\files\" -Verbose

	# Download files with aria for each language.
	$OnlyLanguageEx.split("|") | ForEach-Object {
		$tLang = $_.ToLower()
		Write-Host "[$(_LINE_)] Downloading for language `"$($tLang)`""
		try {
			Invoke-WebRequest -Uri "https://uupdump.ml/get.php?id=$DUMP_ID&pack=$tLang&edition=0&autodl=1" -UseBasicParsing -OutFile "$UUP_DUMP_Temp\aria.zip" -Verbose
		}
		catch {
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
	}
}
#endregion Download

$UPDUMP_AriaUUPs_AllFiles = Get-ChildItem -Path "$UUP_DUMP_Aria_UUPs" -Recurse | Where-Object { $_.FullName -notmatch '00._Archive' }

#region MOVE NON MAIN CORE FILES
# TODO: Rename!!!
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
			$Request.Links | Where-Object { $_.href -like "*.cab" } | ForEach-Object {
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

			if (Test-URI -uri $tURI) {
				$tDownloadFilePath = "$UUP_DUMP_Aria_UUPs_Additional\$FileName"

				# File-Check
				if (!(Test-Path -Path $tDownloadFilePath -ErrorAction SilentlyContinue)) {
					#Write-Host "`"$tDownloadFilePath`" loading..." -ForegroundColor Yellow
					#Invoke-WebRequest -Uri $tURI -UseBasicParsing -OutFile $tDownloadFilePath -Verbose

					Start-Job { Invoke-WebRequest $using:tURI -Method Get -OutFile $using:tDownloadFilePath -UserAgent FireFox } | Out-Null
				}
				else {
					Write-Host "`"$FilePath`"" -ForegroundColor Green
				}
			}
			else {
				Write-Host "$tURI" -ForegroundColor Red
				#Write-Host "`"$tURI`"" -ForegroundColor Red
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
			}
			else {
				Write-Host "[$(_LINE_)] $tURI" -ForegroundColor Red
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
	# We might no
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

#region Move files
if ($SkipISOMove) {
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