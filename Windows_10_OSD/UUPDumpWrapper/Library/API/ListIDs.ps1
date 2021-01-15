# Get UUP Editions from UUPDump-API
function Get-UUPIDs {
	[CmdLetBinding()]
	param(
		$SearchQuery = "feat+windows+10+amd64"
	)

	$BASE_UUP_URI = "https://api.uupdump.ml"

	#
	#  Basic Information with UUID.
	#
	try {
		$URI = "$BASE_UUP_URI/listid.php?search=$SearchQuery&sortByDate=1"
		Write-Verbose "Call API on '$URI'"
		$Response = Invoke-WebRequest -Uri $URI -Verbose:$false
	}
 catch {
		Write-Host "Error on IDs: $($_.Exception.Message)" -BackgroundColor Black -ForegroundColor Red
		throw "Error on IDs: $($_.Exception.Message)"
		return
	}

	if (!$Response) {
		Write-Host "No response on request for ids!" -BackgroundColor Black -ForegroundColor Red
		throw "Error on IDs: $(No response on request for ids!)"
		return
	}

	if ($Response.Content) {
		$JSONContent = ($Response.Content | ConvertFrom-Json)
		Write-Verbose "INFO: `$JSONContent responded with JSONAPI version $($JSONContent.jsonApiVersion)."
		Write-Verbose "INFO: `$JSONContent responded with UUPAPI version $($JSONContent.response.apiVersion)."
	}
 else {
		Write-Host "Empty id json content." -BackgroundColor Black -ForegroundColor Red
		throw "Empty id json content."
		return
	}

	if ($JSONContent.response) {
		$JSONResponse = $JSONContent.response
	}
 else {
		Write-Host "Empty id json response." -BackgroundColor Black -ForegroundColor Red
		throw "Empty id json response."
		return
	}
	
	if ($JSONResponse.builds) {
		$PropertyValues = ($JSONResponse.builds | Get-Member -MemberType NoteProperty).Name
		$BuildUUIDs = $PropertyValues | ForEach-Object {
			$JSONResponse.builds."$_"
		}
	}
 else {
		Write-Host "No id build tags found." -BackgroundColor Black -ForegroundColor Red
		throw "No id build tags found."
		return
	}
	
	$LatestUUIDs = $BuildUUIDs | Sort-Object -Property created -Descending
	
	Write-Verbose "$(($LatestUUIDs | Measure-Object).Count) ids found."
	$LatestUUIDs
}