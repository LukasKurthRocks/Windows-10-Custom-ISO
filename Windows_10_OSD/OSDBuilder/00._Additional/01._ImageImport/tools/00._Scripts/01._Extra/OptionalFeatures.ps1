#Requires -RunAsAdministrator

Write-Host "Preparing operations ..."

# Force not using the WU.
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "UseWUServer" -Value 0
Restart-Service wuauserv

$CurrentOptionalFeatures = Get-WindowsOptionalFeature -Online
$CurrentCapabilities = Get-WindowsCapability -Online

Write-Host "Onto the features ..."

# Hyper-V
if ($FeatureHyperV = $CurrentOptionalFeatures | Where-Object { $_.FeatureName -eq "Microsoft-Hyper-V-All" }) {
    $UserInput = Read-Host -Prompt "Feature: `"Hyper-V-All`" aktivieren? [y] (Status: $($FeatureHyperV.State))"
    if ($UserInput.ToLower() -eq "y") {
        if (($FeatureHyperV | Select-Object -ExpandProperty State) -ne "Enabled") {
            # Install the entire Hyper-V stack (hypervisor, services, and tools)
            #Enable-WindowsOptionalFeature -Online -FeatureName "Microsoft-Hyper-V-All" -All -NoRestart
            $FeatureHyperV | Enable-WindowsOptionalFeature -Online -All -NoRestart
            
            # Install only the PowerShell module
            #Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-Management-PowerShell
            # Install the Hyper-V management tool pack (Hyper-V Manager and the Hyper-V PowerShell module)
            #Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-Tools-All
        }
    }
}

# Sandbox
if ($FeatureSandbox = $CurrentOptionalFeatures | Where-Object { $_.FeatureName -eq "Containers-DisposableClientVM" }) {
    $UserInput = Read-Host -Prompt "Feature: `"Sandbox`" aktivieren? [y] (Status: $($FeatureSandbox.State))"
    if ($UserInput.ToLower() -eq "y") {
        if (($FeatureSandbox | Select-Object -ExpandProperty State) -ne "Enabled") {
            $FeatureSandbox | Enable-WindowsOptionalFeature -Online -All -NoRestart

            # Enable-WindowsOptionalFeature -Online -FeatureName "Containers-DisposableClientVM" -All -NoRestart
            # Disable-WindowsOptionalFeature -FeatureName "Containers-DisposableClientVM" -Online
        }
    }
}

# WSL2
if ($FeatureWSL2 = $CurrentOptionalFeatures | Where-Object { $_.FeatureName -eq "Microsoft-Windows-Subsystem-Linux" }) {
    $UserInput = Read-Host -Prompt "Feature: `"WSL`" aktivieren? [y] (Status: $($FeatureWSL2.State))"
    if ($UserInput.ToLower() -eq "y") {
        if ((Get-WindowsOptionalFeature -Online -FeatureName "Microsoft-Hyper-V-All" | Select-Object -ExpandProperty State) -ne "Enabled") {
            Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -All -NoRestart
        }

        if (($FeatureWSL2 | Select-Object -ExpandProperty State) -ne "Enabled") {
            $FeatureWSL2 | Enable-WindowsOptionalFeature -Online -All -NoRestart
            # Enable-WindowsOptionalFeature -Online -FeatureName "Microsoft-Windows-Subsystem-Linux" -All -NoRestart
            # Disable-WindowsOptionalFeature -FeatureName "Microsoft-Windows-Subsystem-Linux" -Online
        }

        wsl --set-default-version 2
    }
}

# NetFx3
if ($FeatureNetFx3 = $CurrentOptionalFeatures | Where-Object { $_.FeatureName -eq "NetFx3" }) {
    $UserInput = Read-Host -Prompt "Feature: `"NetFx3`" aktivieren? [y] (Status: $($FeatureNetFx3.State))"
    if ($UserInput.ToLower() -eq "y") {
        if (($FeatureNetFx3 | Select-Object -ExpandProperty State) -ne "Enabled") {
            $FeatureNetFx3 | Enable-WindowsOptionalFeature -Online -All -NoRestart
            # Enable-WindowsOptionalFeature -Online -FeatureName "NetFx3" -All -NoRestart
            # Disable-WindowsOptionalFeature -FeatureName "NetFx3" -Online
        }
    }
}

# NTVDM
if ($FeatureNTVDM = $CurrentOptionalFeatures | Where-Object { $_.FeatureName -eq "NTVDM" }) {
    $UserInput = Read-Host -Prompt "Feature: `"NTVDM`" aktivieren? [y] (Status: $($FeatureNTVDM.State))"
    if ($UserInput.ToLower() -eq "y") {
        if (($FeatureNTVDM | Select-Object -ExpandProperty State) -ne "Enabled") {
            $FeatureNTVDM | Enable-WindowsOptionalFeature -Online -All -NoRestart
            # Enable-WindowsOptionalFeature -Online -FeatureName "NTVDM" -All -NoRestart
            # Disable-WindowsOptionalFeature -FeatureName "NTVDM" -Online
        }
    }
}

# SMBv1
if ($FeatureSMB = $CurrentOptionalFeatures | Where-Object { $_.FeatureName -eq "SMB1Protocol" }) {
    $UserInput = Read-Host -Prompt "Feature: `"SMB1Protocol`" [a]ktivieren oder [d]eaktivieren? (Status: $($FeatureSMB.State))"
    if ($UserInput.ToLower() -eq "a") {
        if (($FeatureSMB | Select-Object -ExpandProperty State) -ne "Enabled") {
            $FeatureSMB | Enable-WindowsOptionalFeature -Online -All -NoRestart
        }
    }
    
    if ($UserInput.ToLower() -eq "d") {
        if (($FeatureSMB | Select-Object -ExpandProperty State) -ne "Disabled") {
            $FeatureSMB | Disable-WindowsOptionalFeature -Online -NoRestart
        }
    }
}

# RSAT
if ($FeaturesRSAT = $CurrentCapabilities | Where-Object { $_.Name -like "*RSAT*" -and $_.State -eq "NotPresent" }) {
    $UserInput = Read-Host -Prompt "Feature: `"RSAT`" einrichten? [y] (Status: $($FeaturesRSAT.State -join ", "))"
    if ($UserInput.ToLower() -eq "a") {
        $FeaturesRSAT | Add-WindowsCapability -Online
    }
}

# OpenSSH
if ($FeaturesOpenSSHClient = $CurrentCapabilities | Where-Object { $_.Name -like "OpenSSH.Client*" -and $_.State -eq "NotPresent" }) {
    $UserInput = Read-Host -Prompt "Feature: `"OpenSSH Client`" einrichten? [y] (Status: $($FeaturesOpenSSHClient.State -join ", "))"
    if ($UserInput.ToLower() -eq "a") {
        $FeaturesOpenSSHClient | Add-WindowsCapability -Online
    }
}
if ($FeaturesOpenSSHServer = $CurrentCapabilities | Where-Object { $_.Name -like "OpenSSH.Server*" -and $_.State -eq "NotPresent" }) {
    $UserInput = Read-Host -Prompt "Feature: `"OpenSSH Server`" einrichten? [y] (Status: $($FeaturesOpenSSHServer.State -join ", "))"
    if ($UserInput.ToLower() -eq "a") {
        $FeaturesOpenSSHServer | Add-WindowsCapability -Online
    }
}