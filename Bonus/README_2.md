# PowerShell: Fetchen der Feature On Demand Dateien/CABs
Habe zu lange nach einem Weg gesucht, wie ich die Feature On Demand ISO Dateien ohne die ISOs bekomme. Ich will nicht jedes mal die Entwickler damit nerven, mir die zwei FOD ISOs (FOD + LP) aus dem VS MSDN Account zu laden. In Netz findet man auch nur Hinweise auf den MSDN, bzw. auf das Hinzufügen der FODs in die angeschaltete Maschine.

Hier also meine 5 Cent zum bekommen der CAB Dateien. Diese können dann zum Bleistift im OSDBuilder verwendet werden...

## Was das Script macht
Ich rufe die Capability Funktionen von DISM auf, starte die Aktivierung eines Features über DISM im Hintergrund und kopiere mit Robocopy alle Daten aus dem SoftwareDistribution Ordner in einen Ordner meiner Wahl. Mehr nicht.

## Anderes
Gibt hier den Typen der das manuell gemacht hat: [VCloudInfo - Install RSAT Offline](https://www.vcloudinfo.com/2019/01/how-to-install-windows-10-1809-features.html).

## TODOS
- [ ] PS1 Aufräumen
- [ ] Saves löschen, nur temporär
- [ ] Netzwerkverkehr überwachen mit [Fiddler](https://www.telerik.com/fiddler)
  - [ ] [Fiddler HTTPS Help](https://www.telerik.com/forums/fiddler-to-get-https-direct-download-links)

## Saves
- https://www.reddit.com/r/Surface/comments/6jcf54/first_things_to_do_with_new_surface_pro/?sort=top
- https://www.reddit.com/r/AskReddit/comments/4g5sl1/what_application_do_you_always_install_on_your/?sort=top
- https://www.amazon.de/s?k=surface+pro+7+protective+case
