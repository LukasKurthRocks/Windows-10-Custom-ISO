@echo off
cd %~dp0
cmd /c powershell -ExecutionPolicy ByPass -NoProfile -NoLogo -File %~dp0\ClickMe.ps1 -SkipUUPDownloader -SkipUpdateFolder -OnlyEnterprise
pause