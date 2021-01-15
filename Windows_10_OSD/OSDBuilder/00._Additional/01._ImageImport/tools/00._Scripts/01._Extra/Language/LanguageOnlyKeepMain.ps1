#Requires -RunAsAdministrator
#Requires -Version 3.0

[CmdLetBinding()]
param(
    $Language = ([CultureInfo]::InstalledUICulture | Select-Object -First 1).Name
)

$LanguagelistSetting = Get-WinUserLanguageList
$LanguagelistSettingOnlyMain = $LanguagelistSetting | Where-Object { $_.LanguageTag -match "$Language" }

Write-Host "Setting WinUILanguageList '$($LanguagelistSettingOnlyMain.EnglishName -join ", ")'"
try {
    Set-WinUserLanguageList $LanguagelistSettingOnlyMain -Force
} catch {
    Write-Host "Error setting language to list with last exit code '$LASTEXITCODE': $($_.Exception.Message)" -BackgroundColor Black -ForegroundColor Red
    return
}