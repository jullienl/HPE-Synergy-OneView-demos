# Script to fix OneView expired certificate msg: "Delete the expired certificate from OneView, regenerate a new certificate and add the new certificate to OneView with the same alias name."
#
# Useful to generate a new certificate in iLO4 v2.55 when the iLO certificate is expired
# In iLO 2.55, renaming the iLO name + reset does not generate a new certificate in iLO
#
# To learn more, refer to this CA: https://support.hpe.com/hpsc/doc/public/display?docId=emr_na-c03743622
#
# This script is using 'RefreshFailed' status in Server Hardware to select the impacted servers and then it collects their iLO IP addresses
#
# When the script execution is complete, it is necessary to import in OneView the new iLO certificate using the iLO IP address (From Settings > Security > Manage Certificate page)
#
# Requirements: 
# - OneView administrator account 
# - iLO Administrator account 
# - HPE iLO PowerShell Cmdlets (install-module HPEiLOCmdlets)
# - HPEOneView library 

# iLO Credentials
$ilocreds = Get-Credential -UserName Administrator -Message "Please enter the iLO password" 

# OneView information
$username = "Administrator"
$IP = "composer.lj.lab"
$secpasswd = read-host  "Please enter the OneView password" -AsSecureString
 
# Connection to the Synergy Composer
$credentials = New-Object System.Management.Automation.PSCredential ($username, $secpasswd)
Connect-OVMgmt -Hostname $IP -Credential $credentials | Out-Null



#Capturing iLO IP adresses managed by OneView
$iloIPs = Get-OVServer | ? refreshState -Match "RefreshFailed" | where mpModel -eq iLO4 | % { $_.mpHostInfo.mpIpAddresses[1].address }


#Proceeding factory Reset
Foreach ($iloIP in $iLOIPs) {
    Try { 
        $connection = connect-hpeilo -Credential $ilocreds -Address $item 
        $task = Set-HPEiLOFactoryDefault -Force -Server $iloIP -Connection $connection -DisableCertificateAuthentication
    }
    Catch {
        write-host " Factory reset Error for iLO : $iloIP"
    }

}

write-host "`nYou can now import the new iLO certificate of each iLO in OneView using the iLO IP address from Settings > Security > Manage Certificate page"

Disconnect-OVMgmt