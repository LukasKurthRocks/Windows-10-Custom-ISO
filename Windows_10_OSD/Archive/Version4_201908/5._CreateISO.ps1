[CmdLetBinding()]
param(
	# Can be the base name of install.swm if more exists.
	# I will search for all of them.
	$ImageFilename = "install.wim",
	$ISOFileName = "WINDOWS_10.ISO"
)

# I put this here in case I need this
# Althoug a requirement is to have version 5.0
#if (!($PSScriptRoot)) {
#	$PSScriptRoot = (Split-Path $MyInvocation.MyCommand.Path)
#}

Start-Transcript -Path "$env:TEMP\w10iso_merging_$(Get-Date -Format "yyMMdd-HHmmss.fffffff").txt"

# Logging the time the script started.
# In the end I will compare the starttime with the endtime.
$StartTime = Get-Date
Write-Host "STEP5: Started at $(Get-Date -Format "dd.MM.yy HH:mm:ss")"

#region Import Scripts
# ########################################## #
#               IMPORT REGION
# ########################################## #

# =========================================
#         Functions and Variables
# =========================================
Write-Verbose "Importing additional functionalities"
$ScriptImportFolder = "$PSScriptRoot\Scripts"
Get-ChildItem -Path $ScriptImportFolder -Filter "*.ps1" | ForEach-Object {
	Write-Verbose "+ $($_.Name)"
	. $_.FullName
}
$IncludedFunctionNames = @("Clear-MountPath")
$IncludedFunctionNames | ForEach-Object {
	if (!(Get-Command -Name "$_")) {
		Write-Host "Function `"$_`" not found." -ForegroundColor Red
		return
	}
}


# =========================================
#           DISM Functionality
# =========================================
# If I have 1000 lines I do not want to display [0] and [1000].
#$SCRIPT_LinesTotalString = "" + ($MyInvocation.MyCommand.ScriptBlock | Measure-Object -Line).Lines
#endregion Import Script

$ImageBaseFileName = [System.IO.Path]::GetFileNameWithoutExtension($ImageFilename)
$ImageBaseFileExtension = [System.IO.Path]::GetExtension($ImageFilename)
$ImageFiles = Get-ChildItem -Path $UUP_TempFolder -Filter "$ImageBaseFileName*$ImageBaseFileExtension*"

Read-Host -Prompt "Creating ISO. Ready? [PRESS ENTER]"

# Re-Creating Folder here
Write-Host "[$(_LINE_)] Let's see if we can create an ISO Image now..."
if (Test-Path -Path $UUP_IMGMountPath) {
	$null = Remove-Item -Path $UUP_IMGMountPath -Recurse -Force -Verbose
}
if (!(Test-Path -Path $UUP_IMGMountPath)) {
	$null = New-Item -Path $UUP_IMGMountPath -ItemType Directory -Force
}

# Sub = $ADK\<Processor>
$ADK_Folder = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools"
$ADK_Exists = & {
	if (!(Test-Path -Path $ADK_Folder)) {
		Write-Host "[$(_LINE_)] ADK folder not found." -BackgroundColor Black -ForegroundColor Red
		$OSCD_BackupFolder = "$LocalFilesFolder\lib\adk"
		
		if (!(Test-Path -Path $OSCD_BackupFolder)) {
			Write-Host "[$(_LINE_)] OSCD folder not found." -BackgroundColor Black -ForegroundColor Red
		}
		else {
			Write-Host "[$(_LINE_)] But you have a local copy. Good." -ForegroundColor DarkGray
			$script:ADK_Folder = $OSCD_BackupFolder
			return $true
		}
	}
 else {
		return $true
	}
}

# Should be more like "Robocopy missing"
$Robocopy_Exists = & {
	if (!(Get-Command Robocopy* -ErrorAction SilentlyContinue)) {
		Write-Host "[$(_LINE_)] Robocopy does not exist. HOW COULD THAT HAPPEN??" -BackgroundColor Black -ForegroundColor Red
	}
 else {
		return $true
	}
}


# Create That ISO
if ( $ADK_Exists -and $Robocopy_Exists ) {
	#Write-Host "[$(_LINE_)] Creating ISO-File: '$PSScriptRoot\$ISOFileName.iso'"

	# Search for the folder of the installation.
	$LatestWindowsImageFile = Get-ChildItem -Path $UUP_AriaBaseDir -Recurse -ErrorAction SilentlyContinue | Where-Object { !$PSIsContainer -and $_.Name -match "install[.]wim" } | Sort-Object -Property LastWriteTime -Descending | Select-Object -First 1
	#$LatestWindowsImageName = $LatestWindowsImageFile.Name
	$LatestWindowsImageFullName = $LatestWindowsImageFile.FullName
	$LatestWindowsImagePath = Split-Path $LatestWindowsImageFullName

	# I have ISOPATH>source>install.wim. So I have to get the Dir of install.wim and than the name of that parent.
	$ISOPathFullName = $LatestWindowsImageFile.Directory.Parent.FullName
	#$ISOPathName = $LatestWindowsImageFile.Directory.Parent.Name

	#$ImageFilename
	$ImageFilename_NoExtension = [System.IO.Path]::GetFileNameWithoutExtension($ImageFilename)
	$ImageFilename_Extension = [System.IO.Path]::GetExtension($ImageFilename)
	
	$InfoFileName = $ImageFilename
	if ($ImageFilename_Extension -notmatch "[.](wim|esd)") {
		$FoundFile = Get-ChildItem -Path $UUP_TempFolder | Where-Object { $_.Name -match "$ImageFilename_NoExtension[.](wim|esd)" } | Select-Object -First 1
		$InfoFileName = $FoundFile.Name
	}
	$InfoFilePath = "$UUP_TempFolder\$InfoFileName"

	if (Test-Path -Path $InfoFilePath) {
		$DVDLABEL = ""

		# I cannot completely re-do this name.
		# Should work for ISO and LABEL name.
		#18362.1.190318-1202.19H1_RELEASE_CLIENTMULTI_X64FRE_DE-DE
		$WIMInfo = (Get-WimInfo -SourceWIM $InfoFilePath -Verbose:$false | Select-Object -Property Version, Build -First 1)
		$WIMVersion = $WIMInfo.Version, $WIMInfo.Build -join "." -replace "10.0."
		$DVDLABEL += $WIMVersion

		#$WIMDate = Get-Date -Format "yyMMdd-HHmm"
		$WIMDate = Get-Date -Format "yyMMdd"
		$DVDLABEL += ".$WIMDate"

		# CCSA for Multi. I just think you have MULT.
		# As I would care xD
		$DVDLABEL += "_CCSA_MULT_DV5"
	}
 else {
		Write-Warning "[$(_LINE_)] No version can be gathered if we do not have a wim file. Setting basic label name then."
		
		# CCSA for Multi. I just think you have MULT.
		# As I would care xD
		$DVDLABEL = "CCSA_MULTI_DV5"
	}

	Write-Host "[$(_LINE_)] Creating ISO-File: '$PSScriptRoot\$DVDLABEL.iso'"

	# $UUP_IMGMountPath was used to mount WIM files.
	# Copying files there instead.
	# Log missing. Relative Path?
	#ROBOCOPY "$ISOPathName" $UUP_IMGMountPath /COPYALL /E /R:1 /W:10 /TEE

	Copy-Item -Path $LatestWindowsImageFullName -Destination "$UUP_TempFolder\backup_image.bck" -Force -Verbose

	# remove install.wim if we have esd or swm file
	if ([System.IO.Path]::GetExtension($ImageFilename) -match "[.](esd|swm)") {
		$null = Remove-Item -Path "$LatestWindowsImageFullName" -Force -Recurse -Confirm:$false -Verbose
	}
	

	# Insert WIM/ESD/SWM into Image
	$ImageFiles | ForEach-Object {
		$null = Copy-Item -Path $_.FullName -Destination $LatestWindowsImagePath -Force -Verbose
	}

	Start-Process -FilePath "$ADK_Folder\$env:PROCESSOR_ARCHITECTURE\OSCDIMG\oscdimg.exe " -ArgumentList "-m -l$DVDLABEL -o -u2 -udfver102 -bootdata:2#p0,e,b$ISOPathFullName\boot\etfsboot.com#pEF,e,b$ISOPathFullName\efi\microsoft\boot\efisys.bin $ISOPathFullName `"$PSScriptRoot\$DVDLABEL.ISO`"" -Wait -PassThru -NoNewWindow

	$ImageFiles | ForEach-Object {
		$null = Remove-Item -Path "$LatestWindowsImagePath\$($_.Name)" -Force -Verbose
	}

	Copy-Item -Path "$UUP_TempFolder\backup_image.bck" -Destination "$LatestWindowsImagePath\install.wim" -Force -Verbose
}

$EndTime = Get-Date
Write-Host "STEP5: Ended at $(Get-Date -Format "dd.MM.yy HH:mm:ss")"

$TimeSpan = (New-TimeSpan -Start $StartTime -End $EndTime) -join ";"
Write-Host "STEP5: Duration: $TimeSpan"

ScriptCleanUP -StopTranscript
