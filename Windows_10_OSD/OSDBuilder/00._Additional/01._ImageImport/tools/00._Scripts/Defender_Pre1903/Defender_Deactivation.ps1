Set-MpPreference -DisableRealtimeMonitoring $True -Verbose
New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" -Name DisableAntiSpyware -Value 0 -PropertyType DWORD -Force -Verbose