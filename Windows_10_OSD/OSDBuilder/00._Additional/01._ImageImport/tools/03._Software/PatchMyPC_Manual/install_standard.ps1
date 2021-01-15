Write-Host "Installing Standard Software Pack" -ForegroundColor Cyan

# save current tasks
$PreTasks = Get-ScheduledTask

# save current taskbar
$PreTaskbar = Get-Item -Path "$env:Appdata\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\*.*"

# silent and automated installationen
#Start-Process -FilePath "$PSScriptRoot\PatchMyPc.exe" -ArgumentList "/auto /s" -Wait

$StartTime = Get-Date
$Timeout = 120 # Should only take like 10 minutes
$Span = 0

$Process = Start-Process -FilePath "$PSScriptRoot\PatchMyPc.exe" -ArgumentList "/auto /s" -PassThru
while (!$Process.HasExited) {
	$Span = New-TimeSpan -Start $StartTime -End (Get-Date)
	Write-Host "PMPC still running, waiting for it to finish. ($Span <= $TimeOut min. | Time: $(Get-Date -Format "HH:mm:ss"))"

	if ($Span.Minutes -gt $Timeout) {
		Write-Host "Timout reached ($Timeout minutes). Breaking loop." -ForegroundColor Yellow
		break
	}
	
	Start-Sleep -Seconds 1
}

# save "changed" tasks
# wanted to "exclude" Avast
#$AfterTasks = Get-ScheduledTask
#Get-ScheduledTask | Where-Object {$_.TaskName -match (@("Avast","Adobe") -join "|")}
$AfterTasks = Get-ScheduledTask | Where-Object { $_.TaskName -notmatch (@("Avast") -join "|") }

# save "changed" taskbar
$AfterTaskbar = Get-Item -Path "$env:Appdata\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\*.*"

# comparing objects to disable afterwards
Compare-Object -ReferenceObject $PreTasks -DifferenceObject $AfterTasks | Where-Object { $_.SideIndicator -eq "=>" } | ForEach-Object {
	$_.InputObject | Disable-ScheduledTask -Verbose
}
Compare-Object -ReferenceObject $PreTasks -DifferenceObject $AfterTasks | Where-Object { $_.SideIndicator -eq "<=" } | ForEach-Object {
	Write-Host "Task changed after installation: $($_.InputObject.TaskName)" -ForegroundColor Yellow
}

# comparing objects to disable afterwards
Compare-Object -ReferenceObject $PreTaskbar -DifferenceObject $AfterTaskbar | Where-Object { $_.SideIndicator -eq "=>" } | ForEach-Object {
	Remove-Item -Path $_.InputObject.FullName -Force -Verbose
}
Compare-Object -ReferenceObject $PreTaskbar -DifferenceObject $AfterTaskbar | Where-Object { $_.SideIndicator -eq "<=" } | ForEach-Object {
	Write-Host "Taskbar changed after installation: $($_.InputObject.TaskName)" -ForegroundColor Yellow
}