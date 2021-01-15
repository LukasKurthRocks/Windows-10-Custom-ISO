# Get UUP Editions from UUPDump-API
function Get-UUPFiles {
	[CmdLetBinding()]
	param(
		$UpdateID,
		$LanguageCode,
		$EditionCode,
		[switch]$allFiles,
		[switch]$NoLinks # TODO
	)

	$BASE_UUP_URI = "https://api.uupdump.ml"

	#
	#  Get Editions for UUID and language!
	#
	# https://api.uupdump.ml/get.php?id=e7f5c4e9-b130-47ff-9cb7-bc48544ea82b&lang=de-de&edition=PROFESSIONALN # &noLinks=1
	try {
		if ($allFiles) {
			$URI = "$BASE_UUP_URI/get.php?id=$UpdateID"
		}
		else {
			$URI = "$BASE_UUP_URI/get.php?id=$UpdateID&lang=$LanguageCode&Edition=$EditionCode"
		}
		
		Write-Verbose "Call API on '$URI'"
		$Response = Invoke-WebRequest -Uri $URI -UseBasicParsing -Verbose:$false
	}
 catch {
		Write-Host "Error on Edition: $($_.Exception.Message)" -BackgroundColor Black -ForegroundColor Red
		throw "Error on Edition: $($_.Exception.Message)"
		return
	}

	if (!$Response) {
		Write-Host "No response on request for edition!" -BackgroundColor Black -ForegroundColor Red
		throw "No response on request for edition!"
		return
	}

	if ($Response.Content) {
		$JSONContent = ($Response.Content | ConvertFrom-Json)
	}
 else {
		Write-Host "Empty edition json content." -BackgroundColor Black -ForegroundColor Red
		throw "Empty edition json content."
		return
	}

	if ($JSONContent.response) {
		$JSONResponse = $JSONContent.response
	}
 else {
		Write-Host "Empty edition json response." -BackgroundColor Black -ForegroundColor Red
		throw "Empty edition json response."
		return
	}
	
	Write-Verbose "Gathering file list for '$($JSONResponse.updateName)' on arch '$($JSONResponse.arch)'..."
	if ($JSONResponse.files -and ($JSONResponse.files | Measure-Object).Count -ne 0) {
		$UUPFiles = $JSONResponse.files

		$PropertyValues = ($UUPFiles | Get-Member -MemberType NoteProperty).Name
		$BuildUUIDs = $PropertyValues | ForEach-Object {
			[PSCustomObject]@{
				FileName = $_
				FileData = $UUPFiles."$_"
			}
		}
	}
 else {
		Write-Host "Could not gather files for '$($JSONResponse.updateName)'." -BackgroundColor Black -ForegroundColor Red
		throw "Could not gather files for '$($JSONResponse.updateName)'."
		return
	}
	
	Write-Verbose "$(($BuildUUIDs | Measure-Object).Count) files found. Access properties via `$_.FileName and `$_.FileData."
	$BuildUUIDs
}