# TODOs:
# - GridView feature files selection
# - Cleaning this up and resort!?
# - Move complete folder "\Builder" in C:\UUPSTUFF$ Folder?

[CmdLetBinding()]
param(
	$SearchParam = "feat+windows+10+20H2+amd64",
	#$SearchParam = "feat+windows+10+amd64",
	$Language = "de-DE",
	$EditionCode = 0, # CORE, COREN, PROF, PROFN or 0 = ALL
	[switch]$SkipAPICalls,
	[switch]$SkipUUPCheck,
	[switch]$SkipAriaDownload,
	[switch]$SkipUUPConverter
)

Get-ChildItem -Path "$PSScriptRoot\API" -Recurse -File -Force | Where-Object { $_.Name -like "*.ps1" } | ForEach-Object {
	try {
		Import-Module $_.FullName -Force
	}
 catch {
		Write-Host "Error on importing Module '$($_.BaseName)': $($_.Exception.Message)" -BackgroundColor Black -ForegroundColor Red
		return
	}
}

#
#  GLOBAL VARIABLES
#
#region GLOBAL VARIABLES
#DEBUG
$VerbosePreference = [System.Management.Automation.ActionPreference]::Continue

$SubFolder = "$PSScriptRoot\Builder"

# Github Repo for the converter files...
$DownloadAutoDLFiles_URI = "https://github.com/uup-dump/autodl_files/archive/master.zip"
#$DownloadAutoDLFiles_ExtractedFolderName = "autodl_files-master" # needed for ps <= 5

$Application_Aria = "$SubFolder\files\aria2c.exe"

$AriaDownloadScript_Name = "aria_script.$(Get-Random -Minimum 100 -Maximum 99999).txt"
$AriaDownloadScript_Partial = "files\$AriaDownloadScript_Name"
$AriaDownloadScript_Full = "$SubFolder\$AriaDownloadScript_Partial"

$Aria_DestinationFolder = "$SubFolder\UUPs"
#endregion

#region Robocopy
# Robocopy ENUM, because handling can be difficult.
[Flags()] Enum RoboCopyExitCodes{
	NoChange = 0
	OKCopy = 1
	ExtraFiles = 2
	MismatchedFilesFolders = 4
	FailedCopyAttempts = 8
	FatalError = 16
}
#endregion

#region Script Diagnostic Functions
function Get-CurrentLineNumber {
	$MyInvocation.ScriptLineNumber
}
New-Alias -Name _LINE_ -Value Get-CurrentLineNumber -Description "Returns the current line number in a PowerShell script file." -Force

function Get-CurrentFileName {
	$MyInvocation.ScriptName
}
New-Alias -Name _FILE_ -Value Get-CurrentFileName -Description "Returns the name of the current PowerShell script file." -Force
#endregion

