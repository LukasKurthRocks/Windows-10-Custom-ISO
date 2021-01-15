function Set-RegistryValue {
	param($Path,$Name,$Value)

	# create "directory"
	if (!(Test-Path $Path)) {$null = New-Item -ItemType Directory -Force -Path $Path}
	
	# also testing if key exists
	$exists = Get-ItemProperty -Path "$Path" -Name "$Name" -ErrorAction SilentlyContinue
	if (($exists -ne $null) -and ($exists.Length -ne 0)) {
		try {
			$null = Set-ItemProperty $Path $Name $Value -Force -Verbose
		} catch {
			Write-Host "Error while Set-Item: $($_.Exception.Message)" -ForegroundColor Red
		}
		#return $true
	} else {
		try {
			$null = New-ItemProperty -Path "$Path" -Name "$Name" -Value $Value -Verbose
		} catch {
			Write-Host "Error while New-Item: $($_.Exception.Message)" -ForegroundColor Red
		}
		#return $false
	}
}

Set-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "AppsUseLightTheme" -Value 0
Set-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "SystemUsesLightTheme" -Value 0

Write-Host "Done." -ForegroundColor Cyan

#Start-Sleep -Seconds 3
#Write-Host "Done. [PRESS ENTER]:" -ForegroundColor Cyan
#Read-Host