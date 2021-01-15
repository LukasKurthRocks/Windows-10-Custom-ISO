<#
Few things to consider:
- Copying the ISO folder to SCCM
- Copying the install.wim/esd to SCCM
- Generally lokking for content in C:\$ROCKS.UUP

Do it yourself...
#>

#Requires -RunAsAdministrator
#Requires -Version 5.0

[CmdLetBinding()]
param()

# I put this here in case I need this
# Althoug a requirement is to have version 5.0
#if (!($PSScriptRoot)) {
#	$PSScriptRoot = (Split-Path $MyInvocation.MyCommand.Path)
#}

Write-Warning -Message "We did too many things. Please remove the folder '$UUP_WorkingFolder' and all it's content for yourself."

return
Start-Transcript -Path "$env:TEMP\w10iso_customizor_$(Get-Date -Format "yyMMdd-HHmmss.fffffff").txt"

# Logging the time the script started.
# In the end I will compare the starttime with the endtime.
$StartTime = Get-Date
Write-Host "STEP6: Started at $(Get-Date -Format "dd.MM.yy HH:mm:ss")"

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
#endregion Import Script

# The reg might have been loaded.
# Keys are saved in ScriptFunctions.ps1
Get-Variable -Name "CUSTOM_Reg*" | ForEach-Object {
	$tVarValue = $_.Value
	if (Test-Path -Path "Registry::HKEY_LOCAL_MACHINE\$tVarValue") {
		UnmountRegistry -OfflineRegistry "Registry::HKEY_LOCAL_MACHINE\$tVarValue"
	}
}

if (Test-Path -Path $UUP_IMGMountPath) {
	# Unmounting IMGFolder and Cleaning up stale files
	DISM /UnMount-Wim /MountDir:$UUP_IMGMountPath /Discard /English
	DISM /CleanUp-Wim /English
	DismLog -ExitCode $LASTEXITCODE -Operation "Unmount: $WIM_ExportedFilePath`:$MountingIndexNumber | $UUP_IMGMountPath" -Line $(_LINE_)

	if ($LASTEXITCODE -ne 0) {
		Write-Host "DISM returned: '$LASTEXITCODE'. Please fix this." -BackgroundColor Black -ForegroundColor Red
		return
	}
}

if (Test-Path -Path $UUP_WorkingFolder) {
	Get-ChildItem -Path $UUP_WorkingFolder -Recurse -Force | ForEach-Object {
		$null = Remove-Item -Path $_.FullName -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue -ErrorVariable $REMOVE_ERROR -Verbose 
	}
	$null = Remove-Item -Path $UUP_WorkingFolder -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue -ErrorVariable $REMOVE_ERROR -Verbose

	# Path should not exist anymore
	if (Test-Path -Path $UUP_WorkingFolder) {
		if ($REMOVE_ERROR) {
			Write-Host "UUP folder still eisting: $REMOVE_ERROR." -BackgroundColor Black -ForegroundColor Red
		}
	}
}



$EndTime = Get-Date
Write-Host "STEP6: Ended at $(Get-Date -Format "dd.MM.yy HH:mm:ss")"

$TimeSpan = (New-TimeSpan -Start $StartTime -End $EndTime) -join ";"
Write-Host "STEP6: Duration: $TimeSpan"

ScriptCleanUP -StopTranscript