# Windows-10-Builder

## Allgemeines
Hiermit lassen sich die Update-Dateien fetchen, wenn diese über Windows Update von Microsoft geladen werden. Ich brauche das nicht mehr und werde das auch nicht weiter fortführen. Normalerweise sollte man wohl die MS ISOs vom VS MSDN laden (Dev Account benötigt).

## Vorgehensweisen
### Voraussetzungen
- [OSDBuilder - Requirements](https://osdbuilder.osdeploy.com/docs/multilang/requirements)
  - ADK
- Abfolge
  - Für die DaRT Funktionalität wird das [Microsoft Desktop Optimization Pack](https://go.microsoft.com/fwlink/p/?LinkId=166331) benötigt. Teil davon ist dann DaRT v10. Als Anleitung siehe auch [OSDBuilder Doc - WinPE DaRT](https://osdbuilder.osdeploy.com/docs/osbuild/new-osbuildtask/winpe-content-parameters/contentwinpedart)/[OSDBuilder Doc - Content Directory: DaRT](https://osdbuilder.osdeploy.com/docs/osbuild/content-directory/dart).
    - C:\Program Files\Microsoft DaRT\v10 => Toolsx64.cab, Toolsx86.cab => *OSDBuilder\Content\DaRT\DaRT 10
    - Wenn MDT: C:\Program Files\Microsoft Deployment Toolkit\Templates\DartCOnfig8.dat => *OSDBuilder\Content\DaRT\DaRT 10
    - New-OSBuildTask -TaskName "Custom_001" -ContentWinPEDaRT
  - [OSDBuilder - ExtraFiles](https://osdbuilder.osdeploy.com/docs/osbuild/content-directory/extrafiles) (Windows 10 Wallpaper in Installation + Setup; CMTrace; Custom Scripts => WinPE)
  - [WinPE Customization](https://www.osdsune.com/home/blog/2019/osdbuilder-winpe-customization) (CMTrace, Wallpaper, WMIExplorer)
- Get-WindowsCapability -Online | Where-Object Name -match "RSAT" | Add-WindowsCapability -Online

### Beschreibung
- Windows 10 ISO Dateien hole ich mir in der Regel von [uupdump.ml](https://uupdump.ml), manche alten auch schon mal durch MCT/"Windows ISO Downloader".
- RSAT von uupdump implementieren geht nicht. ISO mache ich nicht. Direktdownload dafür kenne ich keinen.
- Appx kann ich deaktivieren

## Probleme
### Remote Server Administration Tools
Ich habe es öfters versucht die RSAT Dateien von uupdump zu laden und zu implementieren. Das habe ich bisher leider nicht hinbekommen. Wo es bei den Sprachpaketen ausreicht die CABs umzubenennen (\~31bf3856ad364e35\~amd64\~\~.cab), fehlen bei den RSAT CABs unter anderen die **metadata** Dateien. Man könnte es sicherlich von VLSC/MSDN laden, welches man auf der Arbeit haben sollte (ich private habe dies nicht). Der Aufwand wäre zum implementieren vielleicht etwas viel, da haue ich die lieber in SCCM rein.

## Checklisten
### ToDo
- [ ] Netzwerkverkehr überwachen mit [Fiddler](https://www.telerik.com/fiddler)
  - [ ] [Fiddler HTTPS Help](https://www.telerik.com/forums/fiddler-to-get-https-direct-download-links)

### Erledigt
- [ ] PEADK/PE Language
- [ ] [Content WinPE DaRT](https://osdbuilder.osdeploy.com/docs/osbuild/new-osbuildtask/winpe-content-parameters/contentwinpedart)

## Quellen
- OSDBuilder Docs + Tuts
  - [Windows 10 - WAAS (ModernDeployment.com)](https://www.moderndeployment.com/quick-start-guide-windows-10-waas-servicing-updates-via-osdbuilder/)
  - [Create MultiLang ISO with OSDBuilder (DeploymentResearch.com)](https://deploymentresearch.com/using-osd-builder-to-create-a-multi-language-windows-10-image/)
  - [OSDBuilder - PeADKLang](https://osdbuilder.osdeploy.com/docs/contentpacks/multilang-content/peadklang)
- Andere
  - [20H2 - Search Files 'RSAT'](https://uupdump.ml/findfiles.php?id=2d91ec01-3f2c-4b75-8cfa-bcfcf5620080&q=FOD)
  - [Windows 10 KMS Keys](https://gist.github.com/Azhe403/d261f2aadccfc2fb20e00414342a3093)
  - [MS DaRT Download](https://docs.microsoft.com/en-us/microsoft-desktop-optimization-pack/dart-v10/)
