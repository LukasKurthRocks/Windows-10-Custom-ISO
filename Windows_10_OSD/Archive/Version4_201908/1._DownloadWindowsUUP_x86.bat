@echo off
PowerShell.exe -NoLogo -NoProfile -ExecutionPolicy ByPass -File "%~dp01._DownloadWindowsUUP.ps1" -SkipRemoveUUPFolder -URIRequestString "Feature x86" -Verbose
echo.Script finished. Please press [ENTER] to continue.
pause > NUL