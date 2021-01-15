#Requires -RunAsAdministrator
#Requires -Version 5.0

[CmdLetBinding()]
param(
	[Parameter(Mandatory=$true)]
	[ValidateScript({
		if([String]::IsNullOrEmpty($_) -or [String]::IsNullOrWhiteSpace($_)) {
			throw "No null, empty or whitespace characters please. You could use '*' if you want EVERYTHING, though not recommended.";
		}
		$true
	})]
	$FeatureStringInstall
)

# I put this here in case I need this
# Althoug a requirement is to have version 5.0
#if (!($PSScriptRoot)) {
#    $PSScriptRoot = (Split-Path $MyInvocation.MyCommand.Path)
#}

Start-Transcript -Path "$env:TEMP\w10_features_$(Get-Date -Format "yyMMdd-HHmmss.fffffff").txt"

Write-Host "Searching for feature with name containing '$FeatureStringInstall'..."
$CapabilitiesToInstall = Get-WindowsCapability -Online -Name "*$FeatureStringInstall*" -Verbose:$false
if($CapabilitiesToInstall -and $CapabilitiesToInstall.Count -gt 0) {
	$CapabilitiesToInstall | ForEach-Object {
		if([String]::IsNullOrEmpty($_.Name) -or [String]::IsNullOrWhiteSpace($_.Name)) {
			Write-Host "Return ''."
			continue
		}

		$CapName = $_.Name
		#Write-Verbose "Processing: '$CapName'" -Verbose
		Write-Host "Processing: '$CapName'" -BackgroundColor Black -ForegroundColor Yellow

		# Getting info of capability
		#DISM /Online /Get-CapabilityInfo /CapabilityName:$CapName /English

		# I need to have the complete filename for this to work.
		# Would need to get the CAB data in a list first... NOPE!
		<#
		DISM /Online /Add-Package /PackagePath:$PSScriptRoot\ /IgnoreCheck /NoRestart /English
		if($LASTEXITCODE -eq 0) {
			Write-Verbose "DISM exited with 'LASTEXITCODE': $LASTEXITCODE (0x$([System.Convert]::ToString($LASTEXITCODE, 16)))" -Verbose
		} else {
			Write-Host "DISM exited with 'LASTEXITCODE': $LASTEXITCODE (0x$([System.Convert]::ToString($LASTEXITCODE, 16)))" -BackgroundColor Black -ForegroundColor Red
		}
		#>

		# Adding the capability to the windows operating system.
		DISM /Online /Add-Capability /LimitAccess /CapabilityName:$CapName /Source:$PSScriptRoot\ /NoRestart /English
		if($LASTEXITCODE -eq 0) {
			Write-Verbose "DISM exited with 'LASTEXITCODE': $LASTEXITCODE (0x$([System.Convert]::ToString($LASTEXITCODE, 16)))"
		} elseif($LASTEXITCODE -eq 3010) {
			Write-Host "DISM exited with 'LASTEXITCODE': $LASTEXITCODE (0x$([System.Convert]::ToString($LASTEXITCODE, 16)), ERROR_SUCCESS_REBOOT_REQUIRED)" -BackgroundColor Black -ForegroundColor Yellow
		} else {
			Write-Host "DISM exited with 'LASTEXITCODE': $LASTEXITCODE (0x$([System.Convert]::ToString($LASTEXITCODE, 16)))" -BackgroundColor Black -ForegroundColor Red
		}
	}
} else {
	Write-Host "No capabilities for '$FeatureStringInstall' found." -BackgroundColor Black -ForegroundColor Red
}

#DISM /Online /Add-Package /PackagePath:$FeatureFullName /IgnoreCheck /Quiet /NoRestart /English
#DISM /Online /Add-Capability /CapabilityName:$FeatureCapabilityNameWithoutLanguage /Source:$FeatureFolder

Stop-Transcript