@echo off
PowerShell.exe -NoLogo -NoProfile -ExecutionPolicy ByPass -Command "%~dp0%~n0.ps1" -Verbose
echo.Script finished. Please press [ENTER] to continue.
pause > NUL