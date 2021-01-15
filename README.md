# Windows 10 OSD Creation

[![Made with PowerShell](https://img.shields.io/badge/Made%20with-PowerShell-blue?logo=PowerShell)](https://docs.microsoft.com/de-de/powershell/)
[![No Maintenance Intended](http://unmaintained.tech/badge.svg)](http://unmaintained.tech/)
[![GitHub issues](https://img.shields.io/github/issues/LukasKurthRocks/Windows-10-Custom-ISO.svg)](https://GitHub.com/LukasKurthRocks/Windows-10-Custom-ISO/issues/)
![GitHub last commit](https://img.shields.io/github/last-commit/LukasKurthRocks/Windows-10-Custom-ISO.svg)
![GitHub repo size](https://img.shields.io/github/repo-size/LukasKurthRocks/Windows-10-Custom-ISO.svg)
[![HitCount](http://hits.dwyl.com/LukasKurthRocks/Windows-10-Custom-ISO.svg)](http://hits.dwyl.com/LukasKurthRocks/Windows-10-Custom-ISO)
![Awesome Badges](https://img.shields.io/badge/badges-awesome-green.svg)

⚠ Benutzung dieses Projektes natürlich auf eigene Gefahr! ⚠\
🖼 Screenshots finden sich [hier](SCREENSHOTS.md).\
📧 Kontaktmöglichkeiten finden sich auf meiner [GitHub Hauptseite](https://github.com/LukasKurthRocks/)

## Offen
- [ ] FODs wie [hier](https://github.com/OSDeploy/OSDBuilder.Public/find/master) beschrieben
- [X] OInstallLite.exe => install.bat anpassen für Business? (zip und Script )
  - Eher nicht, Microsoft Office wird über SCCM installiert.

## Informationen
Ich habe dieses Projekt erstellt, damit ich mir eine angepasste Windows 10 ISO relativ leicht zusammenstellen kann. Möglichkeiten dies zu bewerkstelligen, gibt es mehrere. Erklärungen seitens Microsoft sind da rar gesäht. Vieles muss man ausprobieren und testen. Ein Tool von Microsoft wäre da logisch, gibts aber nicht. Macht aber auch nichts.

### Unfertiges Zeug
Ich habe das Projekt auf meine Zwecke eingerichtet und die Scripts entsprechend meinen Anforderungen geschrieben.
Das Projekt ist weder fertig noch unfehlbar. Es hat auch jeder seine eigenen Vorlieben, was Ordnung und Abfragen in PowerShell betrifft.
So könnte ich den Code in entsprechende Begin/Process/End Blöcke einschließen, brauche ich für mich aber bisher nicht.

### Notfall CD
Ich verlinke hier noch die c't Seiten zu den Notfall CDs. Nach der Erstellung der ISOs habe ich gerne eine aktuelle Notfall CD.
Dazu habe ich auch noch ein paar Daten die ich mir hinzufüge.

<details>
  <summary>Ausklappen!</summary>
  
  - **c't Notfall CD - Beitrag von Heise.de**
    - [2019](https://www.heise.de/ct/artikel/c-t-Notfall-Windows-2019-4171098.html)
    - [2020](http://ct.de/yhft)
    - [2021](https://www.heise.de/ct/artikel/c-t-Notfall-Windows-2021-4954598.html)
  - **c't Notfall CD - Baukit**  
    - [2019](https://ct.de/s/bzyz)
    - [2020](https://cdnpcf.heise.de/ctnotwin20.zip)
    - [2021](https://cdnpcf.heise.de/ctnotwin21.zip)
</details>

### Inhalt
Folgendes ist in diesem Projekt enthalten:

**Achtung**: Ich habe vieles an meine Bedürfnisse angepasst, manches was ich in das Image mit hineinpacke wurde sogar entfernt.
Da exe-Dateien in der Regel sehr groß sind, bleibt es jedem selbst überlassen diese für seine Zwecke hinzuzufügen / zu nutzen.

**\Bonus\Windows_10_Features**
- Kleiner selbstgeschriebener API-Wrapper für die uupdump.ml Seite.
- Ein Versuch die Language Pack Dateien von UUPDump.ml zu laden und zu implementieren.
  - Muss das aufgeben, da die Überprüfung der Möglichkeiten ohne die LP ISOs einfach zu lange dauern würde. Vorschläge sind natürlich gerne willkommen, auch wenn ich daran wahrscheinlich nichts mehr ändern werde.

**\Windows_10_OSD\UUPDumpWrapper**
- Kleiner selbstgeschriebener API-Wrapper für die uupdump.ml Seite.
- ISO Creator mit uupdump.ml API + Ich glaube das Script von Abodi.

**\Windows_10_OSD\OSDBuilder**
- Archiv mit alten Versuchen
- OSDBuilder Scripts (Im Archiv sind auch Varianten ohne, die müsste ich aber aufräumen, sortieren, anpassen)
  - Implementierung von eigenen Tools (kleine Scripts zum Anpassen etc.)
    - Scripts enthalten auch Installation von Software und das "verstecken" der SoftwareUpdates.
    - Habe die Delugia Fonts für Windows Terminal auch drin.
- RunMe.ps1 für das automatische Ablaufen von Scripts
  - MEINE BEDÜRFNISSE!!
  - Ebenso eine *.lnk, die auf den Desktop kopiert wird, wenn fertig. Damit kann das direkt nach der Installation des OS gestartet werden.

In manchen Ordnern (bsp.: [PatchMyPC_Manual](/Windows_10_OSD/OSDBuilder/00._Additional/01._ImageImport/tools/03._Software/PatchMyPC_Manual)) wird die exe des [PatchMyPC - HomeUpdater](https://patchmypc.com/home-updater)s erwartet. Diese bekommen PRIVATNUTZER auf deren Seite. Diese einfach in den Ordner zu der *.ini legen. Wenn nicht benötigt, kann der Ordner einfach gelöscht werden.
Sandboxie_Install.exe habe ich mal drin gelassen. Habe Sanboxie für die Installation mit PatchMyPC.exe verwendet. Damit kann das im Hintergrund laufen, ohne Fenster.

**\OSDBuilder\Files ([README](OSDBuilder/README.md))**
- Content, Content Packs und weitere Ordner aus dem OSBuilder Pfad
  - AutoUnattend.xml für die unbeaufsichtigte Installation von Windows 10 (Company + Privat)
  - Registrierungs-Dateien für Anpassung des Systems
    - **Achtung**: Ein paar Registrungsdateien funktionieren nicht, möglicherweise weil das Windows Setup auf die HKLM Einträge zugreifen muss. Habe die Anpassungen in BACKUP verschoben. Benutzen auf eigene Gefahr (was hierfür generell gilt!).
    - Blockierung des Feature-Upgrades auf bestimmten ISOs (1507, LTSC/LTSB und so), das kann ich wenn gewollt dann auch wieder aktivieren.
    - Admin Wonership für das Kontextmenü, falls man es denn benötigt.
  - Windows Hintergründe (Setup und OS)
  - Delugia Schriftarten für Windows Terminal
- Hier liegt auch ein Script, damit ich das nicht manuell machen muss.

## Anleitung
- Projekt laden (am besten irgendwo direkt auf C:\\)
- Optional: PatchMyPC Updater laden und in Ordnern platzieren
  - Sonst PMPC Sachen löschen wenn nicht benötigt
- Optional: Exe Dateien laden und in 02._ImageImport platzieren
- Optional: Registry den eigenen Bedürfnissen nach einstellen
  - Vor allem der BUSINESS Ordner. Der funktioniert bei mir auch nicht, da die Werte teilweise keinen Sinn machen.
- Letzte Version des OSDBuilders in PowerShell laden
- Laden eine Windows 10 ISO, entweder über UUPDump.ml, den Wrapper, MCT oder ähnliches (siehe links unten)
- Scripts den eigenen Bedürfnissen nach anpassen
  - In BUSINESS beispielsweise das InstallClient.ps1 Script anpassen.
- Scripts der Reihenfolge nach ausführen
- INFO: **0._CleanupMounts.ps1** ist zum Entfernen der Mounts, die nach dem Abbrechen der Scripts noch vorhanden sind.
- INFO: Beim Booten der ISO muss man sich bei meiner letzten AutoUnattend.xml eine Festplatte aussuchen. Das liegt daran, dass die erste Festplatte nicht immer die Festplatte ist, die auch das OS enthalten soll. Versehentliches Löschen der Festplatte soll somit verhindert werden.
- INFO: In **01._ImageImport\\tools** sind alle Tools, Anwendungen und Scripts drin, die ich auf der ISO haben will
  - Mit dabei der neue Edge, das Framework, ein paar Tools...
  - Manches muss einer selber machen und musste entfernt werden.
  - BUSINESS und PRIVATE Ordner haben separate Scripts (und müssen dementsprechend konfiguriert werden)
    - Beispielsweise ein SCCM und AD Script für das Verschieben in einer OU.
    - Oder auch die PowerShell Profile (⚠ die nur als Beispiel dienen sollten ⚠).
- INFO: Am besten die AutoUnattend.xml im "**Windows System Image Manager**" einlesen und ein Passwort für den Administrator hinterlegen.\
  Passwörter kann ich ja schlecht verraten 😉

## Weiteres
- ISOs laden (Linux, Tools etc.)
- Multiboot Tools
  - [Ventoy](https://www.ventoy.net/en/download.html)
  - Multiboot (heise.de/c't 02-2021)
- Windows Activation Script und Office Installation und Aktivierung hinzufügen
  - Ich habe dafür eigene Scripts, die sind aber für mich und sonst niemanden
- Office laden (siehe [ODT](https://docs.microsoft.com/de-de/deployoffice/office2019/deploy))
  - Habe in **01._ImageImport\tools\03._Software\Zusatz** aber auch die OfficeInstall.exe drin, aber: Damit wird Office nur installiert. Aktiviert werden muss es nach der Installation dann immer noch. Sowas KANN für Business-Zwecke verwendet werden. Ich packe das auch für die Arbeit nicht extra mit rein. Office installieren wir aber auch über SCCM.
- An mich: "BuilderContent"
- Ach und die ISO eignet sich später nicht für SCCM oder ähnliche Programme. Dort sollte man alles separat in die TaskSequenzen verteilen.

### Kurzinfos
- Zum Ausführen Script 5.1 anpassen (PRIVATE/BUSINESS) => $CopyProfile = 1 oder 2.
- Die Ordner aus dem Save importieren (Extra Content Ordner)
- OSDBuilder\\Tasks\\\*.json ändern => BUSINESS/PRIVATE oder halt vorher durch die Auswahl die benötigten Contents auswählen.

## TLDR Anleitung (**UNVOLLSTÄNDIG**)
### Vorraussetzung
- OSDBuilder
- Programme/Anwendungen laden
### Anleitung
- Projekt laden
- Extra Content in die Import Ordner laden (Externe HDD)
  - Auch die geladenen Programme/Anwendungen (inklusive PatchMyPC)
- ISO über Script laden (uup)
- Scripts der Reihe nach ausführen in _OSD (Auswahlmöglichkeiten)
  - $CopyProfile = 1 oder 2
  - In Task entweder Privat oder Company auswählen
- In Hyper-V testen bevor vollständig ausgerollt/implementiert oder ähnliches
- Erstellen von ISO PRIVATE, BUSINESS und ADMIN (mit TakeOwn Registry Anpassungen)

## Links
- ISO Download
  - [Media Creation Toolkit - microsoft.com](https://www.microsoft.com/de-de/software-download/windows10)
  - [Windows ISO Download Tool - heidoc.net](https://www.heidoc.net/joomla/technology-science/microsoft/67-microsoft-windows-and-office-iso-download-tool) (Gut für alte Versionen wie 1507)
  - [UPDump.ml - UUP ISO Creator](https://uupdump.ml/)
- [UUP Media Creator (gus33000)](https://github.com/gus33000/UUPMediaCreator) (WIP)
- [OSDBuilder Dokumentation](https://osdbuilder.osdeploy.com/)
- c't Notfall CD - Beitrag von Heise.de
  - [2019](https://www.heise.de/ct/artikel/c-t-Notfall-Windows-2019-4171098.html)
  - [2020](http://ct.de/yhft)
  - [2021](https://www.heise.de/ct/artikel/c-t-Notfall-Windows-2021-4954598.html)
- c't Notfall CD - Baukit 
  - [2019](https://ct.de/s/bzyz)
  - [2020](https://cdnpcf.heise.de/ctnotwin20.zip)
  - [2021](https://cdnpcf.heise.de/ctnotwin21.zip)
