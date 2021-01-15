<#
 # Just wanted to create an AiO iso myself.
 # https://www.deskmodder.de/blog/2019/03/22/1903-18362-iso-esd-deutsch-english/
 # Reduce WIM: https://www.winreducer.net/winreducer-ex-100.html
 # DISM++:     http://www.chuyu.me/de/index.html
 # NTLite??
 # Renamed $Count variables!
 #
 # Might improve:
 # - Invoke-Parallel (@Remove-AppX?)
#>

#Requires -RunAsAdministrator
#Requires -Version 3.0

[CmdLetBinding()]
param(
	[switch]$SkipUUPDownloader,
	[switch]$SkipUpdateFolder,
	[switch]$SkipImageCleanUp,
	[switch]$SkipAppXRemoval,
	[switch]$SkipFeatures,
	[switch]$SkipFOD,
	[switch]$SkipRegTweaks,
	[switch]$SkipEditionSelect, # Skip one mount and dismount (just removing n versions)
	[switch]$OnlyEnterprise,
	[switch]$DoNotRemoveN,
	# JUST KEEP INDEX 1 !? => Just for fast Testig ($OnlyEnterprise => $SkipEditionSelect => $DoNotRemoveN)
	[switch]$DoNotCreateISO,
	[string]$OverrideMountPath = "C:\ISOMount"
)

if (!$PSScriptRoot) {
	Write-Host "no root!"
	return
}

Start-Transcript -Path "$PSScriptRoot\Logs\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_$($MyInvocation.MyCommand.Name).log"

$StartTime = Get-Date
Write-Host "Started at $(Get-Date -Format "dd.MM.yy HH:mm:ss")"

# Lazy LKR
$DEF_MAX_ITERATIONS = 30

<#
 # Clearing Image from $MountPath
