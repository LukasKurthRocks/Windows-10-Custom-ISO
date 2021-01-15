# https://deploymentresearch.com/building-the-perfect-windows-server-2019-reference-image/
# https://osdbuilder.osdeploy.com/docs/
# https://osdbuilder.osdeploy.com/docs/advanced/settings (Global Settings and paths)
# https://garytown.com/osd-builder-in-a-task-sequence (SCCM TaskSequence + OSDBuilder)

# Cycle /w: "private, business" and stuff
# FODs: LPs + Languages
# FODs: RSAT
# FODs: NetFx3 (Built-In!?)

# Windows ADK, DaRT

<#
- OSDBuilder only for Windows 10, Server 2016/2019. Win 8 maybe later, probably not.
- DO NOT USE ON WINDOWS 7 OR SERVER 2012!!
- Windows 7 and Server 2012 R2 can be Updated but not Customized
#>

[CmdLetBinding()]
param()

# TODO: Debug
$VerbosePreference = "Continue"
#$ErrorActionPreference = "Stop"

# Remove OSBuilder (without the D)
if (Get-Module -Name OSBuilder -ListAvailable -ErrorAction SilentlyContinue -Verbose:$false) {
    Uninstall-Module OSBuilder -AllVersions -Force -Verbose:$false
}

# Import OSDBuilder Module
if (!(Get-Module -Name OSDBuilder -ErrorAction SilentlyContinue -Verbose:$false)) {
    Import-Module -Name OSDBuilder -Force -Verbose:$false
}

# Install OSDBuilder Module
if (!(Get-Module -Name OSDBuilder -ListAvailable -ErrorAction SilentlyContinue -Verbose:$false)) {
    # Uninstall-Module -Name OSDBuilder -AllVersions -Force
    Install-Module -Name OSDBuilder -Force -Verbose:$false
    Import-Module -Name OSDBuilder -Force -Verbose:$false
}
else {
    # Update if not updated version existing already.
    # Get-Help OSDBuilder -Detailed

    # This will constantly re-install the PowerShell-Module.
    #OSBuilder -Update
    #Get-OSDBuilder -Update
}

# Auto-Selection of C:\OSDBuilder
# Use 'OSDBuilder -SetPath D:\OSDBuilder\SeguraOSD' for path change (no trailing backslash!).
Get-OSDBuilder -CreatePaths
if (!$SetOSDBuilder -or !$GetOSDBuilder) {
    Write-Host "OSDBuilder variables not found." -BackgroundColor Black -ForegroundColor Red
    return
}
"#1"
$SetOSDBuilder | ConvertTo-Json | Out-File -FilePath "$($GetOSDBuilder.Home)\OSDBuilder.json"
#$OSDBuilderConfig =  Get-Content -Path "$($GetOSDBuilder.Home)\OSDBuilder.json" | ConvertFrom-Json
"#2"

# Import-OSMedia
<#
#Get all OSMedia that needs an Update
$OutOfDateMedia = Get-OSMedia -Revision OK -Updates Update -Newest

#Update all OSMedia that need an Update
foreach ($Media in $OutOfDateMedia) {
    $Media | Update-OSMedia -HideCleanupProgress -Download -Execute
}
#>

# Import base images...
# OSDBuilde requires an untouched Microsoft Gold ISO.
# Be sure this console has administrative rights (elevated).
Write-Verbose "Import-OSMedia ..."

# Will otherwise just exit
$Answer = Read-Host "Type [y]es if you want to import-OSMedia"
if ($Answer.ToLower() -eq "y") {
    # -SkipGrid -ImageIndex 7 -ImageName 'Windows 10 Enterprise' -EditionId ProfessionalWorkstation -Update (Update-OSMedia) -BuildNetFX
    Import-OSMedia -ShowInfo
}

#Get-OSMedia

# OSDBuilder -Download OneDrive
# OSDBuilder -Download OneDriveEnterprise
# Get-DownOSDBuilder -ContentDownload "OneDriveSetup Enterprise"
# Get-DownOSDBuilder -ContentDownload "OneDriveSetup Production"


