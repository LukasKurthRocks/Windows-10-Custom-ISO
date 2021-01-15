Write-Host "TEMP CLEANUP" -ForegroundColor Cyan

$tempfolders = @("$env:SystemRoot\Temp\*", "$env:SystemRoot\Prefetch\*", "$env:SystemDrive\Documents and Settings\*\Local Settings\temp\*", "$env:SystemDrive\Users\*\Appdata\Local\Temp\*")
Remove-Item $tempfolders -Force -Recurse -Verbose -ErrorAction SilentlyContinue

Write-Host "Done." -ForegroundColor Cyan