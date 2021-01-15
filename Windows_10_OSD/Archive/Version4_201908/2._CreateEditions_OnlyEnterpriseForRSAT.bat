@echo off
::PowerShell.exe -NoLogo -NoProfile -ExecutionPolicy ByPass -Command "D:\PowerShell\w10v4\2._CreateEditions.ps1" -WindowsEditions Enterprise
PowerShell.exe -NoLogo -NoProfile -ExecutionPolicy ByPass -Command "%~dp02._CreateEditions.ps1" -WindowsEditions Enterprise -CustomWIMFileName "OnlyEnterprise_RSAT.wim" -WIMDescriptionSuffix """- RSAT"""
::REM finished
echo.Script finished. Please press [ENTER] to continue.
pause > NUL