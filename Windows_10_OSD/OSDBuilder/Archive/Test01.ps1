#OSDBuilder -SetHome $PSScriptRoot
#Show-OSDBuilderInfo #-FullName ""
#$GetOSDBuilder
#$SetOSDBuilder | ConvertTo-Json | Out-File -FilePath "C:\OSDBuilder\OSDBuilder.json"
#Initialize-OSDBuilder -Verbose # Importing JSON File from root or "OSBUilder -Initialize"
#Import-OSMedia # taking only the enterprise images if selected in json
# global options, so updates all in same place (not downloading multiple times)

#Update-OSMedia
#Update-OSMedia -ShowHiddenOSMedia # wenn alle updates etc.
#Update-OSMedia -Download
#OSDbuilder -Download OSMediaUpdates # FeatureUpdates # downloads whats needed

#Get-OSDBuilder
#Get-OSMedia # Piping into Update-PSMedia etc. # => Automation

# Customized ISO
#Task always follows the latest version of the os.
#New-OSBuildTask -AddContentPacks -DisableFeature -EnableFeature -EnableNetFX3 -RemoveAppx -RemoveCapability -RemovePackage
#New-OSBuild -SkipUpdates -SkipComponentCleanup # faster without updates => better for testing customization

# Content Packs
#New-OSDBuilderContentPack -Name "MultiLang 1903 EN" -ContentType All