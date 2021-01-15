@echo off
cmd /c powershell -ExecutionPolicy ByPass -NoProfile -NoLogo -File %~dp0\ApplyCustomStartLayout.ps1
pause