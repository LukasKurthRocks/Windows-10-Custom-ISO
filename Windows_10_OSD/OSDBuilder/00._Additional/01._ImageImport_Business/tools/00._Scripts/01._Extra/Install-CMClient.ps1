# Can create a function for this. Also looping computer names and then Invoke-Command on Start-Process.

[CmdletBinding()]
param ()
    
begin {
    function Get-AllDomains {
        $Root = [ADSI]"LDAP://RootDSE"
        $oForestConfig = $Root.Get("configurationNamingContext")
        $oSearchRoot = [ADSI]("LDAP://CN=Partitions," + $oForestConfig)
        $AdSearcher = [adsisearcher]"(&(objectcategory=crossref)(netbiosname=*))"
        $AdSearcher.SearchRoot = $oSearchRoot
        $domains = $AdSearcher.FindAll()
        return $domains
    }

    function Get-MPFromAD ($SiteCode) {
        $domains = Get-AllDomains
        foreach ($domain in $domains) {
            try {
                $ADSysMgmtContainer = [ADSI]("LDAP://CN=System Management,CN=System," + "$($Domain.Properties.ncname[0])")
                #$AdSearcher = [adsisearcher]"(&(Name=SMS-MP-$SiteCode-*)(objectClass=mSSMSManagementPoint))"
                $AdSearcher = [adsisearcher]"(&(objectClass=mSSMSManagementPoint))"
                $AdSearcher.SearchRoot = $ADSysMgmtContainer
                $ADManagementPoint = $AdSearcher.FindONE()
                $MP = $ADManagementPoint.Properties.mssmsmpname[0]
            }
            catch {
                Write-Host "Error: $($_.exception.Message)"
            }
        }

        return $MP
    }
}
    
process {
    #region Saved
    # This here can not be used without already being connected to the domain.
    # One can set the variables in here, but not when uploading this to GitHub.
    #CCMSetup.exe /mp:SMSMP01 /logon SMSSITECODE=S01 FSP=SMSFSP01
    #$CM12SiteCode = $([WmiClass]"\\localhost\ROOT\ccm:SMS_Client").GetAssignedSite().ssitecode # Only when connected to SCCM
    #$CM12SiteServer = Get-MPFromAD $CM12SiteCode # Only when connected to SCCM
    #$CM12SiteServer = (Get-WMIObject -Namespace "root\SMS" -Class "SMS_ProviderLocation").__Server
    #$CM12ClientInsPath = "\\$CM12SiteServer\SMS_$CM12SiteCode\Client"
    #$CM12SiteServerPrompt = Read-Host -Prompt "Enter the name of the SCCM 2012 Site Server here"

    #$CM12SiteServer = (Get-WMIObject -Namespace "root\SMS" -Class "SMS_ProviderLocation").__Server
    #endregion
    
    # Do stuff here if the SCCM Site Server was NOT detected in the SMS WMI Namespace
    $CM12SiteServerPrompt = Read-Host -Prompt "Enter the name of the SCCM 2012 Site Server here"
    $CM12ClientInsPath = Read-Host -Prompt "Enter the path of the client installation - like '\\$CM12SiteServerPrompt\SMS_ABC\Client\ccmsetup.exe'"

    try {
        Start-Process -FilePath "$CM12ClientInsPath" -ArgumentList "/mp:$CM12SiteServerPrompt"
    }
    catch {
        Write-Warning -Message "Failed to install the SCCM 2012 Client on $env:COMPUTERNAME because $($_.Exception.Message)"
    }
}
	
end {}