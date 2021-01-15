@echo off
cmd /c powershell.exe -NoProfile -NoLogo -ExecutionPolicy ByPass -File "%~dp0\%~n0.ps1"
echo.Script finished. Please press [ENTER] to continue.
pause > NUL