$WimFileMountFolder = "$env:SystemDrive\wimFile"

$WindowsSource = Get-ChildItem -Path "$GetOSDBuilderHome\OSBuilds" | Where-Object { $_.Name -like "*MultiLangBuild*" } | Sort-Object -Property CreationTime -Descending | Select-Object -First 1 -ExpandProperty FullName
if (!$WindowsSource) {
    "Missing Source"
    return
}

# TODO: Hidden?
if (!(Test-Path -Path "$WimFileMountFolder" -ErrorAction SilentlyContinue)) {
    $null = New-Item -Path "$WimFileMountFolder" -ItemType Directory
}

$WindowsSourceOS = "$WindowsSource\OS"
if (!(Test-Path -Path "$WindowsSourceOS" -ErrorAction SilentlyContinue)) {
    "OS Path missing"
    return
}

$WindowsSourceWIM = "$WindowsSource\OS\sources\install.wim"
if (!(Test-Path -Path "$WindowsSourceWIM" -ErrorAction SilentlyContinue)) {
    "WIM missing"
    return
}
# backup if missing ...
if (!(Test-Path -Path "$WindowsSourceWIM.bck" -ErrorAction SilentlyContinue)) {
    Copy-Item -Path "$WindowsSourceWIM" -Destination "$WindowsSourceWIM.bck"
}

# TODO: Test if WIM has Enterprise!?

<##>
# mount to c:\wimfile
Write-Verbose "Mounting image '$WindowsSourceWIM' to '$WimFileMountFolder' ..." -Verbose
Dism /English /Mount-Image /ImageFile:$WindowsSourceWIM /MountDir:$WimFileMountFolder /Index:1

Write-Verbose "Edition Output ..." -Verbose
Dism /English /Image:$WimFileMountFolder /Get-CurrentEdition
Dism /English /Image:$WimFileMountFolder /Get-TargetEditions

Write-Verbose "Change Edition ..." -Verbose
#Dism /English /Image:$WimFileMountFolder /Set-Edition:Enterprise
Dism /English /Image:$WimFileMountFolder /Set-Edition:Enterprise /ProductKey:NPPR9-FWDCX-D2C8J-H872K-2YT43 /AcceptEula

Write-Host "Removing OneDrive Setup"
@(
    "$WimFileMountFolder\Windows\System32\OneDriveSetup.exe"
    "$WimFileMountFolder\Windows\SysWOW64\OneDriveSetup.exe"
) | ForEach-Object {
    # I might want to rename another setup, who knows.
    $OneDriveSetupPath = $_
    $OneDriveSetupName = [System.IO.Path]::GetFileNameWithoutExtension($OneDriveSetupPath)

    if (Test-Path -Path $OneDriveSetupPath -ErrorAction SilentlyContinue) {
        try {
            # Access Denied-Error not thrown to catch. Stop SHOULD work...
            $null = Rename-Item -Path $OneDriveSetupPath -NewName "$OneDriveSetupName.bck" -Force -Verbose:$VerbosePreference -ErrorAction Stop
        }
        catch {
            #Write-Host "Force rename here, as i could not find out the problem." -BackgroundColor DarkRed -ForegroundColor White
            Write-Host "=====================================" -BackgroundColor DarkRed -ForegroundColor White
            Write-Host "Force rename of one drive setup file." -BackgroundColor DarkRed -ForegroundColor White
            Write-Host "=====================================" -BackgroundColor DarkRed -ForegroundColor White
								
            $Acl = Get-ACL $OneDriveSetupPath
								
            # "Administrators" is language specific, BUT
            # S-1-5-32-544 should ALWAYS be the same over all languages!
            $Group = New-Object System.Security.Principal.NTAccount((Get-LocalGroup -SID S-1-5-32-544).Name) # ("Vordefiniert", "Administratoren")
            $User = New-Object System.Security.Principal.NTAccount($env:USERNAME)
								
            # Set admin group as owner and grant group and user full access role
            $ACL.SetOwner($Group) # Admin group or actual user?
            $Acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($User, "FullControl", "Allow")))
            $Acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($Group, "FullControl", "Allow")))

            Set-Acl $OneDriveSetupPath $Acl

            # This WILL HAVE TO work!
            $null = Rename-Item -Path $OneDriveSetupPath -NewName "OneDriveSetup.bck" -Force
        }
    }
}

Write-Verbose "Save WIM ..." -Verbose
Dism /English /Unmount-Image /MountDir:$WimFileMountFolder /Commit
# Dism /Get-WimInfo /WimFile:$WIMFilePath /index:1
# >

Write-Verbose "Rename Index" -Verbose
# IMAGEX [FLAGS] /INFO img_file [img_number | img_name] [new_name] [new_desc]
$ImageX = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\DISM\imagex.exe"
"`"$ImageX`" /info `"$WindowsSourceWIM`" `"Windows 10 Pro`" `"Windows 10 Enterprise`" `"Windows 10 Enterprise`" (IMAGEX [FLAGS] /INFO img_file [img_number | img_name] [new_name] [new_desc])"
Start-Process -FilePath "`"$ImageX`"" -ArgumentList "/info `"$WindowsSourceWIM`" `"Windows 10 Pro`" `"Windows 10 Enterprise`" `"Windows 10 Enterprise`"" -Wait -NoNewWindow -Verbose
# "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\DISM\imagex.exe" /info C:\OSDBuilder\OSBuilds\install_10240_ent.wim "Windows 10 Pro" "Windows 10 Enterprise" "Windows 10 Enterprise"

# backup if missing ...
if ((Test-Path -Path "$WindowsSourceWIM.bck" -ErrorAction SilentlyContinue) -and (Test-Path -Path "$WindowsSourceWIM" -ErrorAction SilentlyContinue)) {
    Remove-Item -Path "$WindowsSourceWIM.bck" -Force
}
#>

# Copying AutoUnattend.xml...
# /MIR = /E (sub directories) und /PURGE (remove from target)
$ImageInsertPath = "$PSScriptRoot\00._Additional\01._ImageImport"
Robocopy $ImageInsertPath $WindowsSourceOS /COPYALL /E /R:5 /W:10 /LOG:"$env:TEMP\robocopy_$(Get-Date -Format "yyMMdd-HHmmss.fffffff").log" /TEE

# not elegant, but works ...
$CopyProfile = 1
if ($CopyProfile -eq 1) {
    $ImageInsertPath = "$PSScriptRoot\00._Additional\01._ImageImport_Business"
    Robocopy $ImageInsertPath $WindowsSourceOS /COPYALL /E /R:5 /W:10 /LOG:"$env:TEMP\robocopy_$(Get-Date -Format "yyMMdd-HHmmss.fffffff").log" /TEE
}
elseif ($CopyProfile -eq 2) {
    $ImageInsertPath = "$PSScriptRoot\00._Additional\01._ImageImport_Private"
    Robocopy $ImageInsertPath $WindowsSourceOS /COPYALL /E /R:5 /W:10 /LOG:"$env:TEMP\robocopy_$(Get-Date -Format "yyMMdd-HHmmss.fffffff").log" /TEE
}
else {
    Write-Verbose "Ignoring ImageProfile '$CopyProfile' ..."
}

Write-Verbose "Finished ..." -Verbose

# remove wim backup?