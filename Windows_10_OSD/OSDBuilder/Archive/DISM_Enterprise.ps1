mkdir C:\wimFile
$WIMFilePath = "C:\OSDBuilder\OSBuilds\MultiLangBuild-1507-Professional 10240.16384\OS\sources\install_ent.wim"
$WIMFilePath = "C:\OSDBuilder\OSBuilds\install_10240_ent.wim"
Dism /Mount-Image /ImageFile:$WIMFilePath /MountDir:C:\wimfile /Index:1
Dism /Image:C:\wimfile /Get-CurrentEdition
Dism /Image:C:\wimfile /Get-TargetEditions
Dism /Image:C:\wimfile /Set-Edition:Enterprise /ProductKey:NPPR9-FWDCX-D2C8J-H872K-2YT43 /AcceptEula
Dism /Image:C:\wimfile /Set-Edition:Enterprise
Dism /Unmount-Image /MountDir:C:\wimfile /Commit
# Dism /Get-WimInfo /WimFile:$WIMFilePath /index:1
# IMAGEX [FLAGS] /INFO img_file [img_number | img_name] [new_name] [new_desc]
# "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\DISM\imagex.exe" /info C:\OSDBuilder\OSBuilds\install_10240_ent.wim "Windows 10 Pro" "Windows 10 Enterprise" "Windows 10 Enterprise"
# Dism /Export-Image /SourceImageFile:OldFile.wim /SourceIndex:1 /DestinationImageFile:NewFile.wim /DestinationName:"Windows 7 Enterprise x86" 

# Recreate ISO File
$OSFolder = "C:\OSDBuilder\OSImport\Windows 10 Enterprise x64\OS"
$OCDProcess = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\AMD64\Oscdimg\oscdimg.exe"
$bootdata = '2#p0,e,b"{0}\boot\etfsboot.com"#pEF,e,b"{0}\efi\microsoft\boot\efisys.bin"' -f $OSFolder
$Arguments = @(
    "-m", "-o", "-u2", "-bootdata:$bootdata", "-u2", "-udfver102", "-l""Win10 $Build $Architecture""",
    "`"$OSFolder`"", "`"C:\Windows_10_Enterprise.iso`""
)
$Process = Start-Process -FilePath $OCDProcess -ArgumentList $Arguments -Wait -PassThru
$Process.ExitCode