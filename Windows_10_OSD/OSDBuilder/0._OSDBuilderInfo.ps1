#
#  Check OSDBuilder Status/Info
#

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

Get-OSDBuilder
#Show-OSDBuilderInfo

# OSDBuilder -Update
# Update-OSDSUS