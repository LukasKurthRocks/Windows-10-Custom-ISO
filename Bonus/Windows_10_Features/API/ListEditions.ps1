# Get UUP Editions from UUPDump-API
function Get-UUPEditions {
	[CmdLetBinding()]
	param(
		$UpdateID,
		$LanguageCode
	)

	$BASE_UUP_URI = "https://api.uupdump.ml"

	#
	#  Get Editions for UUID and language!
	#
	# https://api.uupdump.ml/listeditions.php?updateID=e7f5c4e9-b130-47ff-9cb7-bc48544ea82b&lang=de-de
	try {
		$URI = "$BASE_UUP_URI/listeditions.php?updateID=$UpdateID&lang=$LanguageCode"
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
	
	if ($JSONResponse.editionFancyNames) {
		#$tEditions = $JSONResponse.editionList
		$tFancyNames = $JSONResponse.editionFancyNames
	}
 else {
		Write-Host "No edition tags found." -BackgroundColor Black -ForegroundColor Red
		throw "No edition tags found."
		return
	}

	$LatestUUPEditions = $tFancyNames.PSObject.Properties | foreach-object {
		[PSCustomObject]@{
			EditionCode = $_.Name
			EditionName = $_.Value
		}
	}

	Write-Verbose "$(($LatestUUPEditions | Measure-Object).Count) editions found."
	$LatestUUPEditions
}