@echo off
PowerShell.exe -NoLogo -NoProfile -ExecutionPolicy ByPass -Command "%~dp04.1_MergeImages.ps1" -CreateSWMFileForDVD -Verbose
echo.Script finished. Please press [ENTER] to continue.
pause > NUL