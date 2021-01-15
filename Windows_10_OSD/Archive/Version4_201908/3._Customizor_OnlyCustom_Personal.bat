@echo off
PowerShell.exe -NoLogo -NoProfile -ExecutionPolicy ByPass -Command "%~dp03._Customizor.ps1" -CustomWIMFileName "Private.wim" -SkipFeatures -Verbose
echo.Script finished. Please press [ENTER] to continue.
pause > NUL