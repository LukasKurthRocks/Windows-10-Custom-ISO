# assemblies
[System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null

# return current line
$SCRIPT_LinesTotalString = "" + ($MyInvocation.MyCommand.ScriptBlock | Measure-Object -Line).Lines
$SCRIPT_LinesTotalString = 1
#$SCRIPT_PaddingNumber    = 3
function Get-CurrentLineNumber {
	#$MyInvocation.ScriptLineNumber
	$MyInvocation.ScriptLineNumber.ToString().PadLeft($SCRIPT_LinesTotalString.Length, "0")
	#$MyInvocation.ScriptLineNumber.ToString().PadLeft($SCRIPT_PaddingNumber, "0")
}
# Cannot add two versions of this.
if (!(Get-Alias -Name _LINE_ -ErrorAction SilentlyContinue)) {
	New-Alias -Name _LINE_ -Value Get-CurrentLineNumber �Description "Returns the current line number in a PowerShell script file."
}
#function Get-LinePrefix {
#	$Line = $MyInvocation.ScriptLineNumber.ToString().PadLeft($PaddingNumber, "0")
#	"[$(Get-Date -Format "HH:mm:ss")|$Line]"
#}
#New-Alias -Name _LINEfPREF_ -Value Get-LinePrefix �Description "Returns the current line number in a PowerShell script file."

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
	[CmdLetBinding()]
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
		#[gc]::WaitForPendingFinalizers()

		#Start-Sleep -Seconds 5

		$OfflineRegistry = $OfflineRegistry -replace "Registry::" -replace "HKEY_LOCAL_MACHINE", "HKLM"
		$null = reg unload $OfflineRegistry # Result is language specific!
		Write-Verbose "Unloading registry '$OfflineRegistry' exited with: $LASTEXITCODE"

		# Result of reg unload is language specific!
		$ErrorCounter = 0
		$MAX_ERRORS = 20
		while (($LASTEXITCODE -ne 0) -and ($ErrorCounter -lt $MAX_ERRORS)) {
			$ErrorCounter++
			Start-Sleep -Seconds 1
			$null = reg unload $OfflineRegistry
			Write-Host "$LASTEXITCODE " -ForegroundColor Yellow -NoNewline
		}
		Write-Host ""
		if ($LASTEXITCODE -ne 0) {
			$RegistryProcess = Get-Process -Name Registry
			Write-Host "Could not unload registry at '$OfflineRegistry'. There might be some operations pending (Open registry process: $($RegistryProcess.ProcessName -join ", "))." -BackgroundColor Black -ForegroundColor Red
			#return $false
		}
	}
 else {
		Write-Verbose "No registry to unload at '$OfflineRegistry'"
	}
}

# Unmount MountPath + Unmount Registry + StopTranscript
function ScriptCleanUP {
	[CmdLetBinding()]
	param(
		[string]$MountPath,
		[switch]$OverrideWarning,
		[switch]$ClearAllMountedFolders,
		[switch]$ClearRegistryHives,
		$OfflineRegistry = @("Registry::HKEY_LOCAL_MACHINE\OFFLINE", "Registry::HKEY_LOCAL_MACHINE\OFDEFUSR"),
		$OfflineImagingFolder = "ROCKS.IMGFOLDER",
		[switch]$StopTranscript
	)

	if ($OfflineRegistry) {
		$OfflineRegistry | ForEach-Object {
			UnmountRegistry -OfflineRegistry $_
		}
	}

	if ($ClearRegistryHives) {
		# Unloading registry if possible.
		#-not BCD00000* COMPONENTS HARDWARE SAM Schema SECURITY SOFTWARE SYSTEM
		#{bf1a281b-ad7b-4476-ac95-f47682990ce7}C:/$ROCKS.UUP/ROCKS.IMGFOLDER/Windows/system32/config/SOFTWARE
		$RegistryHives = Get-ChildItem -Path "Registry::HKEY_LOCAL_MACHINE" | Where-Object { $_.Name -match "$OfflineImagingFolder" } | Select-Object -ExpandProperty Name
		foreach ($hive in $RegistryHives) {
			Write-Verbose "Unmounting hive: $hive"
			UnmountRegistry -OfflineRegistry "Registry::$hive" -Verbose
		}
	}
	
	if ($MountPath) {
		Clear-MountPath -MountPath $MountPath -OverrideWarning:$OverrideWarning -ClearAllMountedFolders:$ClearAllMountedFolders
	}

	if ($StopTranscript) {
		Stop-Transcript
	}
}

