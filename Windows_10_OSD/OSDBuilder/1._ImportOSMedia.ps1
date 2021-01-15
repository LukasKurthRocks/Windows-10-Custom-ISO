#
#  INFO: Mounting ISO files, and importing specific indizies from mounted image (ISO and "pre-pounted")
#
# Last Switches: NONE / -Verbose

[CmdLetBinding()]
param(
    # Use this to import "Home"/Core. There is no EditionID for this.
    [switch]$HideGrid,
    # Use this for mounting and dismounting an ISO to import.
    # Use complete ISO-Path like C:\*\windows.iso
    [string]$OSImagePath
)

Start-Transcript -Path "$PSScriptRoot\logs\$(Get-Date -Format "yyMMdd-HHmmss")_OSImport.log"

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

if ($OSImagePath -and (Test-Path -Path "$OSImagePath" -ErrorAction SilentlyContinue)) {
    Write-Verbose "OSImagePath is valid. Using this for mount/dismount."
    $OSImageIsValid = $true
}
else {
    Write-Verbose "OSImagePath '$OSImagePath' is invalid. Using already mounted images if existing."
}

# Get-Help Import-OSMedia -Detailed
# Params: -ImageIndex 7 -ImageName 'Windows 10 Enterprise' -BuildNetFX (New-OSBuild) -Update (Update-OSMedia) -SkipFeatureUpdates -InstallationType Client
# ShowInfo (Show-OSDBuilderInfo -FullName $OSMediaPath)

# remove invalid mounts first. See *RemoveMounts.ps1 for more.
Get-WindowsImage -Mounted -Verbose:$false | Where-Object { $_.MountStatus -eq "Invalid" } | ForEach-Object {
    $MountedPath = $_.Path
    DISM /English /Unmount-WIM /MountDir:"$MountedPath" /Discard
    Remove-Item -Path $MountedPath
}

if ($OSImageIsValid) {
    try {
        Mount-DiskImage -ImagePath "$OSImagePath"
    }
    catch {
        Write-Host "Could not mount image '$OSImagePath': $($_.Exception.Message)"
        Stop-Transcript
        return
    }
}

# Should not be triggered; just to be sure.
try {
    # There is no Core or CoreN. ServerRdsh (Windows 10 for Remote Sessions) still ava.
    #Import-OSMedia -ShowInfo -EditionId Professional, Enterprise, Education -SkipGrid:([System.Management.Automation.SwitchParameter]::new($HideGrid))
    if ($HideGrid) {
        Write-Verbose "Importing Media: $HideGrid"
        Import-OSMedia -ShowInfo -EditionId Professional, Enterprise, Education -SkipGrid
    }
    else {
        Write-Verbose "Importing Media: $HideGrid, watch out for the GridView!"
        Import-OSMedia -ShowInfo
    }
}
catch {
    Write-Host "Error importing OSMedia: $($_.Exception.Message)" -BackgroundColor Black -ForegroundColor Red
    Stop-Transcript
    return
}

if ($OSImageIsValid) {
    try {
        Dismount-DiskImage -ImagePath "$OSImagePath"
    }
    catch {
        Write-Host "Could not dismount image '$OSImagePath': $($_.Exception.Message)"
        Stop-Transcript
        return
    }
}

Stop-Transcript