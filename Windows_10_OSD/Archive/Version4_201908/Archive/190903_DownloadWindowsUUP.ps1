#Requires -RunAsAdministrator
#Requires -Version 5.0

# See README.md for Informations why i have change this... and why this is version "4".

#
# Short information: I had to split this. We have to run through different steps.
# One step depending on the user choosing some options (business or private).
# But this is a good way to just use the ScriptVariables.ps1 and ScriptFunctions.ps1
#
# - Expand-Archive has been introduced in PS5.0
#
# 29.07.2019 - Addendum:
# There was a problem when creating the ISO with ConvertConfig.ini/ConvertUUP.bat
# There were 3 Pro versions, 2 N-versions - titled without N AND without the updates,
# 1 normal version - titled with N AND with the updates - Crazy.
# I assume the converter got confused with something.
# So i decieded to redo the download:
# - I do not have to download the language specific aria zips.
# - I just download the language files with the additional files (is the same process anyways).
#

# TODO LIST:
# - Rename Variables!
# - Compare $MainLanguage with CSV values
# - "DownloadTest" is the wrong name for this

[CmdLetBinding()]
param(
	# only useed for parameter. not quite useful.
    [ValidateSet("amd64","arm64","x86")]
    $OSArch = $env:PROCESSOR_ARCHITECTURE,
    #$URIRequestString = "Windows 10 Insider $OSArch",
	$URIRequestString = "Feature $OSArch",
	[switch]$DisplaySelectionGUI,
    $OnlyLanguageEx = "de-DE|sv-SE|hu-HU|fr-FR|en-US",
	# for example "de-DE"
	$OverrideMainLanguage,
	$OverrideMountPath,
	[switch]$SkipDownload,
	# We can skip this on private. FODs like RSAT
	# are only needed in business environments.
	[switch]$SkipFODDownload,
	# If we don't want to remove the UUP Folder.
	# Get's removed anyway if -KeepUUPTemp not selected.
	[switch]$SkipRemoveUUPFolder,
	# UUPConvert will create the ISO for us.
	[switch]$SkipUUPConvert
)

# Debug informations for me
$ScriptVersion = [Version]"4.0.0.0"
Write-Verbose "So this is the UUPDownloaderScript in version '$ScriptVersion'. Thank you for choosing me."

# I put this here in case we need this
# Althoug a requirement is to have version 5.0
#if (!($PSScriptRoot)) {
#    $PSScriptRoot = (Split-Path $MyInvocation.MyCommand.Path)
#}

Start-Transcript -Path "$env:TEMP\w10iso_uuploader_$(Get-Date -Format "yyMMdd-HHmmss.fffffff").txt"

$StartTime = Get-Date
Write-Host "STEP1: Started at $(Get-Date -Format "dd.MM.yy HH:mm:ss")"

