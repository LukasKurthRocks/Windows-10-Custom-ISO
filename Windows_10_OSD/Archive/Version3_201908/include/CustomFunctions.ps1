# assemblies
[System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null

# return current line
$SCRIPT_LinesTotalString = "" + ($MyInvocation.MyCommand.ScriptBlock | Measure-Object -Line).Lines
function Get-CurrentLineNumber {
	#$MyInvocation.ScriptLineNumber
	("" + $MyInvocation.ScriptLineNumber).PadLeft($SCRIPT_LinesTotalString.Length, "0")
}
New-Alias -Name _LINE_ -Value Get-CurrentLineNumber �Description "Returns the current line number in a PowerShell script file."

# function to test for URIs
function Test-URI {
	[cmdletbinding(DefaultParameterSetName = "Default")]
	Param(
		[Parameter(Position = 0, Mandatory, HelpMessage = "Enter the URI path starting with HTTP or HTTPS",
			ValueFromPipeline, ValueFromPipelineByPropertyName)]
		[ValidatePattern( "^(http|https)://" )]
		[Alias("url")]
		[string]$URI,
		[Parameter(ParameterSetName = "Detail")]
		[Switch]$Detail,
		[ValidateScript( { $_ -ge 0 })]
		[int]$Timeout = 30
	)

	Begin {
		Write-Verbose -Message "Starting $($MyInvocation.Mycommand)" 
		Write-Verbose -message "Using parameter set $($PSCmdlet.ParameterSetName)" 
	} #close begin block

	Process {

		Write-Verbose -Message "Testing $uri"
		Try {
		 #hash table of parameter values for Invoke-Webrequest
		 $paramHash = @{
				UseBasicParsing  = $True
				DisableKeepAlive = $True
				Uri              = $uri
				Method           = 'Head'
				ErrorAction      = 'stop'
				TimeoutSec       = $Timeout
			}

			$test = Invoke-WebRequest @paramHash

		 if ($Detail) {
				$test.BaseResponse | 
				Select-Object ResponseURI, ContentLength, ContentType, LastModified,
				@{Name = "Status"; Expression = { $Test.StatusCode } }
		 } #if $detail
		 else {
				if ($test.statuscode -ne 200) {
					#it is unlikely this code will ever run but just in case
					Write-Verbose -Message "Failed to request $uri"
					write-Verbose -message ($test | out-string)
					$False
			 }
			 else {
					$True
			 }
		 } #else quiet

		}
		Catch {
			#there was an exception getting the URI
			write-verbose -message $_.exception
			if ($Detail) {
				#most likely the resource is 404
				$objProp = [ordered]@{
					ResponseURI   = $uri
					ContentLength = $null
					ContentType   = $null
					LastModified  = $null
					Status        = 404
				}
				#write a matching custom object to the pipeline
				New-Object -TypeName psobject -Property $objProp

			} #if $detail
			else {
				$False
			}
		} #close Catch block
	} #close Process block

	End {
		Write-Verbose -Message "Ending $($MyInvocation.Mycommand)"
	} #close end block
} #close Test-URI Function

# function to format URI request for having tables from HTML content.
function Get-WebTable {
	param(
		[Parameter(Mandatory = $true)]
		[Microsoft.PowerShell.Commands.HtmlWebResponseObject] $WebRequest,
	
		[Parameter(Mandatory = $true)]
		[int] $TableNumber
	)

	## Extract the tables out of the web request
	$tables = @($WebRequest.ParsedHtml.getElementsByTagName("TABLE"))
	$table = $tables[$TableNumber]
	$titles = @()
	$rows = @($table.Rows)

	## Go through all of the rows in the table
	foreach ($row in $rows) {
		$cells = @($row.Cells)
	
		## If we've found a table header, remember its titles
		if ($cells[0].tagName -eq "TH") {
			$titles = @($cells | ForEach-Object { ("" + $_.InnerText).Trim() })
			continue
		}

		## If we haven't found any table headers, make up names "P1", "P2", etc.
		if (!$titles) {
			$titles = @(1..($cells.Count + 2) | ForEach-Object { "P$_" })
		}

		## Now go through the cells in the the row. For each, try to find the
		## title that represents that column and create a hashtable mapping those
		## titles to content

		$resultObject = [Ordered] @{}

		for ($counter = 0; $counter -lt $cells.Count; $counter++) {
			$title = $titles[$counter]
			if (!$title) { continue }
		
			$resultObject[$title] = ("" + $cells[$counter].InnerText).Trim()
		}

		## And finally cast that hashtable to a PSCustomObject
		[PSCustomObject] $resultObject
	}
}

# Clearing Image from $MountPath
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

		# DISM might work better that the Dismount-WindowsImage step,
		# though both doing NEARLY the same.
		& {
			DISM /Unmount-Wim /MountDir:$MountPath /Discard /English /Quiet /NoRestart

			# There can be stale files if mounting a file has been aborted
			DISM /CleanUp-Wim /English /Quiet /NoRestart

			Write-Host "Dismount image returned exit code: $LASTEXITCODE"
		}

		Remove-Item -Path $MountPath -Recurse -Force -ErrorAction SilentlyContinue
	}
}

# Unmount loaded registry hives for registration
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
