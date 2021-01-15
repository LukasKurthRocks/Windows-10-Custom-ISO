Write-Host "Removing desktop icons. You can create your own start menu if you want to." -ForegroundColor Cyan

Start-Sleep -Seconds 5

# Remove-Item -Recurse -Path "$env:USERPROFILE\Desktop" -Force -Filter "*.lnk"
Get-ChildItem -Path "$env:USERPROFILE\Desktop" -Filter "*.lnk" -Force | ForEach-Object {
	Remove-Item -Path $_.FullName -Recurse -Force
}
Get-ChildItem -Path "$env:PUBLIC\Desktop" -Filter "*.lnk" -Force | ForEach-Object {
	Remove-Item -Path $_.FullName -Recurse -Force
}

Start-Sleep -Seconds 1

Write-Host "Done." -ForegroundColor Cyan