#OSDBuilder -Download OSMediaUpdates

Write-Host "You want to add some language packs? Press enter if you have done it ..."
#New-OSDBuilderContentPack -Name "MultiLang DE" -ContentType MultiLang
#New-OSDBuilderContentPack -Name "MultiLang SE" -ContentType MultiLang

# -GridView
#Get-OSDBuilderDownloads -Download -UpdateArch x64 -UpdateBuild 1709 -UpdateOS "Windows 10" -Superseded -Remove
#Show-OSDBuilderInfo

# Content: Drivers, Dart, ADK, ExtraFiles, ISO Extract, Scripts, StartLayout, Unattend
# Extra Files: https://osdbuilder.osdeploy.com/docs/osbuild/content-directory/extrafiles
# => C:\OSDBuilder\Content\ExtraFiles\Windows 10 Wallpaper\Windows\Web\Wallpaper\Windows\img0.jpg This file will be copied to C:\Windows\Web\Wallpaper\Windows\img0.jpg
# ISO Extract: https://osdbuilder.osdeploy.com/docs/osbuild/content-directory/isoextract
# => When adding the Language Pack ISO to the IsoExtract directory, creating a New-OSBuildTask will enable the prompt to select Language Packs
# Scripts: https://osdbuilder.osdeploy.com/docs/osbuild/content-directory/scripts
# => You can easily add a Script to OSBuilder by placing the PowerShell Script in the OSBuilder\Content\Scripts directory
# StartLayout: https://osdbuilder.osdeploy.com/docs/osbuild/content-directory/startlayout
# Unattend: https://osdbuilder.osdeploy.com/docs/osbuild/content-directory/unattend (Windows System Image Manager)

# Languages
# https://osdbuilder.osdeploy.com/docs/advanced/multilang-baseline
# https://osdbuilder.osdeploy.com/docs/multilang

# Remote Server Administration Tools
# https://osdbuilder.osdeploy.com/docs/contentpacks/content/oscapability#add-rsat-capabilities
# https://osbuilder.osdeploy.com/docs/untitled-6/windows-10-1809-rsat-capability
Write-Verbose "New-OSBuildTask ..."
#New-OSBuildTask -SetAllIntl de-de -SetInputLocale 0409 -SetSKUIntlDefaults de-DE -SetSetupUILang de-DE -SetSysLocale de-DE -SetUILang de-DE -SetUILangFallback en-US -SetUserLocale de-de
New-OSBuildTask -TaskName "Build-20200824_NetFx3" -EnableFeature -EnableNetFX3 -RemoveAppx -RemoveCapability -RemovePackage -AddContentPacks -DisableFeature

Write-Verbose "Update-OSMedia ..."
# -Updates Select/Skip; -SkipComponentCleanup -SKipUpdates
Update-OSMedia -Download -Execute
#Get-OSMedia | Where-Object Name -like 'Windows 10 Enterprise x64 1909*' | Where-Object Revision -eq 'OK' | Where-Object Updates -eq 'Update' | foreach {Update-OSMedia -Download -Execute -Name $_.Name}

Write-Verbose "New-OSBuild ..."
New-OSBuild -ByTaskName "Build-20200824_NetFx3" -Download -Execute

# Save as template!?

# New-PEBuildTask
# New-PEBuild
# New-MediaISO
# New-MediaUSB

Write-Verbose "New-OSBMediaISO ..."
# -FullName "C:\OSDBuilder\OSBuilds\Windows 10 Enterprise x64 1809 17763.503"
New-OSBMediaISO # Windows 10 ADK
#New-OSBMediaUSB -UBSLabel "LKMASTER2020"
#New-OSBMediaVHD

# Monthly Cycle Updates:
# OSDBuilder -Update
# Update-OSMedia -Name “Windows 10 Enterprise x64 1809 17763.437” -Download -Execute
# New-OSBuild -Download -Execute
# New-OSBMediaISO