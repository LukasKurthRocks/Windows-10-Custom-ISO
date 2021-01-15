# Useful for Task Sequence!?

$Build = "1507" # 1507, 2009
$Editions = @(
    #"Home"
    "Professional"
    #"Education"
    #"Enterprise"
)
foreach ($Edition in $Editions) {
    Write-Host ">> $Edition"
    
    $OSDTask_TaskName = "MultiLangBuild-$Build-$Edition"
    
    # Not using -Download here!
    New-OSBuild -ByTaskName $OSDTask_TaskName -Execute -Verbose -SkipUpdates
}