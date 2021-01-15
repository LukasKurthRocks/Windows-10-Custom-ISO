@echo off

echo Loading Sysinternals
net use \\live.sysinternals.com\tools

echo Copying Sysinternals
xcopy \\live.sysinternals.com\tools\*.* %SystemDrive%\tools\sysinternals\ /y /d

echo Cleanup
net use \\live.sysinternals.com\tools /d

pause
