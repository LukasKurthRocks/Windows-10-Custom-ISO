# https://osdbuilder.osdeploy.com/docs/osbuild/new-osbuildtask/winpe-content-parameters/contentwinpedart
# https://github.com/W4RH4WK/Debloat-Windows-10/blob/master/scripts/remove-default-apps.ps1

# Other Approach with extarcted FOD/Language ISOs
# https://osdbuilder.osdeploy.com/docs/multilang/osbuild-task
[CmdLetBinding()]
param()

#region OSImport
$SavedVerbosePreference = $VerbosePreference
$VerbosePreference = [System.Management.Automation.ActionPreference]::SilentlyContinue
# Remove OSBuilder (without the D)
if (Get-Module -Name OSBuilder -ListAvailable -ErrorAction SilentlyContinue -Verbose:$false) {
    Uninstall-Module OSBuilder -AllVersions -Force -Verbose:$false
}

# Import OSDBuilder Module
if (!(Get-Module -Name OSDBuilder -ErrorAction SilentlyContinue -Verbose:$false)) {
    Import-Module -Name OSDBuilder -Force -Verbose:$false
}

# Install OSDBuilder Module
if (!(Get-Module -Name OSDBuilder -ListAvailable -ErrorAction SilentlyContinue -Verbose:$false)) {
    # Uninstall-Module -Name OSDBuilder -AllVersions -Force
    Install-Module -Name OSDBuilder -Force -Verbose:$false
    Import-Module -Name OSDBuilder -Force -Verbose:$false
}
$VerbosePreference = $SavedVerbosePreference
#endregion

