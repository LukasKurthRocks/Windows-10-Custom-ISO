# Loading WIM Info from ISO\sources path

param(
	[Parameter(Mandatory = $true)]
	[ValidateScript( { if (Test-Path $_) { return $true }else { throw "SourcePath must be an existing filepath. Please put the windows source files somewhere and provide the complete source path." } })]
	$SourcePath
)

$InstallWIM_Location = "$SourcePath\install.wim"

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
			if ($Split[0] -match "Language") {
				$LanguageLineNumber = ($DISMBaseInfo | Select-String "Language").LineNumber

				# all entries de-DE,en-US,sv-SE
				$Languages = $DISMBaseInfo | Select-Object -Skip $LanguageLineNumber | Select-String "-" | ForEach-Object {
					"$_".Trim()
				}

				$Split[1] = $Languages -join ","
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
} | Format-Table