#
#   API CALLS (UUPDump, Windows 10 1709+)
#
#region API Calls
if (!$SkipAPICalls) {
	# Function returning all UUIDs, sorted by creation date (newest at first).
	try {
		$LatestUUPData = Get-UUPIDs -SearchQuery $SearchParam -Verbose:$VerbosePreference | Select-Object -First 1
	}
 catch {
		Write-Host "[$(_LINE_)] Error fetching ids: $($_.Exception.Message)" -BackgroundColor Black -ForegroundColor Red
		return
	}

	# https://api.uupdump.ml/get.php?id=e7f5c4e9-b130-47ff-9cb7-bc48544ea82b&lang=de-de
	# https://api.uupdump.ml/get.php?id=e7f5c4e9-b130-47ff-9cb7-bc48544ea82b&lang=de-de&edition=PROFESSIONALN
	# https://api.uupdump.ml/get.php?id=e7f5c4e9-b130-47ff-9cb7-bc48544ea82b&lang=de-de&edition=0
	$LatestUUP_FileList = Get-UUPFiles -UpdateID $LatestUUPData.uuid -allFiles -Verbose:$VerbosePreference

	if ($LatestUUP_FileList -and ($LatestUUP_FileList | Measure-Object).Count -gt 0) {
		Write-Verbose "File list received. Time to create an aria file out of it."
        
		$FilterRegexLanguageCodes = "[-]([a-z]{2}[-])([a-z]{4}[-][a-z]{2}|[a-z]{2})[.]"

		# TODO: Put this at parameters
		$SelectedLanguage = $null
		$SelectedFeatureRex = "FOD|metadata"
		#$SelectedFeatureRex = "FOD[\s\S]*?amd64"
		
		$SelectedFeatureRex = "language"
		$SelectedLanguage = "de-de|en-us|sv-se|hu-hu|fr-fr|nl-nl"
		#$SelectedLanguage = "en-us"
		#$SelectedLanguage   = "de-de" # en-us, sv-se, fr-fr, nl-nl, hu-hu

		# Deselect languages when no language is selected
		if ($null -eq $SelectedLanguage) {
			$RexMatch = $SelectedFeatureRex
			$RexNotMatch = $FilterRegexLanguageCodes
			#$Files_FOD = $LatestUUP_FileList | Where-Object { ($_.FileName -match $SelectedFeatureRex) -and ($_.FileName -notmatch $FilterRegexLanguageCodes) }
		}
		else {
			$RexMatch = "($SelectedFeatureRex)[\s\S]*?($SelectedLanguage)"
			$RexNotMatch = "NOMATCH"
			#$Files_Lang = $LatestUUP_FileList | Where-Object { ($_.FileName -match "$SelectedFeatureRex[\s\S]*?$SelectedLanguage") -and ($_.FileName -notmatch "NOMATCH") }
		}
		$LatestUUP_FileList = $LatestUUP_FileList | Where-Object { ($_.FileName -match $RexMatch) -and ($_.FileName -notmatch $RexNotMatch) }
		$FilesTotalSize = 0
		($LatestUUP_FileList | Select-Object -ExpandProperty FileData).size | ForEach-Object { $FilesTotalSize += $_ }
		
		# TODO: Move somewhere
		function FormatBytes($num) {
			$suffix = "B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"
			$index = 0
			while ($num -gt 1kb) {
				$num = $num / 1kb
				$index++
			} 

			"{0:N1} {1}" -f $num, $suffix[$index]
		}

		$FilesTotalSizeConverted = FormatBytes $FilesTotalSize

		# FOD, but not languages!?
		Write-Host "[$(_LINE_)] Are theres the files you are looking for (with a total size of $FilesTotalSizeConverted)?"
		#($LatestUUP_FileList | Where-Object { ($_.FileName -match "FOD") -and ($_.FileName -notmatch "[-]([a-z]{2}[-])([a-z]{4}[-][a-z]{2}|[a-z]{2})[.]") }).FileName | Out-Host
		#$LatestUUP_FileList = $LatestUUP_FileList | Where-Object { ($_.FileName -match "FOD") -and ($_.FileName -notmatch "[-]([a-z]{2}[-])([a-z]{4}[-][a-z]{2}|[a-z]{2})[.]") }
		#($LatestUUP_FileList | Where-Object { ($_.FileName -like "*language*de-de*") }).FileName | Out-Host
		#$LatestUUP_FileList = $LatestUUP_FileList | Where-Object { ($_.FileName -like "*language*de-de*") }
		$LatestUUP_FileList.FileName | Out-Host


		Start-Sleep -Seconds 1
		Write-Host ""
		Read-Host -Prompt "Finished with setting up 'FOD' files for aria. Press any key to continue with aria download."

		# create aria script download array
		$FileContent = @()
		$LatestUUP_FileList | ForEach-Object {
			$ChecksumType = "Unknown"
			if ($_.FileData.sha1) {
				$ChecksumType = "sha-1"
			}
			$FileContent += "$($_.FileData.url)"
			$FileContent += "  out=$($_.FileName)"
			$FileContent += "  checksum=$ChecksumType=$($_.FileData.sha1)"
			$FileContent += ""
		}
	}
}
#endregion

