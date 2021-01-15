function MSIFileVersion {
    param(
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.IO.FileInfo]$Path,
    
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet("ProductCode", "ProductVersion", "ProductName", "Manufacturer", "ProductLanguage", "FullVersion")]
        [string]$Property
    )
    Process {
        try {
            # Read property from MSI database
            $WindowsInstaller = New-Object -ComObject WindowsInstaller.Installer
            $MSIDatabase = $WindowsInstaller.GetType().InvokeMember("OpenDatabase", "InvokeMethod", $null, $WindowsInstaller, @($Path.FullName, 0))
            $Query = "SELECT Value FROM Property WHERE Property = '$($Property)'"
            $View = $MSIDatabase.GetType().InvokeMember("OpenView", "InvokeMethod", $null, $MSIDatabase, ($Query))
            $View.GetType().InvokeMember("Execute", "InvokeMethod", $null, $View, $null)
            $Record = $View.GetType().InvokeMember("Fetch", "InvokeMethod", $null, $View, $null)
            $Value = $Record.GetType().InvokeMember("StringData", "GetProperty", $null, $Record, 1)
    
            # Commit database and close view
            $MSIDatabase.GetType().InvokeMember("Commit", "InvokeMethod", $null, $MSIDatabase, $null)
            $View.GetType().InvokeMember("Close", "InvokeMethod", $null, $View, $null)           
            $MSIDatabase = $null
            $View = $null
    
            # Return the value
            return $Value
        } 
        catch {
            Write-Warning -Message $_.Exception.Message ; break
        }
    }
    End {
        # Run garbage collection and release ComObject
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($WindowsInstaller) | Out-Null
        [System.GC]::Collect()
    }
}

$ApplicationSaveFolder = "C:\_temp"

$AllApps = @()

Get-ChildItem $ApplicationSaveFolder -Recurse -Depth 1 | Where-Object { !$_.PSIsContainer -and ( $_.FullName -match "msi" ) } | ForEach-Object {
    $Arch = ""
    if ($_.Name -match "x64") {
        $Arch = "x64"
    }
    if ($_.Name -match "x86") {
        $Arch = "x86"
    }

    $FileInformation = [PSCustomObject]@{
        AppName  = "$((MSIFileVersion -Path $_.FullName -Property "ProductName")[3]) - $((MSIFileVersion -Path $_.FullName -Property "ProductVersion")[3])"
        Version  = (MSIFileVersion -Path $_.FullName -Property "ProductVersion")[3]
        AppType  = "MSI"
        AppSpec  = @{
            Code            = (MSIFileVersion -Path $_.FullName -Property "ProductCode")[3]
            ProductLanguage = (MSIFileVersion -Path $_.FullName -Property "ProductLanguage")[3]
        }
        AppArch  = $Arch
        Company  = (MSIFileVersion -Path $_.FullName -Property "Manufacturer")[3]
        FileName = $_.Name
        #FullVersion = MSIFileVersion -Path $_.FullName -Property "FullVersion"
        FullName = $_.FullName
    }
    $AllApps += $FileInformation
}

