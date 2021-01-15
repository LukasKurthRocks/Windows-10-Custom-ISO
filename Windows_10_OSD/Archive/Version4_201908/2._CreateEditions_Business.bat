@echo off
::PowerShell.exe -NoLogo -NoProfile -ExecutionPolicy ByPass -Command "D:\PowerShell\w10v4\2._CreateEditions.ps1" -WindowsEditions Enterprise,EnterpriseN,IoTEnterprise,ServerRdsh
PowerShell.exe -NoLogo -NoProfile -ExecutionPolicy ByPass -Command "%~dp02._CreateEditions.ps1" -WindowsEditions Enterprise,EnterpriseN,IoTEnterprise,ServerRdsh -CustomWIMFileName "BusinessEnterprise.wim"
echo.Script finished. Please press [ENTER] to continue.
pause > NUL