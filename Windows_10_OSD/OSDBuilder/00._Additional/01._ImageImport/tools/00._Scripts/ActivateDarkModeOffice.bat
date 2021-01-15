@echo off
cmd /c powershell -ExecutionPolicy ByPass -NoProfile -NoLogo -File "%~dp0\%~n0.ps1"
echo.Script finished. Please press [ENTER] to continue.
pause > NUL