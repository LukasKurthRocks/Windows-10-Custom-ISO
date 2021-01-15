# New-OSBMediaISO will NOT combine anything. To combine images i'll use DISM (after ISO creation?)
# https://osbuilder.osdeploy.com/module/functions-1/osbmedia/new-osbmediaiso
# https://www.powershellgallery.com/packages/OSBuilder/19.1.2.1/Content/Private%5CNew-OSBMedia.ps1
#New-OSBMediaISO

[CmdLetBinding()]
param()

Start-Transcript "$env:TEMP\psimage_iso_$(Get-Date -Format "yyMMdd-HHmmss").log"

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

#$ImageNameAdd = " (Language Packs)"
$ImageNameAdd = ""
$Architecture = "x64"

$Build = "1507" # 1507, 2009
$Editions = @(
    #"Home"
    "Professional"
    #"Education"
    #"Enterprise"
)

if (!(Test-Path -Path "$GetOSDBuilderHome\OSBuilds")) {
    Get-OSBuilder
    #Write-Host "Error: Path '$GetOSDBuilderHome\OSBuilds' not found."
    #return
}

$WindowsSource = Get-ChildItem -Path "$GetOSDBuilderHome\OSBuilds" | Where-Object { $_.Name -like "*MultiLangBuild*" } | Sort-Object -Property CreationTime -Descending | Select-Object -First 1 -ExpandProperty FullName
#$OSFolder = "$GetOSDBuilderHome\OSBuilds\MultiLangBuild-2009-Home 19042.487\OS"
$OSFolder = "$GetOSDBuilderHome\OSBuilds\Custom01\OS"
$ISOFolder = "$GetOSDBuilderHome\OSBuilds\Custom01\ISO"
if (!(Test-Path -Path "$OSFolder")) {
    $null = New-Item -ItemType Directory -Path "$OSFolder" -Verbose
}
if (!(Test-Path -Path "$ISOFolder")) {
    $null = New-Item -ItemType Directory -Path "$ISOFolder" -Verbose
}

[Flags()] Enum RoboCopyExitCodes {
    NoChange = 0
    OKCopy = 1
    ExtraFiles = 2
    MismatchedFilesFolders = 4
    FailedCopyAttempts = 8
    FatalError = 16
}

Robocopy.exe "$WindowsSource\OS" "$OSFolder" /E /NDL /XF install.wim

# filter robocopy results
switch ($LASTEXITCODE) {
    { 0, 1, 2, 3 } { Write-Verbose "Robocopy exited with: $([RoboCopyExitCodes]$_) ($_). Will continue with the script..." }
    default {
        Write-Host "[$(_LINE_)] 'Robocopy' exited with an error: $([RoboCopyExitCodes]$_) ($_)." -BackgroundColor Black -ForegroundColor Red
        Stop-Transcript
        break
    }
}

foreach ($Edition in $Editions) {
    Write-Host ">> $Edition"

    #$ImageName = "Windows 10 $Edition - Build: $Build"
    #Write-Host "Windows Image: $ImageName"

    $ImageFolder = Get-Item -Path "$GetOSDBuilderHome\OSBuilds\MultiLangBuild-$Build-$Edition*" | Sort-Object -Property CreationTime -Descending | Select-Object -ExpandProperty FullName -First 1
    if (!$ImageFolder) {
        Write-Host "No ImageFolder"
        continue
    }

    $SourceImage = "$ImageFolder\OS\sources\install.wim"
    
    Write-Verbose "Getting imageInfo from '$SourceImage' ..." -Verbose
    #DISM /Get-ImageInfo /ImageFile:$SourceImage /Index:1
    $ImageInfo = Get-WindowsImage -ImagePath "$SourceImage" -Index 1
    $ImageInfo_Name = $ImageInfo.ImageName
    $ImageInfo_Build = $ImageInfo.Build
    $ImageIndexName = "$ImageInfo_Name $ImageInfo_Build $Architecture$ImageNameAdd" # ImageInfoBuild oder Build!?

    Write-Verbose "Exporting image '$SourceImage`:1' to '$OSFolder\sources\install.wim' ..." -Verbose
    Dism /Export-Image /SourceImageFile:$SourceImage /SourceIndex:1 /DestinationImageFile:"$OSFolder\sources\install.wim" /DestinationName:"$ImageIndexName"
}

#region Build ISO file
if (Test-Path "$OSBuilderContent\Tools\$env:PROCESSOR_ARCHITECTURE\Oscdimg\oscdimg.exe") {
    $OCDProcess = "$OSBuilderContent\Tools\$env:PROCESSOR_ARCHITECTURE\Oscdimg\oscdimg.exe"
}
elseif (Test-Path "$env:ProgramFiles\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\$env:PROCESSOR_ARCHITECTURE\Oscdimg\oscdimg.exe") {
    $OCDProcess = "$env:ProgramFiles\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\$env:PROCESSOR_ARCHITECTURE\Oscdimg\oscdimg.exe"
}
elseif (Test-Path "${env:ProgramFiles(x86)}\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\$env:PROCESSOR_ARCHITECTURE\Oscdimg\oscdimg.exe") {
    $OCDProcess = "${env:ProgramFiles(x86)}\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\$env:PROCESSOR_ARCHITECTURE\Oscdimg\oscdimg.exe"
}
else {
    Write-Host '========================================================================================' -ForegroundColor DarkGray
    Write-Warning "Could not locate OSCDIMG in Windows ADK at:"
    Write-Warning "${env:ProgramFiles(x86)}\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe"
    Write-Warning "You can optionally copy OSCDIMG to:"
    Write-Warning "$OSBuilderContent\Tools\$env:PROCESSOR_ARCHITECTURE\Oscdimg\oscdimg.exe"
    break
}
Write-Verbose "OSCDIMG: $OCDProcess"

# Check for OS content
$etfsboot = "$OSFolder\boot\etfsboot.com"
if (!(Test-Path $etfsboot)) {
    Write-Warning "Could not locate $etfsboot"
    break
}
$efisys = "$OSFolder\efi\microsoft\boot\efisys.bin"
if (!(Test-Path $efisys)) {
    Write-Warning "Could not locate $efisys"
    break
}

# Splatting Parameters
#$bootdata = '2#p0,e,b"{0}\boot\etfsboot.com"#pEF,e,b"{0}\efi\microsoft\boot\efisys.bin"' -f $OSFolder
$bootdata = '2#p0,e,b"{0}"#pEF,e,b"{1}"' -f $etfsboot, $efisys
$Arguments = @(
    "-m", "-o", "-u2", "-bootdata:$bootdata", "-u2", "-udfver102", "-l""Win10 $Build $Architecture""",
    "`"$OSFolder`"", "`"$ISOFolder\Win10 $Build $Architecture.iso`""
)

# ISO Creation
Write-Verbose "$OCDProcess $Arguments" -Verbose
$Process = Start-Process -FilePath $OCDProcess -ArgumentList $Arguments -Wait -PassThru
$Process.ExitCode

if ($Process.ExitCode -eq 0) {
    Remove-Item -Path "$OSFolder" -Force -Recurse #-Verbose
}
#endregion

Stop-Transcript