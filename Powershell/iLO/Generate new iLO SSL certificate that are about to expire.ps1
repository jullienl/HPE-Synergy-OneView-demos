<# 

This PowerShell script renews the iLO self-signed SSL certificate of all servers managed by HPE Oneview whose certificates are about to expire.

$nb_days_before_expiration variable at the begining of the script defines the number of days until the certificate expires. 
If the difference between the certificate expiration date and the script execution date is less than the set number of days, then a new SSL certificate is generated.

The scripts takes care of deleting old certificates and importing new ones into the OneView trust store. 
It also triggers a server hardware refresh to reset the communication between the servers and Oneview using the new SSL certificates.

Gen9 and Gen10 servers are supported. 

Requirements: 
- Latest HPEOneView library 
- OneView administrator account


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

# VARIABLES
# Number of days until the certificate expires 
$nb_days_before_expiration = "90"


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


$servers = Get-OVServer 
#$servers = Get-OVServer | select -first 1


ForEach ($server in $servers) {

    $iloIP = $server.mpHostInfo.mpIpAddresses | ? type -ne LinkLocal | % address

    try {
        $ilosessionkey = ($server | Get-OVIloSso -IloRestSession)."X-Auth-Token"
        
    }
    catch {
        Write-Warning "iLO [$iloip] cannot be found ! Fix any communication problem you have in OneView with this iLO/server hardware !"
        break
    }

    # Creation of the header using the SSO Session Key 
    $headerilo = @{ } 
    $headerilo["X-Auth-Token"] = $ilosessionkey 
    $headerilo["OData-Version"] = "4.0"

    $url = "/redfish/v1/Managers/1/SecurityService/HttpsCert/"

    #Collect iLO certificate information
    try {
        $rest = Invoke-WebRequest -Uri "https://$iloIP$url"   -Headers $headerilo -ContentType "application/json" -Method GET -UseBasicParsing 
       
    }
    catch {
        $rest.Content
        break
    }

    $cert = $rest.Content | ConvertFrom-Json

    $validnotafter = $cert.X509CertificateInformation.ValidNotAfter
   
    If ( ([DateTime]$validnotafter - (get-date)).days -le $nb_days_before_expiration ) {

        Write-host "`n[$($server.name)]: iLO self-signed SSL certificate is about to expire ! Generating a new certificate on iLO $($iloip), please wait..." -ForegroundColor Yellow

        Try {

            # Send the request to generate a new iLO4 Self-signed Certificate

            $rest = Invoke-WebRequest -Uri "https://$iloIP$url" -Headers $headerilo  -Method Delete  -UseBasicParsing -ErrorAction Stop #-Verbose 
    
            if ($Error[0] -eq $Null) { 
                Write-Host "The Self-Signed SSL certificate on iLO $iloIP has been regenerated. iLO is reseting..."
            }

        }
    
        Catch [System.Net.WebException] { 

            # Error returned if iLO FW is not supported
            # $Error[0] | fl *
            Write-Warning "Error ! Cannot generate a new iLO self-signed certificate !" 
            $rest.Content
            break
        }

        
        ########################## POST EXECUTIONS ##############################

        
        # Wait for OneView to issue an alert about a trusted communication issue with the iLO due to invalid iLO certificate
        Do {
            # Collect data for the 'Unable to establish trusted communication with server' alert
            $ilocertalert = ($server | Get-OVAlert -severity Critical -AlertState Locked | Where-Object { 
                    $_.description -Match "Unable to establish trusted communication with server"     
                })

            sleep 2
        }
        until ( $ilocertalert )

        write-host "iLO [$($iloIP)] communication failure detected, removing old certificate and adding the new iLO self-signed certificate to the OneView trust store..."

        sleep 5

        # Remove old iLO certificate
        $removecerttask = Get-OVApplianceTrustedCertificate -Name $server.mpHostInfo.mpHostName | Remove-OVApplianceTrustedCertificate -Confirm:$false | Wait-OVTaskComplete

        sleep 10

        # Add new iLO self-signed certificate to OneView trust store
        $addcerttask = Add-OVApplianceTrustedCertificate -ComputerName $iloip  -force | Wait-OVTaskComplete

        if ($addcerttask.taskstate -eq "Completed" ) {
            write-host "New iLO self-signed certificate of $($server.name) added successfully to the OneView trust store !"   
        }
        else {
            Write-Warning "Error - New iLO self-signed certificate of $($server.name) cannot be added to the OneView trust store !"
            $addcerttask.taskErrors
            break
        }

        sleep 5

    
        # Perform a server hartdware refresh to re-establish the communication with the iLO
        try {
            write-host "$($server.name) refresh in progress to update the status of the server using the new certificate..." -ForegroundColor Yellow
            $refreshtask = $server | Update-OVServer | Wait-OVTaskComplete
    
        }
        catch {
            Write-Warning "Error - [$($server.name)] refresh cannot be completed!"
            $refreshtask.taskErrors
            break
        }

        # If refresh is failing, we need to re-add the new iLO certificate and re-launch a server hardware refresh
        if ($refreshtask.taskState -eq "warning") {

            # write-host "The refresh could not be completed successfuly, removing and re-adding the new iLO self-signed certificate..."
            sleep 5
    
            # Remove iLO certificate again
            $removecerttask = Get-OVApplianceTrustedCertificate -Name $server.mpHostInfo.mpHostName | Remove-OVApplianceTrustedCertificate -Confirm:$false | Wait-OVTaskComplete
    
            # Add again the new iLO self-signed certificate to OneView trust store 
            $addcerttaskretry = Add-OVApplianceTrustedCertificate -ComputerName $iloip  -force | Wait-OVTaskComplete
    
            sleep 5
    
            # Perform a new refresh to re-establish the communication with the iLO
            $newrefreshtask = $server | Update-OVServer | Wait-OVTaskComplete
    
        }


        # Wait for the trusted communication established with server.
        Do {
            $ilocertalertresult = Send-OVRequest -uri $ilocertalert.uri
            sleep 2
        }
        until ( $ilocertalertresult.alertState -eq "Cleared" )

        write-host "[$($server.name)]: SSL certificate has been renewed successfully on iLO $($iloIP) and communication has been restored with Oneview !" -ForegroundColor Green 
    
    }
      

    Else {    
        
        Write-host "`n[$($server.name)]: No need to renew the SSL certificate on iLO $($iloIP) !" -ForegroundColor Green

    }
     
}

Read-Host -Prompt "`nOperation done ! Hit return to close" 
Disconnect-OVMgmt