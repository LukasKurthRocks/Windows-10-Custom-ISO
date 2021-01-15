# Using UUP Dump "Downloader" stuff, but downloading uups myself.

param(
    [ValidateSet("amd64", "arm64", "x86")]
    $OSArch = $env:PROCESSOR_ARCHITECTURE,
    $searchString = "Windows 10 Insider*$OSArch",
    $OnlyLanguageEx = "de-DE|sv-SE|hu-HU|fr-FR|en-US",
    [switch]$IgnoreFreeSpaceCheck,
    $UUPDownloadFolder = "$PSScriptRoot\UUPs"
)

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
        if (-not $titles) {
            $titles = @(1..($cells.Count + 2) | ForEach-Object { "P$_" })
        }

        ## Now go through the cells in the the row. For each, try to find the
        ## title that represents that column and create a hashtable mapping those
        ## titles to content
        $resultObject = [Ordered] @{}

        for ($counter = 0; $counter -lt $cells.Count; $counter++) {
            $title = $titles[$counter]
            if (-not $title) { continue }
            
            $resultObject[$title] = ("" + $cells[$counter].InnerText).Trim()
        }

        ## And finally cast that hashtable to a PSCustomObject
        [PSCustomObject] $resultObject
    } 
}

Write-Verbose "fetching main URI" -Verbose
$Content = Invoke-WebRequest -Uri "https://uupdump.ml/known.php"
$OSDownloadLink = $Content.Links | Where-Object { !$_.class -and $_.innerText -like "*$searchString*" } | Select-Object -First 1

$null = $OSDownloadLink.href -match "=([\d\D]*)$"
$CollectionHash = $Matches[1]

$AllFilesLink = "https://uupdump.ml/findfiles.php?id=$CollectionHash&pack=0&q="

Write-Verbose "fetching sub URI" -Verbose
$AllFilesContent = Invoke-WebRequest -Uri $AllFilesLink
Write-Verbose "+generating table" -Verbose
$AllFilesTable = Get-WebTable -WebRequest $AllFilesContent -TableNumber 0

$AllFilesDownload = $AllFilesContent.Links

# "File","SHA-1","Size"
Write-Verbose "+excluding !($OnlyLanguageEx)" -Verbose
$ExcludeFiles = $AllFilesTable.File | Where-Object { ($_ -match "[\d\D]{2}-[\d\D]{2}([^a-z])") -and ($_ -notmatch $OnlyLanguageEx) }

#Write-Verbose "+filtering sub URI" -Verbose
#$FilesToDownload = $AllFilesTable | ? { $ExcludeFiles -notcontains $_.File }

if ($IgnoreFreeSpaceCheck) {
    Write-Verbose "+filtering sub URI" -Verbose
    $FilesToDownload = $AllFilesTable | Where-Object { $ExcludeFiles -notcontains $_.File }
}
else {
    Write-Verbose "+filtering sub URI with space check" -Verbose
    $FilesToDownload = ($AllFilesTable | Where-Object { $ExcludeFiles -notcontains $_.File } | Select-Object "File", "SHA-1", @{N = "Size"; E = {
                $Size = $_.Size
                switch -Wildcard ($Size) {
                    "*KiB*" { [Double]($_ -replace "[ ][\w]*") * 1024 }
                    "*MiB*" { [Double]($_ -replace "[ ][\w]*") * 1024 * 1024 }
                    "*GiB*" { [Double]($_ -replace "[ ][\w]*") * 1024 * 1024 * 1024 }
        
                    default { Write-Host "!MiB,KiB||GiB" }
                }
            }
        })


    function Get-FriendlySize {
        param($Bytes)
        $sizes = 'Bytes,KB,MB,GB,TB,PB,EB,ZB' -split ','
        for ($i = 0; ($Bytes -ge 1kb) -and 
            ($i -lt $sizes.Count); $i++) { $Bytes /= 1kb }
        $N = 2; if ($i -eq 0) { $N = 0 }
        "{0:N$($N)} {1}" -f $Bytes, $sizes[$i]
    }

    Write-Verbose "printing..." -Verbose
    $TotalFileSizeInBytes = ($FilesToDownloadSizeInBytes.Size | Measure-Object -Sum).Sum
    $TotalFileSize = Get-FriendlySize -Bytes $TotalFileSizeInBytes
    
    # if "You do not have enough free space to download."
    <#
    Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='C:'" | Foreach-Object {
        $Size = Get-FriendlySize -Bytes $_.Size
        $FreeSpace = Get-FriendlySize -Bytes $_.FreeSpace
        
        "$($Size) -> $($FreeSpace)"
    }
    #>

    $MainDriveFreeSpace = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'" | Select-Object Size, FreeSpace, @{Name = "FriendlySize"; E = { Get-FriendlySize -Bytes $_.Size } }, @{Name = "FriendlyFreeSpace"; E = { Get-FriendlySize -Bytes $_.FreeSpace } }

    if ($MainDriveFreeSpace.FriendlyFreeSpace -le $TotalFileSizeInBytes) {
        Write-Host "$($MainDriveFreeSpace.FreeSpace) -le $TotalFileSizeInBytes | $($MainDriveFreeSpace.FriendlyFreeSpace) -le $TotalFileSize" -ForegroundColor Red
        return
    }
    else {
        Write-Host "$($MainDriveFreeSpace.FreeSpace) -gt $TotalFileSizeInBytes | $($MainDriveFreeSpace.FriendlyFreeSpace) -gt $TotalFileSize" -ForegroundColor Yellow
    }

    $FilesToDownload | Select-Object -First 1 | ForEach-Object {
        $AllFilesDownload | Where-Object { $_.innerText -match $File } | ForEach-Object {
            Write-Host ">> Download: $($_.innerText)" -ForegroundColor Cyan
            $Link = "https://uupdump.ml/$($_.href -replace "./")"
            $Link -match "(;file=)([\w]*)([.][\w]*)$"
            $FileName = "$($Matches[2])$($Matches[3])"
            $FileName

            Invoke-WebRequest -Uri $Link -OutFile "$UUPDownloadFolder\$FileName" -Verbose


            #[System.IO.Path]::GetFileNameWithoutExtension($Link)
            #[System.IO.Path]::GetExtension($Link)

            $_
        }
    }
}

# https://uupdump.ml/findfiles.php?id=f25a2976-28dc-48bf-b641-d2cad0b6b0b1&pack=0&q=
# https://uup.rg-adguard.net/api/GetFiles?id=f25a2976-28dc-48bf-b641-d2cad0b6b0b1&lang=de-de&edition=all&txt=yes