#Requires -RunAsAdministrator
#Requires -Version 3.0

netsh advfirewall reset
if((Get-MpPreference -Verbose:$false).ExclusionPath) {
	Remove-MpPreference -ExclusionPath (Get-MpPreference).ExclusionPath -Verbose:$false
}
if((Get-MpPreference -Verbose:$false).ExclusionProcess) {
	Remove-MpPreference -ExclusionProcess (Get-MpPreference).ExclusionProcess -Verbose:$false
}
if((Get-MpPreference -Verbose:$false).ExclusionExtension) {
	Remove-MpPreference -ExclusionExtension (Get-MpPreference).ExclusionExtension -Verbose:$false
}

if(Get-Module Defender -ListAvailable -Verbose:$false -ErrorAction SilentlyContinue) {
    Set-MpPreference -DisableRealtimeMonitoring $False
    $null = New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" -Name DisableAntiSpyware -Value 0 -PropertyType DWORD -Force
}