@echo off
PowerShell.exe -NoLogo -NoProfile -ExecutionPolicy ByPass -File "%~dp01._DownloadAndISO.ps1" -SkipRemoveUUPFolder -DisplaySelectionGUI
echo.Script finished. Please press [ENTER] to continue.
pause > NUL