<#
# Implement his scripts ...
# https://github.com/abbodi1406/WHD/tree/master/scripts
# TODO: Implement line count on errors!
#>

# 1507, 1511, 1607, 1703, 1709, 1803, 1809, 2004, 20H2

[CmdLetBinding()]
param(
	$SearchParam = "feat+windows+10+20H2+amd64",
	#$SearchParam = "feat+windows+10+amd64",
	$Language = "de-DE",
	$EditionCode = 0, # CORE, COREN, PROF, PROFN or 0 = ALL
	[switch]$SkipAPICalls,
	[switch]$SkipINIConfig,
	[switch]$SkipUUPFileDownload,
	[switch]$SkipUUPCheck,
	[switch]$SkipAriaDownload,
	[switch]$SkipUUPConverter
)

# DEBUG
#$VerbosePreference = "Continue"
#$ErrorActionPreference = "Stop"
$VerbosePreference = [System.Management.Automation.ActionPreference]::Continue
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop

# Mostly for me, so I can remove files as I wish!
$SubFolder = "$PSScriptRoot\Builder"

#TODO:
#Start-Transcript -Path ""
#Stop-Transcript
# Insider??
# https://api.uupdump.ml/fetchupd.php?arch=amd64&flight=current

Get-ChildItem -Path "$PSScriptRoot\Library\API" -Recurse -File -Force | Where-Object { $_.Name -like "*.ps1" } | ForEach-Object {
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
# Github Repo for the converter files...
$DownloadAutoDLFiles_URI = "https://github.com/uup-dump/autodl_files/archive/master.zip"
#$DownloadAutoDLFiles_ExtractedFolderName = "autodl_files-master" # needed for ps <= 5

$Application_Aria = "$SubFolder\files\aria2c.exe"

$AriaDownloadScript_Name = "aria_script.$(Get-Random -Minimum 100 -Maximum 99999).txt"
$AriaDownloadScript_Partial = "files\$AriaDownloadScript_Name"
$AriaDownloadScript_Full = "$SubFolder\$AriaDownloadScript_Partial"

$Aria_DestinationFolder = "$SubFolder\UUPs"
#endregion

#
#   API CALLS
#
#TODO: Check for Edition and Language!?
#region API Calls
if (!$SkipAPICalls) {
	# Function returning all UUIDs, sorted by creation date (newest at first).
	try {
		$LatestUUPData = Get-UUPIDs -SearchQuery $SearchParam -Verbose:$VerbosePreference | Select-Object -First 1
	}
 catch {
		Write-Host "Error fetching ids: $($_.Exception.Message)" -BackgroundColor Black -ForegroundColor Red
		return
	}
	Write-Host "Found ids calling the API." -BackgroundColor Black -ForegroundColor Yellow

	try {
		$LatestUUP_Languages = Get-UUPLanguages -UpdateID $LatestUUPData.uuid -Verbose:$VerbosePreference
	}
 catch {
		Write-Host "Error fetching languages: $($_.Exception.Message)" -BackgroundColor Black -ForegroundColor Red
		return
	}
	Write-Host "Found '$($LatestUUP_Languages.Count)' languages calling the API." -BackgroundColor Black -ForegroundColor Yellow
	
	try {
		$LatestUUP_Editions = Get-UUPEditions -UpdateID $LatestUUPData.uuid -LanguageCode "de-de" -ErrorAction Stop -Verbose:$VerbosePreference
	}
 catch {
		Write-Host "Error fetching languages: $($_.Exception.Message)" -BackgroundColor Black -ForegroundColor Red
		return
	}
	Write-Host "Found '$($LatestUUP_Editions.Count)' editions calling the API." -BackgroundColor Black -ForegroundColor Yellow

	# https://api.uupdump.ml/get.php?id=e7f5c4e9-b130-47ff-9cb7-bc48544ea82b&lang=de-de
	# https://api.uupdump.ml/get.php?id=e7f5c4e9-b130-47ff-9cb7-bc48544ea82b&lang=de-de&edition=PROFESSIONALN
	# https://api.uupdump.ml/get.php?id=e7f5c4e9-b130-47ff-9cb7-bc48544ea82b&lang=de-de&edition=0
	$LatestUUP_FileList = Get-UUPFiles -UpdateID $LatestUUPData.uuid -LanguageCode "de-de" -EditionCode $EditionCode -Verbose:$VerbosePreference

	if ($LatestUUP_FileList -and ($LatestUUP_FileList | Measure-Object).Count -gt 0) {
		Write-Verbose "File list received. Time to create an aria file out of it."

		# create aria file
		<#
		http://tlu.dl.delivery.mp.microsoft.com/filestreamingservice/files/a5a47ce1-c6c4-47a2-aecf-9def2b644af7?P1=1580369806&P2=402&P3=2&P4=m8iDZoqRZGHuCb%2bdIRlRrHVOKLWyLH3KpT%2bhk8VNVtQxAtCBfaUlSkPlaf6iiZnxbN1Wvf21ONoA%2f19MJ97Gsw%3d%3d
		out=microsoft-windows-foundation-package.esd
		checksum=sha-1=ce4ad8829820b9c02ee13476727957a20ee544dd

		http://tlu.dl.delivery.mp.microsoft.com/filestreamingservice/files/db0ed424-6458-4402-8083-9fbb06583f4d?P1=1580369806&P2=402&P3=2&P4=Ayg2ASlL8a3mYpI7MZV2uMrV609zCQMo%2f63zhYbzdyA%2bPBNkcxaJvub2k00xEujMsb48I%2fGvIvO764TrDV9GEA%3d%3d
		out=microsoft-windows-not-supported-on-ltsb-package.esd
		checksum=sha-1=d9fab96dd6a6a50f8deefe5e7455b687960c3e85
		#>
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

#region SAVED, REMOVE LATER
<#
#Write-Host Determining latest release
#$repo = "dotnet/codeformatter"
#$file = "CodeFormatter.zip"
#$releases = "https://api.github.com/repos/$repo/releases"
#$tag = (Invoke-WebRequest $releases | ConvertFrom-Json)[0].tag_name
#$download = "https://github.com/$repo/releases/download/$tag/$file"
#$name = $file.Split(".")[0]
#$zip = "$name-$tag.zip"
#$dir = "$name-$tag"
#>
<#
$ConverterGithubRepo_LatestReleaseURI = "https://api.github.com/repos/abbodi1406/BatUtil/releases/latest"
$Request = Invoke-WebRequest -Uri $ConverterGithubRepo_LatestReleaseURI -UseBasicParsing -Verbose:$false
$ConverterJSONContent = $Request.Content | ConvertFrom-Json
$ConvVersion = $ConverterJSONContent.tag_name
$ConvName = $ConverterJSONContent.name
$ConvDate = $ConverterJSONContent.published_at
$ConvDLog = $ConverterJSONContent.body

# zip download!!
$ConverterDownloadAssets = $ConverterJSONContent.assets
$ConverterFileName = $ConverterDownloadAssets[0].name
$ConverterDownloadLink = $ConverterDownloadAssets[0].browser_download_url

# checks before download
#Invoke-WebRequest -Uri $ConverterDownloadLink -UseBasicParsing -OutFile "$SubFolder\$ConverterFileName"


# https://api.github.com/repos/abbodi1406/BatUtil/releases/latest
# html_url = "https://github.com/abbodi1406/BatUtil/releases/tag/0.20.0"
# tag_name = 0.20.0
# assets[0].browser_download_url = "https://github.com/abbodi1406/BatUtil/releases/download/0.20.0/uup-converter-wimlib-20.7z"
#>
#endregion

#$LatestUUP_FileList.FileName

#
#   UUP converter files check
#
#region UUPCHECK
if (!$SkipUUPCheck) {
	Write-Host "Checking for UUP prerequisites..."
	
	# Do not mess with the script!
	if (!$DownloadAutoDLFiles_URI) {
		Write-Host "There was an error with the GitHub Repo..." -BackgroundColor Black -ForegroundColor Red
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
				Write-Host "Error expanding archive '$SubFolder\temp\files.zip': $($_.Exception.Message)" -BackgroundColor Black -ForegroundColor Red
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
	# TODO IMplement _LINE_
	if (!(Test-Path -Path "$SubFolder\files\7zr.exe") -or !(Test-Path -Path "$SubFolder\files\uup-converter-wimlib.7z")) {
		Write-Host "Error on checking files on the extracted directory." -BackgroundColor Black -ForegroundColor Red
		return
	}

	# extract them files...
	Write-Verbose "Extracting them files from uup-converter-wimlib."
	#Write-Verbose "`"$SubFolder\files\7zr.exe`" -ArgumentList `"-x!ConvertConfig.xml -y x `"$SubFolder\files\uup-converter-wimlib.7z`"`"" -Verbose
	$Process = Start-Process -FilePath "$SubFolder\files\7zr.exe" -ArgumentList "-x!ConvertConfig.xml -y x `"$SubFolder\files\uup-converter-wimlib.7z`" -o$Subfolder" -Wait -PassThru -WindowStyle Hidden
	if ($Process.ExitCode -ne 0) {
		Write-Host "Error extracting needed files. Please fix this!! (Exited with error code '$($Process.ExitCode)')" -BackgroundColor Black -ForegroundColor Red
		return
	}
 else {
		Write-Host "Extracted files from 'files\uup-converter-wimlib.7z'." -ForegroundColor Green
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

#
#   Custom INI
#
#region ImportChangeINI
if (!$SkipINIConfig) {
	$ConfigFileName = "ConvertConfig.ini"

	if (!(Test-Path "$SubFolder\$ConfigFileName" -ErrorAction SilentlyContinue)) {
		Write-Host "Error: ConvertConfig.ini not found." -BackgroundColor Black -ForegroundColor Red
		return
	}

	try {
		$ini = Get-IniFile -Path "$SubFolder\$ConfigFileName"

		#[convert-UUP]
		$ini."convert-uup".AutoStart = 1
		$ini."convert-uup".AddUpdates = 1
		$ini."convert-uup".Cleanup = 1
		$ini."convert-uup".ResetBase = 0
		$ini."convert-uup".NetFx3 = 1
		$ini."convert-uup".StartVirtual = 1
		$ini."convert-uup".wim2esd = 0
		$ini."convert-uup".SkipISO = 0
		$ini."convert-uup".SkipWinRE = 0
		$ini."convert-uup".ForceDism = 0
		$ini."convert-uup".RefESD = 0

		#[create_virtual_editions]
		$ini."create_virtual_editions".vAutoStart = 1
		$ini."create_virtual_editions".vDeleteSource = 0
		$ini."create_virtual_editions".vPreserve = 0
		$ini."create_virtual_editions".vwim2esd = 0
		$ini."create_virtual_editions".vSkipISO = 0
		#$ini."create_virtual_editions".vAutoEditions = "CoreSingleLanguage,ProfessionalWorkstation,ProfessionalEducation,Education,Enterprise,ServerRdsh,ProfessionalWorkstationN,ProfessionalEducationN,EducationN,EnterpriseN"
		$ini."create_virtual_editions".vAutoEditions = "Education,Enterprise,ServerRdsh,EducationN,EnterpriseN"

		# AGAIN: Encoding is very important. Convert-uup reads content in UTF8!!
		Out-IniFile -InputObject $ini -FilePath "$SubFolder\$ConfigFileName" -Encoding UTF8 -Force -Verbose:$VerbosePreference
	}
 catch {
		Write-Host "Error applying custom ini configuration. Please fix or use `$SkipINIConfig!!" -BackgroundColor Black -ForegroundColor Red
		return
	}
}
#endregion ImportChangeINI

#
#   Aria Stuff
#
#region ARIA DOWNLOAD
if (!$SkipAriaDownload) {
	if (!(Test-Path -Path $Application_Aria)) {
		Write-Host "Aria application does not exist. This file is inside the uup-converter autodl_files. (Is CheckConverter skipped: $SkipUUPCheck)" -BackgroundColor Black -ForegroundColor Red
		return
	}
	
	Read-Host -Prompt "Finished with setting up files for aria. Press any key to continue with aria download."

	#"%aria2%" --no-conf --log-level=info --log="aria2_download.log" -x16 -s16 -j5 -c -R -d"%destDir%" -i"%aria2Script%"
	$ArgumentList = "--no-conf --log-level=info --log=`"$SubFolder\aria2_download.log`" -x16 -s16 -j5 -c -R -d`"$Aria_DestinationFolder`" -i`"$AriaDownloadScript_Full`""
	Write-Verbose "$Application_Aria $ArgumentList"
	$Process = Start-Process -FilePath $Application_Aria -ArgumentList $ArgumentList -Wait -NoNewWindow -PassThru
	Write-Host "Exit: $LASTEXITCODE $($Process.ExitCode)"

	if ($Process.ExitCode -ne 0) {
		Write-Host "Aria exited with ExitCode '$($Process.ExitCode)'. Aborting rest of script." -BackgroundColor Black -ForegroundColor Red
		return
	}
}
#endregion

#
#   UUP Converter
#
if (!$SkipUUPConverter) {
	Write-Verbose "Converting UUP to ISO..."
	if (!(Test-Path -Path "$SubFolder\convert-UUP.cmd")) {
		Write-Host "UUP converter not found. Aborting script." -BackgroundColor Black -ForegroundColor Red
		return
	}

	Write-Verbose "Replacing cls|color for optic reasons..."
	@(
		"convert-UUP.cmd",
		"create_virtual_editions.cmd",
		"multi_arch_iso.cmd"
	) | ForEach-Object {
		$CMDContent = Get-Content -Path "$SubFolder\$_"
		$CMDContent = $CMDContent -replace '(^color|^@color)', "::`$1"
		$CMDContent = $CMDContent -replace '(^cls|^@cls)', "::`$1"
		$CMDContent | Set-Content "$SubFolder\$_"
	}

	<#
	$ConvertContent = Get-Content -Path "$SubFolder\convert-UUP.cmd"
	$ConvertContent = $ConvertContent -replace '(^color|^@color)',"::`$1"
	$ConvertContent = $ConvertContent -replace '(^cls|^@cls)',"::`$1"
	$ConvertContent | Set-Content "$SubFolder\convert-UUP.cmd"
	#>

	# TODO: Test for exit code...
	#Invoke-Item -Path "$SubFolder\convert-UUP.cmd"
	#Invoke-Expression "cmd.exe /c `"$SubFolder\convert-UUP.cmd`""
	Read-Host -Prompt "Finished with setting up files for UUPConverter. Press any key to continue with UUPConverter."
	$Process = Start-Process "cmd" -ArgumentList "/c $SubFolder\convert-UUP.cmd" -NoNewWindow -Wait -PassThru # && $LASTEXITCODE
	$Process.ExitCode
	
	$LASTEXITCODE
}

#Stop-Transcript