#
#   UUP converter files check
#
#region UUPCHECK
if (!$SkipUUPCheck) {
	Write-Host "[$(_LINE_)] Checking for UUP prerequisites..."
	
	# Do not mess with the script!
	if (!$DownloadAutoDLFiles_URI) {
		Write-Host "[$(_LINE_)] There was an error with the GitHub Repo..." -BackgroundColor Black -ForegroundColor Red
		return
	}

	# files folder
	# TODO: Check for 7zr exe etc...
	if (!(Test-Path -Path "$SubFolder\files")) {
		Write-Verbose "'$SubFolder\files' path does not exist. Downloading needed files now."

		# create temp
		if (!(Test-Path -Path "$SubFolder\temp")) {
			Write-Verbose "'$SubFolder\temp' path does not exist. Creating path."
			$null = New-Item -Path "$SubFolder\temp" -ItemType Directory -Force
		}
		if (!(Test-Path "$SubFolder\temp\files.zip")) {
			Write-Verbose "'$SubFolder\temp\files.zip' file does not exist. Downloading uupdump.ml autodl_files."
			Invoke-WebRequest -Uri $DownloadAutoDLFiles_URI -UseBasicParsing -OutFile "$SubFolder\temp\files.zip" -Verbose:$false
		}

		Write-Verbose "'$SubFolder\temp\files.zip' got to be extracted now."
		if ($PSVersionTable.PSVersion.Major -gt 5) {
			try {
				$ExpandedFiles = Expand-Archive "$SubFolder\temp\files.zip" -DestinationPath "$SubFolder" -Force -PassThru -Verbose:$VerbosePreference
			}
			catch {
				Write-Host "[$(_LINE_)] Error expanding archive '$SubFolder\temp\files.zip': $($_.Exception.Message)" -BackgroundColor Black -ForegroundColor Red
				return
			}
			if ($ExpandedFiles) {
				$ExtractedFolder = $ExpandedFiles | Where-Object { $_.PsIsContainer }
				if ($ExtractedFolder) {
					Rename-Item $ExtractedFolder.FullName -NewName files
				}
			}
		}
		else {
			# "If you want to use ZipFileExtensions.ExtractToDirectory() with overwrite, you'll need to extract the
			# files to a temporary folder and then copy/move them to the desired location."
			$TempFolder = Join-Path -Path "$SubFolder\temp" -ChildPath ([System.IO.Path]::GetRandomFileName()) -Verbose:$VerbosePreference
			
			# Unfortunately there is no -PassThru on Expand-Archive in PowerShell Major less than 5...
			# Could fetch files and folders like in above statement.
			Expand-Archive "$SubFolder\temp\files.zip" -DestinationPath $TempFolder -Force -Verbose:$VerbosePreference
			$DownloadDirecory = (Get-ChildItem -Path $TempFolder -Directory).FullName
			
			if (!(Test-Path -Path "$SubFolder\files")) {
				$null = New-Item -Path "$SubFolder\files" -ItemType Directory -Force
			}

			# Copy-Item files to the files folder.
			$DownloadDirectory_Files = Get-ChildItem -Path $DownloadDirecory
			if (!$DownloadDirectory_Files) {
				Write-Host "Error fetching files from extracted directory." -BackgroundColor Black -ForegroundColor Red
				return
			}
			$DownloadDirectory_Files | ForEach-Object {
				$null = Copy-Item -Path $_.FullName -Destination "$SubFolder\files" -Force -Recurse
			}
		}

		if (Test-Path "$SubFolder\temp\files.zip") {
			Write-Verbose "Cleaning temp folder."
			$null = Remove-Item -Path "$SubFolder\temp" -Recurse -Force -Verbose:$VerbosePreference
		}
	}

	# TODO: Test for exe, zip
	if (!(Test-Path -Path "$SubFolder\files\7zr.exe") -or !(Test-Path -Path "$SubFolder\files\uup-converter-wimlib.7z")) {
		Write-Host "[$(_LINE_)] Error on checking files on the extracted directory." -BackgroundColor Black -ForegroundColor Red
		return
	}

	# extract them files...
	Write-Verbose "Extracting them files from uup-converter-wimlib."
	#Write-Verbose "`"$SubFolder\files\7zr.exe`" -ArgumentList `"-x!ConvertConfig.xml -y x `"$SubFolder\files\uup-converter-wimlib.7z`"`"" -Verbose
	$Process = Start-Process -FilePath "$SubFolder\files\7zr.exe" -ArgumentList "-x!ConvertConfig.xml -y x `"$SubFolder\files\uup-converter-wimlib.7z`" -o$Subfolder" -Wait -PassThru -WindowStyle Hidden
	if ($Process.ExitCode -ne 0) {
		Write-Host "[$(_LINE_)] Error extracting needed files. Please fix this!! (Exited with error code '$($Process.ExitCode)')" -BackgroundColor Black -ForegroundColor Red
		return
	}
 else {
		Write-Host "[$(_LINE_)] Extracted files from 'files\uup-converter-wimlib.7z'." -BackgroundColor Black -ForegroundColor Green
	}

	# if already loaded file list...
	if (!$SkipAPICalls -and $FileContent) {
		if (!(Test-Path -Path "$SubFolder\files")) {
			$null = New-Item -Path "$SubFolder\files" -ItemType Directory -Force
		}
		# HAS TO HAVE UTF8!!. Core sets it right, "normal" version does not!!
		if ($PSVersionTable.PSVersion.Major -gt 5) {
			$FileContent | Out-File -FilePath $AriaDownloadScript_Full -Force -Verbose:$VerbosePreference
		}
		else {
			$Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
			[System.IO.File]::WriteAllLines($AriaDownloadScript_Full, $FileContent, $Utf8NoBomEncoding)
		}
	}

	Write-Verbose "Done checking for UUP prerequisites."
}
#endregion

# FILTER STUFF!


#
#   Aria Stuff
#
#region ARIA DOWNLOAD
if (!$SkipAriaDownload) {
	if (!(Test-Path -Path $Application_Aria)) {
		Write-Host "[$(_LINE_)] Aria application does not exist. This file is inside the uup-converter autodl_files. (Is CheckConverter skipped: $SkipUUPCheck)" -BackgroundColor Black -ForegroundColor Red
		return
	}
	
	# Not needed to check for press when downloaded files.
	#Read-Host -Prompt "Finished with setting up files for aria. Press any key to continue with aria download."

	#"%aria2%" --no-conf --log-level=info --log="aria2_download.log" -x16 -s16 -j5 -c -R -d"%destDir%" -i"%aria2Script%"
	$ArgumentList = "--no-conf --log-level=info --log=`"$SubFolder\aria2_download.log`" -x16 -s16 -j5 -c -R -d`"$Aria_DestinationFolder`" -i`"$AriaDownloadScript_Full`""
	Write-Verbose "$Application_Aria $ArgumentList"
	$Process = Start-Process -FilePath $Application_Aria -ArgumentList $ArgumentList -Wait -NoNewWindow -PassThru
	Write-Host "[$(_LINE_)] Exit: $LASTEXITCODE $($Process.ExitCode)"

	if ($Process.ExitCode -ne 0) {
		Write-Host "[$(_LINE_)] Aria exited with ExitCode '$($Process.ExitCode)'. Aborting rest of script." -BackgroundColor Black -ForegroundColor Red
		return
	}
}
#endregion

#region Convert ESD Files
# TODO: Move file download to top
#https://github.com/abbodi1406/WHD/blob/master/scripts/ESD2CAB-CAB2ESD.zip
if (!$SkipUUPConverter) {
	# TODO: Check and than skip!
	$ESDFiles = Get-ChildItem -Path "$SubFolder\UUPs" -Filter "*.esd"

	# testing for temp
	if (!(Test-Path -Path "$SubFolder\temp")) {
		Write-Verbose "'$SubFolder\temp' path does not exist. Creating path."
		$null = New-Item -Path "$SubFolder\temp" -ItemType Directory -Force
	}

	# if file not existing
	#Invoke-WebRequest -Uri "https://github.com/abbodi1406/WHD/blob/master/scripts/ESD2CAB-CAB2ESD.zip" -UseBasicParsing -OutFile "$SubFolder\temp\ESD2CAB-CAB2ESD.zip" -Verbose:$true
	#(New-Object System.Net.WebClient).DownloadFile("https://github.com/abbodi1406/WHD/blob/master/scripts/ESD2CAB-CAB2ESD.zip", "$SubFolder\temp\ESD2CAB-CAB2ESD.zip")
	#(New-Object System.Net.WebClient).DownloadFileAsync("https://api.github.com/repos/abbodi1406/WHD/blob/master/scripts/ESD2CAB-CAB2ESD.zip", "$SubFolder\temp\ESD2CAB-CAB2ESD.zip")

	#https://api.github.com/repos/abbodi1406/WHD/contents/scripts/ESD2CAB-CAB2ESD.zip
	$Response = Invoke-WebRequest -Uri "https://api.github.com/repos/abbodi1406/WHD/contents/scripts/ESD2CAB-CAB2ESD.zip" -UseBasicParsing -Verbose:$false
	if ($Response.Content) {
		$GitObjects = $Response.Content | ConvertFrom-Json
		#$GitObjects | Where-Object { $_.type -eq "file" } | Select-Object -ExpandProperty download_url
		Invoke-WebRequest -Uri "$($GitObjects | Select-Object -ExpandProperty download_url)" -OutFile "$SubFolder\temp\ESD2CAB-CAB2ESD.zip" -UseBasicParsing -Verbose:$false
	}

	Write-Verbose "'$SubFolder\temp\ESD2CAB-CAB2ESD.zip' got to be extracted now."
	if ($PSVersionTable.PSVersion.Major -gt 5) {
		try {
			$ExpandedFiles = Expand-Archive "$SubFolder\temp\ESD2CAB-CAB2ESD.zip" -DestinationPath "$SubFolder\tools" -Force -PassThru -Verbose:$VerbosePreference
		}
		catch {
			Write-Host "[$(_LINE_)] Error expanding archive '$SubFolder\temp\ESD2CAB-CAB2ESD.zip': $($_.Exception.Message)" -BackgroundColor Black -ForegroundColor Red
			return
		}
		if ($ExpandedFiles) {
			#!?
		}
	}
 else {
		# "If you want to use ZipFileExtensions.ExtractToDirectory() with overwrite, you'll need to extract the
		# files to a temporary folder and then copy/move them to the desired location."
		$TempFolder = Join-Path -Path "$SubFolder\temp" -ChildPath ([System.IO.Path]::GetRandomFileName()) -Verbose:$VerbosePreference
        
		# Unfortunately there is no -PassThru on Expand-Archive in PowerShell Major less than 5...
		# Could fetch files and folders like in above statement.
		Write-Verbose "`"$SubFolder\temp\ESD2CAB-CAB2ESD.zip`" -DestinationPath `"$SubFolder\tools`""
		Expand-Archive "$SubFolder\temp\ESD2CAB-CAB2ESD.zip" -DestinationPath "$SubFolder\tools" -Force -Verbose:$VerbosePreference
	}

	if (Test-Path -Path "$SubFolder\temp\ESD2CAB-CAB2ESD.zip" -ErrorAction SilentlyContinue) {
		Remove-Item -Path "$SubFolder\temp\ESD2CAB-CAB2ESD.zip" -Recurse
	}

	if (Test-Path -Path "$SubFolder\tools\bin") {
		if ($env:PROCESSOR_ARCHITECTURE -eq "AMD64") {
			$arch = "x64"
		}
		else {
			$arch = "x86"
		}

		# Setting needed applications
		if (Test-Path -Path "$SubFolder\tools\bin\image$arch.exe") {
			$AppImageXOld = Get-Item -Path "$SubFolder\tools\bin\image$arch.exe"
		}
		if (Test-Path -Path "$SubFolder\tools\bin\cabarc.exe") {
			$AppCabarc = Get-Item -Path "$SubFolder\tools\bin\cabarc.exe"
		}
		if (!$AppImageXOld -or !$AppCabarc) {
			Write-Host "[$(_LINE_)] Error on getting cabarc and imagex..." -BackgroundColor Black -ForegroundColor Red
			return
		}
	}

	if ($ESDFiles.Count -eq 0) {
		Write-Host "[$(_LINE_)] 0 ESD Files found."
	}
 else {
		# INFOS:
		# - ImageX and Cabarc are best run locally (tested with Virtual Machine in Hyper-V)
		# - Using folder directly on the SystemDrive, better than the path i used
		# 	(the extracted files have way too long file names)
		# - Functions for temp paths
		#   [System.IO.Path]::GetTempPath(); [System.Guid]::NewGuid(); [System.IO.Path]::GetRandomFileName()
		# - TODO: Hm, maybe checking for UNC or not?

		$WorkingFolder = "$env:SystemDrive\`$UUPConvert"
		if (!(Test-Path -Path "$WorkingFolder" -ErrorAction SilentlyContinue)) {
			Write-Host "[$(_LINE_)] Creating temp folder '$WorkingFolder'"
			New-Item -ItemType Directory -Path $WorkingFolder -Verbose:$VerbosePreference | Set-ItemProperty -Name Attributes -Value "Hidden"
		}

		# removing remaining T3mp folders.
		try {
			Get-ChildItem -Path "$WorkingFolder\T3mp*" | Remove-Item -Recurse -Force -Verbose:$VerbosePreference -ErrorAction Stop
		}
		catch {
			Write-Host "[$(_LINE_)] Error removing olf temp folders: $($_.Exception.Message)" -BackgroundColor Black -ForegroundColor Red
			return
		}
		
		# Copying ImageX*.exe with robocopy.
		# *:D is for only copying data, not attributes (because hidden folder) /A-: for removing attributes.
		Robocopy $SubFolder\tools\bin $WorkingFolder "image$arch.exe" /E /NJH /NJS /A-:RASHNT /DCOPY:D /COPY:D
		switch ($LASTEXITCODE) {
			# https://ss64.com/nt/robocopy-exit.html
			{ $_ -in 0, 1, 2, 3 } { Write-Host "[$(_LINE_)] Result: '$([RoboCopyExitCodes]$_) ($_)' on copy 'imagex*.exe'; Mode: Continue" }
			default { Write-Host "[$(_LINE_)] Result: '$([RoboCopyExitCodes]$_) ($_)' on copy 'imagex*.exe'; Mode: Stop"; return; }
		}
		$AppImageX = "$WorkingFolder\image$arch.exe"
		if (!(Test-Path -Path $AppImageX -ErrorAction SilentlyContinue)) {
			Write-Host "[$(_LINE_)] Fatal error: '$AppImageX' not found." -BackgroundColor Black -ForegroundColor Red
			return
		}
		
		# Copy *.esd-files to working directory.
		# *:D is for only copying data, not attributes (because hidden folder) /A-: for removing attributes.
		Robocopy "$SubFolder\UUPs" "$WorkingFolder" *.esd /E /NJH /NJS /A-:RASHNT /DCOPY:D /COPY:D
		switch ($LASTEXITCODE) {
			# https://ss64.com/nt/robocopy-exit.html
			{ $_ -in 0, 1, 2, 3 } { Write-Host "[$(_LINE_)] Result: '$([RoboCopyExitCodes]$_) ($_)' on copy '\UUPs'; Mode: Continue" }
			default { Write-Host "[$(_LINE_)] Result: '$([RoboCopyExitCodes]$_) ($_)' on copy '\UUPs'; Mode: Stop"; return; }
		}

		# Convert each esd file one by one.
		foreach ($ESDFile in $ESDFiles) {
			# Creating new temp folder for extracting esd file
			$ThisTempDir = "$WorkingFolder\T3mp$([System.IO.Path]::GetRandomFileName() -replace "[.]")"
			if (!(Test-Path -Path "$ThisTempDir" -ErrorAction SilentlyContinue)) {
				Write-Host "[$(_LINE_)] Creating temp folder '$ThisTempDir'"
				$null = New-Item -ItemType Directory -Path "$ThisTempDir" -Verbose:$VerbosePreference
			}

			$FileName = [System.IO.Path]::GetFileNameWithoutExtension($ESDFile.FullName)
			$ESD_BaseFileName = $ESDFile.Name

			# Just for me; so when I have done something wrong the script stops.
			if (!$ESD_BaseFileName -or ($null -eq $ESD_BaseFileName)) {
				Write-Host "$ESD_BaseFileName is null ..."
				return
			}
			
			# Skipping when already converted
			$ConvertedCABFullName = "$SubFolder\UUPs\$FileName.cab"
			if (Test-Path -Path $ConvertedCABFullName -ErrorAction SilentlyContinue) {
				Write-Host "[$(_LINE_)] File '$FileName' already converted to cab."
				continue
			}

			# 1. Expanding ESD file to "temp"-folder
			Write-Host "[$(_LINE_)] Expanding ESD to '$WorkingFolder'" -ForegroundColor Cyan
			$ArgumentList = "/APPLY `"$WorkingFolder\$ESD_BaseFileName`" 1 `"$ThisTempDir`" /NOACL ALL /NOTADMIN /TEMP `"$env:TEMP`""
			Write-Verbose "$AppImageX => $ArgumentList" -Verbose

			$Process = Start-Process -FilePath $AppImageX -ArgumentList $ArgumentList -Wait -PassThru -Verbose:$VerbosePreference
			switch ($Process.ExitCode) {
				0 { Write-Host "[$(_LINE_)] ImageX returned ExitCode '$_'. Mode: Continue" }
				default { Write-Host "[$(_LINE_)] ImageX returned ExitCode '$_'. Mode: Stop"; return }
			}

			# 2. Using "temp"-folder to create *.cab file in UUP folder.
			Write-Host "[$(_LINE_)] Converting to '$FileName.cab'" -ForegroundColor Cyan
			$ArgumentList = "-m LZX:21 -r -p N `"$ConvertedCABFullName`" *.*"
			Write-Verbose "$AppCabarc => $ArgumentList" -Verbose
			
			$Process = Start-Process -FilePath $AppCabarc -ArgumentList $ArgumentList -Wait -PassThru -WorkingDirectory $ThisTempDir -Verbose:$VerbosePreference
			switch ($Process.ExitCode) {
				0 { Write-Host "[$(_LINE_)] CABARC returned ExitCode '$_'. Mode: Continue" }
				default { Write-Host "[$(_LINE_)] CABARC returned ExitCode '$_'. Mode: Stop"; return }
			}

			# Last check if successful
			if (!(Test-Path -Path $ConvertedCABFullName -ErrorAction SilentlyContinue)) {
				Write-Host "[$(_LINE_)] File '$ConvertedCABFullName' not exists." -BackgroundColor Black -ForegroundColor Red
			}
			else {
				Write-Host "[$(_LINE_)] File '$ConvertedCABFullName' exists."
				
				<#
				# removing T3mp folder for this cab.
				try {
					Get-ChildItem -Path $ThisTempDir -Recurse | Remove-Item -Recurse -Force -Verbose:$VerbosePreference -ErrorAction Stop
					Remove-Item -Path $ThisTempDir -Recurse -Force -Verbose:$VerbosePreference -ErrorAction Stop
				}
				catch {
					Write-Host "[$(_LINE_)] Error removing old temp folders: $($_.Exception.Message)" -BackgroundColor Black -ForegroundColor Red
					return
				}
				#>
			}
		} # /end foreach

		# Testing if counts of ESD and converted CAB files do match.
		Write-Verbose "Checking for esd and cab file count ..." -Verbose:$VerbosePreference
		$CheckCABFiles = $ESDFiles | ForEach-Object { Get-Item -Path "$SubFolder\UUPs\$($_.BaseName).cab" }
		$CheckCABCount = ($CheckCABFiles | Measure-Object).Count
		$CheckESDCount = ($ESDFiles | Measure-Object).Count
		
		if ($CheckCABCount -ne $CheckESDCount) {
			Write-Host "[$(_LINE_)] CAB + ESD Count not matching. Aborting. Please check folders." -BackgroundColor Black -ForegroundColor Red
			return
		}
		else {
			Write-Host "[$(_LINE_)] CAB + ESD Count matching." -BackgroundColor Black -ForegroundColor Green
		}
		
		# removing remaining T3mp folders.
		try {
			Get-ChildItem -Path $WorkingFolder -Recurse | Remove-Item -Recurse -Force -Verbose:$VerbosePreference -ErrorAction Stop
			Remove-Item -Path $WorkingFolder -Recurse -Force -Verbose:$VerbosePreference -ErrorAction Stop
		}
		catch {
			Write-Host "[$(_LINE_)] Error removing old temp folders: $($_.Exception.Message)" -BackgroundColor Black -ForegroundColor Red
			return
		}
	} # /end "if more than 1 esd file"

	Write-Host "[$(_LINE_)] Done with converting from esd to cab."
} # /end all (true)

$ExtraFolder = "$PSScriptRoot\Xtra"
if ($SelectedFeatureRex) {
	$ExtraFolder += "\$($SelectedFeatureRex -replace '[^a-zA-Z0-9]')"
}
Robocopy $Aria_DestinationFolder $ExtraFolder /E /NJH /NJS /A-:RASHNT /DCOPY:D /COPY:D
switch ($LASTEXITCODE) {
	# https://ss64.com/nt/robocopy-exit.html
	{ $_ -in 0, 1, 2, 3 } { Write-Host "[$(_LINE_)] Result: '$([RoboCopyExitCodes]$_) ($_)' on copy '\UUPs'; Mode: Continue" }
	default { Write-Host "[$(_LINE_)] Result: '$([RoboCopyExitCodes]$_) ($_)' on copy '\UUPs'; Mode: Stop"; return; }
}

# removing builder folder when done
Read-Host -Prompt "Finished with all feature file operations. Press Enter to remove the '$SubFolder' path"
try {
	Get-ChildItem -Path $SubFolder -Recurse | Remove-Item -Recurse -Force -Verbose:$VerbosePreference -ErrorAction Stop
	Get-Item -Path $SubFolder -Force | Remove-Item -Recurse -Force -Verbose:$VerbosePreference -ErrorAction Stop
}
catch {
	Write-Host "[$(_LINE_)] Error removing olf temp folders: $($_.Exception.Message)" -BackgroundColor Black -ForegroundColor Red
	return
}
#endregion