$Content = Get-Content C:\test.txt
$Sarr = @{}
$Bits = "X86"

$Content | ForEach-Object {
    if (!$Sarr["$Bits"]) {
        $Sarr["$Bits"] = @()
    }
    $Name, $Link, $NOTHING = $_.Split(" ")

    $Sarr["$Bits"] += [PSCustomObject]@{
        "Link" = $Link
        "Name" = "languagepack_$Name.cab"
    }
}

#$sarr
$sarr | ConvertTo-Json | Out-File -FilePath C:\test.json