#region Import Scripts
Write-Verbose "Importing additional functionalities"
$ScriptImportFolder = "$PSScriptRoot\Scripts"
Get-ChildItem -Path $ScriptImportFolder -Filter "*.ps1" | ForEach-Object {
	Write-Verbose "+ $($_.Name)"
	. $_.FullName
}
$IncludedFunctionNames = @("Test-URI", "Get-WebTable", "Clear-MountPath", "UnmountRegistry")
$IncludedFunctionNames | ForEach-Object {
	if(!(Get-Command -Name "$_")) {
		Write-Host "Function `"$_`" not found." -ForegroundColor Red
		return
	}
}
#endregion Import Script

#region Check WebTable function
# The Get-WebTable stuff does not work with PowerShell core this way.
try {
	[Microsoft.PowerShell.Commands.HtmlWebResponseObject]$null
} catch {
	Write-Host "Sorry, do not have some good CORE-functions for this. I need the HTML Table, and i am not messing around with [XML]`$Request.Content. Too dumb for this." -ForegroundColor Red -BackgroundColor Black
	return
}
#endregion Check WebTable function

#region Language Check
if($OverrideMainLanguage) {
	$OSMainLang = $OverrideMainLanguage
	
	# TODO: Compare with LanguageCSV
	#$CSVContent = Import-Csv -Path "" -Delimiter ";" -Encoding UTF8
	#if( ($CSVContent -notcontains "$OSMainLang") -or ($CSVContent -notcontains "$OverrideMainLanguage") ) {
	#	Write-Host "Could not finf language tag in CSV: ($OSMainLang/$OverrideMainLanguage)" -BackgroundColor Black -ForegroundColor Red
	#	return
	#}
}
#endregion Language Check

#region CleanUp Mounted Paths
if($OverrideMountPath) {
	$UUP_ISOMountPath = $OverrideMountPath
}
ScriptCleanUP -MountPath $UUP_ISOMountPath -OfflineRegistry "Registry::HKEY_LOCAL_MACHINE\OFFLINE" -Verbose:$false
#endregion CleanUp Mounted Paths

#region TempFolder CleanUp and Creation
# We do not want to remove the folder if it exists.
# Also the folder does not get removed in the end.
if(! ($SkipRemoveUUPFolder -and (Test-Path -Path $UUP_AriaUUPs)) ) {
	$UUP_WorkingFolder = "$env:SystemDrive\`$ROCKS.UUP"
	try {
		if((Test-Path -Path $UUP_WorkingFolder) -and !$SkipRemoveUUPFolder) {
			Get-ChildItem -Path $UUP_WorkingFolder -Recurse -ErrorAction Stop | ForEach-Object {
				Remove-Item -Path $_.FullName -Recurse -Confirm:$false
			}
			Remove-Item -Path $UUP_WorkingFolder -Recurse -Force
		}
	} catch {
		Write-Host "[$(_LINE_)] Could not begin. Might need to restart system." -ForegroundColor Red
		return
	}

	if(!(Test-Path -Path $UUP_WorkingFolder -ErrorAction SilentlyContinue)) {
		$null = New-Item $UUP_WorkingFolder -ItemType Directory
		(get-item $UUP_WorkingFolder).Attributes += 'Hidden'
	} else {
		if(!$SkipRemoveUUPFolder) {
			Write-Host "[$(_LINE_)] Could not remove temp folder." -ForegroundColor Red
			return
		}
	}
}

# Create \temp folder in $WorkingFolder (C:\$ROCKS\)
if(!(Test-Path -Path $UUP_TempFolder)) {
	$null = New-Item -Path $UUP_TempFolder -ItemType Directory
}
#endregion TempFolder CleanUp and Creation

#region DownloadTest
# On 24.07.2019 i tried to download the current list and another entry appeared with
# no possible download option. So i have to check for download link first i guess,...
# or skip to the next possible download option.
# We should possibly NEVER skip this.
if(!$SkipDownloadTest) {
	# URL like "https://uupdump.ml/known.php?q=1903"
	$DownloadRequestURI = ("{0}{1}" -f $UUP_DownloadRequestURI,$URIRequestString)

	# Adding the ability to have the "user" (mostly me) select a Windows 10 release.
	# But i will have to have the CLI version for "Automation" purposes.
	if($DisplaySelectionGUI) {
		Write-Verbose "[$(_LINE_)] Retrieving new releases for '$URIRequestString' ..."
		try {
			$BuildRequest = Invoke-WebRequest -Uri $DownloadRequestURI -Verbose:$false
			$BuildRequestTable = Get-WebTable -WebRequest $BuildRequest -TableNumber 0
		} catch {
			Write-Host "[$(_LINE_)] Could not retrieve table from request. Error `"$($_.Exception.Message)`"" -ForegroundColor Red
		}

		# Users CAN input the wrong request string.
		if(!$BuildRequestTable) {
			Write-Host "[$(_LINE_)] Nothing found. Please choose another RequestURI" -ForegroundColor Red
			ScriptCleanUP -StopTranscript
			return
		}

		# GridView only if more than one entry
		# If single entry, that is the entry we need.
		# Implemented a counter to stop if tries are reached.
		$SelectCounter = 3
		while($SelectCounter -gt 0) {
			if($BuildRequestTable.Count -gt 1) {
				$BuildSelection = $BuildRequestTable | Out-GridView -Title "Windows 10 UUP Releases" -OutputMode Single
			} elseif ( ($BuildRequestTable.Count -eq 0) -or (!$BuildRequestTable.Count) ) {
				$BuildSelection = $BuildRequestTable
			}

			# User HAS TO select.
			if(!$BuildSelection) {
				Write-Host "[$(_LINE_)] Abortion is not supported. If you don't want to use the GUI dont select the switch for it, or have a clear RequestURI as we do not need to display a GUI for one result. Try -URIRequestString 'feature'." -ForegroundColor Red
				ScriptCleanUP -StopTranscript
				return
			}
			Write-Host "[$(_LINE_)] Selected: `"$($BuildSelection.Build)`" with ID: `"$($BuildSelection."Update ID")`""

			$DUMPY = $BuildSelection."Update ID"

			# Duplicate of the code down below, but i cannot merge them together properly
			# Have added a GUI message anyways, that does not need to be displayed on CLI.
			try {
				$Request_StatusCode = (Invoke-WebRequest -Uri  "$UUP_DownloadURI/selectedition.php?id=$DUMPY&pack=$OSMainLang" -UseBasicParsing).StatusCode
				Write-Verbose "[$(_LINE_)] '$DUMPY' Returned status code '$Request_StatusCode'"

				$DUMP_ID = $DUMPY
				$SelectCounter = 0
			} catch {
				$eMessage = $_.Exception.Message
				Write-Host "[$(_LINE_)] '$UUP_DownloadURI/selectedition.php?id=$DUMPY&pack=$OSMainLang' >> There is no language selection for this link... ($eMessage)" -ForegroundColor Red
				$null = [System.Windows.Forms.MessageBox]::Show(`
					"There is no language selection for this BuildID. Please select correct Windows 10 release.`n" +
					"Error: `"$eMessage`"`n`n" +
					"ID:`t$DUMPY`n" +
					"Lang:`$OSMainLang`n" +
					"$UUP_DownloadURI/selectedition.php?id=$DUMPY&pack=$OSMainLang",
				
					"Error downloading language package (#$(_LINE_))",`
					[System.Windows.Forms.MessageBoxButtons]::OKCancel,[System.Windows.Forms.MessageBoxIcon]::Warning)
				$SelectCounter--
			}
		} # /end while SelectCounter

		if(($SelectCounter -le 0) -and (!$DUMP_ID)) {
			Write-Host "[$(_LINE_)] Had your chance. Please try again later." -ForegroundColor Red
			ScriptCleanUP -StopTranscript
			return
		}
	} else { # CLI instead of GUI
		Write-Verbose "[$(_LINE_)] Request `"$DownloadRequestURI`""
		$Request = Invoke-WebRequest -Uri $DownloadRequestURI -Verbose:$false

		# Extract generic ids from links.
		# /get.php?id=91712d02-7dcf-478a-acfc-6e4c474fc754&pack=0&edition=0
		$DUMP_IDs = & {
			# Not here. Thats what the $URIRequestString is for!
			#$Request.Links | Where-Object { $_.outerHTML -match "(?=.*1903)(?=.*amd64)" }
			$Request.Links | Select-Object -Property * | Where-Object { $_.href -match "id[=]" } | ForEach-Object {
				$H = $_.href; $I = $H.IndexOf("=")+1; $H.substring($I, $H.length - $I)
			}
		}

		Write-Verbose "[$(_LINE_)] Checking for aria."

		# Remember: Do NOT use 'ForEach-Object' if you want to break out of that loop!
		foreach($DUMPY in $DUMP_IDs) {
			# return first successfull id
			# skipping until finding one.
			try {
				$Request_StatusCode = (Invoke-WebRequest -Uri  "$UUP_DownloadURI/selectedition.php?id=$DUMPY&pack=$OSMainLang" -UseBasicParsing -Verbose:$false).StatusCode
				Write-Verbose "[$(_LINE_)] '$DUMPY' returned status code '$Request_StatusCode'"

				$DUMP_ID = $DUMPY
				break
			} catch {
				$eMessage = $_.Exception.Message
				if($eMessage -like "*(429)*") {
					Write-Host "[$(_LINE_)] '$UUP_DownloadURI/selectedition.php?id=$DUMPY&pack=$OSMainLang' >> Too many requests? Looks like we will have to wait a while... ($eMessage)" -ForegroundColor Red
					break
				} else {
					Write-Host "[$(_LINE_)] '$UUP_DownloadURI/selectedition.php?id=$DUMPY&pack=$OSMainLang' >> Trying next one... ($eMessage)" -ForegroundColor DarkGray
				}
			}
		}

		# if none of them has been successful break this script.
		if(!$DUMP_ID) {
			Write-Host "[$(_LINE_)] No feature id found. Please leave the area." -ForegroundColor Red
			return
		}
	} # /end if GUI/NoGUI
} # /end SkipDownloadTest
#endregion DownloadTest

#region Download
# Had to test a lot, so we 'might' need to skip the donwload region
if(!$SkipDownload) {
	Write-Host "[$(_LINE_)] Downloading aria packages..."

	# First downloading package with more batch files, so we have them.
	# Have to download "normal" package afterwards, so the converter batch does not run (inside aria script).
	# Extracting and starting of converting will be done later.
	# ALSO: We don't have to use the pack=0 (all languages).
	# Will download languages down here somewhere.
	#Invoke-WebRequest -Uri "$UUP_DownloadURI/get.php?id=$DUMP_ID&pack=0&edition=0&autodl=2" -UseBasicParsing -OutFile "$UUP_TempFolder\aria_base.zip"
	Invoke-WebRequest -Uri "$UUP_DownloadURI/get.php?id=$DUMP_ID&pack=$OSMainLang&edition=0&autodl=2" -UseBasicParsing -OutFile "$UUP_TempFolder\aria_base.zip" -Verbose:$false
	
	Write-Verbose "[$(_LINE_)] Expanding Archive."
	if($PSVersionTable.PSVersion.Major -ge 5) {
		Expand-Archive -Path "$UUP_TempFolder\aria_base.zip" -DestinationPath $UUP_AriaBaseDir -Force
	} else {
		Write-Verbose "[$(_LINE_)] Ignoring Archive-Extraction in PSVersion.Major below version 5. Please upgrade your Windows Management Framework. Thanks."
		return
	}

	# After downloading and extracting the base zip for the $OSMainLang
	# we can download the standard aria download files for the main language.
	Write-Host "[$(_LINE_)] Downloading for language `"$($OSMainLang)`""
	try {
		Invoke-WebRequest -Uri "$UUP_DownloadURI/get.php?id=$DUMP_ID&pack=$OSMainLang&edition=0&autodl=1" -UseBasicParsing -OutFile "$UUP_TempFolder\aria.zip" -Verbose:$false
	} catch {
		Write-Host "[$(_LINE_)] Could not get current file list from '$UUP_DownloadURI/get.php?id=$DUMP_ID&pack=$OSMainLang&edition=0&autodl=1': $($_.Exception.Message)" -ForegroundColor Red
	}

	Write-Verbose "[$(_LINE_)] Expanding Archive."
	if($PSVersionTable.PSVersion.Major -ge 5) {
		Expand-Archive -Path "$UUP_TempFolder\aria.zip" -DestinationPath $UUP_AriaBaseDir -Force
	} else {
		Write-Verbose "[$(_LINE_)] Ignoring Archive-Extraction in PSVersion.Major below version 5. Please upgrade your Windows Management Framework. Thanks."
	}

	# After everything has been set up we start the aria downloader
	Write-Verbose "[$(_LINE_)] RUN CMD> Aria"
	Get-ChildItem -Path "$UUP_AriaBaseDir\aria*.cmd" | ForEach-Object {
		#Invoke-Item -Path $_.FullName # -WhatIf
		$Process = Start-Process "cmd" -ArgumentList "/c $($_.FullName)" -Wait -NoNewWindow
		$Process.ExitCode
	}
}
#endregion Download

#region FOD Download
# RSAT/FOD and LanguagePacks do not get included inside of the ISO/WIM.
# So we will have to implement that later.
# Here we have to download these cab files
if(!$SkipFODDownload) {
	# Getting all files in UUP folder
	$UPDUMP_AriaUUPs_AllFiles = Get-ChildItem -Path $UUP_AriaUUPs -Recurse | Where-Object { $_.FullName -notmatch '00._Archive' }

	# So we move them FODs in a subfolder.
	# Couldn't be implemented in ConvertUUP anyways.
	if(!(Test-Path -Path $UUP_AriaAdditionalFODs)) {
		$null = New-Item -Path $UUP_AriaAdditionalFODs -ItemType Directory
	}

	# !! The check for new files starts here !!
	# This way it is faster, as I do not have to parse or convert to table.
	# I might not get the filesize, but there is no use for this anyhow.
	$WebContent = Invoke-WebRequest -Uri "$UUP_DownloadURI/get.php?id=$DUMP_ID&simple=1" -UseBasicParsing -Verbose:$false | Select-Object -ExpandProperty Content
	
	$AdditionalFiles = & {
		$WebContent.Split("`n") | ForEach-Object {
			#microsoft-windows-irda-package-wow64-es-es.cab|43a354256b3d218831199729e0587f6daf4e3cb6|http://tlu.dl.delivery.mp.microsoft.com/filestreamingservice/files/17526a7f-d389-4536-8252-b0b3b18f055e?P1=1567499391&P2=402&P3=2&P4=P8odxxSDXVSfINJApBfpxBn%2bZ1nfVodGIz0zajZjLY8Ny8zCB4VD8AdkE6aeCFsHG16AqzxJzLuGnLiUQEjp0A%3d%3d
			$FileName,$FileHash,$DownloadURL = $_.Split("|")
			[PSCustomObject]@{
				"Name" = $FileName
				"SHA-1" = $FileHash
				"Link" = $DownloadURL
			}
		} | Where-Object { ($_.Name -match "[.](cab|esd|exe)") -and ($_.Name -notmatch "(core|professional)") }
	}

	# Some output for proving. only fileextensions are cab|esd and exe (only one file).
	#$AdditionalFiles | FT -AutoSize
	#$AdditionalFiles.Name | ForEach-Object { [System.IO.Path]::GetExtension($_) } | Select-Object -Unique
	
	<#
	# I will get the file from the links and compare them with the file array from above.
	# Tested for FOD and stuff, but that did not work, and did not get converted via ConvertUUP.
	Write-Host "[$(_LINE_)] Checking for FOD packages (started: $(Get-Date -Format "HH:mm:ss"))" -ForegroundColor Yellow -BackgroundColor Black
	#$Request = Invoke-WebRequest -Uri "$UUP_DownloadURI/findfiles.php?id=$DUMP_ID" -UseBasicParsing -Verbose:$false
	$Request = Invoke-WebRequest -Uri "$UUP_DownloadURI/findfiles.php?id=$DUMP_ID" -Verbose:$false

	# transforming html content into table to have the displayed values for the files.
	# see IWR from the top to have a look for yourself.
	Write-Host "[$(_LINE_)] Resolving table of files (started: $(Get-Date -Format "HH:mm:ss"))" -ForegroundColor Yellow -BackgroundColor Black
	$AdditionalFileTable = Get-WebTable -WebRequest $Request -TableNumber 0

	# Creating a list with additional files from Links.
	# All cabinet files are included.
	Write-Host "[$(_LINE_)] Building and alternating the complete file list (started: $(Get-Date -Format "HH:mm:ss"))" -ForegroundColor Yellow -BackgroundColor Black
	$AdditionalFiles = & {
		$RequestsCounter = 0
		# ? {$_.href -match "cab|esd" -and ($_.href -notmatch "[=](core|profess)") } | select href
		$RequestValidLinks = $Request.Links | Where-Object { ($_.href -match "[.](cab|esd|exe)") -and ($_.href -notmatch "[=](core|profess)") }
		Write-Verbose "[$(_LINE_)] Shredding through '$($RequestValidLinks.Count)' RequestLinks."
		$RequestValidLinks | ForEach-Object {
			$RequestLinkObject = $_

			$RequestsCounter++
			#Write-Verbose "[$(_LINE_)] [$RequestsCounter/$($RequestValidLinks.Count)] $($RequestLinkObject.href)" # only testing
			if(($RequestsCounter % 100 -eq 0) -or ($RequestsCounter -eq $RequestValidLinks.Count)) {
				Write-Verbose "[$(_LINE_)] [$RequestsCounter/$($RequestValidLinks.Count)] $($RequestLinkObject.href) (Reached: $(Get-Date -Format "HH:mm:ss"))" # only testing
			}

			# remove "getfile.php?id=" from the url, we just need the filename
			$Link = $RequestLinkObject.href -replace "&amp;","&"
			$DelimiterPosition = $Link.IndexOf("file=") + 5

			$FileName = $Link.substring($DelimiterPosition, $Link.length - $DelimiterPosition)
			$RequestLinkObject | Add-Member -MemberType NoteProperty -Name "Name" -Value $FileName

			# Removing the ./ from the link and combining it with URL-host
			# (e.g. ./getfile.php?id=90ce484a-2bc5-40ae-9169-9edf153cdf89&amp;file=microsoft-windows-admintools-fod-package-x86-fr-fr.cab).
			# Need to find the redirected link, but not doing it here, as this will just slow the script down dramatically (and i do not even need EVERY 1478 links ^^),
			$HREF = $Link -replace "./"
			$RequestLinkObject | Add-Member -MemberType NoteProperty -Name "Link" -Value ("$UUP_DownloadURI/$HREF")
			#$RequestLinkObject | Add-Member -MemberType NoteProperty -Name "RedirectedLink" -Value (Get-RedirectedUrl -URL "$UUP_DownloadURI/$HREF" -Verbose:$false) # 503-crap

			# Adding values from the WebTable in here.
			# The WebTable entries only have "File", "Size" and "SHA-1".
			$RequestTableEntry = $AdditionalFileTable | Where-Object { $_.File -match $FileName }
			if($RequestTableEntry) {
				$RequestLinkObject | Add-Member -MemberType NoteProperty -Name "SHA-1" -Value $RequestTableEntry."SHA-1"
				$RequestLinkObject | Add-Member -MemberType NoteProperty -Name "Size" -Value $RequestTableEntry."Size"
			}
			$RequestLinkObject
		}
	} # /end collecting additional files
	#$AdditionalFiles | Select -First 1 | FL
	#>

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
	<#
	Get-Job | Remove-Job -Force
	
	$MaxThreads = 10
	$SleepTimer = 500
	$SleepTimer_WaitForRunning = 60000
	$MaxWaitAtEnd = 600
	$i = 0
	#>
	
	# We have defined languages at start and now we download files specific to that defined languages.
	# Checking for existing files in the local folder.
	# Retry ~5 times if not all files have been downloaded
	Write-Host "[$(_LINE_)] Downloading additional files for defined languages '$OnlyLanguageEx'"
	$AdditionalFilesWithRexCode_Counter = 0
	do {
		$AdditionalFilesWithRexCode_Counter++

		Write-Host "[$(_LINE_)] ==========================================="
		Write-Host "[$(_LINE_)]                TRY NUMBER $AdditionalFilesWithRexCode_Counter"
		Write-Host "[$(_LINE_)] ==========================================="

		$UPDUMP_AriaUUPs_AllFiles = Get-ChildItem -Path $UUP_AriaUUPs -Recurse | Where-Object { $_.FullName -notmatch '00._Archive' }
		$LocalAdditionalFiles = $UPDUMP_AriaUUPs_AllFiles | Where-Object { $AdditionalFilesWithRexCode.Name -contains $_.Name }
		$AdditionalFilesWithRexCode_NotExistingLocally = $AdditionalFilesWithRexCode | Where-Object { $LocalAdditionalFiles.Name -notcontains $_.Name }
		$LocalAdditionalFilesNonLanguage = $UPDUMP_AriaUUPs_AllFiles | Where-Object { $AdditionalFilesWithoutLanguage.Name -contains $_.Name }
		$AdditionalFilesWithoutLanguage_NotExistingLocally = $AdditionalFilesWithoutLanguage | Where-Object { $LocalAdditionalFilesNonLanguage.Name -notcontains $_.Name }

		$AdditionalFilesWithRexCode_LocalCount = ($AdditionalFilesWithRexCode_NotExistingLocally | Measure-Object).Count
		Write-Verbose "[$(_LINE_)] CounterCheck: Downloading '$AdditionalFilesWithRexCode_LocalCount' files not matching the '$($LocalAdditionalFiles.Count)' files already existing locally."

		if(!$AdditionalFilesWithRexCode_NotExistingLocally) {
			Write-Host "[$(_LINE_)] All additional files for defined languages ($OnlyLanguageEx) have been downloaded." -ForegroundColor DarkGray
			$AdditionalFilesWithRexCode_Counter = 99
		} else {
			if($AdditionalFilesWithRexCode_Counter -gt 1) {
				Write-Verbose "[$(_LINE_)] Some files might still be needed. Waiting a few seconds before trying again (Try #$AdditionalFilesWithRexCode_Counter)."
				Start-Sleep -Seconds 15
			}
			$RexCodeAriaFile = "$UUP_AriaFiles\aria_script.custom_rex.$(Get-Date -Format "ddffffff").txt"
			$AdditionalFilesWithRexCode_NotExistingLocally | ForEach-Object {
				$FileName = $_.Name
				$FileHash = $_."SHA-1"
				$tURI = $_.Link
				
				<#
				$REDIR_MAX   = 10
				$REDIR_Count = 0
				$REDIR_BreakWhile = $false
				while(!$REDIR_BreakWhile) {
					#$tURI = $_.RedirectedLink
					if($REDIR_Count -gt 0) {
						Start-Sleep -Seconds 10
					}
					if(($RedirectedURI = Get-RedirectedUrl -URL $tURI -Verbose:$false) -or ($REDIR_Count -ge $REDIR_MAX)) {
						$REDIR_BreakWhile = $true # force quit
					}
					$REDIR_Count++
				}
				
				if($RedirectedURI) {
					$tURI = $RedirectedURI
				}
				#>
				#if $AdditionalFilesWithRexCode_LocalCount
				# Building aria list?
				$FileContent = @("$tURI`n  out=$FileName`n  checksum=sha-1=$FileHash`n")
				
				#$FileContent # only debug
				# Append to aria script file, Out-File saves as UTF8-BOM
				#$FileContent | Out-File -FilePath $RexCodeAriaFile -Encoding UTF8 -Append
				[System.IO.File]::AppendAllLines([string]$RexCodeAriaFile, [string[]]$FileContent)
			}

			# Loading all files with aria. This way it's kinda guaranteed that the files are correct.
			# Aria can continue stopped downloads, compare hash values etc.
			$rexArgumentList = " --log-level=debug --log=`"$UUP_AriaBaseDir\aria2_download_custom.log`" -x16 -s16 -j5 -c -R -d`"$UUP_AriaAdditionalFODs`" -i`"$RexCodeAriaFile`""
			Write-Verbose "Process: $UUP_AriaFiles\aria2c.exe $rexArgumentList"
			$rexProcess = Start-Process -FilePath "$UUP_AriaFiles\aria2c.exe" -ArgumentList $rexArgumentList -NoNewWindow -Wait -PassThru
			$rexProcess.ExitCode
			<#
			$AdditionalFilesWithRexCode_NotExistingLocally | ForEach-Object {
				$FileName = $_.Name
				$FileHash = $_."SHA-1"
				$HREF = $_.href -replace "./"
				Write-Verbose "[$(_LINE_)] Download: $FileName"

				# Loop threads running
				While ($(Get-Job -state running).count -ge $MaxThreads){
					Start-Sleep -Milliseconds $SleepTimer
				}

				$tURI = "$UUP_DownloadURI/$HREF"

				# Some test-uris have lost ping
				# Here is my check to prevent losing a file.
				$ReCheckCount = 3 # Someone might lose a ping...
				while($ReCheckCount -gt 0) {
					# IF "too many request" => No Download
					if($tResult = Test-URI -Uri $tURI -verbose:$false) {
						$tDownloadFilePath = "$UUP_AriaAdditionalFODs\$FileName"

						# File-Check
						if(!(Test-Path -Path $tDownloadFilePath -ErrorAction SilentlyContinue)) {
							#Write-Host "`"$tDownloadFilePath`" loading..." -ForegroundColor Yellow
							#Invoke-WebRequest -Uri $tURI -UseBasicParsing -OutFile $tDownloadFilePath

							Start-Job {Invoke-WebRequest $using:tURI -Method Get -OutFile $using:tDownloadFilePath -UserAgent FireFox -UseBasicParsing -Verbose:$false} | Out-Null
						} else {
							Write-Verbose "[$(_LINE_)] [$ReCheckCount] '$tDownloadFilePath' file exists"
						}
						$ReCheckCount = 0 # bye
					} else {
						Write-Host "[$(_LINE_)] [$ReCheckCount] $tURI ($tResult)" -BackgroundColor Black -ForegroundColor Red

						$HTTP_Request = [System.Net.WebRequest]::Create($tURI)
						try {
							$HTTP_Response = $HTTP_Request.GetResponse()
						} catch {
							Write-Host "$($_.Exception.Message)" -BackgroundColor Black -ForegroundColor Red
						}
						$HTTP_Status = [int]$HTTP_Response.StatusCode

						Write-Host "[$(_LINE_)] WebResponse: $HTTP_Response WebStatusCode: $HTTP_Status RunningJobs: $((Get-Job -state running).count)" -BackgroundColor Black -ForegroundColor Cyan
						Start-Sleep -Seconds 1

						#Write-Host "`"$tURI`"" -ForegroundColor Red
						$ReCheckCount--
					}
				} # /end CheckCount
			} # /end download additional files for language
			#>
		} # /end check for already downloaded files

		# At least we now download all files WITHOUT lang code that exists in all files list.
		# Checking for existing files in the local folder.
		Write-Host "[$(_LINE_)] Downloading additional files left..."
		
		$AdditionalFilesWithoutLanguage_LocalCount = ($AdditionalFilesWithoutLanguage_NotExistingLocally | Measure-Object).Count
		Write-Verbose "[$(_LINE_)] CounterCheck: Downloading '$AdditionalFilesWithoutLanguage_LocalCount' files not matching the '$($LocalAdditionalFilesNonLanguage.Count)' files already existing locally."

		if(!$AdditionalFilesWithoutLanguage_NotExistingLocally) {
			Write-Host "[$(_LINE_)] All additional files left have been downloaded." -ForegroundColor DarkGray
		} else {
			$LangCodeAriaFile = "$UUP_AriaFiles\aria_script.custom_lang.$(Get-Date -Format "ddffffff").txt"
			$AdditionalFilesWithoutLanguage_NotExistingLocally | ForEach-Object {
				$FileName = $_.Name
				$FileHash = $_."SHA-1"
				$tURI = $_.Link
				
				<#
				$REDIR_MAX   = 10
				$REDIR_Count = 0
				$REDIR_BreakWhile = $false
				while(!$REDIR_BreakWhile) {
					#$tURI = $_.RedirectedLink
					if($REDIR_Count -gt 0) {
						Start-Sleep -Seconds 10
					}
					if(($RedirectedURI = Get-RedirectedUrl -URL $tURI -Verbose:$false) -or ($REDIR_Count -ge $REDIR_MAX)) {
						$REDIR_BreakWhile = $true # force quit
					}
					$REDIR_Count++
				}
				
				if($RedirectedURI) {
					$tURI = $RedirectedURI
				}
				#>
				#if $AdditionalFilesWithRexCode_LocalCount
				# Building aria list?
				$FileContent = @("$tURI`n  out=$FileName`n  checksum=sha-1=$FileHash`n")
				#$FileContent # only debug

				# Append to aria script file, Out-File saves as UTF8-BOM
				#$FileContent | Out-File -FilePath $LangCodeAriaFile -Encoding UTF8 -Append
				[System.IO.File]::AppendAllLines([string]$LangCodeAriaFile, [string[]]$FileContent)
			}

			# Loading all files with aria. This way it's kinda guaranteed that the files are correct.
			# Aria can continue stopped downloads, compare hash values etc.
			$rexArgumentList = " --log-level=debug --log=`"$UUP_AriaBaseDir\aria2_download_custom.log`" -x16 -s16 -j5 -c -R -d`"$UUP_AriaAdditionalFODs`" -i`"$LangCodeAriaFile`""
			Write-Verbose "Process: $UUP_AriaFiles\aria2c.exe $rexArgumentList"
			$rexProcess = Start-Process -FilePath "$UUP_AriaFiles\aria2c.exe" -ArgumentList $rexArgumentList -NoNewWindow -Wait -PassThru
			$rexProcess.ExitCode
			<#
			$AdditionalFilesWithoutLanguage_NotExistingLocally | ForEach-Object {
				$FileName = $_.Name
				$HREF = $_.href -replace "./"
				Write-Verbose "[$(_LINE_)] Download: $FileName"

				# Loop threads running
				While ($(Get-Job -state running).count -ge $MaxThreads){
					Start-Sleep -Milliseconds $SleepTimer
				}

				$tURI = "$UUP_DownloadURI/$HREF"
			
				# Some test-uris have lost ping
				# Here is my check to prevent losing a file.
				$ReCheckCount = 3 # Someone might lose a ping...
				while($ReCheckCount -gt 0) {
					if($tResult = Test-URI -URI $tURI -Verbose:$false) {
						$tDownloadFilePath = "$UUP_AriaAdditionalFODs\$FileName"

						# File-Check
						if(!(Test-Path -Path $tDownloadFilePath -ErrorAction SilentlyContinue)) {
							#Write-Host "`"$tDownloadFilePath`" loading..." -ForegroundColor Yellow
							#Invoke-WebRequest -Uri $tURI -UseBasicParsing -OutFile $tDownloadFilePath

							Start-Job {Invoke-WebRequest $using:tURI -Method Get -OutFile $using:tDownloadFilePath -UserAgent FireFox -Verbose:$false} | Out-Null
						} else {
							Write-Verbose "[$(_LINE_)] [$ReCheckCount] '$tDownloadFilePath' file exists"
						}
						$ReCheckCount = 0
					} else {
						Write-Host "[$(_LINE_)] [$ReCheckCount] $tURI ($tResult)" -BackgroundColor Black -ForegroundColor Red

						$HTTP_Request = [System.Net.WebRequest]::Create($tURI)
						try {
							$HTTP_Response = $HTTP_Request.GetResponse()
						} catch {
							Write-Host "$($_.Exception.Message)" -BackgroundColor Black -ForegroundColor Red
						}
						$HTTP_Status = [int]$HTTP_Response.StatusCode
						
						Write-Host "[$(_LINE_)] WebResponse: $HTTP_Response WebStatusCode: $HTTP_Status" -BackgroundColor Black -ForegroundColor Cyan

						$ReCheckCount--
					}
				}
			}
			#>
		}

		# Waiting for jobs to complete
		<#
		Write-Host "[$(_LINE_)] Waiting on running jobs"
		$Complete = Get-date
		While ($(Get-Job -State Running).count -gt 0){
			$JobsStillRunning = ""
			ForEach ($System  in $(Get-Job -state running)){$JobsStillRunning += ", $($System.name)"}
			$JobsStillRunning = $JobsStillRunning.Substring(2)
			
			Write-Host "[$(_LINE_)] $($(Get-Job -State Running).count) threads remaining ($JobsStillRunning)"
			if ($(New-TimeSpan $Complete $(Get-Date)).TotalSeconds -ge $MaxWaitAtEnd){"Killing all jobs still running ...";Get-Job -State Running | Remove-Job -Force}
			Start-Sleep -Milliseconds $SleepTimer_WaitForRunning
		}
		#>
	} while($AdditionalFilesWithRexCode_Counter -lt 5)
 
	<#
	Write-Host "[$(_LINE_)] Receiving all jobs"
	ForEach($Job in Get-Job){
		#Receive-Job $Job
		$null = $Job | Wait-Job
	}
	#>
} # /end skip fod download
#endregion

#region ConvertUUP
# Invoking the ConvertUUP.bat. This will create the ISO for us.
# We cannot inject the LPs or RSAT this way, but we have SCCM, so who cares.
if(!$SkipUUPConvert) {
	Read-Host -Prompt "Ready?"

	Get-ChildItem -Path "$UUP_AriaFiles\*.7z" | ForEach-Object {
		$DestinationFolder = "$UUP_AriaFiles\" + $_.BaseName

		$Process = Start-Process $UUP_7zExec -ArgumentList "x -y $($_.FullName) -o`"$DestinationFolder`"" -Wait -WindowStyle Minimized
		$Process.ExitCode

		#$ExtractedFiles = Get-ChildItem -Path $DestinationFolder -Recurse

		# /MIR = /E (Unterverzeichnisse) und /PURGE (L�schen im Ziel)
		RoboCopy $DestinationFolder $UUP_AriaBaseDir /COPYALL /E /R:5 /W:10 /LOG:"$env:TEMP\robcopy_$(Get-Date -Format "yyMMdd-HHmmss.fffffff").log" /TEE
	}

	# Running this is a capsulated ScriptBlock.
	# We do not need those values and results.
	& {
		# "Just" a quick test to see if config has changed.
		# If numbers of lines do NOT match, i compare the content and see if there is a new value/key.
		$ConvertConfigContent_Archive = Get-Content -LiteralPath $UUP_ConvertConfig
		$ConvertConfigContent_Custom  = Get-Content -LiteralPath $LocalConvertConfig

		if(!(Test-Path -Path $LocalConvertConfig -ErrorAction SilentlyContinue)) {
			Write-Host "[$(_LINE_)] '$LocalConvertConfig' could not be found. Script finished." -ForegroundColor Red
			ScriptCleanUP -StopTranscript
			return
		}

		$LinesArchiveConfig = ($ConvertConfigContent_Archive | Measure-Object).Count
		$LinesCustomConfig  = ($ConvertConfigContent_Custom  | Measure-Object).Count
		if($LinesArchiveConfig -ne $LinesCustomConfig) {
			Write-Verbose "[$(_LINE_)] CenvertConfig.ini might have been changed ($LinesArchiveConfig/$LinesCustomConfig)."
			$ConvertConfigComparison = Compare-Object -ReferenceObject $LinesArchiveConfig -DifferenceObject $LinesCustomConfig
			$ComparisonInputObjects   = $ConvertConfigComparison.InputObject
		
			# when there is just some other value there are two values
			# but when there is a new entry, there is inly one value.
			$NewConfigEntries = $ComparisonInputObjects | ForEach-Object { $a,$b = "$_" -split "=",2; $a } | Group-Object | Where-Object { $_.Count -lt 2 }
			if($NewConfigEntries) {
				$NewConfigEntries | ForEach-Object {
					$entry = $_.Name
					$entryCompare = $ConvertConfigComparison | Where-Object { $_.InputObject -match $entry }
					if($entryCompare.SideIndicator -eq "<=") {
						Write-Host "New entry in '$UUP_ConvertConfig': '$entry'" -ForegroundColor Yellow
					} elseif($entryCompare.SideIndicator -eq "=>") {
						Write-Host "New entry in '$LocalConvertConfig': '$entry'" -ForegroundColor Yellow
					} else {
						# dunno how anyone should get here
						Write-Host "Error fetching entries. ($entry|$entryCompare)"
					}
				}
			} else {
				Write-Host "No new entries in configs found. Might be just a line number mismatch." -ForegroundColor Yellow
			}

			Write-Host "To let you choose what to do we will wait ~20 seconds." -BackgroundColor Black -ForegroundColor Cyan
			Start-Sleep -Seconds 20
		} # /end if lines not match
	} # /end of capsulated block (ConvertConfig match check)

	# Copying ConvertConfig into where the convert script lies.
	# Might will have to check for changes regularyly.
	$null = Copy-Item $LocalConvertConfig -Destination $UUP_AriaBaseDir

	Write-Verbose "[$(_LINE_)] RUN CMD> UUP-Convert"
	Get-ChildItem -Path $UUP_ConvertConfBatch | ForEach-Object {
		$Process = Start-Process "cmd" -ArgumentList "/c $($_.FullName)" -Wait -NoNewWindow
		$Process.ExitCode
	}
} # /end SkipUUP
#endregion ConvertUUP

#region Remove UUP
# We can acutally run the "create_virtual_editions.cmd" separately
# So we remove only the big UUP files first
if(!$SkipRemoveUUPFolder) {
	try {
		if((Test-Path -Path $UUP_AriaUUPs)) {
			Get-ChildItem -Path $UUP_AriaUUPs -Recurse -ErrorAction Stop | ForEach-Object {
				Remove-Item -Path $_.FullName -Recurse -Confirm:$false
			}
			Remove-Item -Path $UUP_AriaUUPs -Recurse -Force
		}
	} catch {
		Write-Host "[$(_LINE_)] Exception while removing: $($_.Exception.Message)." -ForegroundColor Red
		#return
	}
}
#endregion Remove UUP

$EndTime = Get-Date
Write-Host "STEP1: Ended at $(Get-Date -Format "dd.MM.yy HH:mm:ss")"

$TimeSpan = (New-TimeSpan -Start $StartTime -End $EndTime) -join ";"
Write-Host "STEP1: Duration: $TimeSpan"

ScriptCleanUP -StopTranscript
# /END FOR PART #1