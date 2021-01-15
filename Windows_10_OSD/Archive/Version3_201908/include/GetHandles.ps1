#Requires -RunAsAdministrator
#Requires -Version 3.0

# Unfortunately it need the handles.exe.
# Example: FindAndClose-Handle -SearchString "C:\Windows\Remove.txt" -WhatIf
# https://powershellminute.wordpress.com/2016/05/18/use-powershell-handle-exe-to-close-a-list-of-locked-files/
# https://docs.microsoft.com/en-us/sysinternals/downloads/handle

function Get-Handle {
	param(
		$SearchString
	)

	#if(!(Test-Path -Path "$FullFileName")) {
	#	Write-Host "Files does not exist. So there is no handle." -BackgroundColor Black -ForegroundColor Red
	#	return
	#}

	$HandleExecutable = "$PSScriptRoot\handle.exe"

	$AllHandles = @()

	$ThatHandle = & $HandleExecutable -a -accepteula -nobanner -u $SearchString

	if ($ThatHandle -like "*No matching handles*") {
		Write-Host "There are not handles matching '$SearchString'" -BackgroundColor Black -ForegroundColor red
		return
	}

	$ThatHandle | ForEach-Object {
		# can happen that it is empty??
		if ($_) {
			# Split by spaces
			$HandleSplit = $_ -split "\s+"

			$HandleObject = [PSCustomObject]@{
				"ProcessName" = $HandleSplit[0] # ProcessName
				"ProcessID"   = $HandleSplit[2] # ProcessID
				"AccessType"  =	$HandleSplit[4] # AccessType (File)
				"UserName"    =	$HandleSplit[5] # UserName (only if -u)
				"HandleID"    =	$HandleSplit[6] -replace ":" # HandleID?
				"FullName"    = $HandleSplit[7] # CompleteFileName
			}
			#$HandleObject
			$AllHandles += $HandleObject
		}
		else {
			Write-Verbose "Fetched empty result. Skip." -Verbose
		}
	}

	return $AllHandles
}

function Close-Handle {
	[CmdletBinding(SupportsShouldProcess = $True)]
	param(
		$Handle
	)
	
	$HandleExecutable = "$PSScriptRoot\handle.exe"

	if ($pscmdlet.ShouldProcess("$($_.FullName) (ID: $($_.ProcessID) | HandleID: $($_.HandleID) | User: $($_.UserName))", "Close Handle")) {
		try {
			Write-Verbose "Closing handle for process $($_.ProcessID) (handle: '$($_.HandleID)')"
			$Result = & $HandleExecutable -accepteula -nobanner -p $_.ProcessID -c $_.HandleID -y
			if ($Result -like "*Handle closed*") {
				Write-Host "Handle closed correctly"
				return $true
			}
			else {
				Write-Host "There might be a problem closing the handle: $Result" -ForegroundColor Red
				return $false
			}
		}
		catch {
			Write-Host "Error while closing handle: $($_.Exception.Message)" -ForegroundColor Red
			return $false
		}
		return $true
	}

	# it finished correctly, even though nothing happened
	return $true
}

function FindAndClose-Handle {
	[CmdletBinding(SupportsShouldProcess = $True)]
	param(
		$SearchString
	)

	$Handles = Get-Handle -SearchString $SearchString
	if ($Handles) {
		$Handles | ForEach-Object {
			Close-Handle -Handle $_ -WhatIf:$WhatIfPreference
		}
	}
 else {
		# message thrown by get-handle function
		return $false
	}
}