# Return info of WIM file, base on the "Source"-Path
function Get-WIMInfo {
	[CmdLetBinding()]
	param(
		#[Parameter(Mandatory=$true)]
		[ValidateScript( { if (Test-Path $_) { return $true }else { throw "SourcePath must be an existing filepath. Please put the windows source files somewhere and provide the complete source path." } })]
		$SourcePath,
		$SourceWIM
	)

	if ($SourcePath) {
		$InstallWIM_Location = "$SourcePath\install.wim"
	}
 else {
		$InstallWIM_Location = $SourceWIM
	}

	if (!(Test-Path -Path $InstallWIM_Location)) {
		Write-Host "No install.wim found in '$SourcePath'" -ForegroundColor Red
		return
	}

	# get base info of wim
	# english because this can change depending on system
	$WIMInfo = DISM /Get-WimInfo /WimFile:"$InstallWIM_Location" /English

	$IndexNumbers = $WIMInfo | Select-String "Index" | ForEach-Object {
		"$_".Split(":").Trim()[1]
	}

	$IndexNumbers | ForEach-Object {
		#$_
		#DISM /Get-WimInfo /WimFile:"$SourcePath\install.wim" /Index:$_ /English | Select-String "Index","Name","ServicePack Build","Edition"

		#$DISMInfo = @{}
		$DISMInfo = [PSCustomObject]@{}
		$DISMBaseInfo = DISM /Get-WimInfo /WimFile:"$InstallWIM_Location" /Index:$_ /English
		$DISMBaseInfo | ForEach-Object {
			#$_
			if ($_ -like "*:*") {
				#$Split = "$_".Split(":").Trim()
				$Split = ($_ -split ":", 2).Trim()

				# Languages are the last few lines
				# Watch our for Editions like "CoreSingleLanguage"
				if ($Split[0] -match "Language") {
					# Languages
					$LanguageLineNumber = ($DISMBaseInfo | Select-String "Language").LineNumber | Select-Object -Last 1

					# Putting this here because of the "CoreSingleLanguage"
					Write-Verbose "Language filter test. Line: $($LanguageLineNumber -join ", ") | LineResult: $(($DISMBaseInfo | Select-String "Language") -join ", ") | FirstSplit: $($Split[0])"

					# all entries de-DE,en-US,sv-SE
					$Languages = $DISMBaseInfo | Select-Object -Skip $LanguageLineNumber | Select-String "-" | ForEach-Object {
						"$_".Trim()
					}

					$Split[1] = $Languages -join ", "
				}

				# replace
				#if($DISMInfo[$Split[0]]) {
				#	$DISMInfo.Remove($Split[0])
				#}
				#$DISMInfo.Add($Split[0], $Split[1])

				if ($DISMInfo | Get-Member -Name "$($Split[0])") {
					$DISMInfo."$($Split[0])" = $Split[1]
				}
				else {
					$DISMInfo | Add-Member -MemberType NoteProperty -Name "$($Split[0])" -Value $Split[1]
				}
			}
		}

		<#
		Version           : 10.0.18362
		Details for image : C:\$ROCKS.UUP\aria\18362.1.190318-1202.19H1_RELEASE_CLIENTMULTI_X64FRE_DE-DE\sources\install.wim
		Index             : 4
		Name              : Windows 10 Pro N
		Description       : Windows 10 Pro N
		Size              : 13.920.868.868 bytes
		WIM Bootable      : No
		Architecture      : x64
		Hal               : <undefined>
		ServicePack Build : 1
		ServicePack Level : 0
		Edition           : ProfessionalN
		Installation      : Client
		ProductType       : WinNT
		ProductSuite      : Terminal Server
		System Root       : WINDOWS
		Directories       : 18939
		Files             : 85051
		Created           : 19.03.2019 - 15:27:55
		Modified          : 30.07.2019 - 14:15:38
		Languages         : de-DE (Default)
		#>
		#Architecture
		$DISMInfo | Select-Object "Index", "Name", "Edition", "Architecture", "Version", @{N = "Build"; E = { $_."ServicePack Build" } }, @{N = "Level"; E = { $_."ServicePack Level" } }, "Languages"
	} # /end index loop
} # /end Function

