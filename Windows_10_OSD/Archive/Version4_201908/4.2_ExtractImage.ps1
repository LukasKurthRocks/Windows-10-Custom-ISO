#Requires -RunAsAdministrator
#Requires -Version 5.0

<#
Just for me, so i can extract the an index for SCCM.
#>

[CmdLetBinding()]
param(
	$SourceImageFileName = "install.wim",
	$DestinationImageFileName = "exported.wim"
)

# I put this here in case I need this
# Althoug a requirement is to have version 5.0
#if (!($PSScriptRoot)) {
#	$PSScriptRoot = (Split-Path $MyInvocation.MyCommand.Path)
#}

Start-Transcript -Path "$env:TEMP\w10iso_extracting_$(Get-Date -Format "yyMMdd-HHmmss.fffffff").txt"

# Logging the time the script started.
# In the end I will compare the starttime with the endtime.
$StartTime = Get-Date
Write-Host "STEP4.2: Started at $(Get-Date -Format "dd.MM.yy HH:mm:ss")"


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

$SourceImageFile = "$UUP_TempFolder\$SourceImageFileName"
$DestinationImageFile = "$UUP_TempFolder\$DestinationImageFileName"
if (!(Test-Path -Path $SourceImageFile)) {
	Write-Host "[$(_LINE_)] '$SourceImageFile' does not exist. Please verify your settings." -BackgroundColor Black -ForegroundColor Red
	return
}

$WIMInfo = Get-WimInfo -SourceWim $SourceImageFile -Verbose:$false
$WIMInfo | Format-Table -AutoSize -Wrap

$SelectedIndex = Read-Host -Prompt "Select your index to export (integer)"
if ($SelectedIndex) {
	try {
		[int]$SelectedIndex
	}
 catch {
		Write-Host "[$(_LINE_)] Come on. INTEGER is requested. You do not need to input the name of the index. (Error: $($_.Exception.Message))" -BackgroundColor Black -ForegroundColor Red
		return
	}
	
	if ($WIMInfo.Index -notcontains $SelectedIndex) {
		Write-Host "[$(_LINE_)] Index '$SelectedIndex' does not exist on image ($($WIMInfo.Index -join ", "))." -BackgroundColor Black -ForegroundColor Red
		return
	}
}
else {
	Write-Host "[$(_LINE_)] You have not entered a valid number. Try again." -BackgroundColor Black -ForegroundColor Red
	return
}

Write-Host "[$(_LINE_)]======================================"
Write-Host "[$(_LINE_)]           Mounting Index $SelectedIndex"
Write-Host "[$(_LINE_)]======================================"

# Mounting Image
Write-Verbose "[$(_LINE_)] Mounting '$SourceImageFile' to '$UUP_IMGMountPath'."
DISM /Mount-Wim /WimFile:$SourceImageFile /Index:$SelectedIndex /MountDir:$UUP_IMGMountPath /Quiet /NoRestart /English /LogPath:$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_mount_os_i$SelectedIndex.log
DismLog -ExitCode $LASTEXITCODE -Operation "Mount: $SourceImageFile`:$SelectedIndex | $UUP_IMGMountPath" -Line $(_LINE_)
	
# Problem with error on mounting needs to be fixed. Unmounting in same progress.
# One thing that COULD be skipped is "-1052638937 (0xc1420127)" / Message: 'The specified image in the specified wim is already mounted for read/write access.'.
if ($LASTEXITCODE -ne 0) {
	Write-Host "[$(_LINE_)] LASTEXITCODE: $LASTEXITCODE (0x$([System.Convert]::ToString($LASTEXITCODE, 16))). Please fix errors and re-start. Unmounting Image." -BackgroundColor Black -ForegroundColor Red

	# Unmounting IMGFolder and Cleaning up stale files
	DISM /UnMount-Wim /MountDir:$UUP_IMGMountPath /Discard /English /LogPath:$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_unmount_os_i$SelectedIndex.log
	DISM /CleanUp-Wim /English /LogPath:$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_cleanup_os_i$SelectedIndex.log
	DismLog -ExitCode $LASTEXITCODE -Operation "Unmount: $SourceImageFile`:$SelectedIndex | $UUP_IMGMountPath" -Line $(_LINE_)
	return
}
	
Write-Host "[$(_LINE_)] Exporting to '$DestinationImageFile'."

# Exporting our image to another wim file
Write-Verbose "[$(_LINE_)] Saving in '$DestinationImageFile'."
Dism /Export-Image /SourceImageFile:$SourceImageFile /SourceIndex:$SelectedIndex /DestinationImageFile:$DestinationImageFile /Compress:max /Bootable /CheckIntegrity /Quiet /NoRestart /English /LogPath:$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_export_os.log
DismLog -ExitCode $LASTEXITCODE -Operation "Export: $ImageFile`:$SelectedIndex | $UUP_IMGMountPath" -Line $(_LINE_)
	
if ($LASTEXITCODE -ne 0) {
	Write-Host "[$(_LINE_)] LASTEXITCODE: $LASTEXITCODE (0x$([System.Convert]::ToString($LASTEXITCODE, 16)))." -BackgroundColor Black -ForegroundColor Red
}

#region Final Unmount and Cleanup
Write-Host "[$(_LINE_)] Unmount and CleanUp (Started: $(Get-Date -Format "HH:mm:ss"))"

# Unmount and cleanup
Write-Verbose "[$(_LINE_)] Unmounting '$UUP_IMGMountPath'."
DISM /UnMount-Wim /MountDir:$UUP_IMGMountPath /Discard /Quiet /NoRestart /English /LogPath:$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_unmount_os_i$SelectedIndex.log
DismLog -ExitCode $LASTEXITCODE -Operation "UnMount" -Line $(_LINE_)
	
if ($LASTEXITCODE -ne 0) {
	Write-Host "[$(_LINE_)] LASTEXITCODE: $LASTEXITCODE (0x$([System.Convert]::ToString($LASTEXITCODE, 16)))." -BackgroundColor Black -ForegroundColor Red
}

# Clean image leftovers
Write-Verbose "[$(_LINE_)] CleanUp leftover or stale DISM files."
DISM /CleanUp-Wim /Quiet /NoRestart /English /LogPath:$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_cleanup_os_i$SelectedIndex.log
DismLog -ExitCode $LASTEXITCODE -Operation "CleanUp" -Line $(_LINE_)
	
if ($LASTEXITCODE -ne 0) {
	Write-Host "[$(_LINE_)] LASTEXITCODE: $LASTEXITCODE (0x$([System.Convert]::ToString($LASTEXITCODE, 16)))." -BackgroundColor Black -ForegroundColor Red
}
#endregion Final Unmount and Cleanup
	
# Last error check
if ($LASTEXITCODE -ne 0) {
	Write-Host "[$(_LINE_)] LASTEXITCODE: $LASTEXITCODE (0x$([System.Convert]::ToString($LASTEXITCODE, 16)))." -BackgroundColor Black -ForegroundColor Red
}
else {
	Write-Host "[$(_LINE_)] LASTEXITCODE: $LASTEXITCODE (0x$([System.Convert]::ToString($LASTEXITCODE, 16)))." -ForegroundColor DarkGray
}

$EndTime = Get-Date
Write-Host "STEP4.2: Ended at $(Get-Date -Format "dd.MM.yy HH:mm:ss")"

$TimeSpan = (New-TimeSpan -Start $StartTime -End $EndTime) -join ";"
Write-Host "STEP4.2: Duration: $TimeSpan"

ScriptCleanUP -StopTranscript