Get-ChildItem $ApplicationSaveFolder -Recurse -Depth 1 | Where-Object { !$_.PSIsContainer -and ( $_.FullName -match "exe" ) } | ForEach-Object {
    $FileInfo = $_ | Select-Object *
    if ($FileInfo.VersionInfo) {
        $Version = $FileInfo.VersionInfo.FileVersion
        if ($Version) {
            $Version = $Version.Trim()
        }
        $AppName = $FileInfo.VersionInfo.ProductName
        if ($AppName) {
            $AppName = $AppName.Trim()
        }
        $CompanyName = $FileInfo.VersionInfo.CompanyName
        if ($CompanyName) {
            $CompanyName = $CompanyName.Trim()
        }

        $Arch = ""
        if ($_.Name -match "x64") {
            $Arch = "x64"
        }
        if ($_.Name -match "x86") {
            $Arch = "x86"
        }

        if (!$Version) {
            <#
                ^([a-zA-Z\s.+7-]+)(([.\d]+)+[.^\s])([\s(][x][\d]+[)][.](exe|msi)|(exe|msi))
                ^([a-zA-Z\s.+7-]+)(([.\d]+)+[.^\s])([\s(]([D][E]|[x][\d]+)[)][.](exe|msi)|(exe|msi))
                ^([a-zA-Z\s.+7-]+)(([.\d]+)+[._^\s])([\s(]([D][E]|[x][\d]+)[)][.](exe|msi)|(exe|msi))
            #>
            #Write-Host "$($_.Name) => $Version | $AppName | $CompanyName"   

            <#
                True
                6                              exe
                5                              DE
                4                              (DE).
                3                              14.1.18533
                2                              14.1.18533
                1                              TeamViewer
                0                              TeamViewer 14.1.18533 (DE).exe
            #>
            $null = $_.Name -match "^([a-zA-Z\s.+7-]+)(([.\d]+)+[._^\s])([x][\d]+[.]|[\s(]([D][E]|[x][\d]+)[)][.]|)(exe|msi)"
            $AppName = $Matches[1]
            $Version = $Matches[3]
            $CompanyName = "" # Just Empty
            #$ArchLang = $Matches[5]
        }

        #$($FileInfo.VersionInfo.LegalCopyright)
        #Write-Host "$($_.Name) => $Version | $AppName | $CompanyName"
        #$FileInfo.VersionInfo | select *

        if ($AppName -match "Installer|Setup|Self Extractor") {
            $AppName = $AppName -replace "Installer|Setup|Self Extractor"
        }

        $AllApps += [PSCustomObject]@{
            AppName  = ($AppName).Trim()
            Version  = $Version
            AppType  = "EXE"
            AppSpec  = @{}
            AppArch  = $Arch
            Company  = $CompanyName
            FileName = $_.Name
            FullName = $_.FullName
        }
    }
    else {
        # there is always entry, even if empty!
        $FileInfo
    }
}

#$AllApps | Sort-Object AppName | Format-Table
#$AllApps | Sort-Object AppName | ConvertTo-Json | Out-File $ApplicationSaveFolder\Apps.json


# TODO: Chrome??