# Dism LOG with predefined variable
#$DISMSuccessRateLogFile = "$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_successrate.log"
function DismLog {
	[CmdLetBinding()]
	param(
		$ExitCode,
		$Operation,
		$Line
	)

	if (!(Test-Path -Path $DISMSuccessRateLogFile)) {
		"DISM Logging started. See '$UUP_LoggingPath' for more informations. These logs might be purged on the next iteration." | `
			Out-File -LiteralPath $DISMSuccessRateLogFile -Encoding UTF8 -Append
	}
	
	# Format saved: dd.MM.yyyy
	Write-Verbose "[$Line] DISM exited with 'LASTEXITCODE': $ExitCode (0x$([System.Convert]::ToString($LASTEXITCODE, 16)))"
	
	# This should be more like a template, as we cannot catch different results here.
	#if($ExitCode -ne 0) {
	#	Write-Host "[$Line] LASTEXITCODE: '$ExitCode' (0x$([System.Convert]::ToString($LASTEXITCODE, 16)))." -BackgroundColor Black -ForegroundColor Red
	#}

	"[$(Get-Date -Format "HH:mm:ss")] [$Line] DISM Exited: $ExitCode`t$Operation" | Out-File -LiteralPath $DISMSuccessRateLogFile -Encoding UTF8 -Append
}

# Used for settings in step 3.
# Read settings from *.ini files.
function Get-IniFile {
	[CmdLetBinding()]
	param(
		$FilePath
	)
	Write-Verbose "Getting content from '$(Resolve-Path $FilePath)'"
    
	#strip out comments that start with ; and blank lines
	$all = Get-Content -Path $FilePath | Where-Object { $_ -notmatch "^(\s+)?;|^\s*$" }
 
	$obj = New-Object -TypeName PSObject -Property @{}
	$hash = [ordered]@{}
 
	foreach ($line in $all) {
 
		Write-Verbose "Processing $line"
 
		if ($line -match "^\[.*\]$" -AND $hash.count -gt 0) {
			#has a hash count and is the next setting
			#add the section as a property
			write-Verbose "Creating section $section"
			Write-verbose ([pscustomobject]$hash | out-string)
			$obj | Add-Member -MemberType Noteproperty -Name $Section -Value $([pscustomobject]$Hash) -Force
			#reset hash
			Write-Verbose "Resetting hashtable"
			$hash = [ordered]@{}
			#define the next section
			$section = $line -replace "\[|\]", ""
			Write-Verbose "Next section $section"
		}
		elseif ($line -match "^\[.*\]$") {
			#Get section name. This will only run for the first section heading
			$section = $line -replace "\[|\]", ""
			Write-Verbose "New section $section"
		}
		elseif ($line -match "=") {
			#parse data
			$data = $line.split("=").trim()
			$hash.add($data[0], $data[1])    
		}
		else {
			#this should probably never happen
			Write-Warning "Unexpected line $line"
		}
 
	} #foreach
 
	#get last section
	if ($hash.count -gt 0) {
		Write-Verbose "Creating final section $section"
		Write-Verbose ([pscustomobject]$hash | Out-String)
		#add the section as a property
		$obj | Add-Member -MemberType Noteproperty -Name $Section -Value $([pscustomobject]$Hash) -Force
	}
 
	#write the result to the pipeline
	$obj
}

# Used in Step3
# Setting Registry Values
function Set-RegistryValue {
	[CmdLetBinding()]
	param($Path, $Name, $Value,
		[ValidateSet("String", "ExpandString", "Binary", "DWord", "MultiString", "QWord", "Unknown")]
		$ValueType = "DWORD"
	)

	#Write-Host "IS VERBOSE SET: $VerbosePreference" -BackgroundColor DarkRed -ForegroundColor White

	# Create "base-directory" or only the directory if name is not set.
	if (!(Test-Path $Path)) { $null = New-Item -ItemType Directory -Force -Path $Path }
	
	# Testing if $Name has a value.
	if ($Name -and ![String]::IsNullOrWhiteSpace($Name)) {
		# See if the key exists so we can update or re-create the key.
		# $VerbosePreference is NEEDED. Won't print message otherwise.
		$ExistingKey = Get-ItemProperty -Path "$Path" -Name "$Name" -ErrorAction SilentlyContinue
		if (($null -ne $ExistingKey) -and ($ExistingKey.Length -ne 0)) {
			try {
				$null = Set-ItemProperty $Path $Name $Value -Force -Verbose:$VerbosePreference
			}
			catch {
				Write-Host "Error while Set-Item: $($_.Exception.Message)" -BackgroundColor Black -ForegroundColor Red
			}
			#return $true
		}
		else {
			try {
				$null = New-ItemProperty -Path "$Path" -Name "$Name" -Value $Value -Force -PropertyType $ValueType -Verbose:$VerbosePreference
			}
			catch {
				Write-Host "Error while New-Item: $($_.Exception.Message)" -BackgroundColor Black -ForegroundColor Red
			}
			#return $false
		}
	}
 else {
		Write-Warning -Message "Only created the directory. KeyName is not existent ('$Name')."
	}
}

function ResetBase {
	[CmdLetBinding()]
	param(
		[ValidateScript( {
				if ( (Test-Path -Path $_) -or ($UUP_IMGMountPath -and (Test-Path -Path $UUP_IMGMountPath)) ) {
					$true
				}
				else {
					throw "No valid mounting path found."
				}
			})]
		$MountPath,
		[ValidateScript( {
				if ( (Test-Path -Path $_) -or ($UUP_LoggingPath -and (Test-Path -Path $UUP_LoggingPath)) ) {
					$true
				}
				else {
					throw "No valid logging path found."
				}
			})]
		$LoggingPath,
		[Parameter(Mandatory = $true)]
		$Line
	)

	# on of these paths SHOULD exist
	if (!$LoggingPath -or !(Test-Path -Path $LoggingPath)) {
		$LoggingPath = $UUP_LoggingPath
	}
	# on of these paths SHOULD exist
	if (!$MountPath -or !(Test-Path -Path $UUP_IMGMountPath)) {
		$MountPath = $UUP_IMGMountPath
	}
	if (!$Line) {
		# No Line?
		return
	}

	# Is reset base after updates required? Let's test that and then do it.
	Write-Verbose "[$Line] CleanUp /Analyze of '$MountPath' (Started: $(Get-Date -Format "HH:mm:ss"))."
	$DISM_CUResult = DISM /Image:$MountPath /Cleanup-Image /AnalyzeComponentStore /English /LogPath:$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_cleanup_image_analyze.log

	# Error on CleanUp /Analyze should not happen.
	# There is a cleanup function for this!
	if ($LASTEXITCODE -ne 0) {
		Write-Host "Error trying to clean-up." -BackgroundColor Black -ForegroundColor Red
		return
	}

	# Component Store Cleanup Recommended : Yes
	if (!$DISM_CUResult) {
		Write-Host "[$Line] Nothing recommended? I don't think so ($DISM_CUResult)." -BackgroundColor Black -ForegroundColor Red
		return
	}
	#$DISM_CURecommended = ($DISM_CUResult | Select-String "Component Store Cleanup Recommended").ToString().Split(":")[1].Trim() -eq "Yes"
	if ($DISM_CURecommendedBool) {
		Write-Host "[$Line] CleanUp of '$MountPath' because of recommendation '$DISM_CURecommendedBool' (Started: $(Get-Date -Format "HH:mm:ss"))."
		DISM /Image:$MountPath /Cleanup-Image /StartComponentCleanup /ResetBase /SPSuperseded /Quiet /NoRestart /English /LogPath:$UUP_LoggingPath\$(Get-Date -Format "yyMMdd-HHmmss-ffffff")_dism_cleanup.log
	}
 else {
		Write-Verbose "[$Line] No need for CleanUp of '$MountPath'."
	}
}

function Get-UrlRedirectionV1 {
	[CmdLetBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[String]$URL
	)
 
	Write-Verbose "Waiting for response of '$URL'"
	$request = [System.Net.WebRequest]::Create($URL)
	$request.AllowAutoRedirect = $false
	$response = $request.GetResponse()
 
	if ($response.StatusCode -eq "Found") {
		$response.GetResponseHeader("Location")
	}
}

function Get-UrlRedirectionV2 {
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory, ValueFromPipeline)] [Uri] $Url,
		[switch] $Enumerate,
		[int] $MaxRedirections = 50 # Use same default as [System.Net.HttpWebRequest]
	)

	process {
		try {

			if ($Enumerate) {
				# Enumerate the whole redirection chain, from input URL to ultimate target,
				# assuming the max. count of redirects is not exceeded.
				# We must walk the chain of redirections one by one.
				# If we disallow redirections, .GetResponse() fails and we must examine
				# the exception's .Response object to get the redirect target.
				$nextUrl = $Url
				$urls = @( $nextUrl.AbsoluteUri ) # Start with the input Uri
				$ultimateFound = $false
				# Note: We add an extra loop iteration so we can determine whether
				#       the ultimate target URL was reached or not.
				foreach ($i in 1..$($MaxRedirections + 1)) {
					Write-Verbose "Examining: $nextUrl"
					$request = [System.Net.HttpWebRequest]::Create($nextUrl)
					$request.AllowAutoRedirect = $False
					try {
						$response = $request.GetResponse()
						# Note: In .NET *Core* the .GetResponse() for a redirected resource
						#       with .AllowAutoRedirect -eq $False throws an *exception*.
						#       We only get here on *Windows*, with the full .NET Framework.
						#       We either have the ultimate target URL, or a redirection
						#       whose target URL is reflected in .Headers['Location']
						#       !! Syntax `.Headers.Location` does NOT work.
						$nextUrlStr = $response.Headers['Location']
						$response.Close()
						# If the ultimate target URL was reached (it was already
						# recorded in the previous iteration), and if so, simply exit the loop.
						if (-not $nextUrlStr) {
							$ultimateFound = $true
							break
						}
					}
					catch [System.Net.WebException] {
						# The presence of a 'Location' header implies that the
						# exception must have been triggered by a HTTP redirection 
						# status code (3xx). 
						# $_.Exception.Response.StatusCode contains the specific code
						# (as an enumeration value that can be case to [int]), if needed.
						# !! Syntax `.Headers.Location` does NOT work.
						$nextUrlStr = try { $_.Exception.Response.Headers['Location'] } catch {}
						# Not being able to get a target URL implies that an unexpected
						# error ocurred: re-throw it.
						if (-not $nextUrlStr) { Throw }
					}
					Write-Verbose "Raw target: $nextUrlStr"
					if ($nextUrlStr -match '^https?:') {
						# absolute URL
						$nextUrl = $prevUrl = [Uri] $nextUrlStr
					}
					else {
						# URL without scheme and server component
						$nextUrl = $prevUrl = [Uri] ($prevUrl.Scheme + '://' + $prevUrl.Authority + $nextUrlStr)
					}
					if ($i -le $MaxRedirections) { $urls += $nextUrl.AbsoluteUri }          
				}
				# Output the array of URLs (chain of redirections) as a *single* object.
				Write-Output -NoEnumerate $urls
				if (-not $ultimateFound) { Write-Warning "Enumeration of $Url redirections ended before reaching the ultimate target." }

			}
			else {
				# Resolve just to the ultimate target,
				# assuming the max. count of redirects is not exceeded.

				# Note that .AllowAutoRedirect defaults to $True.
				# This will fail, if there are more redirections than the specified 
				# or default maximum.
				$request = [System.Net.HttpWebRequest]::Create($Url)
				if ($PSBoundParameters.ContainsKey('MaxRedirections')) {
					$request.MaximumAutomaticRedirections = $MaxRedirections
				}
				$response = $request.GetResponse()
				# Output the ultimate target URL.
				# If no redirection was involved, this is the same as the input URL.
				$response.ResponseUri.AbsoluteUri
				$response.Close()

			}

		}
		catch {
			Write-Error $_ # Report the exception as a non-terminating error.
		}
	} # process

}

