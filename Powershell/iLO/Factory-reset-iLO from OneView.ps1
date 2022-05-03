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
$OV_IP = "composer.lj.lab"


# MODULES TO INSTALL

# HPEOneView
# If (-not (get-module HPEOneView.630 -ListAvailable )) { Install-Module -Name HPEOneView.630 -scope Allusers -Force }


#################################################################################

if (! $ConnectedSessions) {
    
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

    # Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
}

# Added these lines to avoid the error: "The underlying connection was closed: Could not establish trust relationship for the SSL/TLS secure channel."
# due to an invalid Remote Certificate
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
    write-host "`niLO $($iloip) Factory reset is in progress... API response: [$(($rest.Content | convertfrom-json).error.'@Message.ExtendedInfo'.MessageId)]"
}
catch {
    $err = (New-Object System.IO.StreamReader( $_.Exception.Response.GetResponseStream() )).ReadToEnd() 
    $msg = ($err | ConvertFrom-Json ).error.'@Message.ExtendedInfo'.MessageId
    Write-Host -BackgroundColor:Black -ForegroundColor:Red "iLO $($iloip) factory reset error ! Message returned: [$($msg)]"
    Disconnect-OVMgmt
    exit
}

# Wait for OneView to issue an alert about a trusted communication issue with the iLO due to invalid iLO certificate
write-host "Waiting for OneView to issue an [Unable to establish trusted communication with server] alert"
Do {
    # Collect data for the 'Unable to establish trusted communication with server' alert
    $ilocertalert = ( $serverhardware | Get-OVAlert -severity Critical -AlertState Locked | Where-Object { 
            $_.description -Match "Unable to establish trusted communication with server"     
        })

    sleep 2
}
until ( $ilocertalert )

write-host "Alert [Unable to establish trusted communication with server] raised by OneView !"

sleep 5

write-host "iLO communication failure detected, removing old certificate and adding the new iLO self-signed certificate to the OneView trust store..."

# Remove the old iLO certificate from the OneView trust store
try {
    $iLOcertificatename = $Serverhardware | Get-OVApplianceTrustedCertificate | % name
    Get-OVApplianceTrustedCertificate -Name $iLOcertificatename | Remove-OVApplianceTrustedCertificate -Confirm:$false | Wait-OVTaskComplete | Out-Null  
    Write-Host "The old iLO certificate has been successfully removed from the Oneview trust store"
}
catch {
    write-host "Old iLO certificate has not been removed from the Oneview trust store !" -ForegroundColor red
    return
}

sleep 5


################## Post-execution #########################
   

# If refresh (1) is failing, we need to re-add the new iLO certificate and re-launch a server hardware refresh
if ($refreshtask1.taskState -eq "completed" ) {
  
    write-host "$($serverhardware.name) refresh (1) completed successfully !"
    
}
else {
    write-host "Refresh (1) could not be completed successfully, adding the iLO self-signed certificate and performing a new refresh..."
   
    # Add new iLO self-signed certificate to OneView trust store
    $addcerttask1 = Add-OVApplianceTrustedCertificate -ComputerName ($serverhardware.mpHostInfo.mpIpAddresses | ? address -match fe80 | % address)  -force | Wait-OVTaskComplete

    if ($addcerttask1.taskstate -eq "Completed" ) {
        write-host "New iLO self-signed certificate added successfully to the OneView trust store ! Please wait..."   
    }
    else {
        Write-Warning "Error ! New iLO self-signed certificate cannot be added to the OneView trust store !"
        $addcerttask1.taskErrors
        Disconnect-OVMgmt
        return
    }

    sleep 10

    # Perform another server hardware refresh (2) to re-establish the communication with the iLO 
    write-host "$($serverhardware.name) refresh (2) in progress..."

    $refreshtask2 = $Serverhardware | Update-OVServer | Wait-OVTaskComplete
    
    sleep 60

    if ($refreshtask2.taskState -eq "completed" ) {
        write-host "$($serverhardware.name) refresh (2) completed successfully !"
    }
    else {
        # If refresh (2) is failing, we need to wait a bit and re-add certificate and re-launch a server hardware refresh (3)
        write-host "Refresh (2) could not be completed successfully, let's wait a bit and perform another refresh..."
        
        sleep 60
           
        # Add again new iLO self-signed certificate to OneView trust store
        $addcerttask2 = Add-OVApplianceTrustedCertificate -ComputerName ($serverhardware.mpHostInfo.mpIpAddresses | ? address -match fe80 | % address)  -force | Wait-OVTaskComplete
        
        sleep 5

        # Perform another server hardware refresh to re-establish the communication with the iLO 
        $refreshtask3 = $Serverhardware | Update-OVServer | Wait-OVTaskComplete
        write-host "$($serverhardware.name) refresh (3) in progress..."
    
        if ($refreshtask3.taskState -eq "completed" ) {
            write-host "$($serverhardware.name) refresh (3) completed successfully !"
        }
        else {
            write-host "$($serverhardware.name) refresh (3) task cannot be completed ! `nError: $($refreshtask3.taskErrors | select recommendedActions | % recommendedActions)"
            Disconnect-OVMgmt
            return
        }
    }
}

# Wait for the trusted communication established with server.
Do {
    $ilocertalertresult = Send-OVRequest -uri $ilocertalert.uri
    sleep 2
}
until ( $ilocertalertresult.alertState -eq "Cleared" )


write-host "iLO Factory reset completed successfully and communication between [$($serverhardware.name)] and OneView has been restored!" -ForegroundColor Green 

Disconnect-OVMgmt