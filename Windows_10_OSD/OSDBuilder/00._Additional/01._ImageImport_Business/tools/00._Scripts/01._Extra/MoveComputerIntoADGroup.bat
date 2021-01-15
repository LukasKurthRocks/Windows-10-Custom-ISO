@echo off
PowerShell.exe -NoLogo -NoProfile -ExecutionPolicy ByPass -File "%~dp0\%~n0.ps1" -Verbose
echo.Script finished. Please press [ENTER] to continue.
pause > NUL