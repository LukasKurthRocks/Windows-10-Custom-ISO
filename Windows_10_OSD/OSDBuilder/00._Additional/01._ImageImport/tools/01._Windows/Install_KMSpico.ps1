#Requires -RunAsAdministrator
#Requires -Version 3.0

[cmdletbinding()]
param(
)

function Get-RandomLetters {
	param (
		[int]$Num
	)
    
	-join ((65..90) + (97..122) | Get-Random -Count $Num | ForEach-Object { [char]$_ })
}

$ParentPath = (Get-Item $PSScriptRoot).Parent.FullName
$DefenderControl = "$ParentPath\04._Tools\DefenderControl\DefenderControl.exe"

#region defender add exclusion
# Cannot add exclusion if defender is dead.
$SpicoInstallPath = "C:\Program Files\KMSpico"
if (Get-Module Defender -ListAvailable -Verbose:$false -ErrorAction SilentlyContinue) {
	Write-Host "Windows Defender found. Good." -ForegroundColor Green
	# KMSpico standard location is "C:\Program Files\KMSpico", so we exclude that from the defender.

	# ExcludionPath means "Files and Folders"
	$ExclusionPathArray = @(
		"C:\Windows\SECOH-QAD.exe"
		"C:\Windows\SECOH-QAD.dll"
		"C:\Program Files\KMSpico"
		"C:\Program Files\KMSpico\AutoPico.exe"
		"C:\Program Files\KMSpico\KMSELDI.exe"
		"C:\Program Files\KMSpico\Service_KMS.exe"
	)
	# ExclusionProcess means "Running Applications"
	$ExclusionFileArray = @(
		"C:\Windows\SECOH-QAD.exe"
		"C:\Windows\SECOH-QAD.dll"
		"C:\Program Files\KMSpico\AutoPico.exe"
		"C:\Program Files\KMSpico\KMSELDI.exe"
		"C:\Program Files\KMSpico\Service_KMS.exe"
	)

	$ExclusionPathArray | ForEach-Object {
		$tExc = $_
		if ( (Get-MpPreference).ExclusionPath -notcontains $tExc ) {
			Write-Host "Setting exclusion of `"file or folder`" for Windows Defender. Please set this path in your antivirus: `"$tExc`" " -ForegroundColor Cyan
			try {
				Add-MpPreference -ExclusionPath $tExc
			}
			catch {
				Write-Host "Error while adjusting defender: $($_.Exception.Message)" -ForegroundColor Red
				return
			}
		}
		else {
			Write-Host "Exclusions already contains path `"$tExc`". Congratulation." -ForegroundColor Green
		}
	}
	$ExclusionFileArray | ForEach-Object {
		$tExc = $_
		if ( (Get-MpPreference).ExclusionProcess -notcontains $tExc ) {
			Write-Host "Setting exclusion of `"app or process`" for Windows Defender. Please set this path in your antivirus: `"$tExc`" " -ForegroundColor Cyan
			try {
				Add-MpPreference -ExclusionProcess $tExc
			}
			catch {
				Write-Host "Error while adjusting defender: $($_.Exception.Message)" -ForegroundColor Red
				return
			}
		}
		else {
			Write-Host "Exclusions already contains path `"$tExc`". Congratulation." -ForegroundColor Green
		}
	}
}
else {
	Write-Host "Windows Defender not found. Deactivating it."
	Start-Process -FilePath "$DefenderControl" -ArgumentList "/D" -Wait -NoNewWindow
}
#endregion defender add exclusion

Write-Verbose "Deactivate Windows Defender Realtime Monitoring"
if (Get-Module Defender -ListAvailable -Verbose:$false -ErrorAction SilentlyContinue) {
	Start-Process -FilePath "$DefenderControl" -ArgumentList "/D" -Wait
}

netsh advfirewall set allprofiles state off

# Creating a folder for the setup
$TempFolder = "$env:TEMP\$(Get-RandomLetters -Num 12)"
if (!(Test-Path -Path $TempFolder)) {
	$null = New-Item -Path $TempFolder -ItemType Directory -Force
}

# Moving setup to temp folder
Get-Item -Path "$PSScriptRoot\kmspico*.zip" | ForEach-Object {
	#Copy-Item -Path $_.FullName -Destination $TempFolder -WhatIf

	# Extracting Archive
	$ExtractedDirectory = "$TempFolder\$($_.BaseName)"
	if (!(Test-Path -Path $ExtractedDirectory)) {
		$null = New-Item -Path "$ExtractedDirectory" -ItemType Directory
		#Write-Host "$ExtractedDirectory does not exist"
        
		Add-Type -AssemblyName System.IO.Compression.FileSystem
		[System.IO.Compression.ZipFile]::ExtractToDirectory($_.FullName, "$ExtractedDirectory\")
	}
 else {
		"`"$ExtractedDirectory`" exists"
	}

	#$ExtractedDirectory
}

#region spico setup
$SpicoSetup = Get-ChildItem -Path $ExtractedDirectory -Filter "KMSpico*setup*.exe" -Recurse
if ($SpicoSetup) {
	# hm... InnoSetup?
	Write-Host "$($SpicoSetup.FullName) /SP- /VERYSILENT /SUPPRESSMSGBOXES /LOG=`"$env:TEMP\kms_i$(Get-Date -format "yyMMdd-HHmmss").log`" /NOCANCEL /NORESTART /RESTARTAPPLICATIONS /DIR=`"$SpicoInstallPath`" /NOICONS" -ForegroundColor Yellow
	$Process = Start-Process -FilePath $SpicoSetup.FullName -ArgumentList "/SP- /VERYSILENT /SUPPRESSMSGBOXES /LOG=`"$env:TEMP\kms_i$(Get-Date -format "yyMMdd-HHmmss").log`" /NOCANCEL /NORESTART /RESTARTAPPLICATIONS /DIR=`"$SpicoInstallPath`" /NOICONS" -PassThru # -Wait
    
	<##>
	$StartTime = Get-Date
	$Timeout = 120 # Minutes

	Write-Host "Waiting for program to finish..." -ForegroundColor Cyan
	while (!$Process.HasExited) {
		Write-Host "." -NoNewline -ForegroundColor Yellow
		Start-Sleep -Seconds 1
	
		$Span = New-TimeSpan -Start $StartTime -End (Get-Date)
		if ($Span.Minutes -gt $Timeout) {
			Write-Host "`nTimout reached ($Timeout minutes). Breaking loop. (PRESS ENTER)" -ForegroundColor Yellow
			Read-Host
			break
		}
	}
	<##>

	$Process.ExitCode
	
	$GenericKeys = @{
		# Only RTM Keys (not VL Version)
		"Home"                   = "YTMG3-N6DKC-DKB77-7M9GH-8HVX7"
		"Home N"                 = "4CPRK-NM3K3-X6XXQ-RXX86-WXCHW"
		"S"                      = "3NF4D-GF9GY-63VKH-QRC3V-7QW8P"

		# Volume License Key (still generic, no activation)
		"Pro"                    = "W269N-WFGWX-YVC9B-4J6C9-T83GX"
		"Pro N"                  = "MH37W-N47XK-V7XM9-C7227-GCQG9"
		"Pro for Workstations"   = "NRG8B-VKK3Q-CXVCJ-9G2XF-6Q84J"
		"Pro N for Workstations" = "9FNHH-K3HBT-3W4TD-6383H-6XYWF"

		"Education"              = "NW6C2-QMPVW-D7KKK-3GKT6-VCFB2"
		"Education N"            = "2WH4N-8QGBV-H22JP-CT43Q-MDWWJ"
		"Pro Education"          = "6TP4R-GNPTD-KYYHQ-7B7DP-J447Y"
		"Pro Education N"        = "YVWGF-BXNMC-HTQYQ-CPQ99-66QFC"

		"Enterprise"             = "NPPR9-FWDCX-D2C8J-H872K-2YT43"
		"Enterprise G"           = "YYVX9-NTFWV-6MDM3-9PT4T-4M68B"
		"Enterprise G N"         = "44RPN-FTY23-9VTTB-MP9BX-T84FV"
		"Enterprise N"           = "DPH2V-TTNVB-4X9Q3-TJR4H-KHJW4"
		"Enterprise S"           = "FWN7H-PF93Q-4GGP8-M8RF3-MDWWW"

		"Enterprise 2015 LTSB"   = "WNMTR-4C88C-JK8YV-HQ7T2-76DF9"
		"Enterprise 2015 LTSB N" = "2F77B-TNFGY-69QQF-B8YKP-D69TJ"
		"Enterprise LTSB 2016"   = "DCPHK-NFMTC-H88MJ-PFHPY-QJ4BJ"
		"Enterprise N LTSB 2016" = "QFFDN-GRT3P-VKWWX-X7T3R-8B639"
		"Enterprise LTSC 2019"   = "M7XTQ-FN8P6-TTKYV-9D4CC-J462D"
		"Enterprise N LTSC 2019" = "92NFX-8DJQP-P6BBQ-THF9C-7CG2H"
	}
	$WinVersion = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").ProductName -replace "Windows 10 "

	if ($GenericKeys[$WinVersion]) {
		$Key = $GenericKeys[$WinVersion]
		Write-Host "New Key: $Key"

		$service = Get-WmiObject -Query "select * from SoftwareLicensingService" -ComputerName $env:COMPUTERNAME
		$null = $service.InstallProductKey($key)
		$null = $service.RefreshLicenseStatus()
	}
 else {
		Write-Host "No generic key for `"$WinVersion`"" -ForegroundColor Yellow
	}

	# /silent, /backup, /status, /removewatermark, /restorewatermark
	#$Process = Start-Process -FilePath "C:\Program Files\KMSpico\AutoPico.exe" -ArgumentList "/status" -PassThru -Wait
	#$Process.ExitCode
	
	# /silent, /backup, /status, /removewatermark, /restorewatermark
	$Process = Start-Process -FilePath "C:\Program Files\KMSpico\AutoPico.exe" -ArgumentList "/silent" -PassThru -Wait
	$Process.ExitCode

	#$Process = Start-Process -FilePath "C:\Program Files\KMSpico\KMSeldi.exe" -PassThru -Wait
	#$Process.ExitCode
}
#endregion setup

Write-Host "Activate Windows Defender Realtime Monitoring"
if (Get-Module Defender -ListAvailable -Verbose:$false -ErrorAction SilentlyContinue) {
	Start-Process -FilePath "$DefenderControl" -ArgumentList "/E"
}

netsh advfirewall set allprofiles state on

# Removing temp folder.
if (Test-Path -Path $TempFolder) {
	Remove-Item -Path $TempFolder -Recurse -Force
}