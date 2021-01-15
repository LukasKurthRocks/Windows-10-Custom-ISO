# Copying files into here, when changing files in C:\OSDBuilder

$SourceFolder = "C:\OSDBuilder"
$DestinationFolder = "$PSScriptRoot\Files"

[Flags()] Enum RoboCopyExitCodes {
    NoChange = 0
    OKCopy = 1
    ExtraFiles = 2
    MismatchedFilesFolders = 4
    FailedCopyAttempts = 8
    FatalError = 16
}

# Excluding big os folders (ISO, ImageFiles etc.). Everyone needs to import them for themselfes.
# INFO: /E = Copy all subfolders, /S = Copy all subfolders - except empty folders.
Robocopy.exe "$SourceFolder" "$DestinationFolder" /S /NDL /XD OSBuilds OSImport OSMedia

# filter robocopy results
switch ($LASTEXITCODE) {
    { 0, 1, 2, 3 } { Write-Verbose "Robocopy exited with: $([RoboCopyExitCodes]$_) ($_). Will continue with the script..." }
    default {
        Write-Host "[$(_LINE_)] 'Robocopy' exited with an error: $([RoboCopyExitCodes]$_) ($_)." -BackgroundColor Black -ForegroundColor Red
        break
    }
}