#>
function Clear-MountPath {
	param(
		[string]$MountPath,
		[switch]$OverrideWarning,
		[switch]$ClearAllMountedFolders
	)

	if (Test-Path -Path $MountPath) {
		Write-Host "Path `"$MountPath`" exists. Looking for mounted info:" -ForegroundColor Cyan

		try {
			if ($ClearAllMountedFolders) {
				$MountedImages = Get-WindowsImage -Mounted
			}
			else {
				# There CAN only be one.
				$MountedImages = Get-WindowsImage -Mounted | Where-Object { (Join-Path $_.Path '') -eq (Join-Path $MountPath '') }
			}

			<#
			 # Path        : C:\ISOMount
			 # ImagePath   : C:\tmp\w10_custom_image\w10\IDonkIDonk.wim
			 # ImageIndex  : 1
			 # MountMode   : ReadWrite
			 # MountStatus : Ok
			#>
			$MountedImages | Out-Host

			$MountedImages | ForEach-Object {
				Write-Host "-Removing: [$($_.Path) | $($_.ImagePath):$($_.ImageIndex))] with -Discard!" -ForegroundColor Yellow

				# First save and then discard if unsuccessfully
				#$null = Dismount-WindowsImage -Path $_.Path -Save -Append -CheckIntegrity -Verbose
				$null = Dismount-WindowsImage -Path $_.Path -Discard -Verbose # Just in case we cannot save.
			}

			Write-Host "$MountPath should be unmounted now" -ForegroundColor DarkGray
		}
		catch {
			Write-Host "Error removing mounted folder: $($_.Exception.Message)" -ForegroundColor Red
		}
		
		if (!$OverrideWarning) {
			Write-Host "If you haven't saved your work: You got 15 seconds to abort this script!" -BackgroundColor DarkRed -ForegroundColor White
			Start-Sleep -Seconds 15
		}

		# re-set permission to remove folder!
		# (if apps "crash" mount stays in permission for "TrustedInstaller")
		$Acl = Get-ACL $MountPath
		$AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule("Jeder", "FullControl", "ContainerInherit,Objectinherit", "none", "Allow")
		$Acl.AddAccessRule($AccessRule)
		Set-Acl $MountPath $Acl

		Remove-Item -Path $MountPath -Recurse -Force
	}
}

function UnmountRegistry {
	param(
		[string]$OfflineRegistry = "Registry::HKEY_LOCAL_MACHINE\OFFLINE"
	)

	#$OfflineRegistry = $OfflineRegistry -replace "Registry::" -replace "HKEY_LOCAL_MACHINE","HKLM"

	if (Test-Path -Path $OfflineRegistry) {
		$Acl = Get-ACL $OfflineRegistry
		$AccessRule = New-Object System.Security.AccessControl.RegistryAccessRule("Jeder", "FullControl", "ContainerInherit,Objectinherit", "none", "Allow")
		$Acl.AddAccessRule($AccessRule)
		Set-Acl $OfflineRegistry $Acl

		Write-Host "Unload Registry via function" -ForegroundColor Cyan
		$tCloseReg = Get-ChildItem -Path $OfflineRegistry
		$tCloseReg.Handle.Close()
		$tCloseReg.Close()

		# sometimes the registry gets saved
		# as a reference in the variables
		# so we re-create this reference.
		((Get-ChildItem variable:).Name | Select-Object -First 5) -join ";"
		((Get-ChildItem env:).Name | Select-Object -First 5) -join ";"
		((Get-ChildItem variable:).Name | Select-Object -First 5) -join ";"

		[gc]::Collect()

		#Start-Sleep -Seconds 5

		$OfflineRegistry = $OfflineRegistry -replace "Registry::" -replace "HKEY_LOCAL_MACHINE", "HKLM"
		$null = reg unload $OfflineRegistry # Result is language specific!
		Write-Host "L.E.C.: $LASTEXITCODE" -ForegroundColor Magenta
		
		# Result of reg unload is language specific!
		while ($LASTEXITCODE -ne 0) {
			Write-Host "$LASTEXITCODE " -ForegroundColor Yellow -NoNewline
			Start-Sleep -Seconds 1
			$null = reg unload $OfflineRegistry
		}
		Write-Host ""
	}
 else {
		Write-Verbose "No registry to unload"
	}
}

$MountPath = $OverrideMountPath
UnmountRegistry -OfflineRegistry "Registry::HKEY_LOCAL_MACHINE\OFFLINE"
Clear-MountPath -MountPath $MountPath

$UUPDownloader = Get-Item -Path "$PSScriptRoot\UUP\uupdownloader*.exe"
$UUPWimLib = Get-Item -Path "$PSScriptRoot\UUP\bin\wimlib-imagex.exe" # Rename Image

if (!(Test-Path -Path $UUPDownloader -ErrorAction SilentlyContinue)) {
	Write-Host "UUPDownloader not found. Maybe we should download it first."
	return

	# INPUT DOWNLOADER HERE
}
else {
	# Maybe we only want to create the WIM from the already downloaded ISO?
	if (!$SkipUUPDownloader) {
		Write-Host "Starting UUP Downloader. Select your Image, i will wait for the process to finish."
		$Process = Start-Process -FilePath $UUPDownloader -ArgumentList "/help" -Wait -PassThru -Verbose
		$Process.ExitCode

		# JIC
		while (Get-Process AutoHotkey* -ErrorAction SilentlyContinue) {
			Write-Host "We still have AHK running. Please wait..."
			Start-Sleep -Seconds 1
		}
	}

	#Read-Host -Prompt "Is the ISO located Inside subfolders? [y]"
	#$ISOFiles = Get-ChildItem -Recurse -Path $PSScriptRoot -Filter "*.iso"

	# better to process, only direct. Every other ISO getting ignored.
	$ISOFiles = Get-ChildItem -Path "$PSScriptRoot\ISOs\" -Filter "*.iso"
	
	# remove mounted ISOs, in case script was aborted
	$Count_Dismount = 0
	while ($Vol = Get-Volume | Where-Object { ($_.DriveType -eq "CD-ROM") -and ($_.Size -ne 0) }) {
		$Count_Dismount++
		$Vol | ForEach-Object {
			$ISOFiles | ForEach-Object {
				try {
					$null = Dismount-DiskImage -ImagePath $_.FullName
				}
				catch {
					Write-Host "Error with dismount: $($_.Exception.Message)" -ForegroundColor Red
				}
			}
		}

		# Preventing infinite loop
		if ($Count_Dismount -ge $DEF_MAX_ITERATIONS) {
			break
		}
	}

	# in case i do not want to put this in a giant or multiple small try phrase
	#$ErrorActionPreference = "Stop"

	if ($ISOFiles) {
		$ISOFiles | ForEach-Object {
			Write-Host "ISO '$($_.FullName)' found. Mounting it." -ForegroundColor DarkGray
			$IMAGE_Mount = Mount-DiskImage -ImagePath $_.FullName -PassThru -StorageType ISO -Access ReadOnly
			$IMAGE_DriveInformation = $IMAGE_Mount | Get-DiskImage | Get-Volume
			$IMAGE_DriveLetter = $IMAGE_DriveInformation.DriveLetter
			Write-Host "ISO '$($_.FullName)' mounted as $($IMAGE_DriveLetter):" -ForegroundColor DarkGray

			# Cannot proceed if not mounted as drive.
			# Maybe i should check for DrivePath instead of letter!?
			if (!$IMAGE_DriveLetter) {
				Write-Host "No drive letter." -ForegroundColor Red
				$null = Dismount-DiskImage -ImagePath $_.FullName -Verbose
				return
			}

			# Could be WIM or ESD, shouldn't matter for this!
			$InstallImage = Get-Item -Path "$IMAGE_DriveLetter`:\sources\install.*" -ErrorAction Stop
			#$InstallImage_BaseName = [System.IO.Path]::GetFileNameWithoutExtension($InstallImage)
			$InstallImage_Extension = [System.IO.Path]::GetExtension($InstallImage)
			
			# Copy locally, cannot edit on disk (and if ISReadOnly is set)
			$CopiedImageFileName = "IDonkIDonk$InstallImage_Extension"
			$CopiedImageFullName = "$PSScriptRoot\temp\$CopiedImageFileName"
			#$InstallImage_localCopy_FileName = "bahama_beige$InstallImage_Extension"
			Copy-Item -Path $InstallImage -Destination $CopiedImageFullName -Force -PassThru | Set-ItemProperty -Name ISReadOnly -Value $false
			
			# removing all that are not enterprise, can only do that at bottom.
			# maybe we want to keep n afterall (only for testing?)
			if (!$OnlyEnterprise -and !$DoNotRemoveN) {
				# Selection String "^Name:" for german "Name :" for /English version.
				#Name : Windows 10 Enterprise  # English (via /English)
				#Name: "Windows 10 Enterprise" # German

				##| Select-String "^Name:.*?(Enterprise).*?$" -Context 1,0 | ForEach-Object {}
				Write-Host "Removing n-versions. I don't need those. Who does?" -ForegroundColor Cyan
				Dism /English /Get-ImageInfo /ImageFile:$CopiedImageFullName | Select-String "^Name :.*?( N).*?$" -Context 1, 0 | ForEach-Object {
					$ReplaceThisIndexName = $_.Line -replace "Name: " -replace "Name : " -replace "`""

					Write-Host "Removing: $ReplaceThisIndexName" -ForegroundColor Yellow
					$null = Remove-WindowsImage -ImagePath $CopiedImageFullName -Name "$ReplaceThisIndexName" -CheckIntegrity
				}
			}
			
			Write-Host "Retrieve info of WIM file..." -ForegroundColor Cyan
			Dism /English /Get-ImageInfo /ImageFile:$CopiedImageFullName

			try {
				$tDISMInfo = (DISM /English /Get-WimInfo /WimFile:$CopiedImageFullName /Index:1)
				#$Version = [System.Version](($tDISMInfo | Select-String -Pattern "Version" | Select-Object -Property Line | Sort-Object -Descending -Property Line | Select-Object -First 1).Line -replace "Version: ")
				$Version = [System.Version](($tDISMInfo | Select-String -Pattern "Version") -replace "Version|: | : " | Sort-Object -Descending | Select-Object -First 1)
				$WIMArchitecture = (($tDISMInfo | Select-String -Pattern "Architecture" | Select-Object -Property Line | Sort-Object -Descending -Property Line | Select-Object -First 1).Line -replace "Architecture : ")
			}
			catch {
				$Version = [System.Version]"0.0.0.0"
				$WIMArchitecture = $null
			}

			# Where do we start?
			##| Select-String "^Name:.*?( N).*?$" -Context 1,0 | ForEach-Object {}
			$ImageCount = (Dism /English /Get-ImageInfo /ImageFile:$CopiedImageFullName | Select-String "Index").Count

			# Create ISOMount folder
			#$MountPath = "C:\ISOMount"
			if (!(Test-Path -Path $MountPath)) {
				$null = New-Item -Path $MountPath -ItemType Directory -Force
			}
			else {
				Clear-MountPath -MountPath $MountPath
			}
			
			if (!$SkipEditionSelect) {
				Write-Host "Mounting..." -ForegroundColor Cyan
				Write-Host "'$CopiedImageFullName'" -ForegroundColor Yellow
				#Write-Host "Mount-WindowsImage -Path $MountPath -ImagePath `"$PSScriptRoot\$InstallImage_localCopy_FileName`" -Index 1 -Verbose"
				$null = Mount-WindowsImage -Path $MountPath -ImagePath $CopiedImageFullName -Index 1
			
				# All Windows 10 Version Hashes
				$EditionHash = @{
					"Core"                        = @{
						Name    = "Windows 10 Home"
						Enabled = $True
					}
					"CoreN"                       = @{
						Name    = "Windows 10 Home N"
						Enabled = $True
					}
					"CoreSingleLanguage"          = @{
						Name    = "Windows 10 Home Single Language"
						Enabled = $True
					}
					"Professional"                = @{
						Name    = "Windows 10 Pro"
						Enabled = $True
					}
					"ProfessionalN"               = @{
						Name    = "Windows 10 Pro N"
						Enabled = $True
					}
					"ProfessionalEducation"       = @{
						Name    = "Windows 10 Pro Education"
						Enabled = $True
					}
					"ProfessionalEducationN"      = @{
						Name    = "Windows 10 Pro Education N"
						Enabled = $True
					}
					"ProfessionalWorkstation"     = @{
						Name    = "Windows 10 Pro for Workstations"
						Enabled = $True
					}
					"ProfessionalWorkstationN"    = @{
						Name    = "Windows 10 Pro N for Workstations"
						Enabled = $True
					}
					"Education"                   = @{
						Name    = "Windows 10 Education"
						Enabled = $True
					}
					"EducationN"                  = @{
						Name    = "Windows 10 Education N"
						Enabled = $True
					}
					"ProfessionalCountrySpecific" = @{
						Name    = "Windows 10 Pro for China" # China Only (as far as i know)
						Enabled = $False
					}
					"ProfessionalSingleLanguage"  = @{
						Name    = "Windows 10 Pro Single Language"
						Enabled = $True
					}
					"ServerRdsh"                  = @{
						Name    = "Windows 10 Enterprise for Remote Sessions" # "Windows 10 Enterprise for Virtual Desktops"
						Enabled = $True
					}
					"IoTEnterprise"               = @{
						Name    = "Windows 10 IoT Enterprise"
						Enabled = $True
					}
					"Enterprise"                  = @{
						Name    = "Windows 10 Enterprise"
						Enabled = $True
					}
					"EnterpriseN"                 = @{
						Name    = "Windows 10 Enterprise N"
						Enabled = $True
					}
				}

				# List all available editions
				$Editions = (Get-WindowsEdition -Path $MountPath -Target | Select-Object Edition).Edition
				for ($i = 0; $i -lt $Editions.Count; $i++) {
					if ($EditionHash[$Editions[$i]].Enabled) {
						Write-Host "$("$($i+1)".PadLeft(3," ")) - $($EditionHash[$Editions[$i]].Name) ($($EditionHash[$Editions[$i]].Enabled))"
					}
					else {
						# i don't want to add China for now.
						# TODO: Is there something specific i have to set? (LanguagePack needed, etc.)
						Write-Host "$("$($i+1)".PadLeft(3," ")) - $($EditionHash[$Editions[$i]].Name) ($($EditionHash[$Editions[$i]].Enabled))" -ForegroundColor Red
					}
					#Write-Host "$($i+1) - $($Editions[$i])"

					# Auto-select Enterprise!
					if ($OnlyEnterprise) {
						if ($Editions[$i] -eq "Enterprise") {
							$Selection = "$($i+1)"
							break
						}
					}
				}
				Write-Host "" # break after selection

				if (!$OnlyEnterprise) {
					# ask user (or just me) to insert numbers!
					$Selection = Read-Host -Prompt "Please enter the numbers, separated by comma, of the OSVersions you want to have in your WindowsImage (WIM)"
				}
			
				#region EditionHandling
				# Mounting image, so we can add another OS-Edition
				# Could add updates (and more) here, but there wouldn't be any updates in the original images then.
				# Skip this if user has not inputted any character
				if (![String]::IsNullOrEmpty($Selection)) {
					$Selection.Split(",") | ForEach-Object {
						$Edition = $_

						# Integer test. Fails if $_ is not int
						try {
							$null = [int]$Edition
						}
						catch {
							Write-Host "$Edition not int. SKIP."
							break
						}

						# Every Image/Index needs to be added separatley... BURGH...
						$ImageCount++
						try {
							Write-Host "==============================="
							Write-Host "Processing Data #$ImageCount"
							Write-Host "==============================="

							Write-Host "Mounting Image"
							try {
								# Image already mounted
								if (!($MountedImages = Get-WindowsImage -Mounted | Where-Object { (Join-Path $_.Path '') -eq (Join-Path $MountPath '') } )) {
									# Replace index number if we want to insert (N)o-Media-Version!
									$null = Mount-WindowsImage -Path $MountPath -ImagePath $CopiedImageFullName -Index 1 -Verbose
								}
								else {
									Write-Host "Image already mounted: $($MountedImages.ImagePath)" -ForegroundColor DarkGray
								}

								Remove-Variable -Name "MountedImages"
							}
							catch {
								Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
							}

							Write-Host "Adding `"$($EditionHash[$Editions[$Edition-1]].Name)`""
							$null = Set-WindowsEdition -Path $MountPath -Edition $Editions[$Edition - 1]

							# This is just for the testing.
							#Read-Host -Prompt "Hm. Wait?"

							Write-Host "Dismounting Image (-Save -Append)"
							$null = Dismount-WindowsImage -Path $MountPath -Save -Append # Append for NEW image-index

							# We can ONLY rename if it has been dismounted and saved.
							# _path_\wimlib-imagex.exe info _path_\install.wim 3 "Windows 10 Education" "Windows 10 Education"
							Write-Verbose "$UUPWimLib info $CopiedImageFullName $ImageCount $($EditionHash[$Editions[$Edition-1]].Name) $($EditionHash[$Editions[$Edition-1]].Name)" -Verbose

							Write-Host "Renaming Index to `"Windows 10 $($Editions[$_-1])`""
							Start-Process -FilePath "$UUPWimLib" -ArgumentList "info `"$CopiedImageFullName`" $ImageCount `"$($EditionHash[$Editions[$Edition-1]].Name)`" `"$($EditionHash[$Editions[$Edition-1]].Name)`"" -Wait -PassThru -NoNewWindow | Format-Table -AutoSize -Wrap
						}
						catch {
							Write-Host "Error while processing edition #$($Edition): $($_.Exception.Message)" -ForegroundColor Red

							# this will prevent other errors from happening.
							# e.g.: If edition #4 does not exist, how could we change edition #5
							return
						}
					}
				}
				else {
					Write-Host "Nothing selected. Nothing Added."

					# just unmounting if nothing changed
					$null = Dismount-WindowsImage -Path $MountPath -Discard
				}
				#endregion EditionHandling
			}
			
			# Read-Host -Prompt "Last W8 before dismount and get diskimageinfo."

			# Removal of mounted image(s) in $MountPath
			# Doing Join-Path because of possible slash not being recognized
			try {
				# Mounted images in MountPath
				& {
					$MountedImages = Get-WindowsImage -Mounted | Where-Object { (Join-Path $_.Path '') -eq (Join-Path $MountPath '') }
					if ($MountedImages) {
						$null = Dismount-WindowsImage -Path $MountPath -Discard -Verbose
					}
				}

				#Dismount-WindowsImage -Path $MountPath -Save # Append for NEW image-index
			}
			catch {
				# No Error, just a warning, that dismount could not be completed.
				#Write-Warning -Message "Error on Dismount-*: $($_.Exception.Message)"
				Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
			}

			# removing all that are not enterprise, can only do that at bottom.
			if ($OnlyEnterprise) {
				##| Select-String "^Name:.*?(Enterprise).*?$" -Context 1,0 | ForEach-Object {}
				Write-Host "Removing non Enterprise versions from '$CopiedImageFullName'" -ForegroundColor Cyan

				# Loop through all indexes
				Dism /English /Get-ImageInfo /ImageFile:$CopiedImageFullName | Select-String "^Name :.*?(Windows).*?$" -Context 1, 0 | ForEach-Object {
					# Keep Enterprise
					if ($_.Line -notmatch "Enterprise") {
						$ReplaceThisIndexName = $_.Line -replace "Name: " -replace "Name : " -replace "`""

						Write-Host "Removing: $ReplaceThisIndexName" -ForegroundColor Yellow
						$null = Remove-WindowsImage -ImagePath $CopiedImageFullName -Name "$ReplaceThisIndexName" -CheckIntegrity
					}
				}
			}

			Dism /English /Get-ImageInfo /ImageFile:$CopiedImageFullName

			# Adding Windows Updates from Folder if we have some.
			# This is just in general, as we cannot get the complete Version via DISM
			# Just include the updates needed.
			$WindowsUpdateFolder = "$PSScriptRoot\Updates\$($Version.Build)*"
			$WindowsUpdateFiles = Get-ChildItem -Path $WindowsUpdateFolder -Recurse -Filter "*$WIMArchitecture*.msu" | Where-Object { !$_.PSIsContainer }

			Write-Verbose "gci $WindowsUpdateFolder -f `"*$WIMArchitecture*.msu`": $($WindowsUpdateFiles.Count) found." -Verbose
			
			# if cleanup not skipped or update files present
			if (!$SkipImageCleanUp -or ($WindowsUpdateFiles -and !$SkipUpdateFolder)) {
				Write-Host "Checking for updates to implement and cleanup afterwards" -ForegroundColor Cyan
				# Loop through all indexes
				$Count_ImageIndex = 0
				$Indizies = Dism /English /Get-ImageInfo /ImageFile:$CopiedImageFullName | Select-String "^Name :.*?(Windows).*?$" -Context 1, 0
				$Indizies | ForEach-Object {
					$Count_ImageIndex++
					Write-Host "==============================="
					Write-Host "Processing Image #$Count_ImageIndex/$($Indizies.Count)"
					Write-Host "==============================="

					Write-Host "Mounting Image"
					try {
						# Replace index number if we want to insert (N)o-Media-Version!
						$null = Mount-WindowsImage -Path $MountPath -ImagePath $CopiedImageFullName -Index $Count_ImageIndex -Verbose
					}
					catch {
						Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
					}
					
					#region WindowsUpdates
					# Apply updates only if version present und updates in folder
					# Oh and only if we did not "disable" the update folder!
					if ($Version -and ($Version -ne [System.Version]"0.0.0.0") -and $WindowsUpdateFiles -and !$SkipUpdateFolder) {
						# Looping through update files and adding them to the image
						Write-Host "Implementing Updates for $Version (!UUP)" -ForegroundColor Cyan
						$WindowsUpdateFiles | ForEach-Object {
							Write-Host "+Processing Update: $($_.Name)" -ForegroundColor Yellow

							try {
								Write-Verbose "Splitting *.msu-Name ($($_.Name))"
								$KBNum = ($_.Name).Split("-")[1] -replace "([^\d]*)"
							}
							catch {
								Write-Host "Could'n split name from msu. Using `"derp`" instead. ($_.Exception.Message)" -ForegroundColor Red
								$KBNum = "derp"
							}

							# Creating KB folder
							# NO TRAILING SLASH FOR EXPAND!
							$KBExtractFolder = "$PSScriptRoot\temp\$KBNum"
						
							# Pre-Remove
							if (Test-Path -Path $KBExtractFolder) {
								Remove-Item -Path $KBExtractFolder -Recurse -Force
							}
							if (!(Test-Path -Path $KBExtractFolder)) {
								$null = New-Item -Path $KBExtractFolder -ItemType Directory
							}

							# Expanding MSU, as we need to add the CAB file.
							#Write-Host "& cmd /c expand -F:* `"$($_.FullName)`" `"$KBExtractFolder`"" -ForegroundColor Yellow
							$null = & cmd /c "expand -F:* `"$($_.FullName)`" `"$KBExtractFolder`""

							# Addind the CABs to the mounted image.
							#(Get-WindowsPackage -Path $MountPath).PackageName
							Get-ChildItem -Path "$KBExtractFolder" -Filter "*.cab" -Recurse | Where-Object { $_.Name -notmatch "WSUSSCAN.cab" } | ForEach-Object {
								Write-Host "+$($_.Name)" -ForegroundColor Yellow
								try {
									Write-Host "+Package: $((Get-WindowsPackage -Path $MountPath -PackagePath $_.FullName).PackageName)" -ForegroundColor Magenta
									$null = Add-WindowsPackage -Path $MountPath -PackagePath $_.FullName #*.cab file
									#Save-WindowsImage -Path $MountPath
								}
								catch {
									Write-Host "Error adding package: $($_.Exception.Message)" -ForegroundColor Red
								}
							}

							# Remove the mounted folder
							if (Test-Path -Path $KBExtractFolder) {
								$null = Remove-Item -Path $KBExtractFolder -Recurse -Force
							}
							else {
								Write-Host "No folder!?" -ForegroundColor Red
							}
						} # /end update loop
					}
					#endregion WindowsUpdates

					# This is just for the testing.
					#Read-Host -Prompt "Hm. Wait?"
					(Get-WindowsPackage -Path $MountPath).PackageName

					if (!$SkipImageCleanUp) {
						Write-Host "Image cleanup" -ForegroundColor Cyan

						<#
						 # TODO: I HAVE TO TEST WHY THIS IS HAPPENING AT HOME!
						 # I had the problem, that renaming worked at work, but not at home.
						 # Added ACL, maybe i should remove this afterwards.
						 #
						 # Main Difference:
						 # - Inside of Hyper-V, not on machine
						 # - Home OS is Windows 10 (1809) Pro (With Hyper-V-VM on 1903 Enterprise)
						 # - Work OS is Windows 10 (1809) Enterprise
						#>
						
						# Renaming OneDrive Setup exe
						# OneDrive Setup Hook for users is removed in REG\DEFAULT region
						Write-Host "Removing OneDrive Setup" -ForegroundColor Yellow
						@(
							"$MountPath\Windows\System32\OneDriveSetup.exe"
							"$MountPath\Windows\SysWOW64\OneDriveSetup.exe"
						) | ForEach-Object {
							# I might want to rename another setup, who knows.
							$OneDriveSetupPath = $_
							$OneDriveSetupName = [System.IO.Path]::GetFileNameWithoutExtension($OneDriveSetupPath)

							if (Test-Path -Path $OneDriveSetupPath -ErrorAction SilentlyContinue) {
								try {
									# Access Denied-Error not thrown to catch. Stop SHOULD work...
									$null = Rename-Item -Path $OneDriveSetupPath -NewName "$OneDriveSetupName.bck" -Force -Verbose -ErrorAction Stop
								}
								catch {
									Write-Host "=======================================================" -BackgroundColor DarkRed -ForegroundColor White
									Write-Host "Force rename here, as i could not find out the problem." -BackgroundColor DarkRed -ForegroundColor White
									Write-Host "=======================================================" -BackgroundColor DarkRed -ForegroundColor White
								
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
									$null = Rename-Item -Path $OneDriveSetupPath -NewName "onedrivesetup.bck" -Force
								}
							}
						}

						#region RemoveBloatware
						if (!$SkipAppXRemoval) {
							# From: https://github.com/W4RH4WK/Debloat-Windows-10
							Write-Host "+Remove AppX Stuff" -ForegroundColor Yellow
							$apps = @(
								# default Windows 10 apps
								"Microsoft.3DBuilder"
								"Microsoft.Appconnector"
								"Microsoft.BingFinance"
								"Microsoft.BingNews"
								"Microsoft.BingSports"
								"Microsoft.BingTranslator"
								"Microsoft.BingWeather"
								#"Microsoft.FreshPaint"
								"Microsoft.Microsoft3DViewer"
								"Microsoft.MicrosoftOfficeHub"
								"Microsoft.MicrosoftSolitaireCollection"
								"Microsoft.MicrosoftPowerBIForWindows"
								"Microsoft.MinecraftUWP"
								#"Microsoft.MicrosoftStickyNotes"
								"Microsoft.NetworkSpeedTest"
								"Microsoft.Office.OneNote"
								#"Microsoft.OneConnect"
								"Microsoft.People"
								"Microsoft.Print3D"
								"Microsoft.SkypeApp"
								"Microsoft.Wallet"
								#"Microsoft.Windows.Photos"
								"Microsoft.WindowsAlarms"
								#"Microsoft.WindowsCalculator"
								"Microsoft.WindowsCamera"
								"microsoft.windowscommunicationsapps"
								"Microsoft.WindowsMaps"
								"Microsoft.WindowsPhone"
								"Microsoft.WindowsSoundRecorder"
								#"Microsoft.WindowsStore"
								"Microsoft.XboxApp"
								"Microsoft.XboxGameOverlay"
								"Microsoft.XboxGamingOverlay"
								"Microsoft.XboxSpeechToTextOverlay"
								"Microsoft.Xbox.TCUI"
								"Microsoft.ZuneMusic"
								"Microsoft.ZuneVideo"
    
								# Threshold 2 apps
								"Microsoft.CommsPhone"
								"Microsoft.ConnectivityStore"
								"Microsoft.GetHelp"
								"Microsoft.Getstarted"
								"Microsoft.Messaging"
								"Microsoft.Office.Sway"
								"Microsoft.OneConnect"
								"Microsoft.WindowsFeedbackHub"

								# Creators Update apps
								"Microsoft.Microsoft3DViewer"
								#"Microsoft.MSPaint"

								#Redstone apps
								"Microsoft.BingFoodAndDrink"
								"Microsoft.BingTravel"
								"Microsoft.BingHealthAndFitness"
								"Microsoft.WindowsReadingList"

								# Redstone 5 apps
								"Microsoft.MixedReality.Portal"
								"Microsoft.ScreenSketch"
								"Microsoft.XboxGamingOverlay"
								"Microsoft.YourPhone"

								# non-Microsoft
								"9E2F88E3.Twitter"
								"PandoraMediaInc.29680B314EFC2"
								"Flipboard.Flipboard"
								"ShazamEntertainmentLtd.Shazam"
								"king.com.CandyCrushSaga"
								"king.com.CandyCrushSodaSaga"
								"king.com.BubbleWitch3Saga"
								"king.com.*"
								"ClearChannelRadioDigital.iHeartRadio"
								"4DF9E0F8.Netflix"
								"6Wunderkinder.Wunderlist"
								"Drawboard.DrawboardPDF"
								"2FE3CB00.PicsArt-PhotoStudio"
								"D52A8D61.FarmVille2CountryEscape"
								"TuneIn.TuneInRadio"
								"GAMELOFTSA.Asphalt8Airborne"
								#"TheNewYorkTimes.NYTCrossword"
								"DB6EA5DB.CyberLinkMediaSuiteEssentials"
								"Facebook.Facebook"
								"flaregamesGmbH.RoyalRevolt2"
								"Playtika.CaesarsSlotsFreeCasino"
								"A278AB0D.MarchofEmpires"
								"KeeperSecurityInc.Keeper"
								"ThumbmunkeysLtd.PhototasticCollage"
								"XINGAG.XING"
								"89006A2E.AutodeskSketchBook"
								"D5EA27B7.Duolingo-LearnLanguagesforFree"
								"46928bounde.EclipseManager"
								"ActiproSoftwareLLC.562882FEEB491" # next one is for the Code Writer from Actipro Software LLC
								"DolbyLaboratories.DolbyAccess"
								"SpotifyAB.SpotifyMusic"
								"A278AB0D.DisneyMagicKingdoms"
								"WinZipComputing.WinZipUniversal"
								"CAF9E577.Plex"  
								"7EE7776C.LinkedInforWindows"
								"613EBCEA.PolarrPhotoEditorAcademicEdition"
								"Fitbit.FitbitCoach"
								"DolbyLaboratories.DolbyAccess"
								"Microsoft.BingNews"
								"NORDCURRENT.COOKINGFEVER"

								# apps which cannot be removed using Remove-AppxPackage
								#"Microsoft.BioEnrollment"
								#"Microsoft.MicrosoftEdge"
								#"Microsoft.Windows.Cortana"
								#"Microsoft.WindowsFeedback"
								#"Microsoft.XboxGameCallableUI"
								#"Microsoft.XboxIdentityProvider"
								#"Windows.ContactSupport"

								# apps which other apps depend on
								"Microsoft.Advertising.Xaml"
							)

							# Count just for me displaying the removals left
							$Count_AppRemoval = 0
							foreach ($app in $apps) {
								$Count_AppRemoval++
								Write-Host "[$Count_AppRemoval/$($Apps.Count)] Push removal of `"$app`"" -ForegroundColor DarkGray

								try {
									#Get-AppxPackage -Name $app -PackageTypeFilter | Remove-AppxPackage -AllUsers

									# All Users (-AllUsers) does not exist in MountedImages
									$null = Get-AppXProvisionedPackage -Path $MountPath | Where-Object DisplayName -eq $app | Remove-AppxProvisionedPackage
								}
								catch {
									Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
								}
						
								# Manual via GridView!
								#Get-AppxProvisionedPackage -Path $MountPath | Out-GridView -PassThru | Remove-AppxProvisionedPackage
							} # /end of app loop
						} # /end of !$SkipAppXRemoval
						
						#endregion RemoveBloatware

						#region Registry
						if (!$SkipRegTweaks) {
							<# These hives can be loaded:
							 # REG LOAD HKLM\DEFUSER "$MountPath\Users\default\ntuser.dat"
							 # reg load HKLM\OFFLINE "$MountPath\Windows\System32\Config\SOFTWARE"
							 # reg load HKLM\OFFLINE "$MountPath\Windows\System32\Config\DEFAULT"
							 # reg load HKLM\OFFLINE "$MountPath\Windows\System32\Config\DRIVERS"
							 # reg load HKLM\OFFLINE "$MountPath\Windows\System32\Config\SAM"
							 # reg load HKLM\OFFLINE "$MountPath\Windows\System32\Config\SYSTEM"
							#>
							function Set-RegistryValue {
								param($Path, $Name, $Value)

								# create "directory"
								if (!(Test-Path $Path)) { $null = New-Item -ItemType Directory -Force -Path $Path }
	
								# also testing if key exists
								$exists = Get-ItemProperty -Path "$Path" -Name "$Name" -ErrorAction SilentlyContinue
								if (($null -ne $exists) -and ($exists.Length -ne 0)) {
									try {
										$null = Set-ItemProperty $Path $Name $Value -Force -Verbose
									}
									catch {
										Write-Host "Error while Set-Item: $($_.Exception.Message)" -ForegroundColor Red
									}
									#return $true
								}
								else {
									try {
										$null = New-ItemProperty -Path "$Path" -Name "$Name" -Value $Value -Verbose
									}
									catch {
										Write-Host "Error while New-Item: $($_.Exception.Message)" -ForegroundColor Red
									}
									#return $false
								}
							}

							<#
							 # DEFAULT USER HIVES!
							 # Had to use dark mode in here, as AutoUnattended.xaml seems wrong:
								<Themes>
									<WindowColor>Automatic</WindowColor>
									<SystemUsesLightTheme>false</SystemUsesLightTheme>
									<UWPAppsUseLightTheme>false</UWPAppsUseLightTheme>
								</Themes>
							 # TODO: Test @ work!
							#>

							#region NTUSERDAT
							# Maybe export to separate PS1?
							Write-Host "Load offline registry" -ForegroundColor Cyan
							<#
							 # https://www.windowspro.de/wolfgang-sommergut/registry-offline-bearbeiten-regeditexe-powershell
							 # [...] und wechselt auf dem Laufwerk des ausgeschalteten Windows in das Verzeichnis \windows\system32\config.
							 # Die Dateien SOFTWARE, SYSTEM und SAM repräsentieren die Datenbanken für HKLM\Software, HKLM\System und HKLM\Sam.
							 # DEFAULT steht für HKCU\Default und NTUSER.DAT für HKEY_CURRENT_USER.
							#>
							if (Test-Path -Path "$MountPath\Users\default\ntuser.dat") {
								Write-Verbose "`"$MountPath\Users\default\ntuser.dat`" found." -Verbose

								# no return, could catch $LASTEXITCODE
								$null = REG LOAD HKLM\OFDEFUSR "$MountPath\Users\default\ntuser.dat"
							
								if (Test-Path -Path "HKLM:\OFDEFUSR") {
									# QuickEdit
									Set-RegistryValue -Path "HKLM:\OFDEFUSR\Console" -Name "QuickEdit" -Value 1

									# Explorer Tweaks
									Set-RegistryValue -Path "HKLM:\OFDEFUSR\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "LaunchTo" -Value 1          # QuickAccess => ThisPC
									Set-RegistryValue -Path "HKLM:\OFDEFUSR\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Value 1            # Show hidden files and folders
									Set-RegistryValue -Path "HKLM:\OFDEFUSR\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 0       # Show File Extensions
									Set-RegistryValue -Path "HKLM:\OFDEFUSR\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "AutoCheckSelect" -Value 1   # File Checkboxes
									Set-RegistryValue -Path "HKLM:\OFDEFUSR\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Start_ShowMyGames" -Value 0 # Don't add a Games shortcut to the start menu

									# DARK MODE FTW
									# Info: Looks like the dark mode settings get a reset after logon. Dunno why, and i don't want to search for this. Implemented a script for this.
									Set-RegistryValue -Path "HKLM:\OFDEFUSR\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "AppsUseLightTheme" -Value 0    # Does not work, gets a reset...
									Set-RegistryValue -Path "HKLM:\OFDEFUSR\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "SystemUsesLightTheme" -Value 0 # Dark Settings + Dark Explorer
								
									# Hide Taskbar Cortana on Default User
									Set-RegistryValue -Path "HKLM:\OFDEFUSR\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" -Name "SearchboxTaskbarMode" -Value 0

									# Remove Windows Store from TaskBar
									Set-RegistryValue -Path "HKLM:\OFDEFUSR\SOFTWARE\Policies\Microsoft\Windows\Explorer" -Name "NoPinningStoreToTaskbar" -Value 1

									# Show All Symbols on Taskbar
									Set-RegistryValue -Path "HKLM:\OFDEFUSR\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoAutoTrayNotify" -Value 1
								
									# Disable People Bar
									Set-RegistryValue -Path "HKLM:\OFDEFUSR\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People" -Name "PeopleBand" -Value 0
									Set-RegistryValue -Path "HKLM:\OFDEFUSR\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People" -Name "TaskbarCapacity" -Value 0

									# Remove OneDriveSetup Hook
									if (Get-ItemProperty -Path "HKLM:\OFDEFUSR\Software\Microsoft\Windows\CurrentVersion\Run\" -Name "OneDrive" -ErrorAction SilentlyContinue) {
										$null = Remove-ItemProperty -Path "HKLM:\OFDEFUSR\Software\Microsoft\Windows\CurrentVersion\Run\" -Name "OneDrive" -ErrorAction SilentlyContinue -Verbose
									}
								}
								else {
									Write-Host "HKLM:\OFDEFUSR not found" -ForegroundColor Red
								}

								UnmountRegistry -OfflineRegistry "Registry::HKEY_LOCAL_MACHINE\OFDEFUSR"
							}
							else {
								Write-Host "`"$MountPath\Users\default\ntuser.dat`" not found." -ForegroundColor Red
							}
							#endregion NTUSERDAT

							#region DEFAULT
							# ntusers.dat for quick changes, this here is for HKEY_USERS\.DEFAULT
							if (Test-Path -Path "$MountPath\Windows\System32\Config\DEFAULT") {
								Write-Verbose "`"$MountPath\Windows\System32\Config\DEFAULT`" found." -Verbose

								$null = REG LOAD HKLM\OFDEFUSR "$MountPath\Windows\System32\Config\DEFAULT"
							
								if (Test-Path -Path "HKLM:\OFDEFUSR") {
									# QuickEdit
									Set-RegistryValue -Path "HKLM:\OFDEFUSR\Console" -Name "QuickEdit" -Value 1
									
									# Explorer Tweaks
									Set-RegistryValue -Path "HKLM:\OFDEFUSR\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "LaunchTo" -Value 1          # QuickAccess => ThisPC
									Set-RegistryValue -Path "HKLM:\OFDEFUSR\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Value 1            # Show hidden files and folders
									Set-RegistryValue -Path "HKLM:\OFDEFUSR\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 0       # Show File Extensions
									Set-RegistryValue -Path "HKLM:\OFDEFUSR\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "AutoCheckSelect" -Value 1   # File Checkboxes
									Set-RegistryValue -Path "HKLM:\OFDEFUSR\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Start_ShowMyGames" -Value 0 # Don't add a Games shortcut to the start menu

									# DARK MODE FTW
									# Info: Looks like the dark mode settings get a reset after logon (Default setting is right).
									# Dunno why, and i don't want to search for this (another key?). Implemented a script in \tools for this.
									Set-RegistryValue -Path "HKLM:\OFDEFUSR\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "AppsUseLightTheme" -Value 0    # Does not work, gets a reset...
									Set-RegistryValue -Path "HKLM:\OFDEFUSR\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "SystemUsesLightTheme" -Value 0 # Dark Settings + Dark Explorer

									# Hide Taskbar Cortana on Default User
									Set-RegistryValue -Path "HKLM:\OFDEFUSR\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" -Name "SearchboxTaskbarMode" -Value 0

									# Remove Windows Store from TaskBar
									Set-RegistryValue -Path "HKLM:\OFDEFUSR\SOFTWARE\Policies\Microsoft\Windows\Explorer" -Name "NoPinningStoreToTaskbar" -Value 1

									# Show All Symbols on Taskbar
									Set-RegistryValue -Path "HKLM:\OFDEFUSR\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoAutoTrayNotify" -Value 1
								
									# Disable People Bar
									Set-RegistryValue -Path "HKLM:\OFDEFUSR\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People" -Name "PeopleBand" -Value 0
									Set-RegistryValue -Path "HKLM:\OFDEFUSR\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People" -Name "TaskbarCapacity" -Value 0
								
									# Remove OneDriveSetup Hook
									if (Get-ItemProperty -Path "HKLM:\OFDEFUSR\Software\Microsoft\Windows\CurrentVersion\Run\" -Name "OneDrive" -ErrorAction SilentlyContinue) {
										$null = Remove-ItemProperty -Path "HKLM:\OFDEFUSR\Software\Microsoft\Windows\CurrentVersion\Run\" -Name "OneDrive" -ErrorAction SilentlyContinue -Verbose
									}
								}
								else {
									Write-Host "HKLM:\OFDEFUSR not found" -ForegroundColor Red
								}

								UnmountRegistry -OfflineRegistry "Registry::HKEY_LOCAL_MACHINE\OFDEFUSR"
							}
							else {
								Write-Host "`"$MountPath\Windows\System32\Config\DEFAULT`" not found." -ForegroundColor Red
							}
							#endregion DEFAULT

							<#
							 # SOFTWARE HIVE
							#>

							#region HKLM\SOFTWARE
							if (Test-Path -Path "$MountPath\Windows\System32\Config\SOFTWARE") {
								Write-Verbose "`"$MountPath\Windows\System32\Config\SOFTWARE`" found." -Verbose
								$null = reg load HKLM\OFFLINE "$MountPath\Windows\System32\Config\SOFTWARE"

								if (Test-Path -Path "HKLM:\OFFLINE") {
									#$tReg = "HKLM:\OFFLINE\Policies\Microsoft\WindowsStore"
									#if (!(Test-Path $tReg)) {New-Item -ItemType Directory -Force -Path $tReg}
									#Set-ItemProperty "HKLM:\OFFLINE\Policies\Microsoft\WindowsStore" "AutoDownload" 2

									# Windows Store Auto Download (2 = always off; 4 = always on; delete = user choice)
									Set-RegistryValue -Path "HKLM:\OFFLINE\Policies\Microsoft\WindowsStore" -Name "AutoDownload" -Value 2

									# Prevents "Suggested Applications" returning
									#$tReg = "HKLM:\OFFLINE\Policies\Microsoft\Windows\CloudContent"
									#if (!(Test-Path $tReg)) {New-Item -ItemType Directory -Force -Path $tReg}
									#Set-ItemProperty "HKLM:\OFFLINE\Policies\Microsoft\Windows\CloudContent" "DisableWindowsConsumerFeatures" 1
									Set-RegistryValue -Path "HKLM:\OFFLINE\Policies\Microsoft\Windows\CloudContent" -Name "DisableWindowsConsumerFeatures" -Value 1

									#;When opening files with an unknown extension, dont prompt to 'Look for an app in the Store'
									Set-RegistryValue -Path "HKLM:\OFFLINE\Policies\Microsoft\Windows\Explorer" -Name "NoUseStoreOpenWith" -Value 1
									
									# 4 = Download And Install, 3 Download, 2 = CheckOnly, 1 = NoCheck
									#Set-RegistryValue -Path "HKLM:\OFFLINE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto" -Name "AUOptions" -Value 3

									# ShutUp Cortana
									$tReg = "HKLM:\OFFLINE\Policies\Microsoft\Windows\Windows Search"
									#if (!(Test-Path $tReg)) {New-Item -ItemType Directory -Force -Path $tReg}
									#Set-ItemProperty "HKLM:\OFFLINE\Policies\Microsoft\Windows\Windows Search" "AllowCortana" 0
									Set-RegistryValue -Path $tReg -Name "AllowCortana" -Value 0
									Set-RegistryValue -Path $tReg -Name "AllowCortanaAboveLock" -Value 0
									Set-RegistryValue -Path $tReg -Name "BingSearchEnabled" -Value 0
									Set-RegistryValue -Path $tReg -Name "ConnectedSearchUseWeb" -Value 0
									Set-RegistryValue -Path $tReg -Name "DisableWebSearch" -Value 1
								
									$tReg = "HKLM:\OFFLINE\Microsoft\Windows Search"
									#if (!(Test-Path $tReg)) {New-Item -ItemType Directory -Force -Path $tReg}
									#Set-ItemProperty "HKLM:\OFFLINE\Microsoft\Windows Search" "AllowCortana" 0
									Set-RegistryValue -Path $tReg -Name "AllowCortana" -Value 0
									Set-RegistryValue -Path $tReg -Name "AllowCortanaAboveLock" -Value 0
									Set-RegistryValue -Path $tReg -Name "BingSearchEnabled" -Value 0
									Set-RegistryValue -Path $tReg -Name "ConnectedSearchUseWeb" -Value 0
									Set-RegistryValue -Path $tReg -Name "DisableWebSearch" -Value 1

									# Disable Logon Microsoft Message
									Set-RegistryValue -Path "HKLM:\OFFLINE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableFirstLogonAnimation" -Value 0
									Set-RegistryValue -Path "HKLM:\OFFLINE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "EnableFirstLogonAnimation" -Value 0

									# Disable OneDrive FileSync
									Set-RegistryValue -Path "HKLM:\OFFLINE\Wow6432Node\Policies\Microsoft\Windows\OneDrive" -Name "DisableFileSyncNGSC" -Value 1
								}
								else {
									Write-Host "HKLM:\OFFLINE not found" -ForegroundColor Red
								}
							
								UnmountRegistry -OfflineRegistry "Registry::HKEY_LOCAL_MACHINE\OFFLINE"
							}
							else {
								Write-Host "`"$MountPath\Windows\System32\Config\SOFTWARE`" not found." -ForegroundColor Red
							}
							#endregion HKLM\SOFTWARE

							<#
							 # SYSTEM HIVE
							#>

							#region HKLM\SYSTEM
							# Did this via unattended.xml, source: https://community.spiceworks.com/topic/1368478-windows-10-mdt-network-discovery
							$SkipREG_SYSTEM = $true
							if (!$SkipREG_SYSTEM) {
								if (Test-Path -Path "$MountPath\Windows\System32\Config\SYSTEM") {
									Write-Verbose "`"$MountPath\Windows\System32\Config\SYSTEM`" found." -Verbose
									$null = reg load HKLM\OFFLINE "$MountPath\Windows\System32\Config\SYSTEM"

									if (Test-Path -Path "HKLM:\OFFLINE") {
										# "New Network Found" Window Prompt

										<#
										 # CANNOT WORK, CAUSING ERROR BOOTING IMAGE (BSOD: CONFIG INITIALIZATION FAILED)
										 # 
										 # try {
										 #   $null = New-Item -Path "HKLM:\OFFLINE\CurrentControlSet\Control\Network\NewNetworkWindowOff" -ItemType Directory -Force -Verbose
										 # } catch {
										 #   Write-Host "Error with NewNetworkOff: $($_.Exception.Message)" -ForegroundColor Red
										 # }
										#>
								
										# Looks like this is also causing troubles.
										# ControlSet001 is loaded as "CurrentControlSet", this might be the problem.
										try {
											$null = New-Item -Path "HKLM:\OFFLINE\ControlSet001\Control\Network\NewNetworkWindowOff" -ItemType Directory -Force -Verbose
										}
										catch {
											Write-Host "Error with NewNetworkOff: $($_.Exception.Message)" -ForegroundColor Red
										}
								
										# This is just for me, so i can check in regedit if everything went fine.
										#Read-Host -Prompt "Safety Prompt"
									}
									else {
										Write-Host "HKLM:\OFFLINE not found" -ForegroundColor Red
									}
							
									UnmountRegistry -OfflineRegistry "Registry::HKEY_LOCAL_MACHINE\OFFLINE"
								}
								else {
									Write-Host "`"$MountPath\Windows\System32\Config\SYSTEM`" not found." -ForegroundColor Red
								}
							}
							else {
								Write-Host "Skipped REG_SYSTEM" -ForegroundColor Yellow
							}
							#endregion HKLM\SYSTEM
						} # /end !$SkipRegTweaks
						
						#endregion Registry
												
						<#
						 # Adding features with Source could result in a DISM command not being executed
						 # as there is a "pending command" that needs to be finished first.
						 # DISM won't tell, but i guess it's the package that DISM needs to add to the index.
						 # 
						 # So, adding features is the LAST task. Huh.
						 # If there is a way to add it without major saving stuff TELL ME!
						#>
						Write-Host "+DISM Cleanup" -ForegroundColor Yellow
						DISM.exe /English /Image:$MountPath /Cleanup-Image /StartComponentCleanup /ResetBase

						# Just in case it is still pending
						$Count_Cleanup = 0
						while ($Result = Dism /English /Image:$MountPath /Cleanup-Image /StartComponentCleanup /ResetBase | Select-String "pending") {
							$Count_Cleanup++
							Write-Host "Waiting for pending dism command ($Result)"
							Start-Sleep -Seconds 2

							if ($Count_Cleanup -ge $DEF_MAX_ITERATIONS) {
								break
							}
						}

						#region SetupFeatures
						if (!$SkipFeatures) {
							Write-Host "+Remove Features" -ForegroundColor Yellow

							<#
							 # Features to remove.
							 # - Nobody should use SMB1 anyway (can always re-add via optionalfeatures)
							 # - I would like to remove the IE, but i might have to use it for stuff like IWR/CURL
							#>
							$featuresRemove = @(
								"SMB1Protocol"
								#"Internet-Explorer-Optional-amd64" # Internet-Explorer-Optional*
							)
							$featuresRemove | ForEach-Object {
								$tFeature = $_
								if ($null = Get-WindowsOptionalFeature -Path $MountPath -FeatureName $tFeature) {
									Write-Host "-Feature `"$tFeature`"" -ForegroundColor Yellow
									try {
										# Enabling Features uses Source when nothing found.
										# Source only contains "Internet Explorer" and ".NETFx3.5"
										$null = Disable-WindowsOptionalFeature -Path $MountPath -FeatureName $tFeature

										#$Success = $true
									}
									catch {
										# NetFX might not work (needs files)
										Write-Host "Error while removing Feature '$tFeature': $($_.Exception.Message)" -ForegroundColor Red
									}
								}
								else {
									Write-Host "No feature `"$tFeature`" found to remove. Might be better than expected." -ForegroundColor Red
									$null = Get-WindowsOptionalFeature -Path $MountPath -FeatureName "*$tFeature*" -ErrorAction SilentlyContinue # want to see if something can be found.
								}
							}

							# The features ME likes alot !?
							Write-Host "+Add Features" -ForegroundColor Yellow
							$featuresAdd = @(
								"NetFx3" # just in case, we can always remove this. NetFX needs source files though...
								"Microsoft-Hyper-V-All"
								"TelnetClient"
								"Containers-DisposableClientVM" # Windows-Sandbox
								#"NTVDM"
							)
							$featuresAdd | ForEach-Object {
								$tFeature = $_
								if ($null = Get-WindowsOptionalFeature -Path $MountPath -FeatureName $tFeature) {
									Write-Host "+Feature `"$tFeature`"" -ForegroundColor Yellow
									try {
										# Enabling Features uses Source when nothing found.
										# Source from ISO only contains "Internet Explorer" and ".NETFx3.5"
										$null = Enable-WindowsOptionalFeature -Path $MountPath -FeatureName $tFeature -Source "$IMAGE_DriveLetter`:\sources\sxs"

										# We also just add the package, to have the POSSIBILITY of enabling this feature...
										#DISM /Image:$MountPath /Enable-Feature /FeatureName:NetFx3 /All /LimitAccess /Source:"$IMAGE_DriveLetter`:\sources\sxs"
										#DISM /Image:$MountPath /Add-Capability /CapabilityName:NetFx3~~~~ /Source:"$IMAGE_DriveLetter`:\sources\sxs"
										#DISM /Image:$MountPath /Add-Package /PackagePath:"$IMAGE_DriveLetter`:\sources\sxs\*$tFeature*.cab
										$Success = $true
									}
									catch {
										# NetFX might not work (needs files)
										Write-Host "Error while adding Feature '$tFeature': $($_.Exception.Message)" -ForegroundColor Red
									}

									# Should never be run as the PowerShell-Command does everything needed.
									# If the command was not successfull, DISM will be run.
									if (!$Success) {
										try {
											Write-Verbose "DISM /Image:$MountPath /Enable-Feature /FeatureName:$tFeature /All /LimitAccess /Source:$IMAGE_DriveLetter`:\sources\sxs" -Verbose
											DISM /Image:$MountPath /Enable-Feature /FeatureName:$tFeature /All /LimitAccess /Source:$IMAGE_DriveLetter`:\sources\sxs
										}
										catch {
											Write-Host "Error while adding Feature '$tFeature' with DISM: $($_.Exception.Message)" -ForegroundColor Red
										}
									}
								}
								else {
									# To verify, that this will never be shown make sure that the "OptionalFeature" does exist!
									Write-Host "No feature `"$tFeature`" found." -ForegroundColor Red
									$null = Get-WindowsOptionalFeature -Path $MountPath -FeatureName "*$tFeature*" -ErrorAction SilentlyContinue # want to see if something can be found.
								}
							}
						}
						#endregion SetupFeatures
						
						#region RSAT
						if (!($SkipFOD)) {
							# Pre FOD ISOs only ava. via MSDN-Sub-Account.
							# VLSC is getting FOD for 1903 later, i hope.
							if (Test-Path -Path "$PSScriptRoot\FOD\RSAT\$($Version.Build)*\$WIMArchitecture") {
								Write-Host "+Add RSAT" -ForegroundColor Yellow

								#$WIMArchitecture
								$FOD_Folder = Get-Item -Path "$PSScriptRoot\FOD\RSAT\$($Version.Build)*\$WIMArchitecture" | Where-Object { $_.PSIsContainer } | Select-Object -First 1

								$RSAT_CAP = Get-WindowsCapability -Path $MountPath | Where-Object { $_.Name -like "*RSAT*" -and $_.State -eq "NotPresent" }
								$RSAT_CAP | ForEach-Object {
									# It's possible to do this in a one-liner.
									# Verbose of these DISM-like commands is not so useful.
									Write-Verbose "Feature: $($_.Name)" -Verbose
									$null = $_  | Add-WindowsCapability -Path $MountPath -Source $FOD_Folder.FullName
								}
							}
						}
						#endregion RSAT

						<#
						 # Could also add Language Packs here. Have to look out for them.
						 # DISK Space is too low for now *sad*.
						 # 
						 # Also i could do some finalize stuff for the image in
						 # "$MountPath\Windows\Setup\Scripts\SetupComplete.cmd".
						 # More like adding that to the AutoUnattend.xml file (RunSynchronousCommand)
						 # 
						 # Also also there are the DefaultAppAssociations.
						 # We haven't installed any software in the image (use case!),
						 # so this might not be a good option.
						 # We have SCCM, so i know ways to handle it here.
						 # And i don't think it's vital for private users.
						 # 
						 #Write-Host "+Default Apps" -ForegroundColor Yellow
						 #Dism /English /Image:$MountPath /Get-DefaultAppAssociations
						 # Hm, maybe: Dism /English /Online /Export-DefaultAppAssociations:"F:\AppAssociations.xml"
						 # Dism /English /Image:$MountPath /Get-DefaultAppAssociations
						 # Dism /English /Image:$MountPath /Remove-DefaultAppAssociations
						 # Dism /English /Image:$MountPath /Import-DefaultAppAssociations:F:\AppAssociations.xml
						#>
					}

					Write-Host "Dismounting Image (-Save)" -ForegroundColor Yellow
					$null = Dismount-WindowsImage -Path $MountPath -Save # Append for NEW image-index
				} # /end of dism image index loop

				# comparing result?
				Dism /English /Get-ImageInfo /ImageFile:$CopiedImageFullName
			} # /end of version and update files check

			#region ISO
			# maybe we want to skip that for testing?
			if (!$DoNotCreateISO) {
				Read-Host -Prompt "Creating ISO. Ready? [PRESS ENTER]"

				# Re-Creating Folder here
				Write-Host "Let's see if we can create an ISO Image now..."
				if (Test-Path -Path $MountPath) {
					$null = Remove-Item -Path $MountPath -Recurse -Force -Verbose
				}
				if (!(Test-Path -Path $MountPath)) {
					$null = New-Item -Path $MountPath -ItemType Directory -Force
				}

				# TODO... maybe: Read from registry if installed.
				$ADK_Folder = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools"
				$ADK_Exists = & {
					if (!(Test-Path -Path $ADK_Folder)) {
						Write-Host "ADK folder not found. Maybe we should change this. Hm." -ForegroundColor Red
					}
					else {
						return $true
					}
				}

				# Should be more like "Robocopy missing" (how comes that?)
				$Robocopy_Exists = & {
					if (!(Get-Command Robocopy* -ErrorAction SilentlyContinue)) {
						Write-Host "Robocopy does not exist. HOW COMES THAT??" -ForegroundColor Red
					}
					else {
						return $true
					}
				}

				# Create That ISO
				if ( $ADK_Exists -and $Robocopy_Exists ) {
					Write-Host "Creating ISO-File in $PSScriptRoot\$($IMAGE_DriveInformation.FileSystemLabel).iso" -ForegroundColor Cyan

					# $MountPath was use to mount WIM, now i
					# copy the content of the original ISO to $MountPath.
					# /MIR works, if nothing is left ;-)
					ROBOCOPY "$IMAGE_DriveLetter`:\" $MountPath /E /R:1 /W:10 /TEE /Log+:Logs\"$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_robo.log"

					# Instert WIM into Image
					# TODO: Maybe split WIM into multiple or compress to ESD for USB etc.?
					$null = Copy-Item -Path $CopiedImageFullName -Destination "$MountPath\sources\install.wim" -Force -Verbose

					# Want something in the ISO? Place it inside of \Includence
					# Autounattended.xml and InstallDrive.tag will be in there!
					Write-Host "+Adding content" -ForegroundColor Yellow
					ROBOCOPY "$PSScriptRoot\Includence\" $MountPath /E /R:1 /W:10 /TEE /Log+:Logs\"$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_robo.log"

					Start-Process -FilePath "$ADK_Folder\$env:PROCESSOR_ARCHITECTURE\OSCDIMG\oscdimg.exe " -ArgumentList "-m -l$($IMAGE_DriveInformation.FileSystemLabel) -o -u2 -udfver102 -bootdata:2#p0,e,b$MountPath\boot\etfsboot.com#pEF,e,b$MountPath\efi\microsoft\boot\efisys.bin $MountPath `"$PSScriptRoot\$($IMAGE_DriveInformation.FileSystemLabel).iso`"" -Wait -PassThru -NoNewWindow | Format-Table -AutoSize -Wrap
				}
			} # /end of not creating ISO
			#endregion ISO
			
			Read-Host -Prompt "See? I did what you wanted. Wanna remove the rest? [PRESS ENTER]"

			# removing mount folder
			if (Test-Path -Path $MountPath) {
				# end of script: no warning!
				Clear-MountPath -MountPath $MountPath -OverrideWarning
			}
			
			# remove local wim
			Remove-Item -Path $CopiedImageFullName -Force
				
			$null = Dismount-DiskImage -ImagePath $_.FullName -Verbose
			Write-Host "ISO '$($_.FullName)' unmounted, i guess..."
		} # /end of iso loop
	}
 else {
		Write-Host "No ISO in SubFolders. Please copy ISO inside any subfolder, if you have any, and restart me."
		return
	}
}

$EndTime = Get-Date
Write-Host "Ended at $(Get-Date -Format "dd.MM.yy HH:mm:ss")"

$TimeSpan = (New-TimeSpan -Start $StartTime -End $EndTime) -join ";"
Write-Host "Duration: $TimeSpan"

Stop-Transcript

#dism /English /Compress:max /Export-Image /SourceImageFile:\sources\install.wim /SourceIndex:1 /DestinationImageFile:\exported\install.wim