##Requires -RunAsAdministrator

param(
	#[ValidateSet("amd64","arm64","x86")]
	#$OSArch = $env:PROCESSOR_ARCHITECTURE,
	#$searchString = "Windows 10 Insider*$OSArch",
	$OnlyLanguageEx = "de-DE|sv-SE|hu-HU|fr-FR|en-US",
	[switch]$IgnoreFreeSpaceCheck
	#$UUPDownloadFolder = "$PSScriptRoot\UUPs"
)

# If needed for older Scripts ($PSScriptRoot is > v3)
#if (!($PSScriptRoot)) {
#	$PSScriptRoot = (Split-Path $MyInvocation.MyCommand.Path)
#}

function Get-CurrentLineNumber {
	$MyInvocation.ScriptLineNumber
}

New-Alias -Name _LINE_ -Value Get-CurrentLineNumber �Description "Returns the current line number in a PowerShell script file."

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

function Get-WebTable {
	param(
		[Parameter(Mandatory = $true)]
		[Microsoft.PowerShell.Commands.HtmlWebResponseObject] $WebRequest,
	
		[Parameter(Mandatory = $true)]
		[int] $TableNumber
	)

	## Extract the tables out of the web request
	$tables = @($WebRequest.ParsedHtml.getElementsByTagName("TABLE"))
	$table = $tables[$TableNumber]
	$titles = @()
	$rows = @($table.Rows)

	## Go through all of the rows in the table
	foreach ($row in $rows) {
		$cells = @($row.Cells)
	
		## If we've found a table header, remember its titles
		if ($cells[0].tagName -eq "TH") {
			$titles = @($cells | ForEach-Object { ("" + $_.InnerText).Trim() })
			continue
		}

		## If we haven't found any table headers, make up names "P1", "P2", etc.
		if (!$titles) {
			$titles = @(1..($cells.Count + 2) | ForEach-Object { "P$_" })
		}

		## Now go through the cells in the the row. For each, try to find the
		## title that represents that column and create a hashtable mapping those
		## titles to content

		$resultObject = [Ordered] @{}

		for ($counter = 0; $counter -lt $cells.Count; $counter++) {
			$title = $titles[$counter]
			if (!$title) { continue }
		
			$resultObject[$title] = ("" + $cells[$counter].InnerText).Trim()
		}

		## And finally cast that hashtable to a PSCustomObject
		[PSCustomObject] $resultObject
	}
}

# we might have to use aria for this.
# dunno yet.

#$UUP_DUMP_URI = "https://uupdump.ml/"
$UUP_DUMP_FeatureRequestURI = "https://uupdump.ml/known.php?q=feature"
# KNWON BUILDS = https://uupdump.ml/known.php

$UUP_DUMP_Folder = "$PSScriptRoot\UUPDump\UUPs"
$UUP_DUMP_Aria = "$PSScriptRoot\UUPDump\aria"

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
Write-Verbose "[$(_LINE_)] Request `"$UUP_DUMP_FeatureRequestURI`"" -Verbose
$Request = Invoke-WebRequest -Uri $UUP_DUMP_FeatureRequestURI
$DUMP_ID = & {
	$Request.Links | Where-Object { $_.outerHTML -match "(?=.*1903)(?=.*amd64)" } | Select-Object -First 1 -Property * | ForEach-Object {
		$H = $_.href; $I = $H.IndexOf("=") + 1; $H.substring($I, $H.length - $I)
	}
}

# List KBs for UUP: https://uupdump.ml/findfiles.php?id=$DUMP_ID&q=Windows10%20KB
$PackFiles_Link = "https://uupdump.ml/findfiles.php?id=$DUMP_ID&pack=0&q="

Write-Verbose "[$(_LINE_)] Request `"$PackFiles_Link`"" -Verbose
$PackFiles_Content = Invoke-WebRequest -Uri $PackFiles_Link
$PackFiles_Links = $PackFiles_Content.Links | Where-Object { $_.href -match "file[=]" }

Write-Verbose "[$(_LINE_)] +Modelling table" -Verbose
$PackFiles_FileTable = Get-WebTable -WebRequest $PackFiles_Content -TableNumber 0

# "File","SHA-1","Size"
Write-Verbose "[$(_LINE_)] +Excluding languages not being: $OnlyLanguageEx" -Verbose
$PackFiles_ExlcudeFiles = $PackFiles_FileTable.File | Where-Object { ($_ -match "[\d\D]{2}-[\d\D]{2}([^a-z])") -and ($_ -notmatch $OnlyLanguageEx) }

#Write-Verbose "[$(_LINE_)] +filtering sub URI" -Verbose
#$FilesToDownload = $PackFiles_FileTable | Where-Object { $PackFiles_ExlcudeFiles -notcontains $_.File }
#$FilesToDownload

