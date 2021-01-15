@echo off
PowerShell.exe -NoLogo -NoProfile -ExecutionPolicy ByPass -Command "%~dp01._Get-UUPDumpISO.ps1" -SearchParam "feat+windows+10+20H2+amd64" -Language "de-DE" -EditionCode 0 -Verbose
echo.Script finished. Please press [ENTER] to continue.
pause > NUL