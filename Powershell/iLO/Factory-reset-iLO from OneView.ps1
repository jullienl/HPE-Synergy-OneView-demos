<# 

PowerShell script to factory reset an iLO managed by HPE OneView. The IP address of the iLO must be provided at runtime.  

 After a factory reset, it is necessary to import the new iLO self-signed certificate into the Oneview trust store 
 and then to refresh the Server Hardware. This script performs these operations once the iLO factory reset is complete.

 Gen9 and Gen10 servers are supported. 

 Requirements:
   - HPE OneView Powershell Library
   - HPE OneView administrator account 

 Author: lionel.jullien@hpe.com
 Date:   May 2021
    
#################################################################################
#        (C) Copyright 2017 Hewlett Packard Enterprise Development LP           #
#################################################################################
#                                                                               #
# Permission is hereby granted, free of charge, to any person obtaining a copy  #
# of this software and associated documentation files (the "Software"), to deal #
# in the Software without restriction, including without limitation the rights  #
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell     #
# copies of the Software, and to permit persons to whom the Software is         #
# furnished to do so, subject to the following conditions:                      #
#                                                                               #
# The above copyright notice and this permission notice shall be included in    #
# all copies or substantial portions of the Software.                           #
#                                                                               #
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR    #
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,      #
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE   #
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER        #
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, #
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN     #
# THE SOFTWARE.                                                                 #
#                                                                               #
#################################################################################
#>


# OneView Credentials and IP
$OV_username = "Administrator"
$OV_IP = "oneview.lj.lab"


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

# iLO IP address
$iloIP = read-host  "Please enter the iLO IP address you want to factory reset"

$SH = Get-OVServer

foreach ($item in $SH) {

    $IPs = $item.mpHostInfo.mpIpAddresses

    foreach ($ip in $IPs) {
            
        if ($ip.address -eq $iloIP) {
            
            $serverhardware = $item

        }
    }
}

$iloModel = $serverhardware.mpModel


try {
    $ilosessionkey = ($serverhardware | Get-OVIloSso -IloRestSession)."X-Auth-Token"
}
catch {
    Write-Warning "iLO [$iloip] cannot be found ! Fix any communication problem you have in OneView with this iLO/server hardware !"
    return
}


# Creation of the header using the SSO Session Key 
$headerilo = @{ } 
$headerilo["X-Auth-Token"] = $ilosessionkey 
$headerilo["OData-Version"] = "4.0"

# Creation of the body for the iLO factory reset
$bodyiloParams = @{ } 
$bodyiloParams["ResetType"] = "Default"
$bodyiloParams = $bodyiloParams | ConvertTo-Json  

if ($iloModel -eq "ilo4") {
    $url = "/redfish/v1/Managers/1/Actions/Oem/Hp/HpiLO.ResetToFactoryDefaults/"
}
else {
    $url = "/redfish/v1/Managers/1/Actions/Oem/Hpe/HpeiLO.ResetToFactoryDefaults/"
}

#Proceeding iLO factory Reset
try {
    $rest = Invoke-WebRequest -Uri "https://$iloIP$url" -Body $bodyiloParams -Headers $headerilo -ContentType "application/json" -Method POST -UseBasicParsing 
    write-host "`niLO Factory reset is in progress... Message from API:" ($rest.Content | convertfrom-json).error.'@Message.ExtendedInfo'.MessageId
}
catch {
    Write-Warning "Factory Reset Error ! " 
    exit
}

# Wait for OneView to issue an alert about a communication issue with the server hardware
Do {
    # Collect data for the 'network connectivity has been lost' alert
    $networkconnectivityalert = (Get-OVServer | where { $_.mpHostInfo.mpIpAddresses[1].address -eq $iloIP } | 
        Get-OVAlert -severity Critical -AlertState Locked | Where-Object { 
            $_.description -Match "Network connectivity has been lost for server hardware"   
        })
    sleep 2
}
until ($networkconnectivityalert)

# Wait for OneView to issue an alert about a trusted communication issue with the iLO due to invalid iLO certificate
Do {
    # Collect data for the 'Unable to establish trusted communication with server' alert
    $ilocertalert = (Get-OVServer | where { $_.mpHostInfo.mpIpAddresses[1].address -eq $iloIP } | 
        Get-OVAlert -severity Critical -AlertState Locked | Where-Object { 
            $_.description -Match "Unable to establish trusted communication with server"     
        })

    sleep 2
}
until ( $ilocertalert )

write-host "iLO communication failure detected, removing old certificate and adding the new iLO self-signed certificate to the OneView trust store..."

sleep 5

################## Post-execution #########################

# Remove old iLO certificate
$removecerttask = Get-OVApplianceTrustedCertificate -Name $serverhardware.mpHostInfo.mpHostName | Remove-OVApplianceTrustedCertificate -Confirm:$false | Wait-OVTaskComplete

sleep 10

# Add new iLO self-signed certificate to OneView trust store
$addcerttask = Add-OVApplianceTrustedCertificate -ComputerName ($serverhardware.mpHostInfo.mpIpAddresses | ? address -match fe80 | % address)  -force | Wait-OVTaskComplete

if ($addcerttask.taskstate -eq "Completed" ) {
    write-host "New iLO self-signed certificate added successfully to the OneView trust store !"   
}
else {
    Write-Warning "Error - New iLO self-signed certificate cannot be added to the OneView trust store !"
    $addcerttask.taskErrors
    return
}

sleep 5

# Perform a server hardware refresh to re-establish the communication with the iLO
try {
    write-host "$($serverhardware.name) refresh in progress..."
    $refreshtask = $serverhardware | Update-OVServer | Wait-OVTaskComplete
    
}
catch {
    Write-Warning "Error - $($serverhardware.name) refresh cannot be completed!"
    $refreshtask.taskErrors
    return
}

# If refresh is failing, we need to re-add the new iLO certificate and re-launch a server hardware refresh
if ($refreshtask.taskState -eq "warning") {

    # write-host "The refresh could not be completed successfuly, removing and re-adding the new iLO self-signed certificate..."
    sleep 5
    
    # Remove iLO certificate again
    $removecerttask = Get-OVApplianceTrustedCertificate -Name $serverhardware.mpHostInfo.mpHostName | Remove-OVApplianceTrustedCertificate -Confirm:$false | Wait-OVTaskComplete
    
    # Add again the new iLO self-signed certificate to OneView trust store 
    $addcerttaskretry = Add-OVApplianceTrustedCertificate -ComputerName $iloip  -force | Wait-OVTaskComplete
    
    sleep 5
    
    # Perform a new refresh to re-establish the communication with the iLO
    $newrefreshtask = $serverhardware | Update-OVServer | Wait-OVTaskComplete
    
}


# Wait for the trusted communication established with server.
Do {
    $ilocertalertresult = Send-OVRequest -uri $ilocertalert.uri
    sleep 2
}
until ( $ilocertalertresult.alertState -eq "Cleared" )


# Wait for the network connectivity to be restored
Do {
    $networkconnectivityalertresult = Send-OVRequest -uri $networkconnectivityalert.uri
    sleep 2
}
until ( $networkconnectivityalertresult.alertState -eq "Cleared" )


write-host "iLO Factory reset completed successfully and communication between [$($serverhardware.name)] and OneView has been restored!" -ForegroundColor Green 

Disconnect-OVMgmt


