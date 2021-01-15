#Requires -RunAsAdministrator
#Requires -Version 3.0

[CmdLetBinding()]
param(
    #$LPLocation = "D:\sources\sxs"
    $LPLocation = "$PSScriptRoot"
)

# Language Codes on the disk.
#"([~][\w]{2}[-][\w]{2}[~])|([~][\w]{2}[-][\w]{4}[-][\w]{2}[~])"
#"-(([\w]{2}-[\w]{2})|([\w]{2}-[\w]{4}-[\w]{2}))-"
$LanguageCodes = Get-ChildItem -Path $LPLocation | Where-Object { $_.Name -match "-(([\w]{2}-[\w]{2})|([\w]{2}-[\w]{4}-[\w]{2}))-" } | ForEach-Object {
    $Matches[1]
} | Select-Object -Unique

Write-Verbose "Gathering language capabilities"
# not only de-de, also fonts like: Language.Fonts.Arab~~~und-ARAB~0.0.1.0
$InstallableLanguageCapabilities = Get-WindowsCapability -Online | Where-Object { ($_.Name -like "Language*") -and ($_.State -ne "Installed") }

$LanguagelistSetting = Get-WinUserLanguageList

$LanguageCodes | ForEach-Object {
    # First install all available
    $LIC = $_
    Write-Host "Processing language '$LIC'"

    $LanguageCapabilities = $InstallableLanguageCapabilities | Where-Object { $_.Name -like "*$LIC*" -and $_.State -ne "Installed" }
    if(!$LanguageCapabilities) {
        Write-Host "No capabilities to install for '$LIC'" -BackgroundColor Black -ForegroundColor Yellow
    } else {
        $LanguageCapabilities | ForEach-Object {
            try {
                Add-WindowsCapability -Online -Name $_.Name -Source $LPLocation -LimitAccess
            } catch {
                Write-Host "Error adding language capability with last exit code '$LASTEXITCODE': $($_.Exception.Message)" -BackgroundColor Black -ForegroundColor Red
                return
            }
        }
    }

    if($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        Write-Host "We should have exit code 0: '$LASTEXITCODE'. Please fix errors and re-try." -BackgroundColor Black -ForegroundColor Red
        return
    }

    try {
        $LanguagelistSetting.Add("$LIC")
    } catch {
        Write-Host "Error adding language to list with last exit code '$LASTEXITCODE': $($_.Exception.Message)" -BackgroundColor Black -ForegroundColor Red
        return
    }
    
}

Write-Host "Setting WinUILanguageList '$($LanguagelistSetting.EnglishName -join ", ")'"
try {
    Set-WinUserLanguageList $LanguagelistSetting -Verbose -Force
} catch {
    Write-Host "Error setting language to list with last exit code '$LASTEXITCODE': $($_.Exception.Message)" -BackgroundColor Black -ForegroundColor Red
    return
}