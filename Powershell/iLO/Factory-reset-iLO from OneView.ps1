# Script to factory reset an iLO from OneView/Composer
#
# After a factory reset, it is necessary to import in OneView the new iLO certificate using the iLO IP address (from Settings > Security > Manage Certificate page) 
# and then to refresh the Server Hardware (from Actions /Refresh)
#
# Requirements:
# - OneView administrator account 
# - HPEOneView library 

# iLO IP address
$iloIP = read-host  "Please enter the iLO IP address you want to factory reset"

# OneView information
$username = "Administrator"
$IP = "composer.lj.lab"
$secpasswd = read-host  "Please enter the OneView password" -AsSecureString
 
# Connection to the Synergy Composer
$credentials = New-Object System.Management.Automation.PSCredential ($username, $secpasswd)
Connect-OVMgmt -Hostname $IP -Credential $credentials | Out-Null


add-type -TypeDefinition  @"
        using System.Net;
        using System.Security.Cryptography.X509Certificates;
        public class TrustAllCertsPolicy : ICertificatePolicy {
            public bool CheckValidationResult(
                ServicePoint srvPoint, X509Certificate certificate,
                WebRequest request, int certificateProblem) {
                return true;
            }
        }
"@
   
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

$SH = Get-OVServer | where { $_.mpHostInfo.mpIpAddresses[1].address -eq $iloIP }

$ilosessionkey = ($SH | Get-OVIloSso -IloRestSession)."X-Auth-Token"

# Creation of the header using the SSO Session Key 
$headerilo = @{ } 
$headerilo["X-Auth-Token"] = $ilosessionkey 

# Creation of the body for the iLO factory reset
$bodyiloParams = @{ } 
$bodyiloParams["ResetType"] = "Default"
$bodyiloParams = $bodyiloParams | ConvertTo-Json  

#Proceeding iLO factory Reset
try {
    $rest = Invoke-WebRequest -Uri "https://$iloIP/redfish/v1/Managers/1/Actions/Oem/Hpe/HpeiLO.ResetToFactoryDefaults/" -Body $bodyiloParams  -Headers $headerilo -ContentType "application/json" -Method POST -UseBasicParsing 
    write-host "`niLO Factroy reset is in progress... "

}
catch {
    Write-Warning "Factory Reset Error ! " 
    $rest.Content
    
}


          
Disconnect-OVMgmt