#Requires -RunAsAdministrator
#Requires -Version 5.0

<#
I guess it is just useful for me.
This is the only interactive script.

1. wim file:
- Enterprise
- Enterprise N (who knows)
- Enterprise IoT
- Virtual Desktops (ServerRdsh)

2. wim file:
- Enterprise with RSAT

3. wim file:
- Enterprise with Language Packs

# 4. wim file:
# - Enterprise with Customizations for SCCM
# => I screated a separate script for this in 4.2!

TODO: Check for filesize of ISO in step 5?
SWM might be smaller than 4.7, but ISO might not!
#>

[CmdLetBinding()]
param(
	$WIMFiles = @(),
	# You can define install.wim/esd. ESD CAN be smaller;
	# but with multiple x64-indizies it would be better to split.
	$DestinationImageFileName = "install.wim",
	# i will not remove this. just splitting.
	[switch]$CreateSWMFileForDVD
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
Write-Host "STEP4.1: Started at $(Get-Date -Format "dd.MM.yy HH:mm:ss")"


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

if (Test-Path -Path "$UUP_TempFolder\$DestinationImageFileName") {
	$Result = Read-Host -Prompt "install.wim already exists. Do you want to remove this [y]? Will get merged otherwise [ENTER]."

	# I do not care HOW it is written.
	if ($Result -match "y") {
		$null = Remove-Item -Path "$UUP_TempFolder\$DestinationImageFileName" -Force -Recurse
	}
}

# TODO: [ValidateScript({})]
if (!$WIMFiles) {
	# I created this folder for WIM extraction, so there should be some WIM files.
	$WIMFiles = Get-ChildItem -Path $UUP_TempFolder -Filter "*.wim"
}
if (!$WIMFiles) {
	Write-Host "[$(_LINE_)] No image found to merge."
	return
}

$AllWIMInfo = @()
$NewIndizies = 0

Write-Verbose "[$(_LINE_)] Images found to merge: $($WIMFiles -join ", ")"
$WIMFiles | ForEach-Object {
	$WIMFileName = $_.FullName
	Get-WimInfo -SourceWim $WIMFileName -Verbose:$false | ForEach-Object {
		$NewIndizies++
		#$_.Index = $NewIndizies
		$_ | Add-Member -MemberType NoteProperty -Name "OrderIndex" -Value $NewIndizies
		$_ | Add-Member -MemberType NoteProperty -Name "ImageFile"  -Value $WIMFileName
		$AllWIMInfo += $_
	}
}

Write-Host "[$(_LINE_)] Listing indizies of '$($WIMFiles.Name -join ", ")':"
$AllWIMInfo | Format-Table -AutoSize -Wrap

$Result = Read-Host -Prompt "Please input the values of OrderIndex representing your order (1-$($AllWIMInfo.Count), like '3,1,2'; seperated by comma ',') you want to have. Press [ENTER] if you are fine with the displayed order."
if ($Result) {
	# Pre-Test if this is a number.
	try {
		# Is there a shorter way to compare input as numbers?
		$null = $Result.Split(",") | ForEach-Object { [int]$_ }
	}
 catch {
		Write-Host "[$(_LINE_)] Error: $($_.Exception.Message)" -BackgroundColor DarkRed -ForegroundColor White
		return
	}

	if ($Result.Split(",").Count -ne $AllWIMInfo.Count) {
		Write-Host "[$(_LINE_)] You have to insert the same count of numbers. (On image: $($AllWIMInfo.Count) | selected: $($Result.Split(",").Count))" -BackgroundColor DarkRed -ForegroundColor White
		return
	}
	$IndiziesOrder = $Result
}
else {
	$IndiziesOrder = $AllWIMInfo.OrderIndex -join ","
}

$IndiziesOrderCounter = 0
$IndiziesOrder.Split(",") | ForEach-Object {
	$IndiziesOrderCounter++
	$IndiziesOrderIndex = $_

	$ImageInformationIndex = $AllWIMInfo | Where-Object { $_.OrderIndex -eq $IndiziesOrderIndex }
	$ImageInformation_File = $ImageInformationIndex.ImageFile
	$ImageInformation_Index = $ImageInformationIndex.Index

	Write-Host "[$(_LINE_)]======================================"
	Write-Host "[$(_LINE_)]      Mounting Index $IndiziesOrderCounter/$($AllWIMInfo.Count) => $IndiziesOrderIndex|$ImageInformation_Index"
	Write-Host "[$(_LINE_)]======================================"

	# Mounting Image
	Write-Verbose "[$(_LINE_)] Mounting '$ImageInformation_File' to '$UUP_IMGMountPath'."
	DISM /Mount-Wim /WimFile:$ImageInformation_File /Index:$ImageInformation_Index /MountDir:$UUP_IMGMountPath /Quiet /NoRestart /English /LogPath:$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_mount_os_i$IndiziesOrderCounter.log
	DismLog -ExitCode $LASTEXITCODE -Operation "Mount: $ImageInformation_File`:$ImageInformation_Index | $UUP_IMGMountPath" -Line $(_LINE_)
	
	# Problem with error on mounting needs to be fixed. Unmounting in same progress.
	# One thing that COULD be skipped is "-1052638937 (0xc1420127)" / Message: 'The specified image in the specified wim is already mounted for read/write access.'.
	if ($LASTEXITCODE -ne 0) {
		Write-Host "[$(_LINE_)] LASTEXITCODE: $LASTEXITCODE (0x$([System.Convert]::ToString($LASTEXITCODE, 16))). Please fix errors and re-start. Unmounting Image." -BackgroundColor Black -ForegroundColor Red

		# Unmounting IMGFolder and Cleaning up stale files
		DISM /UnMount-Wim /MountDir:$UUP_IMGMountPath /Discard /English /LogPath:$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_unmount_os_i$IndiziesOrderCounter.log
		DISM /CleanUp-Wim /English /LogPath:$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_cleanup_os_i$IndiziesOrderCounter.log
		DismLog -ExitCode $LASTEXITCODE -Operation "Unmount: $ImageInformation_File`:$IndiziesOrderIndex | $UUP_IMGMountPath" -Line $(_LINE_)
		return
	}
	
	Write-Host "[$(_LINE_)] Exporting to '$UUP_TempFolder\$DestinationImageFileName'."

	# Exporting our image to another wim file
	Write-Verbose "[$(_LINE_)] Saving in '$UUP_TempFolder\$DestinationImageFileName'."
	Dism /Export-Image /SourceImageFile:$ImageInformation_File /SourceIndex:$ImageInformation_Index /DestinationImageFile:$UUP_TempFolder\$DestinationImageFileName /Compress:max /Bootable /CheckIntegrity /Quiet /NoRestart /English /LogPath:$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_export_os.log
	DismLog -ExitCode $LASTEXITCODE -Operation "Export: $ImageInformation_File`:$ImageInformation_Index | $UUP_IMGMountPath" -Line $(_LINE_)
	
	if ($LASTEXITCODE -ne 0) {
		Write-Host "[$(_LINE_)] LASTEXITCODE: $LASTEXITCODE (0x$([System.Convert]::ToString($LASTEXITCODE, 16)))." -BackgroundColor Black -ForegroundColor Red
	}

	#region Final Unmount and Cleanup
	Write-Host "[$(_LINE_)] Unmount and CleanUp (Started: $(Get-Date -Format "HH:mm:ss"))"

	# Unmount and cleanup
	Write-Verbose "[$(_LINE_)] Unmounting '$UUP_IMGMountPath'."
	DISM /UnMount-Wim /MountDir:$UUP_IMGMountPath /Discard /Quiet /NoRestart /English /LogPath:$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_unmount_os_i$IndiziesOrderCounter.log
	DismLog -ExitCode $LASTEXITCODE -Operation "UnMount" -Line $(_LINE_)
	
	if ($LASTEXITCODE -ne 0) {
		Write-Host "[$(_LINE_)] LASTEXITCODE: $LASTEXITCODE (0x$([System.Convert]::ToString($LASTEXITCODE, 16)))." -BackgroundColor Black -ForegroundColor Red
	}

	# Clean image leftovers
	Write-Verbose "[$(_LINE_)] CleanUp leftover or stale DISM files."
	DISM /CleanUp-Wim /Quiet /NoRestart /English /LogPath:$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_cleanup_os_i$IndiziesOrderCounter.log
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
}

Write-Host "[$(_LINE_)] Listing indizies of '$DestinationImageFileName':"
Get-WimInfo -SourceWim "$UUP_TempFolder\$DestinationImageFileName" -Verbose:$false | Format-Table -AutoSize -Wrap

if (Test-Path -Path "$UUP_TempFolder\$DestinationImageFileName") {
	$Result = Read-Host -Prompt "You like the new order? Press [ENTER] if you are done, so we can remove the other WIM files. Press CTRL+C to cancel operation (would be the last anyway)."
	if (!$Result) {
		Get-ChildItem -Path $UUP_TempFolder -Filter "*.wim" | Where-Object { $_.Name -notmatch "install.wim" } | ForEach-Object {
			$null = Remove-Item -Path $_.FullName -Force -Recurse -Confirm
		}
	}

	# I once had 6 indizies on one image, filesize was too big for DVD.
	# If you want to burn this to DVD you NEED to split.
	if ($CreateSWMFileForDVD) {
		$Limit = 4700
		$MBLimit = "$Limit`MB"
		$SWMFileName = [System.IO.Path]::GetFileNameWithoutExtension($DestinationImageFileName)

		if ( (Get-Item "$UUP_TempFolder\$DestinationImageFileName").Length -gt (Invoke-Expression -Command $MBLimit) ) {
			Dism /Split-Image /ImageFile:$UUP_TempFolder\$DestinationImageFileName /SWMFile:$UUP_TempFolder\$SWMFileName.swm /FileSize:$Limit /NoRestart /English /LogPath:$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_splitSWM_i$IndiziesOrderCounter.log
		}
	} # /end split
}
else {
	Write-Verbose "[$(_LINE_)] No install.wim has been created. Can that be right?"
}

Write-Warning -Message "PLEASE KEEP THE '$UUP_TempFolder\$DestinationImageFileName' UNTIL WE HAVE CREATED THE ISO. THANKS. (6._CleanUP will get rid of everything anyways)."

$EndTime = Get-Date
Write-Host "STEP4.1: Ended at $(Get-Date -Format "dd.MM.yy HH:mm:ss")"

$TimeSpan = (New-TimeSpan -Start $StartTime -End $EndTime) -join ";"
Write-Host "STEP4.1: Duration: $TimeSpan"

ScriptCleanUP -StopTranscript