# Get UUP Languages from UUPDump-API
function Get-UUPLanguages {
	[CmdLetBinding()]
	param(
		$UpdateID
	)

	$BASE_UUP_URI = "https://api.uupdump.ml"

	#
	#  Verify Languae selected!
	#
	# https://api.uupdump.ml/listlangs.php?updateID=e7f5c4e9-b130-47ff-9cb7-bc48544ea82b
	try {
		$URI = "$BASE_UUP_URI/listlangs.php?updateID=$UpdateID"
		Write-Verbose "Call API on '$URI'"
		$Response = Invoke-WebRequest -Uri $URI -UseBasicParsing -Verbose:$false
	}
 catch {
		Write-Host "Error on Lang: $($_.Exception.Message)" -BackgroundColor Black -ForegroundColor Red
		throw "Error on Lang: $($_.Exception.Message)"
		return
	}

	if (!$Response) {
		Write-Host "No response on request for language!" -BackgroundColor Black -ForegroundColor Red
		throw "No response on request for language!"
		return
	}

	if ($Response.Content) {
		$JSONContent = ($Response.Content | ConvertFrom-Json)
	}
 else {
		Write-Host "Empty language json content." -BackgroundColor Black -ForegroundColor Red
		throw "Empty language json content."
		return
	}

	if ($JSONContent.response) {
		$JSONResponse = $JSONContent.response
	}
 else {
		Write-Host "Empty language json response." -BackgroundColor Black -ForegroundColor Red
		throw "Empty language json response."
		return
	}
	
	if ($JSONResponse.langFancyNames) {
		#$tEditions = $JSONResponse.langList
		$tFancyNames = $JSONResponse.langFancyNames
	}
 else {
		Write-Host "No edition tags found." -BackgroundColor Black -ForegroundColor Red
		throw "No edition tags found."
		return
	}

	$LatestUUP_Languages = $tFancyNames.PSObject.Properties | ForEach-Object {
		[PSCustomObject]@{
			LanguageCode = $_.Name
			LanguageName = $_.Value
		}
	}

	Write-Verbose "$(($LatestUUP_Languages | Measure-Object).Count) languages found."
	$LatestUUP_Languages	
}