#Requires -RunAsAdministrator
#Requires -Version 3.0

# Putting computers into groups without the GUI. One can confirm computer name (in case there is another virtual PC like *NAME*-V)
# Then one can select (and search for) the ADGroup to put the computer in.
[CmdLetBinding()]
param()

if (!(Get-Module -ListAvailable -Name "ActiveDirectory")) {
    Write-Host "Could not find module 'ActiveDirectory'. Please install Remote Administration Tools." -BackgroundColor Black -ForegroundColor Red
    return
}

$ADComps = Get-ADComputer -Filter * | Where-Object { $_.Name -match $env:COMPUTERNAME } | Sort-Object -Property Name | `
    Out-GridView -PassThru -title "Select Computers to place into AD groups" | Select-Object -ExpandProperty SamAccountName

$ADGroups = Get-ADGroup -Filter * | Select-Object -Property Name, DistinguishedName | Out-GridView -PassThru | Select-Object -ExpandProperty DistinguishedName

foreach ($group in $ADGroups) {
    foreach ($comp in $ADComps) {
        Add-ADGroupMember -Identity $group -Members $comp
    }
}

Write-Host "Script finished."