# Script to factory reset an iLO from OneView/Composer
#
# After a factory reset, it is necessary to import the new iLO self-signed certificate into the Oneview trusted certificate store 
# and then to refresh the Server Hardware. This script performs these operations when the iLO factory reset is completed.
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

try {
    $ilosessionkey = ($SH | Get-OVIloSso -IloRestSession)."X-Auth-Token"
}
catch {
    Write-Warning "iLO [$iloip] cannot be found ! Fix any communication problem you have in OneView with this iLO/server hardware !"
    return
}


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

# Wait until server hardware communication is lost
write-host "Waiting for the iLO communication to be restored..."
Do {
    $task = (Get-OVServer | where { $_.mpHostInfo.mpIpAddresses[1].address -eq $iloIP }).status
    sleep 2
}
until ( $task -eq "Critical")

# Wait for OneView to issue an alert about a trusted communication issue with the iLO due to invalid iLO certificate
Do {
    $ilocertalert = (Get-OVServer | where { $_.mpHostInfo.mpIpAddresses[1].address -eq $iloIP } | 
        Get-OVAlert -severity Critical -AlertState Locked | Where-Object { 
            $_.description -Match "Unable to establish trusted communication with server"   
        })

        

    sleep 2
}
until ( $ilocertalert )

# Collect data for the 'network connectivity has been lost' alert
$networkconnectivityalert = (Get-OVServer | where { $_.mpHostInfo.mpIpAddresses[1].address -eq $iloIP } | 
    Get-OVAlert -severity Critical -AlertState Locked | Where-Object { 
        $_.description -Match "Network connectivity has been lost for server hardware"   
    })

# Collect data for the 'Unable to establish trusted communication with server' alert
$ilocertalert = (Get-OVServer | where { $_.mpHostInfo.mpIpAddresses[1].address -eq $iloIP } | 
    Get-OVAlert -severity Critical -AlertState Locked | Where-Object { 
        $_.description -Match "Unable to establish trusted communication with server"   
    })


write-host "iLO communication failure detected, adding the new iLO self-signed certificate to the OneView store..."


################## Post-execution #########################

# Remove if present the old iLO certificate
$removecerttask = Get-OVApplianceTrustedCertificate -Name $SH.mpHostInfo.mpHostName | Remove-OVApplianceTrustedCertificate -Confirm:$false | Wait-OVTaskComplete

# Add new iLO self-signed certificate to OneView trusted certificate store
$addcerttask = Add-OVApplianceTrustedCertificate -ComputerName $iloip  -force | Wait-OVTaskComplete

if ($addcerttask.taskstate -eq "Completed" ) {
    write-host "iLO self-signed certificated added successfully !"   
}
else {
    Write-Warning "Error - iLO self-signed certificated cannot be added to the OneView store !"
    $addcerttask.taskErrors
    return
}

# Wait for the invalid iLO certificate alert to be cleared.
Do {
    $ilocertalertresult = Send-OVRequest -uri $ilocertalert.uri
}
until ( $ilocertalertresult.alertState -eq "Cleared" )

sleep 5

# Perform a server hartdware refresh to re-establish the communication with the iLO
try {
    write-host "$($SH.name) refresh in progress..."
    $refreshtask = $SH | Update-OVServer | Wait-OVTaskComplete
    
}
catch {
    Write-Warning "Error - $($SH.name) refresh cannot be completed!"
    $refreshtask.taskErrors
    return
}

# Check that the alert 'network connectivty has been lost' has been cleared.
$networkconnectivityalertresult = Send-OVRequest -uri $networkconnectivityalert.uri

if ($networkconnectivityalertresult.alertState -eq "Cleared" ) {
    write-host "iLO Factory reset completed successfully and communication with [$($SH.name)] has been restored with Oneview !" -ForegroundColor Cyan 
}
else {
    write-warning "Error ! Communication with [$($SH.name)] cannot be restored with Oneview !"
}



Disconnect-OVMgmt