#region Enable/Disable/Remove vars
# https://github.com/W4RH4WK/Debloat-Windows-10/blob/master/scripts/remove-default-apps.ps1
$RemoveAppx = @(
    # default Windows 10 apps
    "Microsoft.3DBuilder"
    "Microsoft.Appconnector"
    "Microsoft.BingFinance"
    "Microsoft.BingMaps"
    "Microsoft.BingNews"
    "Microsoft.BingSports"
    "Microsoft.BingTranslator"
    "Microsoft.BingWeather"
    #"Microsoft.FreshPaint"
    "Microsoft.GamingServices"
    "Microsoft.Media.PlayReadyClient.2"
    "Microsoft.Microsoft3DViewer"
    "Microsoft.MicrosoftOfficeHub"
    "Microsoft.MicrosoftPowerBIForWindows"
    "Microsoft.MicrosoftSolitaireCollection"
    #"Microsoft.MicrosoftStickyNotes"
    "Microsoft.MinecraftUWP"
    "Microsoft.NetworkSpeedTest"
    "Microsoft.Office.OneNote"
    "Microsoft.People"
    "Microsoft.Print3D"
    "Microsoft.SkypeApp"
    "Microsoft.Wallet"
    #"Microsoft.Windows.Photos"
    "Microsoft.WindowsAlarms"
    #"Microsoft.WindowsCalculator"
    #"Microsoft.WindowsCamera"
    "microsoft.windowscommunicationsapps"
    "Microsoft.WindowsMaps"
    "Microsoft.WindowsPhone"
    "Microsoft.WindowsSoundRecorder"
    "Microsoft.WinJS.1.0"
    "Microsoft.WinJS.2.0"
    "Microsoft.Xbox.TCUI"
    "Microsoft.XboxApp"
    "Microsoft.XboxGameOverlay"
    "Microsoft.XboxGamingOverlay"
    "Microsoft.XboxSpeechToTextOverlay"
    #"Microsoft.YourPhone"
    "Microsoft.ZuneMusic"
    "Microsoft.ZuneVideo"

    # Threshold 2 apps
    "Microsoft.CommsPhone"
    "Microsoft.ConnectivityStore"
    "Microsoft.GetHelp"
    "Microsoft.Getstarted"
    "Microsoft.Messaging"
    "Microsoft.Office.Sway"
    "Microsoft.OneConnect"
    "Microsoft.WindowsFeedbackHub"

    # Creators Update apps
    "Microsoft.Microsoft3DViewer"
    #"Microsoft.MSPaint"

    #Redstone apps
    "Microsoft.BingFoodAndDrink"
    "Microsoft.BingHealthAndFitness"
    "Microsoft.BingTravel"
    "Microsoft.WindowsReadingList"

    # Redstone 5 apps
    "Microsoft.MixedReality.Portal"
    #"Microsoft.ScreenSketch"
    "Microsoft.XboxGamingOverlay"
    #"Microsoft.YourPhone"

    # non-Microsoft
    "2414FC7A.Viber"
    "2FE3CB00.PicsArt-PhotoStudio"
    "41038Axilesoft.ACGMediaPlayer"
    "46928bounde.EclipseManager"
    "4DF9E0F8.Netflix"
    "613EBCEA.PolarrPhotoEditorAcademicEdition"
    "64885BlueEdge.OneCalendar"
    "6Wunderkinder.Wunderlist"
    "7EE7776C.LinkedInforWindows"
    "828B5831.HiddenCityMysteryofShadows"
    "89006A2E.AutodeskSketchBook"
    "9E2F88E3.Twitter"
    "A278AB0D.DisneyMagicKingdoms"
    "A278AB0D.DragonManiaLegends"
    "A278AB0D.MarchofEmpires"
    "ActiproSoftwareLLC.562882FEEB491" # Code Writer from Actipro Software LLC
    "AD2F1837.GettingStartedwithWindows8"
    "AD2F1837.HPJumpStart"
    "AD2F1837.HPRegistration"
    "AdobeSystemsIncorporated.AdobePhotoshopExpress"
    "Amazon.com.Amazon"
    "C27EB4BA.DropboxOEM"
    "CAF9E577.Plex"  
    "ClearChannelRadioDigital.iHeartRadio"
    "CyberLinkCorp.hs.PowerMediaPlayer14forHPConsumerPC"
    "D52A8D61.FarmVille2CountryEscape"
    "D5EA27B7.Duolingo-LearnLanguagesforFree"
    "DB6EA5DB.CyberLinkMediaSuiteEssentials"
    "DolbyLaboratories.DolbyAccess"
    "Drawboard.DrawboardPDF"
    "Facebook.Facebook"
    "Fitbit.FitbitCoach"
    "flaregamesGmbH.RoyalRevolt2"
    "Flipboard.Flipboard"
    "GAMELOFTSA.Asphalt8Airborne"
    "KeeperSecurityInc.Keeper"
    "king.com.*"
    "king.com.BubbleWitch3Saga"
    "king.com.CandyCrushFriends"
    "king.com.CandyCrushSaga"
    "king.com.CandyCrushSodaSaga"
    "king.com.FarmHeroesSaga"
    "NORDCURRENT.COOKINGFEVER"
    "PandoraMediaInc.29680B314EFC2"
    "Playtika.CaesarsSlotsFreeCasino"
    "PricelinePartnerNetwork.Booking.comBigsavingsonhot"
    "ShazamEntertainmentLtd.Shazam"
    "SlingTVLLC.SlingTV"
    "SpotifyAB.SpotifyMusic"
    #"TheNewYorkTimes.NYTCrossword"
    "ThumbmunkeysLtd.PhototasticCollage"
    "TuneIn.TuneInRadio"
    "WinZipComputing.WinZipUniversal"
    "XINGAG.XING"

    # apps which cannot be removed using Remove-AppxPackage
    #"Microsoft.BioEnrollment"
    #"Microsoft.MicrosoftEdge"
    #"Microsoft.Windows.Cortana"
    #"Microsoft.WindowsFeedback"
    #"Microsoft.XboxGameCallableUI"
    #"Microsoft.XboxIdentityProvider"
    #"Windows.ContactSupport"

    # apps which other apps depend on
    #"Microsoft.Advertising.Xaml"

    # Remove Windows Store
    #"Microsoft.DesktopAppInstaller"
    #"Microsoft.Services.Store.Engagement"
    #"Microsoft.StorePurchaseApp"
    #"Microsoft.WindowsStore" # can not be re-installed
)

