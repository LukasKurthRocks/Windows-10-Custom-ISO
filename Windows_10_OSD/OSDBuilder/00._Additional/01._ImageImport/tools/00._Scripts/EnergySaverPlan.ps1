Write-Host "PowerPlan Customization" -ForegroundColor Cyan

# list schemes
powercfg /l

# high performance
powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c

# tweaks the basic power settings
powercfg -change -hibernate-timeout-ac 0
powercfg -change -hibernate-timeout-dc 0 

# turns hibernation off
powercfg -hibernate OFF 

Write-Host "Done." -ForegroundColor Cyan