# Could have gotten this myself, but was stuck with "[System.Net.WebRequest]".
# All it returned was "503, server not available" or something like that.
# Found in so; The shortest comment can sometimes just be on the point:
# https://stackoverflow.com/questions/45574479/powershell-determine-new-url-of-a-permanently-moved-redirected-resource
function Get-RedirectedURL {
	[CmdLetBinding()]
	param(
		[Parameter(Mandatory = $true)]
		[String]$URL
	)

	# Might not throw in catch when ignore, but need ignore for this to work.
	Write-Verbose "Waiting for response of '$URL'"
	try {
		$Response = Invoke-WebRequest -Method HEAD -Uri $URL -MaximumRedirection 0 -ErrorAction Ignore -Verbose:$false
	}
 catch {
		Write-Host "Error on '$URL': $($_.Exception.Message); $Response" -BackgroundColor Black -ForegroundColor Red
	}
	
	# 301 = Moved Permanently
	# 302 = Found (Moved Temporarily)
	$StatusCode = $Response.StatusCode
	if (@(301, 302) -contains $StatusCode) {
		$Location = $Response.Headers.Location
		Write-Verbose "> Server returned status '$StatusCode', found new location: $Location"
		$Location
	}
 elseif ($StatusCode -eq 429) {
		Write-Verbose "> Too many requests. Might wait before trying again."
	}
 else {
		Write-Verbose "> Returned $StatusCode`: $StatusCode"
	}
}