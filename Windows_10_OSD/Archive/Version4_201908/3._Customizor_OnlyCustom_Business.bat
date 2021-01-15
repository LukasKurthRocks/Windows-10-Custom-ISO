@echo off
PowerShell.exe -NoLogo -NoProfile -ExecutionPolicy ByPass -Command "%~dp03._Customizor.ps1" -CustomWIMFileName "BusinessEnterprise.wim" -SkipFeatures -SkipCustom_StartLayout -Verbose
echo.Script finished. Please press [ENTER] to continue.
pause > NUL