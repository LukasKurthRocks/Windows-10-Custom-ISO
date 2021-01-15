@echo off
PowerShell.exe -NoLogo -NoProfile -ExecutionPolicy ByPass -File "%~dp00._GetWIMInfo.ps1" -SourcePath "C:\`$ROCKS.UUP\aria\18362.1.190318-1202.19H1_RELEASE_CLIENTMULTI_X64FRE_DE-DE\sources"
echo.Script finished. Please press [ENTER] to continue.
pause > NUL