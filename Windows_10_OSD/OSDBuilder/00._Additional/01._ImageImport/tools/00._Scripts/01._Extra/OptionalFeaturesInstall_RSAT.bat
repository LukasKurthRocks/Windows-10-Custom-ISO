@echo off
PowerShell.exe -NoLogo -NoProfile -ExecutionPolicy ByPass -Command "%~dp0OptionalFeaturesInstall.ps1" -FeatureStringInstall "RSAT" -Verbose
echo.Script finished. Please press [ENTER] to continue.
pause > NUL