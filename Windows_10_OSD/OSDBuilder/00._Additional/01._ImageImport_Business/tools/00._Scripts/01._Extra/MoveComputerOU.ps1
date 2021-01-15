#Requires -RunAsAdministrator
#Requires -Version 3.0

# Moving computers without the gui. One can select computers that got pushed inside the StandardOU
# Then one can select (and search for) the OU to place the computer in.
[CmdLetBinding()]
param()

if (!(Get-Module -ListAvailable -Name "ActiveDirectory")) {
    Write-Host "Could not find module 'ActiveDirectory'. Please install Remote Administration Tools." -BackgroundColor Black -ForegroundColor Red
    return
}

$ADComputersContainer = (Get-ADDomain).ComputersContainer
$ADComps = Get-ADComputer -Filter * -SearchBase $ADComputersContainer | Select-Object -Property Name | Sort-Object -Property Name | `
    Out-GridView -PassThru -title "Select Computers to Move" | Select-Object -ExpandProperty Name

$ADOUs = Get-ADOrganizationalUnit -Filter * | Select-Object -Property DistinguishedName | Out-GridView -PassThru -title "Select Target OU" | Select-Object -ExpandProperty DistinguishedName

foreach ($ou in $ADOUs) {
    foreach ($comp in $ADComps) {
        Get-ADComputer $comp | Move-ADObject -TargetPath "$ou" -Verbose 
    }
}

Write-Host "Script finished."