if ($IgnoreFreeSpaceCheck) {
	Write-Verbose "[$(_LINE_)] +Filtering sub URI" -Verbose
	$FilesToDownload = $PackFiles_FileTable | Where-Object { $PackFiles_ExlcudeFiles -notcontains $_.File }
}
else {
	Write-Verbose "[$(_LINE_)] +Filtering sub URI with space check" -Verbose
	$FilesToDownload = ($PackFiles_FileTable | Where-Object { $PackFiles_ExlcudeFiles -notcontains $_.File } | Select-Object "File", "SHA-1", @{N = "Size"; E = {
				$Size = $_.Size
				switch -Wildcard ($Size) {
					"*KiB*" { [Double]($_ -replace "[ ][\w]*") * 1024 }
					"*MiB*" { [Double]($_ -replace "[ ][\w]*") * 1024 * 1024 }
					"*GiB*" { [Double]($_ -replace "[ ][\w]*") * 1024 * 1024 * 1024 }
        
					default { Write-Host "!MiB,KiB||GiB" }
				}
			}
		})


	function Get-FriendlySize {
		param($Bytes)
		$sizes = 'Bytes,KB,MB,GB,TB,PB,EB,ZB' -split ','
		for ($i = 0; ($Bytes -ge 1kb) -and 
			($i -lt $sizes.Count); $i++) { $Bytes /= 1kb }
		$N = 2; if ($i -eq 0) { $N = 0 }
		"{0:N$($N)} {1}" -f $Bytes, $sizes[$i]
	}

	Write-Verbose "[$(_LINE_)] Printing SizeInfo:" -Verbose
	$TotalFileSizeInBytes = ($FilesToDownload.Size | Measure-Object -Sum).Sum
	$TotalFileSize = Get-FriendlySize -Bytes $TotalFileSizeInBytes
    
	# if "You do not have enough free space to download."
	<#
    Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='C:'" | Foreach-Object {
        $Size = Get-FriendlySize -Bytes $_.Size
        $FreeSpace = Get-FriendlySize -Bytes $_.FreeSpace
        
        "$($Size) -> $($FreeSpace)"
    }
    #>

	$MainDriveFreeSpace = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'" | Select-Object Size, FreeSpace, @{Name = "FriendlySize"; E = { Get-FriendlySize -Bytes $_.Size } }, @{Name = "FriendlyFreeSpace"; E = { Get-FriendlySize -Bytes $_.FreeSpace } }

	if ($MainDriveFreeSpace.FriendlyFreeSpace -le $TotalFileSizeInBytes) {
		Write-Host "$($MainDriveFreeSpace.FreeSpace) -le $TotalFileSizeInBytes | $($MainDriveFreeSpace.FriendlyFreeSpace) -le $TotalFileSize" -ForegroundColor Red
		return
	}
 else {
		Write-Host "$($MainDriveFreeSpace.FreeSpace) -gt $TotalFileSizeInBytes | $($MainDriveFreeSpace.FriendlyFreeSpace) -gt $TotalFileSize" -ForegroundColor Yellow
	}

	if (!(Test-Path -Path $UUP_DUMP_Folder)) {
		$null = New-Item -Path $UUP_DUMP_Folder -ItemType Directory -Force
	}

	#$wc = New-Object net.webclient
	#$wc.Downloadfile($video_url, $local_video_url)
	
	Write-Verbose "[$(_LINE_)] Downloading files. Progress bar slows things down." -Verbose
	$ProgressPreference = 'SilentlyContinue'
    
	$FilesToDownload | ForEach-Object {
		$File = $_.File
		$PackFiles_Links | Where-Object { $_.innerText -match $File } | ForEach-Object {
			"https://uupdump.ml/$($_.href -replace "./" -replace "&amp;","&")"
		}
	} | Out-File -FilePath "$UUP_DUMP_Aria\aria_script.txt" -Encoding utf8

	Read-Host

	Write-Host "$UUP_DUMP_Aria\aria2c.exe -x16 -s16 -j5 -c -R --max-overall-download-limit=0 -d`"$UUP_DUMP_Folder\`" -i`"$UUP_DUMP_Aria\aria_script.txt`""
	$Process = Start-Process -FilePath "$UUP_DUMP_Aria\aria2c.exe" -ArgumentList "-x16 -s16 -j5 -c -R --max-overall-download-limit=0 -d`"$UUP_DUMP_Folder`" -i`"$UUP_DUMP_Aria\aria_script.txt`"" -Wait -PassThru -NoNewWindow
	$Process.ExitCode

	Remove-Item -Path "$UUP_DUMP_Aria\aria_script.txt" -Recurse -Force
	
	return
	$FilesToDownload | ForEach-Object {
		$File = $_.File
		$FileSize = Get-FriendlySize -Bytes $_.Size
		#Write-Host "$File"
		$PackFiles_Links | Where-Object { $_.innerText -match $File } | ForEach-Object {
			Write-Host ">> Download: $($_.innerText) | $FileSize" -ForegroundColor Cyan
			$Link = "https://uupdump.ml/$($_.href -replace "./" -replace "&amp;","&")"
			#$Link -match "(;file=)([\w]*)([.][\w]*)$"
			$null = $Link -match "(file=)([\w\W]*)$" # returns true|false
			$FileName = "$($Matches[2])$($Matches[3])"
			$FileName

			Write-Host "Download `"$Link`" to `"$UUP_DUMP_Folder\$FileName`""
			if (!(Test-Path -Path $UUP_DUMP_Folder\$FileName)) {
				Invoke-WebRequest -Uri $Link -OutFile "$UUP_DUMP_Folder\$FileName" -Method Get -Verbose
			}
			else {
				"skip."
			}

			#[System.IO.Path]::GetExtension($Link)
			#$_.innerText
		}
		
	} # /end filestodownload
	$ProgressPreference = 'Continue' # Standard
}
