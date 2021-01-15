# Need to implement FODs like RSAT or LanguagePackes/Features intor the ISO.
# There are only some methos to install them
# - !MSU were removed!!
# - Online: https://github.com/imabdk/Powershell/blob/master/Install-RSATv1809v1903v1909v2004.ps1
# - FOD ISO
# - C:\Windows\SoftwareDistribution\Download (When downloaded for that Machine)
# - uupdump.ml files!? => Test!!
# => https://uupdump.ml/findfiles.php?id=a726046b-0765-4f72-970b-2cb075af259b

# https://www.ntlite.com/community/index.php?threads/help-cant-add-en-in-feature-on-demand-fod-packs-in-latest-ntlite-getting-error-everytime.1013/
# https://www.ntlite.com/community/index.php?threads/how-to-add-integrate-language-pack-language-feature-pack-into-a-iso-via-ntlite.978/#post-10097

<#
Via Update
- Machine with Build you need ...
=> Add-WindowsCapability -Name OpenSSH.Server~~~~0.0.1.0 -Online
- My Machine creating that ISO
=> Get-WindowsImage -ImagePath C:\Temp\install.wim (get index)
=> Mount-WindowsImage -Path C:\Temp\Mount\ -ImagePath C:\Temp\install.wim -Index 2
- My Machine applying that FOD
=> Add-WindowsCapability -Name OpenSSH.Server~~~~0.0.1.0 -Source C:\temp\Sources\ -Path C:\temp\Mount\
=> Get-WindowsCapability -Name OpenSSH.Server~~~~0.0.1.0 -Path C:\Temp\Mount\
=> Dismount-WindowsImage -Path C:\temp\Mount\ -Save
#>

<#
$SourceMachine = Read-Host "What is your source machine?"
$Path = "\\" + $SourceMachine + "\c$\Windows\SoftwareDistribution\Download"
$Cabs = Get-ChildItem -Path "$Path" -Recurse -Include *.cab | Sort LastWriteTime 
Mount-WindowsImage -ImagePath C:\X64\sources\install.wim -Index 1 -Path C:\Mount\
ForEach ($Cab in $Cabs){
    Add-WindowsPackage -Path C:\Mount -PackagePath $Cab.FullName
    if ($? -eq $TRUE){
        $Cab.Name | Out-File -FilePath .\Updates-Sucessful.log -Append
    } else {    
        $Cab.Name | Out-File -FilePath .\Updates-Failed.log -Append
    }
}
Dismount-WindowsImage –Path C:\Mount –Save
#>

<#
# Language FOD
$prefered_list = Get-WinUserLanguageList
$prefered_list.Add("cs-cz")
$prefered_list.Add("de-de")
$prefered_list.Add("pl-pl")
$prefered_list.Add("sk-sk")
$prefered_list.Add("zh-cn")
Set-WinUserLanguageList($prefered_list) -Force
#>


<#
TODO Later
- Create ISO with files "RunMe.bat" and Cracks and stuff ...
#>


# $Cabs = ls -Recurse -Include *.cab | sort -Property LastWriteTime
# foreach($Cab in $Cabs) { Add-WindowsPackage -Online -PackagePath $Cab.FullName -Verbose -NoRestart }
# => If not successful? Is already installed?

# Remove Packages if existing
# - First Remove from PCSettings (Languages in LanguageSettings and FOD in Apps and Features)
# - Then Check User Languages (Get-WinUserLanguageList | ft)
# $Current = Get-WinSystemLocale | select -exp Name
# Get-WindowsPackage -Online -PackageName "*lang*" | ? { $_.PackageName -notmatch $Current } | select -exp packagename
# Get-WindowsPackage -Online -PackageName "*lang*" | ? { $_.PackageName -notmatch $Current } | Remove-WindowsPackage -Online -NoRestart -Verbose # Restart Afterwards
# OR: $Cabs = ls -Recurse -Include *.cab | ? { $_.Name -notmatch "de-de" } | sort -Property LastWriteTime 
# OR: foreach($Cab in $Cabs) { Write-Host "Trying to remove $Cab"; Remove-WindowsPackage -PackagePath $Cab.FullName -NoRestart -Online -Verbose }
# dism /online /Remove-Package /PackageName:Microsoft-Windows-LanguageFeatures-OCR-de-de-Package~31bf3856ad364e35~amd64~~10.0.19041.1
# Get-WindowsPackage -Online -PackageName "*lang*" | ? { $_.PackageName -notmatch $Current } | % { $PackageName = $_.PackageName; Dism /Online /Remove-Package /PackageName:$PackageName }

# Languages
# Get-WinUserLanguageList | ft

# Registry Comnvert to Powershell


# $Cabs = ls -Recurse -Include *.cab | ? { $_.Name -notmatch "de-de" } | sort -Property LastWriteTime 
# http://windows-update-checker.com/FAQ/How%20to%20uninstall%20permanent%20updates.htm
<#
How to uninstall permanent updates. (Thanks to abbodi1406)

    Search for the *.mum file in C:\Windows\servicing\Packages\
    Open the .mum file with notepad
    Search for permanent
    delete àpermanency=”permanent”ß
    Then use dism to remove the package
#>

# Languages
$Current = Get-WinSystemLocale | Select-Object -ExpandProperty Name
$Cabs = Get-ChildItem -Recurse -Include *.cab | Where-Object { $_.Name -notmatch $Current } | Sort-Object -Property LastWriteTime 
foreach ($Cab in $Cabs) {
    Write-Host "[$(Get-Date -Format "HH:mm:ss")] $($Cab.BaseName)"
    $null = Add-WindowsPackage -Online -PackagePath $Cab.FullName -NoRestart
}
foreach ($Cab in $Cabs) {
    Write-Host "[$(Get-Date -Format "HH:mm:ss")] $($Cab.BaseName)" -F Cyan
    DISM /online /english /add-package /packagepath:"$($Cab.FullName)" /norestart
}

$AppX = Get-ChildItem -Recurse -Include *.appx | Where-Object { $_.Name -notmatch $Current } | Sort-Object -Property LastWriteTime 
foreach ($ax in $AppX) {
    Write-Host "Trying to add $ax"
    Add-AppxProvisionedPackage -Online -PackagePath "$($ax.FullName)" -SkipLicense
}
foreach ($ax in $AppX) {
    Write-Host "Trying to add $ax"
    DISM /Online /English /Add-ProvisionedAppxPackage /PackagePath="$($ax.FullName)" /NoRestart /SkipLicense
}
#$list = Get-WinUserLanguageList
#$list.Add("en-us")
#Set-WinUserLanguageList $list -Force


# foreach($Cab in $Cabs) { Write-Host "Trying to remove $Cab"; Remove-WindowsPackage -PackagePath $Cab.FullName -NoRestart -Online -Verbose }

# - Get name from cab and test if still existing
# - Order of uninstalling packages? Basic last? Only when all success??


<#
/*
uupdump name	                    microsoft-windows-languagefeatures-basic-ja-jp-package-amd64.cab
cat file name pattern	            Microsoft-Windows-LanguageFeatures-Basic-ja-jp-Package~31bf3856ad364e35~amd64~~10.0.18362.1.cat
rename the cab in [1] like this     Microsoft-Windows-LanguageFeatures-Basic-ja-jp-Package~31bf3856ad364e35~amd64~~.cab
*/
#>

# Für FOD aggregatedmetadata