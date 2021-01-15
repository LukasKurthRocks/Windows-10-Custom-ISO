@echo off
PowerShell.exe -NoLogo -NoProfile -ExecutionPolicy ByPass -Command "%~dp03._Customizor.ps1" -CustomWIMFileName "OnlyEnterprise_LPs.wim" -Languages """de-de|en-us|sv-se|fr-fr|hu-hu""" -SkipFODs -SkipCustom_StartLayout -Verbose
echo.Script finished. Please press [ENTER] to continue.
pause > NUL