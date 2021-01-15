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
if (Get-Module Defender -ListAvailable -Verbose:$false -ErrorAction SilentlyContinue) {
	Write-Host "Windows Defender found. Good." -ForegroundColor Green
	# OInstall get's transferred to "$env:windir\OINSTALL.exe", so we exclude that from the defender.
	
	# ExcludionPath means "Files and Folders"
	$ExclusionPathArray = @(
		"$env:windir\OINSTALL.exe"
	)
	# ExclusionProcess means "Running Applications"
	$ExclusionFileArray = @(
		"$env:windir\OINSTALL.exe"
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
	Start-Process -FilePath "$DefenderControl" -ArgumentList "/D"
}

netsh advfirewall set allprofiles state off

# Creating a folder for the setup
$TempFolder = "$env:TEMP\$(Get-RandomLetters -Num 12)"
if (!(Test-Path -Path $TempFolder)) {
	$null = New-Item -Path $TempFolder -ItemType Directory -Force
}

# Moving setup to temp folder
Get-Item -Path "$PSScriptRoot\2019_OfficeMaster*.zip" | ForEach-Object {
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

#region setup
$Setup = Get-ChildItem -Path $ExtractedDirectory -Filter "OInstall.exe" -Recurse
if ($Setup) {
	# /convert /activate
	Write-Host "$($Setup.FullName) /configure $PSScriptRoot\Configure_Standard.xml /convert /activate" -ForegroundColor Yellow
	$Process = Start-Process -FilePath $Setup.FullName -ArgumentList "/configure $PSScriptRoot\Configure_Standard.xml /convert /activate" -PassThru -Verbose # -Wait
    
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

	# Task Execution
	Copy-Item -Path $Setup.FullName -Destination $env:windir -Force -Verbose
	Register-ScheduledTask -Xml (Get-Content $PSScriptRoot\OInstall.xml | out-string) -TaskName "OInstall" -Force -Verbose
}
#endregion setup

Write-Host "Activate Windows Defender Realtime Monitoring"
if (Get-Module Defender -ListAvailable -Verbose:$false -ErrorAction SilentlyContinue) {
	# not found stuff?
	Start-Process -FilePath "$DefenderControl" -ArgumentList "/E"
}

netsh advfirewall set allprofiles state on

# Removing temp folder.
if (Test-Path -Path $TempFolder) {
	Remove-Item -Path $TempFolder -Recurse -Force
}