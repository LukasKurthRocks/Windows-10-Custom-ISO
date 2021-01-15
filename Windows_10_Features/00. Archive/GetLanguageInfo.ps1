# Same with 
# Get-Command -Module International
$LanguageOptions = @(
    #"WinAcceptLanguageFromLanguageListOptOut"
    #"WinCultureFromLanguageListOptOut"
    #"WinDefaultInputMethodOverride"
    "WinHomeLocation"
    "WinLanguageBarOption"
    "WinSystemLocale"
    #"WinUILanguageOverride"
    "WinUserLanguageList"
)

$LanguageOptions | ForEach-Object {
    $Result = $null
    $Result = Invoke-Expression "Get-$_"
    if ($Result -and $null -ne $Result) {
        Write-Verbose "$_" -Verbose
        #$Result.GetType()
        $Result | Format-Table
    }
    else {
        Write-Verbose "Skipped $_ " -Verbose
    }
}

# Sprachen über FOD:
dism /Online /Get-Packages /format:table
Dism /Online /English /Get-Capabilities /format:table | findstr /i "installed"
#$Current = Get-WinSystemLocale | Select-Object -exp Name
#| ? { $_.PackageName -notmatch $Current }
Get-WindowsPackage -Online -PackageName "*lang*" | Format-Table PackageName, DisplayName, Description, ReleaseType, Installed, InstallTime, RestartRequired
DISM /Online /Get-Intl

return

#Remove all features
# foreach($Cab in $Cabs) { Write-Host "Trying to remove $Cab"; Remove-WindowsPackage -PackagePath $Cab.FullName -NoRestart -Online -Verbose }
# Get-WindowsPackage -Online -PackageName "*lang*" | ? { $_.PackageName -notmatch $Current } | % { $PackageName = $_.PackageName; Dism /Online /Remove-Package /PackageName:$PackageName }
# dism /online /Remove-Package /PackageName:Microsoft-Windows-LanguageFeatures-OCR-de-de-Package~31bf3856ad364e35~amd64~~10.0.19041.1

# $Cabs = ls -Recurse -Include *.cab | ? { $_.Name -notmatch "de-de" } | sort -Property LastWriteTime 
# foreach($Cab in (ls -Recurse -Include *.cab | sort -Property LastWriteTime)) { Add-WindowsPackage -Online -PackagePath $Cab.FullName -Verbose -NoRestart }
# foreach($Cab in (ls -Recurse -Include *.cab | sort -Property LastWriteTime)) { Write-Host "[$(Get-Date -Format "HH:mm:ss")] $($Cab.BaseName)"; $null = Add-WindowsPackage -Online -PackagePath $Cab.FullName -NoRestart }
# foreach($Cab in (ls -Recurse -Include *.cab | sort -Property LastWriteTime)) { Write-Host "[$(Get-Date -Format "HH:mm:ss")] $($Cab.BaseName)" -F Cyan; dism.exe /online /english /add-package /packagepath:"$($Cab.FullName)" /norestart }

# $AppX = ls -Recurse -Include *.appx | ? { $_.Name -notmatch "de-de" } | sort -Property LastWriteTime 
# foreach($ax in $AppX) { Write-Host "Trying to add $ax"; DISM /Online /English /Add-ProvisionedAppxPackage /PackagePath="$($ax.FullName)" /NoRestart /SkipLicense }
# languageexperiencepack.sv-se.neutral.appx
# foreach($ax in $AppX) { Write-Host "Trying to add $ax"; Add-AppxProvisionedPackage -Online -PackagePath "$($ax.FullName)" -SkipLicense }
# Get-AppxPackage -AllUsers | ? Name -Like *LanguageExperiencePack* | Format-List Name, PackageUserInformation
#$p = (Get-AppxPackage | ? Name -Like *LanguageExperiencePacksv-SE).InstallLocation
#Add-AppxPackage -Register -Path "$p\AppxManifest.xml" -DisableDevelopmentMode
#Set-WinUILanguageOverride -Language en-us

#$list = New-WinUserLanguageList -Language en-us
#$list = Get-WinUserLanguageList
#$list.Add("en-us")
#Set-WinUserLanguageList $list -Force

# DISM LOGPATH
