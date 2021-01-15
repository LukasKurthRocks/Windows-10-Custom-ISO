# get-windowsupdate.ps1 (profile_scripts)
function HideFeatureUpdate {
    param (
        $KBNumbers,
        [string]$UpdateName
    )

    # Count = 0? Show Help?
    #$PSBoundParameters
    #$Arguments
    
    if (($KBNumbers | Measure-Object).Count -eq 0) {
        Write-Host "No update kb ('$KBNumbers')." -BackgroundColor Black -ForegroundColor Red
        return
    }

    # JIC ...
    if ($UpdateBypass) {
        Write-Host "Disabling WSUS server usage ..."
        
        # Registry Windows Update Options | https://docs.microsoft.com/de-de/security-updates/windowsupdateservices/18127499
        Set-ItemProperty -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU -Name UseWUServer -Value 0 # Skip WUServer; Using MS Servers
        Set-ItemProperty -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU -Name AllowMUUpdateService -Value 1 # Also install microsoft products
        Set-ItemProperty -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU -Name AUOptions -Value 3 # 3 = Automatically download and notify of installation.
        Set-ItemProperty -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU -Name NoAutoRebootWithLoggedOnUsers -Value 1 # 1 = Logged-on user gets to choose whether or not to restart his or her computer.

        # Re-enabling service when disabled on machines
        Write-Verbose "Stopping services ... (use something like 'psexec -s \\$env:COMPUTERNAME cmd /c taskkill /F /FI `"SERVICES eq wuauserv`"' when services are not responsing)"
        Get-Service wuauserv | Where-Object { $_.StartType -eq "Disabled" } | Set-Service -StartupType Manual -Verbose
        Get-Service wuauserv, TrustedInstaller, msiserver, cryptsvc, AppIDSvc, BITS | Stop-Service -Force -Verbose

        # Removing old update folders and files (fresh update)
        Get-ChildItem -Path "$env:WINDIR\SoftwareDistribution" -Recurse | Remove-Item -Recurse -Force -Verbose
        Get-ChildItem -Path "$env:WINDIR\system32\catroot2" -Recurse | Remove-Item -Recurse -Force -Verbose
        Get-Service wuauserv | Start-Service -Verbose
    }

    Write-Host "Starting Update Searcher ..."
    $Searcher = New-Object -ComObject Microsoft.Update.Searcher
    $Result = $Searcher.Search("IsInstalled=0")

    Write-Host "Looping Updates ..."
    foreach ($rUpdate in $Result.Updates) {
        foreach ($rKB in $rUpdate.KBArticleIDs) {
            foreach ($hideKB in $KBNumbers) {
                if ($rKB -eq $hideKB) {
                    #Write-Host "$rKB -eq $hideKB" -ForegroundColor Green

                    if (!$rUpdate.IsHidden) {
                        Write-Host "Hiding Update: '$($rUpdate.Title)' (KB$($rKB))"
                        $rUpdate.IsHidden = $true
                    }
                    else {
                        Write-Host "Already Hidden: '$($rUpdate.Title)' (KB$($rKB))"
                    }
                }
                else {
                    #Write-Host "(Not Matching) ToHide: $hideKB, Found: $rKB ('$($rUpdate.Title)')" -ForegroundColor Red
                }
            } # /end foreach KBNumbers (Search Parameter)
        } # /end foreach KBNumbers (from Update)

        if ($rUpdate.Title -match $UpdateName) {
            #Write-Host "$($rUpdate.Title) -match $UpdateName" -ForegroundColor Green
            
            if (!$rUpdate.IsHidden) {
                if ((Read-Host -Prompt "Do you want to hide '$($rUpdate.Title)'? (SearchFilter: '$UpdateName')").ToLower() -eq "") {
                    Write-Host "Hiding Update: '$($rUpdate.Title)'"
                    $rUpdate.IsHidden = $true
                }
            }
            else {
                Write-Host "Already Hidden: '$($rUpdate.Title)'"
            }
        }

    } # /end foreach Updates from result
}

# 3012973 = 1903 Feature Update
# 4517245 = 1909 Feature Update (Enablement)
# 4562830 = 20H2 Feature Update (Enablement)
HideFeatureUpdate -KBNumbers "3012973", "4517245", "4562830" -UpdateName "Feature"