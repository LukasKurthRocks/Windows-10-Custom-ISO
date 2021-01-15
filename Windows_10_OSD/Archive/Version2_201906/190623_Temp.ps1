# SAAFE:
# https://uupdump.ml/get.php?id=91712d02-7dcf-478a-acfc-6e4c474fc754&pack=0&edition=0
# https://uupdump.ml/findfiles.php?id=91712d02-7dcf-478a-acfc-6e4c474fc754
# https://uupdump.ml/download.php?id=91712d02-7dcf-478a-acfc-6e4c474fc754&pack=de-de&edition=0
# https://uupdump.ml/get.php?id=91712d02-7dcf-478a-acfc-6e4c474fc754&pack=0&edition=updateOnly
# https://uupdump.ml/get.php?id=91712d02-7dcf-478a-acfc-6e4c474fc754&pack=0&edition=0&aria2=1

#region
# moved here on 29.07.2019
# wanted to sort the FODs, but this is not really needed.
# if we call dism to add FODs, we can use a base path.
# might have a script to sort these somewhere.

$UUP_DUMP_Aria_UUPs_Sorted_FODs = "$UUP_DUMP_Aria_UUPs_Sorted\FODs"
$UUP_DUMP_Aria_UUPs_Sorted_LPs = "$UUP_DUMP_Aria_UUPs_Sorted\LPs"

if (!(Test-Path -Path $UUP_DUMP_Aria_UUPs_Sorted_FODs)) {
	$null = New-Item -Path $UUP_DUMP_Aria_UUPs_Sorted_FODs -ItemType Directory
}
if (!(Test-Path -Path $UUP_DUMP_Aria_UUPs_Sorted_LPs)) {
	$null = New-Item -Path $UUP_DUMP_Aria_UUPs_Sorted_LPs -ItemType Directory
}

# remove duplicates
<#
if(Test-Path -Path $UUP_DUMP_Aria_UUPs_Sorted_FODs) {
	Get-ChildItem -Path $UUP_DUMP_Aria_UUPs_Sorted_FODs -Filter "*.cab" | ForEach-Object {
		$FileName = $_.Name
		if(Test-Path -Path "$UUP_DUMP_Aria_UUPs\$FileName") {
			Remove-Item "$UUP_DUMP_Aria_UUPs\$FileName" -Verbose
		}
	}
}
if(Test-Path -Path $UUP_DUMP_Aria_UUPs_Sorted_LPs) {
	Get-ChildItem -Path $UUP_DUMP_Aria_UUPs_Sorted_LPs -Filter "*.cab" | ForEach-Object {
		$FileName = $_.Name
		if(Test-Path -Path "$UUP_DUMP_Aria_UUPs\$FileName") {
			Remove-Item "$UUP_DUMP_Aria_UUPs\$FileName" -Verbose
		}
	}
}
#>

