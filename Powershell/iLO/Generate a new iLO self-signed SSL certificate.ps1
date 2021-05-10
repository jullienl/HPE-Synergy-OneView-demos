<# 

This PowerShell script generates a new iLO 4 self-signed SSL certificate on servers having some certificate issues related to the following advisory: 
https://support.hpe.com/hpesc/public/docDisplay?docLocale=en_US&docId=emr_na-a00042194en_us
(HP Integrated Lights-Out (iLO) - iLO 3 and iLO 4 Self-Signed SSL Certificate May Have an Expiration Date Earlier Than the Issued Date).

After a new iLO certificate is generated, the iLO restarts then the new certificate is imported into OneView and a OneView refresh takes place to update the status of the server using the new certificate.

A RedFish REST command that was added in iLO 4 firmware 2.55 (or later) is used by this script to generate the new self-signed SSL certificate.

Requirements: 
- iLO 4 firmware 2.55 (or later) 
- Latest HPEOneView library 
- OneView administrator account.


  Author: lionel.jullien@hpe.com
  Date:   March 2018
    
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

# MODULES TO INSTALL/IMPORT

# HPEONEVIEW
# If (-not (get-module HPEOneView.550 -ListAvailable )) { Install-Module -Name HPEOneView.530 -scope Allusers -Force }
# import-module HPEOneView.550


Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

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



$servers = Get-OVServer | where mpModel -eq iLO4
#$servers = Get-OVServer | select -first 1

$serverstoimport = New-Object System.Collections.ArrayList


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
    $ValidNotBefore = $cert.X509CertificateInformation.ValidNotBefore

    If ( ([DateTime]$validnotafter - [DateTime]$ValidNotBefore).days -gt 1 ) {
        Write-host "`nNo iLO4 Self-Signed SSL certificate issue found on $($server.name) !" -ForegroundColor Green
    }

    Else {
        
        If ($server.mpFirmwareVersion -lt "2.55") {
            Write-host "`niLO4 Self-Signed SSL certificate issue on $($server.name) has been found but the iLO is running a FW version < 2.55 that does not support RedFish web request to generate a new Self-Signed certificate!" -ForegroundColor Red
              
        }
        Else {        
            Write-host "`niLO4 Self-Signed SSL certificate issue on $($server.name) has been found ! Generating a new Self-Signed certificate, please wait..." -ForegroundColor Yellow

            $serverstoimport.Add($server)

            Try {

                # Send the request to generate a new iLO4 Self-signed Certificate

                $rest = Invoke-WebRequest -Uri "https://$iloIP$url" -Headers $headerilo  -Method Delete  -UseBasicParsing -ErrorAction Stop #-Verbose 
    
                if ($Error[0] -eq $Null) { 
                    Write-Host "`nThe Self-Signed SSL certificate on iLo $iloIP has been regenerated. iLO is reseting..."
                }

            }
    
            Catch [System.Net.WebException] { 

                # Error returned if iLO FW is not supported
                # $Error[0] | fl *
                Write-Warning "Error ! Cannot generate a new iLO4 self-signed certificate !" 
                $rest.Content
                break
            }

        }
     
    }

       


}


If ($serverstoimport) {
    Sleep 60
}

########################## POST EXECUTIONS ##############################

#$server =$serverstoimport
ForEach ($servertoimport in $serverstoimport) {

    $iloIP = $servertoimport.mpHostInfo.mpIpAddresses | ? type -ne LinkLocal | % address
        
    # Wait for OneView to issue an alert about a trusted communication issue with the iLO due to invalid iLO certificate
    Do {
        # Collect data for the 'Unable to establish trusted communication with server' alert
        $ilocertalert = ($servertoimport | Get-OVAlert -severity Critical -AlertState Locked | Where-Object { 
                $_.description -Match "Unable to establish trusted communication with server"     
            })

        sleep 2
    }
    until ( $ilocertalert )

    write-host "iLO [$($iloIP)] communication failure detected, removing old certificate and adding the new iLO self-signed certificate to the OneView trust store..."

    sleep 5

    # Remove old iLO certificate
    $removecerttask = Get-OVApplianceTrustedCertificate -Name $servertoimport.mpHostInfo.mpHostName | Remove-OVApplianceTrustedCertificate -Confirm:$false | Wait-OVTaskComplete

    sleep 10

    # Add new iLO self-signed certificate to OneView trust store
    $addcerttask = Add-OVApplianceTrustedCertificate -ComputerName $iloip  -force | Wait-OVTaskComplete

    if ($addcerttask.taskstate -eq "Completed" ) {
        write-host "New iLO self-signed certificate of $($servertoimport.name) added successfully to the OneView trust store !"   
    }
    else {
        Write-Warning "Error - New iLO self-signed certificate of $($servertoimport.name) cannot be added to the OneView trust store !"
        $addcerttask.taskErrors
        break
    }

    sleep 5

    
    # Perform a server hartdware refresh to re-establish the communication with the iLO
    try {
        write-host "$($servertoimport.name) refresh in progress to update the status of the server using the new certificate..." -ForegroundColor Yellow
        $refreshtask = $servertoimport | Update-OVServer | Wait-OVTaskComplete
    
    }
    catch {
        Write-Warning "Error - $($servertoimport.name) refresh cannot be completed!"
        $refreshtask.taskErrors
        break
    }

    # If refresh is failing, we need to re-add the new iLO certificate and re-launch a server hardware refresh
    if ($refreshtask.taskState -eq "warning") {

        # write-host "The refresh could not be completed successfuly, removing and re-adding the new iLO self-signed certificate..."
        sleep 5
    
        # Remove iLO certificate again
        $removecerttask = Get-OVApplianceTrustedCertificate -Name $servertoimport.mpHostInfo.mpHostName | Remove-OVApplianceTrustedCertificate -Confirm:$false | Wait-OVTaskComplete
    
        # Add again the new iLO self-signed certificate to OneView trust store 
        $addcerttaskretry = Add-OVApplianceTrustedCertificate -ComputerName $iloip  -force | Wait-OVTaskComplete
    
        sleep 5
    
        # Perform a new refresh to re-establish the communication with the iLO
        $newrefreshtask = $servertoimport | Update-OVServer | Wait-OVTaskComplete
    
    }


    # Wait for the trusted communication established with server.
    Do {
        $ilocertalertresult = Send-OVRequest -uri $ilocertalert.uri
        sleep 2
    }
    until ( $ilocertalertresult.alertState -eq "Cleared" )

    write-host "[$($servertoimport.name)]: iLO self-signed certificate operation completed successfully on [$($iloIP)] and communication has been restored with Oneview !" -ForegroundColor Green 

}



Read-Host -Prompt "`nOperation done ! Hit return to close" 

Disconnect-OVMgmt