# Windows 10 OSD Scripts

Ich musste zum vierten Mal komplett neu anordnen.

## Mögliche Vorangehensweise
- Laden der entsprechenden ISO
  - MCT (Microsoft)
  - [UUP Dump](https://uupdump.ml/)
  - Deskmodder (Blog-Suche oder Sidebar)
- Anpassen der ISO
  - Automatismus oder per GUI

## Befehle zum Erstellen einer ISO
⚠ Dazu muss das ADK installiert sein. Pfad kann jeder selber anpassen.
```powershell
$oscd = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe"
$ImagePath ="C:\Users\KurthRocks\Downloads\Win10_German_10240_HomePro_x64"
Start-Process $oscd -ArgumentList "-lW10_10240_DE_x64 -m -u2 -b$ImagePath\boot\etfsboot.com $ImagePath C:\10240.iso" -NoNewWindow -Wait
```