# It seems that only files named like "Microsoft-Windows-<Language>-Package~31bf3856ad364e35~amd64~~.cab" will be added by DISM.
# So, no version number at the end and the hashvalue between the tildes.
# I can get this number from the *.cat inside the *.cab file.

[CmdLetBinding()]
param()

#$Folder = "C:\OSDBuilder\ContentPacks\MultiLang DE\OSLanguageFeatures\2009 x64"
#$Folder = "C:\OSDBuilder\ContentPacks\MultiLang EN\OSLanguageFeatures\2009 x64"
#$Folder = "C:\OSDBuilder\ContentPacks\MultiLang SE\OSLanguageFeatures\2009 x64"
#$Folder = "C:\OSDBuilder\ContentPacks\MultiLang HU\OSLanguageFeatures\2009 x64"
#$Folder = "C:\OSDBuilder\ContentPacks\MultiLang FR\OSLanguageFeatures\2009 x64"
#$Folder = "C:\OSDBuilder\ContentPacks\MultiLang NL\OSLanguageFeatures\2009 x64"
$Folder = "C:\OSDBuilder\ContentPacks\FOD RSAT MultiLang\OSCapability\2009 x64 RSAT"
if (!(Test-Path -Path "$Folder" -ErrorAction SilentlyContinue)) {
    Write-Host "Folder '$Folder' does not exist."
    return
}

# Finding all cabs, except the already renamed ones.
Get-ChildItem -Path $Folder -Filter "*.cab" | Where-Object { $_.Name -notlike "*~~*" } | ForEach-Object {
    # Extract cab to search for real name
    $CabExtractFolder = "$($_.Directory)\$($_.BaseName)"
    if (!(Test-Path -Path "$CabExtractFolder" -ErrorAction SilentlyContinue)) {
        $null = New-Item -Path "$CabExtractFolder" -ItemType Directory -Verbose
    }
    try {
        Write-Verbose "Extracting cab '$($_.FullName)' to '$($CabExtractFolder)' ..."
        
        # Only extract the cat files. Rest can lead to errors (maybe the total folder length of ~256 chars)
        expand $_.FullName -F:*.cat "$CabExtractFolder" # 2>NUL
    }
    catch {
        Write-Host "Error expanding archive: $($_.Exception.Message)" -ForegroundColor White -BackgroundColor DarkRed
    }

    # searching for cat for proper naming (removing the last version part), like in this thread.
    # https://www.ntlite.com/community/index.php?threads/how-to-add-integrate-language-pack-language-feature-pack-into-a-iso-via-ntlite.978/#post-10097
    #Microsoft-Windows-LanguageFeatures-Basic-en-us-Package~31bf3856ad364e35~amd64~~10.0.19041.1.cat
    #Microsoft-Windows-LanguageFeatures-Basic-en-us-Package~31bf3856ad364e35~amd64~~
    #$FolderName = (Get-Item $CabExtractFolder).Name -replace "[-](amd64|wow64|x86)"
    $FolderName = ((Get-Item $CabExtractFolder).Name -split "-")[0..7] -join "-"
    $OriginalCat = Get-ChildItem "$CabExtractFolder\$FolderName*amd64*.cat"

    if ($OriginalCat) {
        #$NewFileName = $OriginalCat.Name.Substring(0, $OriginalCat.Name.IndexOf("~~") + 2)
        $NewFileName = '{0}{1}' -f (($OriginalCat.Name -split "~")[0..3] -join "~"), "~"
        $NewFileDestination = "$($_.Directory)\$NewFileName.cab"
        if (Test-Path -Path "$NewFileDestination" -ErrorAction SilentlyContinue) {
            Write-Host "File '$NewFileDestination' does already exist." -ForegroundColor Green
        }
        else {
            Copy-Item $_.FullName $NewFileDestination
        }
    }
    else {
        Write-Host "Cat file not found in '$CabExtractFolder'!" -ForegroundColor Yellow
    }

    # remove the extracted folder CONTENTS
    Get-ChildItem -Path $CabExtractFolder -Recurse | ForEach-Object {
        try {
            Remove-Item -Path $_.FullName -Recurse -Force -ErrorAction Stop -Verbose:$false -WhatIf:$false
        }
        catch {
            Write-Host "Error expanding archive: $($_.Exception.Message)" -ForegroundColor White -BackgroundColor DarkRed
        }
    }

    # Al least trying to remove the extracted folder the files were extracted to.
    # This might not work. Please verify empty folders!!
    try {
        Write-Verbose "Recurse remove of '$CabExtractFolder' ..." -Verbose
        $null = Remove-Item -Path $CabExtractFolder -Recurse -Force -ErrorAction Stop -Verbose:$false -WhatIf:$false
    }
    catch {
        Write-Host "Error removing '$CabExtractFolder': $($_.Exception.Message)" -ForegroundColor White -BackgroundColor DarkRed
    }
    Write-Verbose "" -Verbose
}