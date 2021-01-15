#Requires -RunAsAdministrator
#Requires -Version 3.0

$host.UI.RawUI.WindowTitle = "Semi-Automation Script"
Write-Host "Starting Semi-Automation Script" -ForegroundColor Magenta
Write-Host "!! Please wait for the scripts to finish correctly. !!" -ForegroundColor Yellow

Start-Sleep -Seconds 5

function Out-Current {
	param($Text, [int]$int = 30, [ConsoleColor]$ForegroundColor = [ConsoleColor]::Yellow, [ConsoleColor]$BackgroundColor = [ConsoleColor]::Blue)

	# calculate space from begin to text
	# only needs left side, as right is just the rest
	$TextLength = " $Text ".Length

	if ($TextLength -le $int) {
		$TextPadCountLeft = ($int - $TextLength) / 2
		$TextPadCountLeft = [math]::Round($TextPadCountLeft) # no double or float!!

		$Text = (("".PadLeft($TextPadCountLeft, " ")) + (" $Text ")).PadRight($int, " ")
	} # else just keep it that way
	
	$Line = "".PadRight(30, "=")
	Write-Host $Line -ForegroundColor $ForegroundColor -BackgroundColor $BackgroundColor
	Write-Host $Text -ForegroundColor $ForegroundColor -BackgroundColor $BackgroundColor
	Write-Host $Line -ForegroundColor $ForegroundColor -BackgroundColor $BackgroundColor
}

$00Path = "$PSScriptRoot\00._Scripts"
$00DarkMode = "$00Path\ActivateDarkMode.ps1"
$00DarkModeOFC = "$00Path\ActivateDarkModeOffice.ps1"
$00Policies = "$00Path\policies\RestoreGPO.ps1"
$00EnergyPlan = "$00Path\EnergySaverPlan.ps1"
$00TempCleanup = "$00Path\CleanTempFolders.ps1"
$00StartLayout = "$00Path\StartMenu\ApplyCustomStartLayout.ps1"
$00RemOneDrive = "$00Path\OneDrive\RemoveOneDrive\remove-onedrive.ps1"
$00DisableStartup = "$00Path\DisableStartupApps.ps1"

$01Path = "$PSScriptRoot\01._Windows"
$01Windows = "$01Path\install_KMSpico.ps1"

$02Path = "$PSScriptRoot\02._Office"
$02Office = "$02Path\install.ps1"

$03Path = "$PSScriptRoot\03._Software"
$03Software = "$03Path\PatchMyPC_Manual\install_standard.ps1"
$03NoIcons = "$03Path\PatchMyPC_Manual\remove_desktop_icons.ps1"

if (Test-Path -Path $00DarkMode) {
	Out-Current -Text "Activating Dark Mode"
	PowerShell -ExecutionPolicy ByPass -NoLogo -NoProfile -File $00DarkMode
}
else {
	Write-Host "`"$00DarkMode`" not found." -ForegroundColor Red
}

Start-Sleep -Seconds 1

if (Test-Path -Path $00EnergyPlan) {
	Out-Current -Text "Setting Energy Settings"
	PowerShell -ExecutionPolicy ByPass -NoLogo -NoProfile -File $00EnergyPlan
}
else {
	Write-Host "`"$00EnergyPlan`" not found." -ForegroundColor Red
}

Start-Sleep -Seconds 1

if (Test-Path -Path $00Policies) {
	Out-Current -Text "Starting GPO Restore"
	PowerShell -ExecutionPolicy ByPass -NoLogo -NoProfile -File $00Policies
}
else {
	Write-Host "`"$00Policies`" not found." -ForegroundColor Red
}

Start-Sleep -Seconds 1

if (Test-Path -Path $01Windows) {
	Out-Current -Text "Windows Scripts"
	PowerShell -ExecutionPolicy ByPass -NoLogo -NoProfile -File $01Windows
}
else {
	Write-Host "`"$01Windows`" not found." -ForegroundColor Red
}

Start-Sleep -Seconds 5

if (Test-Path -Path $02Office) {
	Out-Current -Text "Microsoft Office Installer"
	PowerShell -ExecutionPolicy ByPass -NoLogo -NoProfile -File $02Office

	# Dark Mode AFTER Settings
	if (Test-Path -Path $00DarkModeOFC) {
		Out-Current -Text "Microsoft Office Tweaks"
		PowerShell -ExecutionPolicy ByPass -NoLogo -NoProfile -File $00DarkModeOFC
	}
 else {
		Write-Host "`"$00DarkModeOFC`" not found." -ForegroundColor Red
	}
}
else {
	Write-Host "`"$02Office`" not found." -ForegroundColor Red
}

Start-Sleep -Seconds 5

if (Test-Path -Path $03Software) {
	Out-Current -Text "Software Installer"

	Write-Host "You can run this manually afterward if you need to." -ForegroundColor DarkGray
	PowerShell -ExecutionPolicy ByPass -NoLogo -NoProfile -File $03Software
}
else {
	Write-Host "`"$03Software`" not found." -ForegroundColor Red
}

Start-Sleep -Seconds 2

if (Test-Path -Path $00RemOneDrive) {
	Out-Current -Text "Final OneDrive Removal"
	PowerShell -ExecutionPolicy ByPass -NoLogo -NoProfile -File $00RemOneDrive
}
else {
	Write-Host "`"$00RemOneDrive`" not found." -ForegroundColor Red
}

Start-Sleep -Seconds 2

if (Test-Path -Path $00DisableStartup) {
	Out-Current -Text "Disable Startup Apps"
	PowerShell -ExecutionPolicy ByPass -NoLogo -NoProfile -File $00DisableStartup
}
else {
	Write-Host "`"$00DisableStartup`" not found." -ForegroundColor Red
}

Start-Sleep -Seconds 3

if (Test-Path -Path $03NoIcons) {
	Out-Current -Text "Icon Removal"
	PowerShell -ExecutionPolicy ByPass -NoLogo -NoProfile -File $03NoIcons
}
else {
	Write-Host "`"$03NoIcons`" not found." -ForegroundColor Red
}

Start-Sleep -Seconds 1

if (Test-Path -Path $00StartLayout) {
	Out-Current -Text "Apply Default Startmenu Layout"
	PowerShell -ExecutionPolicy ByPass -NoLogo -NoProfile -File $00StartLayout
}
else {
	Write-Host "`"$00StartLayout`" not found." -ForegroundColor Red
}

Start-Sleep -Seconds 5

if (Test-Path -Path $00TempCleanup) {
	Out-Current -Text "Temp Folder Cleanup"
	PowerShell -ExecutionPolicy ByPass -NoLogo -NoProfile -File $00TempCleanup
}
else {
	Write-Host "`"$00TempCleanup`" not found." -ForegroundColor Red
}

Start-Sleep -Seconds 1

DISM.exe /English /Online /Cleanup-Image /StartComponentCleanup /ResetBase

Start-Sleep -Seconds 1

Read-Host -Prompt "Press [ENTER] if everything finished."

# No need for this if we do not copy the folder
# and remove the lnk files afterwards.
#Out-Current -Text "Attention".ToUpper() -ForegroundColor White -BackgroundColor Red
#Write-Host "Please (re-)move the folder with the scripts from the desktop now. I could do it myself, but that would be to complicated for now (some tasks or multiple jobs or runspaces who would kill itself...)."
#Write-Host "(this script will autoclose then)" -ForegroundColor DarkGray
#Read-Host