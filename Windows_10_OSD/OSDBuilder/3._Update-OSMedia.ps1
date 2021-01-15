#
#  Updating imported medias (OSDBuilder)
#
# Last Switches: None / -Verbose

# Had Problems with Hyper-V after everything has been finished.
#
#

[CmdLetBinding()]
param([switch]$manual)

# 1. Skip Updates
Get-OSMedia -GridView | ForEach-Object { Update-OSMedia -Name $_.Name -SkipUpdates -SkipUpdatesPE -Execute }

return
if ($manual) {
    Get-OSMedia -GridView | ForEach-Object { Update-OSMedia -Download -Execute -Name $_.Name }
}
else {
    Get-OSMedia | Where-Object { $_.Revision -eq 'OK' -and $_.Updates -eq 'Update' } | ForEach-Object { Update-OSMedia -Download -Execute -Name $_.Name }
}