# moving these cabinet files.
# used for soring them.
$SkipMove = $true # TODO: I moved something important... what?
if (!$SkipMove) {
	Get-ChildItem -Path "$UUP_DUMP_Aria_UUPs\*" -Include @("*.cab", "*.esd") | ForEach-Object {
		# Reading the cab info. this might take a while...
		# Capability Identity : Rsat.DHCP.Tools~~~de-DE~0.0.1.0
		$CapabilityString = DISM /Online /Get-PackageInfo /PackagePath:$($_.FullName) /English | Select-String "Capability"
	
		# standard should do NOTHING
		#$Destination = "$UUP_DUMP_Aria_UUPs_Sorted\Other"
	
		Remove-Variable Destination -Force -Verbose -ErrorAction SilentlyContinue

		# Most of these features are listed here:
		# https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/features-on-demand-non-language-fod

		# Language.Client.UI => LanguagePack (ESD)
		<#
		if($CapabilityString -match "Language[.]") {
			$Destination = "$UUP_DUMP_Aria_UUPs_Sorted\LPs"
			if(!(Test-Path -Path $Destination)) {
				$null = New-Item -Path $Destination -ItemType Directory
			}
		}
		#>
		if ($CapabilityString -match "RSAT[.]") {
			$Destination = "$UUP_DUMP_Aria_UUPs_Sorted\RSAT"
			if (!(Test-Path -Path $Destination)) {
				$null = New-Item -Path $Destination -ItemType Directory
			}
		}
		# for Windows 10 N versions...
		if ($CapabilityString -match "MediaFeaturePack") {
			$Destination = "$UUP_DUMP_Aria_UUPs_Sorted\MediaFeatures"
			if (!(Test-Path -Path $Destination)) {
				$null = New-Item -Path $Destination -ItemType Directory
			}
		}
		if ($CapabilityString -match "Network[.]IRDA") {
			$Destination = "$UUP_DUMP_Aria_UUPs_Sorted\Network.IRDA_Unsupported"
			if (!(Test-Path -Path $Destination)) {
				$null = New-Item -Path $Destination -ItemType Directory
			}
		}
		# RAS Connection Manager Administration Kit (CMAK)
		# Create profiles for connecting to remote servers and networks
		if ($CapabilityString -match "RasCMAK[.]Client") {
			$Destination = "$UUP_DUMP_Aria_UUPs_Sorted\RasCMAK.Client"
			if (!(Test-Path -Path $Destination)) {
				$null = New-Item -Path $Destination -ItemType Directory
			}
		}
		# RIP Listener
		# Listens for route updates sent by routers that use the Routing Information Protocol version 1 (RIPV1)
		if ($CapabilityString -match "RIP[.]Listener") {
			$Destination = "$UUP_DUMP_Aria_UUPs_Sorted\RIP.Listener"
			if (!(Test-Path -Path $Destination)) {
				$null = New-Item -Path $Destination -ItemType Directory
			}
		}
		# Simple Network Management Protocol (SNMP)
		# This feature includes SNMP agents that monitor the activity in network devices and report to the network console
		if ($CapabilityString -match "SNMP[.]Client") {
			$Destination = "$UUP_DUMP_Aria_UUPs_Sorted\SNMP.Client"
			if (!(Test-Path -Path $Destination)) {
				$null = New-Item -Path $Destination -ItemType Directory
			}
		}
		# SNMP WMI Provider
		# Enables WMI clients to consume SNMP information through the CIM model as implemented by WMI
		if ($CapabilityString -match "WMI[-]SNMP[-]Provider[.]Client") {
			$Destination = "$UUP_DUMP_Aria_UUPs_Sorted\WMI-SNMP-Provider.Client"
			if (!(Test-Path -Path $Destination)) {
				$null = New-Item -Path $Destination -ItemType Directory
			}
		}
		# Windows Storage Management
		# Windows Storage Management allows you to manage a wide range of storage configurations, from single-disk desktops to external storage arrays.
		if ($CapabilityString -match "Microsoft[.]Windows[.]StorageManagement") {
			$Destination = "$UUP_DUMP_Aria_UUPs_Sorted\Microsoft.Windows.StorageManagement"
			if (!(Test-Path -Path $Destination)) {
				$null = New-Item -Path $Destination -ItemType Directory
			}
		}
		# Windows Storage Management
		# Windows Storage Management allows you to manage a wide range of storage configurations, from single-disk desktops to external storage arrays.
		if ($CapabilityString -match "Microsoft[.]OneCore[.]StorageManagement") {
			$Destination = "$UUP_DUMP_Aria_UUPs_Sorted\Microsoft.Windows.StorageManagement"
			if (!(Test-Path -Path $Destination)) {
				$null = New-Item -Path $Destination -ItemType Directory
			}
		}
		# Server Core App Compatibility
		# Server Core App Compatibility significantly improves the app compatibility of the Windows Server Core installation option by including a subset
		# of binaries and packages from Windows Server with Desktop Experience, without adding all components of the Windows Server Desktop Experience
		# graphical environment. This FOD is available on the Server FOD ISO.
		if ($CapabilityString -match "ServerCore[.]AppCompatibility") {
			$Destination = "$UUP_DUMP_Aria_UUPs_Sorted\ServerCore.AppCompatibility"
			if (!(Test-Path -Path $Destination)) {
				$null = New-Item -Path $Destination -ItemType Directory
			}
		}
		# Accessibility - Braille Support
		# This Feature on Demand enables Braille devices to work with the inbox Narrator screen reader.
		# !Don't include these Features on Demand in your image, as doing so could conflict with Braille device rights restrictions.
		if ($CapabilityString -match "Accessibility[.]Braille") {
			$Destination = "$UUP_DUMP_Aria_UUPs_Sorted\Accessibility.Braille"
			if (!(Test-Path -Path $Destination)) {
				$null = New-Item -Path $Destination -ItemType Directory
			}
		}
		# Windows Developer Mode
		# An on-device diagnostic platform used via a browser. Installs a SSH server on the device for UWP remote deployment as well as Windows Device Portal.
		# Enabling Developer Mode will attempt to auto-install this Feature on Demand. On devices that are WSUS-managed, this auto-install will likely fail due
		# to WSUS blocking FOD packages by default. If this Feature on Demand is not successfully installed, device discovery and Device Portal can't be enabled,
		# preventing remote deployment to the device.
		# !In general, don't preinstall on devices. If you are building an image for "developer edition" devices, where the primary market for the device is
		# developers or users who plan on developing or testing UWPs, consider preinstalling.
		if ($CapabilityString -match "Tools[.]DeveloperMode[.]Core") {
			$Destination = "$UUP_DUMP_Aria_UUPs_Sorted\Tools.DeveloperMode.Core"
			if (!(Test-Path -Path $Destination)) {
				$null = New-Item -Path $Destination -ItemType Directory
			}
		}
		# Graphics Tools
		# Used for Direct3D application development. It is typically installed by AAA game engine developers, enterprise graphics software developers, or niche hobbyists.
		# !Don't install. This Feature on Demand is only needed by specific users who can trigger installation through Visual Studio when certain optional packages are chosen at install.
		if ($CapabilityString -match "Tools[.]Graphics[.]DirectX") {
			$Destination = "$UUP_DUMP_Aria_UUPs_Sorted\Tools.Graphics.DirectX"
			if (!(Test-Path -Path $Destination)) {
				$null = New-Item -Path $Destination -ItemType Directory
			}
		}
		# Microsoft WebDriver
		# This Feature on Demand enables automated testing of Microsoft Edge and WWA's or WebView controls. This was previously available as a separate download.
		# !In general, don't preinstall on devices. If you are building an image for "developer edition" devices, where the primary market for the device is developers
		# or users who plan on testing websites in Microsoft Edge or web content in UWPs, consider preinstalling.
		if ($CapabilityString -match "Microsoft[.]WebDriver") {
			$Destination = "$UUP_DUMP_Aria_UUPs_Sorted\Microsoft.WebDriver"
			if (!(Test-Path -Path $Destination)) {
				$null = New-Item -Path $Destination -ItemType Directory
			}
		}
		# Printing
		# These Features on Demand are for devices running Windows Server as a Print Server role which supports Azure AD joined devices.
		# If this FOD is not installed, then a Windows Server acting as a Print Server will only support the printing needs of traditional
		# domain joined devices. Azure AD joined devices will not be able to discover corporate printers.
		if ($CapabilityString -match "Print[.]EnterpriseCloudPrint|Print[.]MopriaCloudService") {
			$Destination = "$UUP_DUMP_Aria_UUPs_Sorted\Printing"
			if (!(Test-Path -Path $Destination)) {
				$null = New-Item -Path $Destination -ItemType Directory
			}
		}
		# MSIX Packaging Tool Driver
		# MSIX Packaging tool driver monitors the environment to capture the changes that an application installer is making on the system
		# to allow MSIX Packaging Tool to repackage the installer as MSIX package.
		if ($CapabilityString -match "Msix[.]PackagingTool[.]Driver") {
			$Destination = "$UUP_DUMP_Aria_UUPs_Sorted\Msix.PackagingTool.Driver"
			if (!(Test-Path -Path $Destination)) {
				$null = New-Item -Path $Destination -ItemType Directory
			}
		}
		# Mixed Reality
		# This Feature on Demand enables Mixed Reality (MR) devices to be used on a PC. If this Feature on Demand is not present, MR devices may not function properly.
		if ($CapabilityString -match "Analog[.]Holographic") {
			$Destination = "$UUP_DUMP_Aria_UUPs_Sorted\Analog.Holographic.Desktop"
			if (!(Test-Path -Path $Destination)) {
				$null = New-Item -Path $Destination -ItemType Directory
			}
		}
		# Admin Tools
		# ??
		if ($CapabilityString -match "Microsoft[.]AdminTools") {
			$Destination = "$UUP_DUMP_Aria_UUPs_Sorted\Microsoft.AdminTools_UNKNOWN"
			if (!(Test-Path -Path $Destination)) {
				$null = New-Item -Path $Destination -ItemType Directory
			}
		}

		# OneCoreUAP.OneSync~~~~0.0.1.0 # Exchange ActiveSync and Internet Mail Sync Engine
		# Microsoft-Windows-AdminTools-FOD-Package??

		# Others...
		if ($CapabilityString -match "OpenSSH[.]Server") {
			$Destination = "$UUP_DUMP_Aria_UUPs_Sorted_FODs"
			if (!(Test-Path -Path $Destination)) {
				$null = New-Item -Path $Destination -ItemType Directory
			}
		}

		if ($Destination) {
			Write-Host "[$(_LINE_)] Moving `"$CapabilityString`""
			$FileName = $_.Name
			Copy-Item -Path $_.FullName -Destination "$Destination\$FileName" -Verbose
			Remove-Item -Path $_.FullName -Verbose
		}
		else {
			Write-Host "[$(_LINE_)]`"$CapabilityString`" not matching ($($_.Name))."
		}
	}
}
#endregion

#Invoke-Item -Path "$UUP_DUMP_Aria\*"