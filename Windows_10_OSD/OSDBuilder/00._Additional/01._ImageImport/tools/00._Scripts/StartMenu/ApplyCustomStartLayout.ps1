Write-Host "Apply StartMenu Layout File" -ForegroundColor Cyan

# Start Menu is sorted here !?
#if(Test-Path -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\CloudStore\Store\Cache\DefaultAccount\"NET Framework Setup"\NDP") {
#	Remove-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\CloudStore\Store\Cache\DefaultAccount\" -Recurse -Force -Verbose
#}

if (Test-Path -Path "$PSScriptRoot\CustomStartMenuLayout.xml" -ErrorAction SilentlyContinue) {
    Import-StartLayout -LayoutPath "$PSScriptRoot\CustomStartMenuLayout.xml" -MountPath "$env:SystemDrive\" -Verbose
} else {
	Write-Host "file '$PSScriptRoot\CustomStartMenuLayout.xml' not found." -ForegroundColor Red
}

Write-Host "Done." -ForegroundColor Cyan