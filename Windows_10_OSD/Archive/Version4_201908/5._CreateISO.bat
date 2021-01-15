@echo off
PowerShell.exe -NoLogo -NoProfile -ExecutionPolicy ByPass -Command "%~dp05._CreateISO" -Verbose
echo.Script finished. Please press [ENTER] to continue.
pause > NUL