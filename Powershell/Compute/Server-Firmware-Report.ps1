# Generates a Server Firmware report 
#
# Requirements:
#    - HPE OneView Powershell Library
#    - HPE OneView administrator account 
#
####################################################################

# OneView Credentials and IP
$OV_username = "Administrator"
$OV_IP = "composer2.lj.lab"


# MODULES TO INSTALL

# HPEOneView
# If (-not (get-module HPEOneView.630 -ListAvailable )) { Install-Module -Name HPEOneView.630 -scope Allusers -Force }


#################################################################################

$secpasswd = read-host  "Please enter the OneView password" -AsSecureString
 
# Connection to the OneView / Synergy Composer
$credentials = New-Object System.Management.Automation.PSCredential ($OV_username, $secpasswd)

try {
    Connect-OVMgmt -Hostname $OV_IP -Credential $credentials -ErrorAction stop | Out-Null    
}
catch {
    Write-Warning "Cannot connect to '$OV_IP'! Exiting... "
    return
}

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

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


#################################################################################


$servers = Get-OVserver | Sort-Object locationuri, { [int]$_.position }
$NewServer = "###################################################################### "
Foreach ($server in $servers) {
    echo $NewServer >> Server_FW_Report.txt
    echo "              $($server.name)" >> Server_FW_Report.txt
    echo $NewServer >> Server_FW_Report.txt
    Get-OVServer -Name $server.name | Format-List position, name, mpModel, mpFirmwareVersion, model, serialNumber, processorType, memoryMb, romVersion, intelligentProvisioningVersion, state, powerState  | Out-File Server_FW_Report.txt -Append
(Send-OVRequest -Uri ($server.uri + "/firmware")).components | Format-Table componentName, componentLocation, componentVersion | Out-File Server_FW_Report.txt -Append
}


Get-Content .\Server_FW_Report.txt

Disconnect-OVMgmt