# Windows 10 Features laden

Ich lasse das jetzt erst einmal wieder. FODs mit in die ISO zu kriegen ist privat nicht drin.
Ich glaube ich lasse den Stift da mal nach suchen. Ich werde mir bestimmte Seiten speichern und dann später da wieder rein schauen.
Da gibts unter anderem einen Typen, der eine UWP App machen wollte.



PS.: Hier noch ein paar Informationen:
Am besten das folgende ausführen, wenn man alle RSAT haben will:
Get-WindowsCapability -Name RSAT* -Online | Add-WindowsCapability –Online
https://www.microsoft.com/en-US/download/details.aspx?id=45520 (RSAT MSU / maybe catch metadata?)
http://www.microsoft.com/vlsc
MSDN: https://go.microsoft.com/fwlink/?LinkId=131359 ; https://devicepartner.microsoft.com/ ; https://visualstudio.microsoft.com/de/subscriptions/ (MyVisualStudio/MSDN)


Info: Letzte Commands:
#Xtra_1709_16299_x64
#.\Get-FeatureFilesFromUUPDUMP.ps1 -SearchParam "feat+windows+10+1803+191+amd64" -Verbose
#.\Get-FeatureFilesFromUUPDUMP.ps1 -SearchParam "feat+windows+10+20H2+x86" -Verbose