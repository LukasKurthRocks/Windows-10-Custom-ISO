@echo off
PowerShell.exe -NoLogo -NoProfile -ExecutionPolicy ByPass -File "%~dp01._DownloadWindowsUUP.ps1" -SkipRemoveUUPFolder -Verbose
echo.Script finished. Please press [ENTER] to continue.
pause > NUL