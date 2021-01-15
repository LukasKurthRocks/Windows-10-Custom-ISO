<#
 # Wanted to have a way to disable services.
 # This is waht i came up with.
 # not very beatiful, but works...
 #
 # You can not disable antivirus like that (just a note)
 #
 # Get-CimInstance Win32_StartupCommand | Select-Object Name,Location,Command
#>

# TODO: Maybe i should load "Default user"?

Write-Host "Disable StartUp for user: $env:USERNAME" -ForegroundColor Cyan

# also see "install_standard" in 03\manual
$BlackList = @(
    "OneDriveSetup"
    "DriveBooster"
    "KeePass"
    "iTunesHelper",
    "Ccleaner Monitoring",
    "SunJavaUpdateSched",
    "Steam",
    "Discord"
)

# as we are removing startups from the "current user" this is just for checking
# could "reg load" into user hive if needed.
Get-ChildItem -Path "$env:SystemDrive\Users" | Where-Object { ($_.FullName -notin @($env:USERPROFILE, $env:PUBLIC)) } | ForEach-Object {
	Write-Host "We should check for user: $($_.Name)" -ForegroundColor Yellow
}

# remove all startup apps
Get-ChildItem -Path "$env:SystemDrive\Users" | ForEach-Object {
	$UserFullName = $_.FullName

	#C:\Users\Administrator\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup
	$AppDataStartup = "$UserFullName\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup"
	if(Test-Path -Path $AppDataStartup) {
		Write-Host "Remove items from: `"$($_.Name)\Startup`"" -ForegroundColor Yellow
		Get-ChildItem -Path $AppDataStartup | ForEach-Object {
			Remove-Item $_.FullName -Force -Verbose
		}
	}
}
# All User Startup
$tProgramDataStartup = "$env:ALLUSERSPROFILE\Microsoft\Windows\Start Menu\Programs\Startup"
if(Test-Path -Path $tProgramDataStartup) {
	Write-Host "Remove items from: `"ProgramData\Startup`"" -ForegroundColor Yellow
	Get-ChildItem -Path $tProgramDataStartup | ForEach-Object {
		Remove-Item $_.FullName -Force -Verbose
	}
}

# This is for disabling them in registry. it "could" be that this isn't working for RunMe.ps1
# Tested it manually though, and that WORKED (That stuff is weird sometimes).
@(
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run"
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run32"
	"HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder"
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run"
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run32"
	"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder"
) | ForEach-Object {
    $cRegPath = $_
    if($cRegPath -and (Test-Path -Path $cRegPath)) {
        (Get-Item -Path $cRegPath).Property | ForEach-Object {
            $datItemProperty = $_
            
            $BlackList | ForEach-Object {
                $datBlackList = $_

                if($datItemProperty -match $datBlackList) {
                    $DisableThis = $datItemProperty
                    Write-Host "Disabling: `"$datItemProperty`"" -ForegroundColor Magenta

                    # Disable a program
                    try {
                        Set-ItemProperty -Path $cRegPath -Name $DisableThis -Value ([byte[]](0x03,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00)) -Force -Verbose -ErrorAction Stop
                    } catch {
                        Write-Host "Error disabling `"$DisableThis`": $($_.Exception.Message)" -ForegroundColor Red
                    }

                    # Enable a program
                    #Set-ItemProperty HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run -Name f.lux -Value ([byte[]](0x02,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00))
                } else {
					Write-Host "Ignoring: `"$datItemProperty`" !match `"$datBlackList`"" -ForegroundColor DarkGray
				}
            }
        }
    } else {
		Write-Host "Key `"$cRegPath`" not found." -ForegroundColor Yellow
	}
}

# After disabling some applications from starup, some remained in user settings
# Se here i am "disabling" them forever: the're REMOVED completely.
# I they're necessary, they can be reinstalled/repaired from app-setup.
@(
	"HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
	"HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
	"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
	"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
	"HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Run"
	"HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\RunOnce"
) | ForEach-Object {
	$cRegPath = $_
    if($cRegPath -and (Test-Path -Path $cRegPath)) {
		Write-Host "Entries in `"$cRegPath`":" -ForegroundColor Yellow

		# the entries are listed with "poperty" (like 'OneDriveSetup')
		Get-Item -Path $cRegPath | Select-Object -ExpandProperty Property | ForEach-Object {
            $datItemProperty = $_
            
			Write-Host ">> $datItemProperty" -ForegroundColor Yellow
            $BlackList | ForEach-Object {
                $datBlackList = $_

                if($datItemProperty -match $datBlackList) {
                    $DisableThis = $datItemProperty
                    Write-Host "Removing: `"$datItemProperty`"" -ForegroundColor Magenta

                    # "Disable" a program
                    try {
						Remove-ItemProperty -Path $cRegPath -Name $DisableThis -Verbose
                    } catch {
                        Write-Host "Error removing `"$DisableThis`": $($_.Exception.Message)" -ForegroundColor Red
                    }
                } else {
					Write-Host "Ignoring: `"$datItemProperty`" !match `"$datBlackList`"" -ForegroundColor DarkGray
				}
            }
		}
	}
}

Write-Host "Done." -ForegroundColor Cyan