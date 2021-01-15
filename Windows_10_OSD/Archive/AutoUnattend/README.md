# AutoUnattend.xml

Ein paar Sachen für mich zum Speichern

## Administrator-Passwort
| Hash Wert | Passwort |
| ------------- | ------------- |
| cABhAHMAcwB3AG8AcgBkAEEAZABtAGkAbgBpAHMAdAByAGEAdABvAHIAUABhAHMAcwB3AG8AcgBkAA== | password |

## Features aktivieren
**INFO**: Wenn die entsprechend dafür benötigten Dateien nicht in der ISO sind, bricht die Installation ab.

```XML
<servicing>
    <package action="configure">
        <assemblyIdentity name="Microsoft-Windows-Foundation-Package" version="10.0.10240.16384" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="" />
        <selection name="Microsoft-Hyper-V-All" state="true" />
    </package>
    <package action="configure">
        <assemblyIdentity name="Microsoft-Windows-Foundation-Package" version="10.0.19041.1" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="" />
        <selection name="Microsoft-Hyper-V-All" state="true" />
        <selection name="Microsoft-Hyper-V-Management-Clients" state="true" />
        <selection name="Microsoft-Hyper-V" state="true" />
        <selection name="Microsoft-Windows-Subsystem-Linux" state="true" />
        <selection name="NetFx3" state="false" />
        <selection name="SMB1Protocol" state="true" />
        <selection name="Microsoft-Hyper-V-Management-PowerShell" state="true" />
        <selection name="Microsoft-Hyper-V-Tools-All" state="true" />
    </package>
</servicing>
```

## Windows 10 Product Keys

```XML
<UserData>
    <ProductKey>
        <!-- 
            https://docs.microsoft.com/de-de/windows-server/get-started/kmsclientkeys
            Windows 10 - KMS/Generic Keys:
            
            YTMG3-N6DKC-DKB77-7M9GH-8HVX7   Home
            TX9XD-98N7V-6WMQ6-BX7FG-H8Q99   Home
            7HNRX-D7KGG-3K4RQ-4WPJ4-YTDFH   Home Single Language
            W269N-WFGWX-YVC9B-4J6C9-T83GX   Professional
            VK7JG-NPHTM-C97JM-9MPGT-3V66T   Professional
            MH37W-N47XK-V7XM9-C7227-GCQG9   Professional N
            NRG8B-VKK3Q-CXVCJ-9G2XF-6Q84J   Professional for Workstations
            9FNHH-K3HBT-3W4TD-6383H-6XYWF   Professional for Workstations N
            6TP4R-GNPTD-KYYHQ-7B7DP-J447Y   Professional Education
            YVWGF-BXNMC-HTQYQ-CPQ99-66QFC   Professional Education N
            NW6C2-QMPVW-D7KKK-3GKT6-VCFB2   Education
            2WH4N-8QGBV-H22JP-CT43Q-MDWWJ   Education N
            NPPR9-FWDCX-D2C8J-H872K-2YT43   Enterprise
            DPH2V-TTNVB-4X9Q3-TJR4H-KHJW4   Enterprise N
            YYVX9-NTFWV-6MDM3-9PT4T-4M68B   Enterprise G
            44RPN-FTY23-9VTTB-MP9BX-T84FV   Enterprise G N

            M7XTQ-FN8P6-TTKYV-9D4CC-J462D   Enterprise LTSC 2019
            92NFX-8DJQP-P6BBQ-THF9C-7CG2H   Enterprise N LTSC 2019
            DCPHK-NFMTC-H88MJ-PFHPY-QJ4BJ   Enterprise LTSB 2016
            QFFDN-GRT3P-VKWWX-X7T3R-8B639   Enterprise N LTSB 2016
            WNMTR-4C88C-JK8YV-HQ7T2-76DF9   Enterprise 2015 LTSB
            2F77B-TNFGY-69QQF-B8YKP-D69TJ   Enterprise 2015 LTSB N
        -->
        <Key>NPPR9-FWDCX-D2C8J-H872K-2YT43</Key>
        <WillShowUI>Never</WillShowUI>
    </ProductKey>
    <AcceptEula>true</AcceptEula>
    <Organization>Private</Organization>
</UserData>
```

## Festplatte Konfiguration
**NOTE**: Für den Fall, dass es IMMER die gleiche Platte ist.

```XML
<DiskConfiguration>
    <Disk wcm:action="add">
        <CreatePartitions>
            <CreatePartition wcm:action="add">
                <Order>1</Order>
                <Size>450</Size>
                <Type>Primary</Type>
            </CreatePartition>
            <CreatePartition wcm:action="add">
                <Order>2</Order>
                <Size>100</Size>
                <Type>EFI</Type>
            </CreatePartition>
            <CreatePartition wcm:action="add">
                <Order>3</Order>
                <Size>16</Size>
                <Type>MSR</Type>
            </CreatePartition>
            <CreatePartition wcm:action="add">
                <Extend>true</Extend>
                <Order>4</Order>
                <Type>Primary</Type>
            </CreatePartition>
        </CreatePartitions>
        <ModifyPartitions>
            <ModifyPartition wcm:action="add">
                <Format>NTFS</Format>
                <Label>WinRE</Label>
                <Order>1</Order>
                <PartitionID>1</PartitionID>
                <TypeID>DE94BBA4-06D1-4D40-A16A-BFD50179D6AC</TypeID>
            </ModifyPartition>
            <ModifyPartition wcm:action="add">
                <Format>FAT32</Format>
                <Label>System</Label>
                <Order>2</Order>
                <PartitionID>2</PartitionID>
            </ModifyPartition>
            <ModifyPartition wcm:action="add">
                <Order>3</Order>
                <PartitionID>3</PartitionID>
            </ModifyPartition>
            <ModifyPartition wcm:action="add">
                <Format>NTFS</Format>
                <Label>Windows</Label>
                <Letter>C</Letter>
                <Order>4</Order>
                <PartitionID>4</PartitionID>
            </ModifyPartition>
        </ModifyPartitions>
        <DiskID>0</DiskID>
        <WillWipeDisk>true</WillWipeDisk>
    </Disk>
</DiskConfiguration>
```