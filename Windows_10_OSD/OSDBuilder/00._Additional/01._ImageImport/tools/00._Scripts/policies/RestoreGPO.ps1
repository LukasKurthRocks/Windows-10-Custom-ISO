Write-Host "Importing Registry Settings" -ForegroundColor Cyan

# Copy saved GPO to C:\Windows\System32\GroupPolicy
$SavedGPOPath = (Get-ChildItem -Path "$PSScriptRoot\" -Filter "*_SavedGPO" | Sort-Object -Property LastWriteTime -Descending | Select-Object -First 1).FullName
$LocalGPOPath = "$env:SystemRoot\System32\GroupPolicy"

ROBOCOPY $SavedGPOPath $LocalGPOPath /E /R:1 /W:10 /IT /IS

Write-Host "Done. See gpedit.msc for prove!" -ForegroundColor Cyan

#Start-Sleep -Seconds 3
#Write-Host "Done. See gpedit.msc now! [PRESS ENTER]:" -ForegroundColor Cyan
#Read-Host