# Read from the JSON when used this script with "-RemoveAppx"
# Deactivated "2019" Apps. Compability reasons.
$RemoveAppxProvisionedPackage_2009 = @(
    # Cortana, see: https://docs.microsoft.com/en-us/answers/questions/33283/remove-cortana-offline-remove-appxprovisionedpacka.html
    #"Microsoft.549981C3F5F10_1.1911.21713.0_neutral_~_8wekyb3d8bbwe" # Cortana
    "Microsoft.BingWeather_4.25.20211.0_neutral_~_8wekyb3d8bbwe"
    #"Microsoft.DesktopAppInstaller_2019.125.2243.0_neutral_~_8wekyb3d8bbwe"
    "Microsoft.GetHelp_10.1706.13331.0_neutral_~_8wekyb3d8bbwe"
    "Microsoft.Getstarted_8.2.22942.0_neutral_~_8wekyb3d8bbwe"
    #"Microsoft.HEIFImageExtension_1.0.22742.0_x64__8wekyb3d8bbwe"
    "Microsoft.Microsoft3DViewer_6.1908.2042.0_neutral_~_8wekyb3d8bbwe"
    "Microsoft.MicrosoftOfficeHub_18.1903.1152.0_neutral_~_8wekyb3d8bbwe"
    "Microsoft.MicrosoftSolitaireCollection_4.4.8204.0_neutral_~_8wekyb3d8bbwe"
    #"Microsoft.MicrosoftStickyNotes_3.6.73.0_neutral_~_8wekyb3d8bbwe"
    "Microsoft.MixedReality.Portal_2000.19081.1301.0_neutral_~_8wekyb3d8bbwe"
    #"Microsoft.MSPaint_2019.729.2301.0_neutral_~_8wekyb3d8bbwe"
    "Microsoft.Office.OneNote_16001.12026.20112.0_neutral_~_8wekyb3d8bbwe"
    #"Microsoft.People_2017.1006.1846.1000_neutral~_8wekyb3d8bbwe"
    #"Microsoft.People_2019.305.632.0_neutral_~_8wekyb3d8bbwe"
    #"Microsoft.ScreenSketch_2019.904.1644.0_neutral_~_8wekyb3d8bbwe"
    "Microsoft.SkypeApp_14.53.77.0_neutral_~_kzf8qxf38zg5c"
    "Microsoft.StorePurchaseApp_11811.1001.1813.0_neutral_~_8wekyb3d8bbwe"
    #"Microsoft.VCLibs.140.00_14.0.27323.0_x64__8wekyb3d8bbwe"
    #"Microsoft.VP9VideoExtensions_1.0.22681.0_x64__8wekyb3d8bbwe"
    "Microsoft.Wallet_2.4.18324.0_neutral_~_8wekyb3d8bbwe"
    #"Microsoft.WebMediaExtensions_1.0.20875.0_neutral_~_8wekyb3d8bbwe"
    #"Microsoft.WebpImageExtension_1.0.22753.0_x64__8wekyb3d8bbwe"
    #"Microsoft.Windows.Photos_2019.19071.12548.0_neutral_~_8wekyb3d8bbwe"
    #"Microsoft.WindowsAlarms_2017.920.157.1000_neutral~_8wekyb3d8bbwe"
    #"Microsoft.WindowsAlarms_2019.807.41.0_neutral_~_8wekyb3d8bbwe"
    #"Microsoft.WindowsCalculator_2020.1906.55.0_neutral_~_8wekyb3d8bbwe"
    #"Microsoft.WindowsCamera_2018.826.98.0_neutral_~_8wekyb3d8bbwe"
    "microsoft.windowscommunicationsapps_16005.11629.20316.0_neutral_~_8wekyb3d8bbwe"
    #"Microsoft.WindowsFeedbackHub_2019.1111.2029.0_neutral_~_8wekyb3d8bbwe"
    #"Microsoft.WindowsMaps_2017.1003.1829.1000_neutral~_8wekyb3d8bbwe"
    #"Microsoft.WindowsMaps_2019.716.2316.0_neutral_~_8wekyb3d8bbwe"
    #"Microsoft.WindowsSoundRecorder_2017.928.5.1000_neutral~_8wekyb3d8bbwe"
    #"Microsoft.WindowsSoundRecorder_2019.716.2313.0_neutral_~_8wekyb3d8bbwe"
    #"Microsoft.WindowsStore_11910.1002.513.0_neutral_~_8wekyb3d8bbwe"
    "Microsoft.Xbox.TCUI_1.23.28002.0_neutral_~_8wekyb3d8bbwe"
    "Microsoft.XboxApp_48.49.31001.0_neutral_~_8wekyb3d8bbwe"
    "Microsoft.XboxGameOverlay_1.46.11001.0_neutral_~_8wekyb3d8bbwe"
    "Microsoft.XboxGamingOverlay_2.34.28001.0_neutral_~_8wekyb3d8bbwe"
    "Microsoft.XboxIdentityProvider_12.50.6001.0_neutral_~_8wekyb3d8bbwe"
    "Microsoft.XboxSpeechToTextOverlay_1.17.29001.0_neutral_~_8wekyb3d8bbwe"
    #"Microsoft.YourPhone_2019.430.2026.0_neutral_~_8wekyb3d8bbwe"
    #"Microsoft.ZuneMusic_2019.19071.19011.0_neutral_~_8wekyb3d8bbwe"
    #"Microsoft.ZuneVideo_2019.19071.19011.0_neutral_~_8wekyb3d8bbwe"
)
$RemoveWindowsCapability_2009 = @(
    #"App.StepsRecorder~~~~0.0.1.0",
    #"App.Support.QuickAssist~~~~0.0.1.0",
    #"Browser.InternetExplorer~~~~0.0.11.0",
    #"DirectX.Configuration.Database~~~~0.0.1.0",
    #"Hello.Face.18967~~~~0.0.1.0",
    #"Hello.Face.Migration.18967~~~~0.0.1.0",
    #"Language.Basic~~~de-DE~0.0.1.0",
    #"Language.Handwriting~~~de-DE~0.0.1.0",
    #"Language.OCR~~~de-DE~0.0.1.0",
    #"Language.Speech~~~de-DE~0.0.1.0",
    #"Language.TextToSpeech~~~de-DE~0.0.1.0",
    #"MathRecognizer~~~~0.0.1.0",
    #"Media.WindowsMediaPlayer~~~~0.0.12.0",
    #"Microsoft.Windows.MSPaint~~~~0.0.1.0",
    #"Microsoft.Windows.Notepad~~~~0.0.1.0",
    #"Microsoft.Windows.PowerShell.ISE~~~~0.0.1.0",
    #"Microsoft.Windows.WordPad~~~~0.0.1.0",
    #"NetFX3~~~~",
    #"OneCoreUAP.OneSync~~~~0.0.1.0",
    #"OpenSSH.Client~~~~0.0.1.0",
    #"Print.Fax.Scan~~~~0.0.1.0",
    #"Windows.Client.ShellComponents~~~~0.0.1.0"
)
$RemoveWindowsPackage_2009 = @(
    #"Microsoft-OneCore-ApplicationModel-Sync-Desktop-FOD-Package~31bf3856ad364e35~amd64~~10.0.19041.487"
    #"Microsoft-OneCore-DirectX-Database-FOD-Package~31bf3856ad364e35~amd64~~10.0.19041.1"
    #"Microsoft-Windows-Client-LanguagePack-Package~31bf3856ad364e35~amd64~de-DE~10.0.19041.487"
    #"Microsoft-Windows-FodMetadata-Package~31bf3856ad364e35~amd64~~10.0.19041.1"
    #"Microsoft-Windows-Foundation-Package~31bf3856ad364e35~amd64~~10.0.19041.1"
    #"Microsoft-Windows-Hello-Face-Migration-Package~31bf3856ad364e35~amd64~~10.0.19041.1"
    #"Microsoft-Windows-Hello-Face-Package~31bf3856ad364e35~amd64~~10.0.19041.1"
    #"Microsoft-Windows-InternetExplorer-Optional-Package~31bf3856ad364e35~amd64~~11.0.19041.1"
    #"Microsoft-Windows-LanguageFeatures-Basic-de-de-Package~31bf3856ad364e35~amd64~~10.0.19041.1"
    #"Microsoft-Windows-LanguageFeatures-Handwriting-de-de-Package~31bf3856ad364e35~amd64~~10.0.19041.1"
    #"Microsoft-Windows-LanguageFeatures-OCR-de-de-Package~31bf3856ad364e35~amd64~~10.0.19041.1"
    #"Microsoft-Windows-LanguageFeatures-Speech-de-de-Package~31bf3856ad364e35~amd64~~10.0.19041.1"
    #"Microsoft-Windows-LanguageFeatures-TextToSpeech-de-de-Package~31bf3856ad364e35~amd64~~10.0.19041.1"
    #"Microsoft-Windows-MediaPlayer-Package~31bf3856ad364e35~amd64~~10.0.19041.487"
    #"Microsoft-Windows-MSPaint-FoD-Package~31bf3856ad364e35~amd64~~10.0.19041.1"
    #"Microsoft-Windows-MSPaint-FoD-Package~31bf3856ad364e35~amd64~de-DE~10.0.19041.1"
    #"Microsoft-Windows-MSPaint-FoD-Package~31bf3856ad364e35~wow64~~10.0.19041.1"
    #"Microsoft-Windows-MSPaint-FoD-Package~31bf3856ad364e35~wow64~de-DE~10.0.19041.1"
    #"Microsoft-Windows-NetFx3-OnDemand-Package~31bf3856ad364e35~amd64~~10.0.19041.1"
    #"Microsoft-Windows-Notepad-FoD-Package~31bf3856ad364e35~amd64~~10.0.19041.487"
    #"Microsoft-Windows-Notepad-FoD-Package~31bf3856ad364e35~amd64~de-DE~10.0.19041.487"
    #"Microsoft-Windows-Notepad-FoD-Package~31bf3856ad364e35~wow64~~10.0.19041.1"
    #"Microsoft-Windows-Notepad-FoD-Package~31bf3856ad364e35~wow64~de-DE~10.0.19041.1"
    #"Microsoft-Windows-PowerShell-ISE-FOD-Package~31bf3856ad364e35~amd64~~10.0.19041.1"
    #"Microsoft-Windows-PowerShell-ISE-FOD-Package~31bf3856ad364e35~amd64~de-DE~10.0.19041.1"
    #"Microsoft-Windows-PowerShell-ISE-FOD-Package~31bf3856ad364e35~wow64~~10.0.19041.1"
    #"Microsoft-Windows-PowerShell-ISE-FOD-Package~31bf3856ad364e35~wow64~de-DE~10.0.19041.1"
    #"Microsoft-Windows-Printing-WFS-FoD-Package~31bf3856ad364e35~amd64~~10.0.19041.487"
    #"Microsoft-Windows-Printing-WFS-FoD-Package~31bf3856ad364e35~amd64~de-DE~10.0.19041.487"
    #"Microsoft-Windows-QuickAssist-Package~31bf3856ad364e35~amd64~~10.0.19041.1"
    #"Microsoft-Windows-StepsRecorder-Package~31bf3856ad364e35~amd64~~10.0.19041.1"
    #"Microsoft-Windows-StepsRecorder-Package~31bf3856ad364e35~amd64~de-DE~10.0.19041.1"
    #"Microsoft-Windows-StepsRecorder-Package~31bf3856ad364e35~wow64~~10.0.19041.1"
    #"Microsoft-Windows-StepsRecorder-Package~31bf3856ad364e35~wow64~de-DE~10.0.19041.1"
    #"Microsoft-Windows-TabletPCMath-Package~31bf3856ad364e35~amd64~~10.0.19041.487"
    #"Microsoft-Windows-UserExperience-Desktop-Package~31bf3856ad364e35~amd64~~10.0.19041.487"
    #"Microsoft-Windows-WordPad-FoD-Package~31bf3856ad364e35~amd64~~10.0.19041.487"
    #"Microsoft-Windows-WordPad-FoD-Package~31bf3856ad364e35~amd64~de-DE~10.0.19041.1"
    #"Microsoft-Windows-WordPad-FoD-Package~31bf3856ad364e35~wow64~~10.0.19041.1"
    #"Microsoft-Windows-WordPad-FoD-Package~31bf3856ad364e35~wow64~de-DE~10.0.19041.1"
    #"OpenSSH-Client-Package~31bf3856ad364e35~amd64~~10.0.19041.487"
    #"Package_for_KB4562830~31bf3856ad364e35~amd64~~10.0.1.2"
    #"Package_for_KB4570334~31bf3856ad364e35~amd64~~19041.441.1.2"
    #"Package_for_RollupFix~31bf3856ad364e35~amd64~~19041.487.1.10"
)
#endregion

