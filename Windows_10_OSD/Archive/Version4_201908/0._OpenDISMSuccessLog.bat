@echo off
:: You can also CLS at the end, so it will be always fresh ;-)
PowerShell.exe -NoLogo -NoProfile -ExecutionPolicy ByPass -Command "while($true){try{Get-ChildItem C:\`$ROCKS.UUP\logs\ -Filter *dism_success* | Sort-Object -Property LastWriteTime -Descending | Select-Object -First 1 | Get-Content -Wait -ErrorAction Stop}catch{""""Could not fetch content.""""};""""$(date -f 'HH:mm:ss'): There is no dism_success file yet."""";sleep 15;}"
echo.Script finished. Please press [ENTER] to continue.
pause > NUL