Write-Host "We NEED some custom `"mutations`"" -ForegroundColor Magenta
$AllApps | ForEach-Object {
    $_ | Add-Member -MemberType NoteProperty -Name "CustomFolderReplacement" -Value ""
    $_ | Add-Member -MemberType NoteProperty -Name "CustomNameReplacement" -Value ""
    if ($_.FileName -like "*Acrobat Reader DC*" -or $_.FileName -like "*Adobe Reader DC*" ) {
        $_.AppName = "Acrobat Reader DC - $($_.Version)"
        $_.CustomFolderReplacement = "Acrobat Reader DC\$($_.Version)"
        $_.CustomNameReplacement = "Acrobat Reader DC - $($_.Version)"
    }
    elseif ($_.FileName -match "7[-]Zip") {
        # Installer Version != FF Version
        $null = $_.FileName -match "(([.\d]+)+[._^\s])"
        $Version = $Matches[2] # 19.00, not 19.00.00.0
        
        $_.CustomFolderReplacement = "7-Zip\$Version\$($_.AppArch)"
        $_.CustomNameReplacement = "7-Zip - $Version"
    }
    elseif ($_.FileName -match "Firefox") {
        # Installer Version != FF Version
        $null = $_.FileName -match "(([.\d]+)+[._^\s])"
        $Version = $Matches[2]
        $_.Version = $Version

        if ($_.FileName -match "ESR") {
            #$_.AppName = "Firefox ESR"
            $_.CustomFolderReplacement = "Firefox ESR\$Version\$($_.AppArch)"
            $_.CustomNameReplacement = "Firefox ESR - $Version"
        }
    }
    elseif ($_.FileName -match "Silverlight") {
        # Name is Microsoft Operating System ... DUH
        $_.CustomFolderReplacement = "Silverlight"
        $_.CustomNameReplacement = "Microsoft Silverlight"
    }
    elseif ($_.FileName -match "Redist") {
        if ($_.FileName -match "C[+][+][ ]2005") {
            # Name is Microsoft Operating System ... DUH
            $_.Version = ($_.Version -replace "([(][\w\W]+[)])").Trim() # replace the (xpsp2) stuff
            if ($_.FileName -match "x86") {
                $_.CustomNameReplacement = "Microsoft Visual C++ 2005 Redistributable (x86)"
                $_.CustomFolderReplacement = "Microsoft Visual C++ 2005 Redistributable (x86)\$($_.Version)\$($_.AppArch)"
            }
            else {
                $_.CustomNameReplacement = "Microsoft Visual C++ 2005 Redistributable (x64)"
                $_.CustomFolderReplacement = "Microsoft Visual C++ 2005 Redistributable (x64)\$($_.Version)\$($_.AppArch)"
            }
        }
        elseif ($_.FileName -match "C[+][+][ ]2008") {
            if ($_.FileName -match "x86") {
                $_.CustomNameReplacement = "Microsoft Visual C++ 2008 Redistributable (x86)"
                $_.CustomFolderReplacement = "Microsoft Visual C++ 2008 Redistributable (x86)\$($_.Version)\$($_.AppArch)"
            }
            else {
                $_.CustomNameReplacement = "Microsoft Visual C++ 2008 Redistributable (x64)"
                $_.CustomFolderReplacement = "Microsoft Visual C++ 2008 Redistributable (x64)\$($_.Version)\$($_.AppArch)"
            }
        }
        elseif ($_.FileName -match "C[+][+][ ]2010") {
            if ($_.FileName -match "x86") {
                $_.CustomNameReplacement = "Microsoft Visual C++ 2010 Redistributable (x86)"
                $_.CustomFolderReplacement = "Microsoft Visual C++ 2010 Redistributable (x86)\$($_.Version)\$($_.AppArch)"
            }
            else {
                $_.CustomNameReplacement = "Microsoft Visual C++ 2010 Redistributable (x64)"
                $_.CustomFolderReplacement = "Microsoft Visual C++ 2010 Redistributable (x64)\$($_.Version)\$($_.AppArch)"
            }
        }
        elseif ($_.FileName -match "C[+][+][ ]201") {
            # Remove the Version number from the string. Just needed in Version variable
            $tName = $_.AppName -replace "\s-\s[\d.]+\w\W\d+"
            $_.CustomNameReplacement = "$tName"
            $_.CustomFolderReplacement = "$tName\$($_.Version)\$($_.AppArch)"
        }
    }
    elseif ($_.FileName -match "Java") {
        if ($_.FileName -match "x86") {
            $_.CustomFolderReplacement = "Java\$($_.Version)\$($_.AppArch)"
        }
        else {
            $_.CustomFolderReplacement = "Java\$($_.Version)\$($_.AppArch)"
        }
    }
    elseif ($_.FileName -like "*Classic Shell*") {
        if ($_.Version -match ",") {
            $_.Version = ($_.Version -split ",").Trim() -join "."
        }
    }
}

# FullName not in visible
#$AllApps | Select-Object * -ExcludeProperty FullName | Sort-Object AppName | Format-Table
#$AllApps | Sort-Object AppName | ConvertTo-Json | Out-File $ApplicationSaveFolder\Apps.json

$AppBaseFolder = "$ApplicationSaveFolder\apps"
if (!(Test-Path -Path $AppBaseFolder)) {
    $null = New-Item -Path $AppBaseFolder -ItemType Directory -Force
}

$AllApps | ForEach-Object {
    $Folder = "$($_.AppName)\$($_.Version)"
    if ($_.FileName -match "x86") {
        $Folder += "\x86"
    }
    elseif ($_.FileName -match "x64") {
        $Folder += "\x64"
    }

    if ($_.CustomFolderReplacement) {
        $Folder = "$($_.CustomFolderReplacement)"
    }
    elseif ($_.CustomNameReplacement) {
        $Folder = "$($_.CustomNameReplacement)\$($_.Version)"
    }

    $CompleteFolder = "$AppBaseFolder\$Folder\"

    if (!(Test-Path -Path $CompleteFolder)) {
        $null = New-Item -Path $CompleteFolder -ItemType Directory -Force
    }

    try {
        #Copy-Item -Path $_.FullName -Destination "$CompleteFolder\$($_.FileName)" -Force -Verbose -ErrorAction SI
        #Remove-Item -Path $_.Fullname -Force -Verbose -WhatIf
    }
    catch {
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

$AllApps | Select-Object * -ExcludeProperty FullName | Sort-Object AppName | Format-Table
$AllApps | Sort-Object AppName | ConvertTo-Json | Out-File $ApplicationSaveFolder\Apps.json