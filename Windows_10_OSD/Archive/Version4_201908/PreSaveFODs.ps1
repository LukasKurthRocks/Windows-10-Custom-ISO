$Folder = "$env:windir\SoftwareDistribution\Download"
#Get-ChildItem $Folder -Recurse

$NewFolder = "$env:SystemDrive\temp\fods"

if (!(Test-Path -Path $NewFolder)) {
    $null = New-Item -Path $NewFolder -ItemType Directory
}

Get-ChildItem -Path "$env:SystemDrive\Windows\Temp" -Filter "*robo_dork.log" | ForEach-Object {
    $null = Remove-Item -Path $_.FullName -Verbose
}

#robocopy $Folder $NewFolder /E /ZB /COPY:DATSOU /R:3 /W:3 /Log:C:\Windows\Temp\robo1.log /V /NP /MON:1 /MOT:0 /MT:16 /TEE

#Get-WindowsCapability -Online -Name "RSAT*" | ForEach-Object { Remove-WindowsCapability -Name $_.Name -Online }
#Get-WindowsCapability -Online -Name "RSAT*" | ForEach-Object { Add-WindowsCapability -Name $_.Name -Online }

$SleepInSeconds = 1
$Counter = 0
while ($true) {
    $Counter++
    robocopy $Folder $NewFolder /E /ZB /COPY:DATSOU /R:3 /W:3 /Log:C:\Windows\Temp\$(Get-Date -Format "yyMMdd-HHmmss-ff")_robo_dork.log /V /NP /MT:16

    Start-Sleep -Seconds 1
    Clear-Host
    "Slept $Counter time(s) with a time of $SleepInSeconds second(s)."
}