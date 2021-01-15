#Requires -RunAsAdministrator
#Requires -Version 3.0

[CmdLetBinding()]
param(
    $LanguageCode = "de-DE",
    [switch]$UpdateLanguageList
)

function Get-RegionInfo($Name = '*') {
    $cultures = [System.Globalization.CultureInfo]::GetCultures('InstalledWin32Cultures')
 
    foreach ($culture in $cultures) {
        try {
            $region = [System.Globalization.RegionInfo]$culture.Name
 
            if ($region.DisplayName -like $Name) {
                $region
            }
        }
        catch {}
    }
}

function Get-RegionInfoByCode($Name = '*') {
    $cultures = [System.Globalization.CultureInfo]::GetCultures('InstalledWin32Cultures')
 
    foreach ($culture in $cultures) {
        try {
            $region = [System.Globalization.RegionInfo]$culture.Name
 
            if ($region.Name -like $Name) {
                $region
            }
        }
        catch {}
    }
}

Set-Culture $LanguageCode -Verbose
Set-WinSystemLocale $LanguageCode -Verbose
Set-WinHomeLocation -GeoId (Get-RegionInfoByCode -Name $LanguageCode).GeoID -Verbose
Set-WinUILanguageOverride $LanguageCode -Verbose

if ($UpdateLanguageList) {
    Set-WinUserLanguageList $LanguageCode -Verbose -Force
}