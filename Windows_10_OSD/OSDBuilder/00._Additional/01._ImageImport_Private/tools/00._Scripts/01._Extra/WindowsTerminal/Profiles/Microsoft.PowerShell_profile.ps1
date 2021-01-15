if (!(Get-PSSnapin | Where-Object { $_.Name -eq "quest.activeroles.admanagement" })) {
    Add-PSSnapin quest.activeroles.admanagement -ErrorAction SilentlyContinue
}

# Set Default Parameters
$PSDefaultParameterValues['Get-Help:ShowWindow'] = $true
$PSDefaultParameterValues['Send-MailMessage:From'] = "Kurth@$env:COMPUTERNAME.lokal"
$VerboseProfile = $false

function IsConsoleRunningElevated {
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $princ = New-Object System.Security.Principal.WindowsPrincipal($identity)
    return $princ.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Windows Terminal + Theming
if (!$env:WT_Session) {
    function global:prompt {
        $arrows = '>'
        if ($NestedPromptLevel -gt 0) {
            $arrows = $arrows * $NestedPromptLevel
        }
    
        # only last parent
        $currentDirectory = Split-Path (Get-Location) -Leaf

        $curUser = (Get-ChildItem Env:\USERNAME).Value
        $curComp = (Get-ChildItem Env:\COMPUTERNAME).Value
        Write-Host -NoNewLine $curUser -ForegroundColor Cyan
        Write-Host -NoNewLine "@" -ForegroundColor Cyan
        Write-Host -NoNewLine "[" -ForegroundColor Yellow
        Write-Host -NoNewLine ("{0:HH}:{0:mm}:{0:ss}" -f (Get-Date)) -ForegroundColor White
        Write-Host -NoNewLine "]" -ForegroundColor Yellow
        Write-Host -NoNewLine "-$(((Get-History -Count 1).ID + 1)) " -ForegroundColor Yellow
        Write-Host -NoNewLine "$currentDirectory" -ForegroundColor Cyan
        Write-Host -NoNewLine "$arrows" #-ForegroundColor Red
    
        if (IsConsoleRunningElevated) {
            $Admin = ""
        }
        else {
            $Admin = " (No Admin)"
        }

        #$host.UI.RawUI.WindowTitle = "PowerShell -- $curUser @ $curComp "
        $host.UI.RawUI.WindowTitle = "$([net.dns]::GetHostName()) $([string]::Join(".", ("$((Get-Host).Version)".Split(".")[0,1])))$Admin $(Get-Location)"
        #Write-VcsStatus
        return " "
    }
}

#Set-PSDebug -Strict 
if (Test-Path -Path "$PSScriptRoot\profile_scripts" -ErrorAction SilentlyContinue) {
    $Host.UI.RawUI.WindowTitle = "PROFILE: Loading scripts folder"

    Resolve-Path "$PSScriptRoot\profile_scripts\*.ps1" |
    Where-Object { -not ($_.ProviderPath.Contains(".Tests.")) } |
    Foreach-Object { . $_.ProviderPath }

    <#
    if (Test-Path -Path "$PSScriptRoot\profile_scripts\") {
        Get-ChildItem "$PSScriptRoot\profile_scripts\" -Recurse |
        Where-Object { ($_.Name -like "*.ps1") -and (-not($_.FullName.Contains(".Tests."))) -and (-not($_.FullName.Contains("TESTS"))) -and (-not($_.FullName.Contains("TaskScheduler"))) } |
        Foreach-Object { . $_.FullName }
    }
    #>
}

#region THEMES EINSTELLEN
# Delugia.Nerd.Font.Complete.ttf + Delugia.Nerd.Font.ttf
# Install-Module posh-git -Scope CurrentUser
# Install-Module oh-my-posh -Scope CurrentUser
# Man kann Einstellungen fuer die Themes setzen: $ThemeSettings, $GitPromptSettings
# Sp sieht man anhand von "$ThemeSettings.PromptSymbols.ElevatedSymbol", dass es im Admin laeuft oder nicht.
if (IsConsoleRunningElevated) {
    if ($env:WT_Session) {
        # Installation Ordner: $ThemeSettings.MyThemesLocation
        # Offizielle Themes:   https://github.com/JanDeDobbeleer/oh-my-posh#themes
        Set-Theme Agnoster

        # Versteckt den Namen, wenn Standard
        $DefaultUser = "Kurth"
    }
    else {
        # Bei mir (Arbeit) ist die Farbe der Argumente falsch.
        #Set-PSReadLineOption -Colors @{Parameter = 'Gray' }
    }
}
else {
    if ($env:WT_Session) {
        Set-Theme Agnoster
    }
    else {
        #Set-PSReadLineOption -Colors @{Parameter = 'Gray' }
    }
}
#endregion

#Set-Alias scrub Remove-Item -Option ReadOnly | Format-List #-Passthru | Format-List

if (Test-Path C:\ -ErrorAction SilentlyContinue) {
    Set-Location C:\
}

# Winget Argument Completer
Register-ArgumentCompleter -Native -CommandName winget -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)
    [Console]::InputEncoding = [Console]::OutputEncoding = $OutputEncoding = [System.Text.Utf8Encoding]::new()
    $Local:word = $wordToComplete.Replace('"', '""')
    $Local:ast = $commandAst.ToString().Replace('"', '""')
    winget complete --word="$Local:word" --commandline "$Local:ast" --position $cursorPosition | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}

function Backup-PowerShellHistory {
    # "$env:APPDATA\Microsoft\Windows\PowerShell\PSReadline\ConsoleHost_history.txt"
    # Current Session Log: Get-History

    [CmdLetBinding()]
    param([switch]$WhatIf)

    $PowerShellHistoryPath = (Get-PSReadlineOption).HistorySavePath
    if (!(Test-Path -Path "$PowerShellHistoryPath")) {
        Write-Verbose "PS history file '$PowerShellHistoryPath' not found."
        return
    }

    # *_history_202011.txt
    $LostItem = Get-Item -Path "$PowerShellHistoryPath"
    $NewHistoryName = "$($LostItem.BaseName)_$$$YessereryBackkpDa(ension)"
    $NewHistoryPath = "$($LostItem.Directory.FullName)\$NewHistoryName"

    if (Test-Path "$NewHistoryPath") {
        Write-Verbose "File '$NewHistoryPath' already exist."
        return
    }

    Copy-Item -Path "$PowerShellHistoryPath" -Destination "$NewHistoryPath"
}
Backup-PowerShellHistory -WhatIf:$false -Verbose:$VerboseProfile

# TODO: Shortcuts.ps1
function imf($name) { Import-Module $name -Force }

Set-Alias np $env:SystemRoot\notepad.exe
Set-Alias npp $env:ProgramFiles\Notepad++\notepad++.exe
Set-Alias edit $env:ProgramFiles\Notepad++\notepad++.exe