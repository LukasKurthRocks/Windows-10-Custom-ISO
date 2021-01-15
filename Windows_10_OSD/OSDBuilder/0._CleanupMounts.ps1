#
#  Cleaning Up Mount Leftovers
#

#Requires -RunAsAdministrator

[CmdLetBinding()]
param()

DISM /English /Get-MountedWIMInfo

Write-Host "Cleanup stale mounts ..." -ForegroundColor Cyan
DISM /English /Cleanup-WIM

Write-Host "Looping mounts /w state 'Invalid' ..." -ForegroundColor Cyan
Get-WindowsImage -Mounted -Verbose:$false | Where-Object { $_.MountStatus -eq "Invalid" } | ForEach-Object {
    DISM /English /Unmount-WIM /MountDir:"$($_.Path)" /Discard

    # PowerShell CmdLet when DISM not working. Could be too fast though.
    if (Test-Path -Path "$($_.Path)" -ErrorAction SilentlyContinue) {
        Write-Verbose "PowerShell: Dismount '$($_.Path)' ..."
        Dismount-DiskImage -ImagePath "$($_.Path)" -ErrorAction SilentlyContinue -Verbose:$VerbosePreference
    }
}

Write-Host "Looping mounts /w state 'NeedsRemount' ..." -ForegroundColor Cyan
Get-WindowsImage -Mounted -Verbose:$false | Where-Object { $_.MountStatus -eq "NeedsRemount" } | ForEach-Object {
    Write-Verbose "DISM: Re-Mounting '$($_.Path)' ..."
    $null = DISM /English /Remount-WIM /MountDir:"$($_.Path)"
    
    Write-Verbose "DISM: Dismount '$($_.Path)' ..."
    DISM /English /Unmount-WIM /MountDir:"$($_.Path)" /Discard

    # PowerShell CmdLet when DISM not working. Could be too fast though.
    if (Test-Path -Path "$($_.Path)" -ErrorAction SilentlyContinue) {
        Write-Verbose "PowerShell: Dismount '$($_.Path)' ..."
        Dismount-DiskImage -ImagePath "$($_.Path)" -ErrorAction SilentlyContinue -Verbose:$VerbosePreference
    }
}

# Just in case there are open mounts to close.
Write-Host "Looping mounts /w state 'OK' ..." -ForegroundColor Cyan
Get-WindowsImage -Mounted -Verbose:$false | Where-Object { $_.MountStatus -eq "OK" } | ForEach-Object {
    if ((Read-Host "Do you want to dismount folder '$($_.Path)'? [y]es = remove").ToLower() -eq "y") {
        DISM /English /Unmount-WIM /MountDir:"$($_.Path)" /Discard
        
        # PowerShell CmdLet when DISM not working. Could be too fast though.
        if (Test-Path -Path "$($_.Path)" -ErrorAction SilentlyContinue) {
            Write-Verbose "PowerShell: Dismount '$($_.Path)' ..."
            Dismount-DiskImage -ImagePath "$($_.Path)" -ErrorAction SilentlyContinue -Verbose:$VerbosePreference
        }
    }
}

Write-Host "Done."