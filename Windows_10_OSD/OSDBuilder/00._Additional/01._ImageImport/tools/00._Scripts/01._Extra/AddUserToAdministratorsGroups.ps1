$AdminGroupName = (Get-WmiObject -Class Win32_Group -Filter 'LocalAccount = True AND SID = "S-1-5-32-544"').Name
$RemoteGroupName = (Get-WmiObject -Class Win32_Group -Filter 'LocalAccount = True AND SID = "S-1-5-32-555"').Name

cmd /c net localgroup $AdminGroupName $env:USERNAME /add
cmd /c net localgroup $RemoteGroupName $env:USERNAME  /add
cmd /c net localgroup $AdminGroupName