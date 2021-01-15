#
#  I HATE CONTENT PACKS!!
#
# INFO: Cancelled. DO NOT USE.

# I do not always create those ContentPacks.
# Quick Info: #https://deploymentresearch.com/using-osd-builder-to-create-a-multi-language-windows-10-image/

[CmdLetBinding()]
param()

#region OSImport
$SavedVerbosePreference = $VerbosePreference
$VerbosePreference = [System.Management.Automation.ActionPreference]::SilentlyContinue
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
$VerbosePreference = $SavedVerbosePreference
#endregion

# Mount ISO + Import-OSMedia

# This is for "Step 4 - Build (Adding ContentPacks)"
# TODO: "*\OSDBuilder\Content\IsoExtract\Windows 10 2009 Language\x64\langpacks" (all) vs.
#       "*\OSDBuilder\ContentPacks\MultiLang DE\OSLanguagePacks\2009 x64" (language depending?)

# Create Company Language Pack Folders
New-OSDBuilderContentPack -Name "MultiLang DE" -ContentType MultiLang
New-OSDBuilderContentPack -Name "MultiLang EN" -ContentType MultiLang
New-OSDBuilderContentPack -Name "MultiLang SE" -ContentType MultiLang
New-OSDBuilderContentPack -Name "MultiLang HU" -ContentType MultiLang
New-OSDBuilderContentPack -Name "MultiLang NL" -ContentType MultiLang
New-OSDBuilderContentPack -Name "MultiLang FR" -ContentType MultiLang

<#
Copy cab files into OSD Folders...
Source:  "*\Microsoft-Windows-Client-Language-Pack_x64_sv-se.cab"
Destination: "<OSDBuilder>\ContentPacks\MultiLang <lang>\OSLanguagePacks\<Build> <Arch>"
├───MultiLang EN
│   ├───OSLanguageFeatures
│   │   ├───1903 x64
│   │   ├───1909 x64
│   │   └───2004 x64
│   ├───OSLanguagePacks
│   │   ├───1903 x64
│   │   ├───1909 x64
│   │   └───2004 x64
│   ├───OSLocalExperiencePacks
│   │   ├───1903 x64
│   │   ├───1909 x64
│   │   └───2004 x64
│   └───PEADKLang
│       ├───1903 x64
│       ├───1909 x64
│       └───2004 x64
#>

#New-OSBuildTask -TaskName MultiLangBuild -AddContentPacks

# Update the media by running the following command
#Get-OSMedia | Where-Object Name -like 'Windows 10 Enterprise x64 1909*' | Where-Object Revision -eq 'OK' | Where-Object Updates -eq 'Update' | foreach {Update-OSMedia -Download -Execute -Name $_.Name}

#New-OSBuild -ByTaskName MultiLangBuild -Execute

### Extra Route when updating:
#OSDBuilder -Update (Module Update)
#Update-OSDSUS (Windows Updates)

#Import-Module -Name OSDBuilder -Force
#Import-Module -Name OSDSUS -Force

#Update Images
#Get-OSMedia | Where-Object Name -like 'Windows 10 Enterprise x64 1909*' | Where-Object Revision -eq 'OK' | Where-Object Updates -eq 'Update' | foreach {Update-OSMedia -Download -Execute -Name $_.Name}

# Create new updated OS Build
#New-OSBuild -ByTaskName MultiLangBuild -Execute