# They will get overwritten if existing

Write-Host "Starting multiple New-BuildTask ..."
<#>
Write-Host ">> Home"
New-OSBuildTask -TaskName "MultiLangBuild-Home" -AddContentPacks -DisableFeature -EnableFeature -EnableNetFX3 -RemoveAppx -RemoveCapability -RemovePackage

Write-Host ">> Professional"
New-OSBuildTask -TaskName "MultiLangBuild-Professional" -AddContentPacks -DisableFeature -EnableFeature -EnableNetFX3 -RemoveAppx -RemoveCapability -RemovePackage

Write-Host ">> Education"
New-OSBuildTask -TaskName "MultiLangBuild-Education" -AddContentPacks -DisableFeature -EnableFeature -EnableNetFX3 -RemoveAppx -RemoveCapability -RemovePackage

Write-Host ">> Enterprise"
New-OSBuildTask -TaskName "MultiLangBuild-Enterprise" -AddContentPacks -DisableFeature -EnableFeature -EnableNetFX3 -RemoveAppx -RemoveCapability -RemovePackage
#>


$Build = "1507" # 1507, 2009
$Editions = @(
    #"Home"
    "Professional"
    #"Education"
    #"Enterprise"
)
foreach ($Edition in $Editions) {
    Write-Host ">> $Edition"
    
    # Getting first matching OS for removing actual AppxPackages
    $OSImageName = Get-OSMedia | Where-Object { $_.MajorVersion -eq 10 -and $_.EditionID -eq $Edition -and $_.ReleaseID -eq $Build } | Sort-Object -Property CreationTime | Select-Object -First 1 -ExpandProperty FullName

    # Reading and looping through JSON
    $AppxJson = Get-Content -Path "$OSImageName\info\json\Get-AppxProvisionedPackage.json" | ConvertFrom-Json
    $AppxJson | Where-Object { $RemoveAppx -contains $_.DisplayName } | ForEach-Object {
        $PackageName = $_.PackageName

        # prevent double entries
        if ($RemoveAppxProvisionedPackage_2009 -notcontains $PackageName) {
            Write-Verbose "Adding '$PackageName' to RemoveAppx step ..." -Verbose
            $RemoveAppxProvisionedPackage_2009 += $PackageName
        }
    }
    
    $OSDTask_TaskName = "MultiLangBuild-$Build-$Edition"
    $OSDTask_CustomName = "MultiLangBuild-$Build-$Edition"

    # -OSMedia
    New-OSBuildTask -TaskName "$OSDTask_TaskName" -CustomName "$OSDTask_CustomName" -AddContentPacks -ContentLanguagePackages # -RemoveAppx -RemovePackage -RemoveCapability

    $OSDTasks_Folder = "$GetOSDBuilderHome\Tasks"

    # Change Settings via JSON
    $OSDTask_Home_JSON = Get-Content -Path "$OSDTasks_Folder\OSBuild $OSDTask_TaskName.json" | ConvertFrom-Json

    # TEST: Skipping packages when having errors.
    $SkipPackages = $false
    if (!$SkipPackages) {
        $OSDTask_Home_JSON.RemoveAppxProvisionedPackage = $null
        if (($RemoveAppxProvisionedPackage_2009 | Measure-Object).Count -ne 0) {
            $OSDTask_Home_JSON.RemoveAppxProvisionedPackage = $RemoveAppxProvisionedPackage_2009
        }

        $OSDTask_Home_JSON.RemoveWindowsCapability = $null
        if (($RemoveWindowsCapability_2009 | Measure-Object).Count -ne 0) {
            $OSDTask_Home_JSON.RemoveWindowsCapability = $RemoveWindowsCapability_2009
        }
    
        $OSDTask_Home_JSON.RemoveWindowsPackage = $null
        if (($RemoveWindowsPackage_2009 | Measure-Object).Count -ne 0) {
            $OSDTask_Home_JSON.RemoveWindowsPackage = $RemoveWindowsPackage_2009
        }
    }

    $OSDTask_Home_JSON | ConvertTo-Json | Out-File -FilePath "$OSDTasks_Folder\OSBuild $OSDTask_TaskName.json"
    # /end of JSON CHANGE
}