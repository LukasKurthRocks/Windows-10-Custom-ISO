$Sarr = @{}
$Bits = "X64"

$Content = Get-Content C:\test.txt
$Content | ForEach-Object {
    #$_
    try {
        $SubHTTP = $_.IndexOf("http")
        $SubREL = $_.IndexOf(".cab")
        $Sub2_TDa = $_.IndexOf("<td>") # 173
        $Sub2_TDe = $_.LastIndexOf("</td>")
    }
    catch {
        $BitsNum += 1
        Write-Host "ERROR"
        return
    }

    $Link = $_.SubString($SubHTTP, $SubREL).Trim()
    $Name = $_.SubString($Sub2_TDa + 4, $Sub2_TDe - $Sub2_TDa - 4)
    
    if (!$Sarr[$Bits]) {
        $Sarr[$Bits] = @()
    }
    $Sarr[$Bits] += [PSCustomObject]@{
        "Link" = $Link
        "Name" = "languagepack_$Name.cab"
    }
}
$sarr | convertto-json | Out-FIle -FilePath C:\test.json

return
$Sarr = @{}
$Content | ForEach-Object {
    if ([String]::IsNullOrEmpty($_)) {
        Write-Host "Empty line: '$_'"
        return
    }
    $a, $b, $c, $d = $_.Split(" ")
    $b = $b -replace "[\*]"
    $c = $c -replace "langpacks[\\]"

    #Write-Verbose "Add $b" -Verbose
    if (!$Sarr["$b"]) {
        $Sarr["$b"] = @()
    }
    $Sarr["$b"] += [PSCustomObject]@{
        "Link" = $a
        "Name" = "languagepack_$c.cab"
    }
}

$sarr | ConvertTo-Json | Out-File -FilePath C:\test.json
