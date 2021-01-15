function Remove-RegistryValue {
	param($Path,$Name)

	# Leave script if empty
	if (!(Test-Path $Path)) {return}
	
	# also testing if key exists
	$exists = Get-ItemProperty -Path "$Path" -Name "$Name" -ErrorAction SilentlyContinue
	if (($exists -ne $null) -and ($exists.Length -ne 0)) {
		try {
			$null = Remove-ItemProperty -Path $Path -Name $Name -Force -Verbose
		} catch {
			Write-Host "Error while Remove-Item: $($_.Exception.Message)" -ForegroundColor Red
		}
		#return $true
	}
}

Remove-RegistryValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI" -Name "LastLoggedOnUser"
Remove-RegistryValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI" -Name "LastLoggedOnSAMUser"
Remove-RegistryValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI" -Name "LastLoggedOnUserSID"
Remove-RegistryValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI" -Name "LastLoggedOnProvider"

Write-Host "Done." -ForegroundColor Cyan

#Start-Sleep -Seconds 3
#Write-Host "Done. [PRESS ENTER]:" -ForegroundColor Cyan
#Read-Host