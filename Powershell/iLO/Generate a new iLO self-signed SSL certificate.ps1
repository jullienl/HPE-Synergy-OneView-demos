<# 

This PowerShell script generates a new iLO 4 self-signed SSL certificate on servers having some certificate issues related to the following advisory: 
http://h41302.www4.hp.com/km/saw/view.do?docId=emr_na-a00042194en_us 
(HP Integrated Lights-Out (iLO) - iLO 3 and iLO 4 Self-Signed SSL Certificate May Have an Expiration Date Earlier Than the Issued Date).

After a new iLO certificate is generated, the iLO restarts then the new certificate is imported into OneView and a OneView refresh takes place to update the status of the server using the new certificate.

A RedFish REST command that was added in iLO 4 firmware 2.55 (or later) is used by this script to generate the new self-signed SSL certificate.

    Requirements: iLO 4 firmware 2.55 (or later) - Latest HPOneView 400 and HPRESTCmdlets libraries - OneView administrator account.



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


# OneView Credentials and IP
$username = "Administrator" 
$password = "password" 
$IP = "192.168.1.110" 

# Modules to import
#Import-Module HPOneview.540 
Import-Module HPRESTCmdlets
   

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# Connection to the Synergy Composer
$secpasswd = ConvertTo-SecureString $password -AsPlainText -Force
$credentials = New-Object System.Management.Automation.PSCredential ($username, $secpasswd)
Connect-OVMgmt -Hostname $IP -Credential $credentials | Out-Null


               
import-OVSSLCertificate -ApplianceConnection ($connectedSessions | ? { $_.name -eq $IP })

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



$servers = Get-OVServer
#$servers = Get-OVServer | select -first 1

$serverstoimport = New-Object System.Collections.ArrayList

#$s = $servers
ForEach ($s in $servers) {
    $iloSession = $s | Get-OVIloSso -IloRestSession

    $cert = Get-HPRESTDataRaw -href 'rest/v1/Managers/1/SecurityService/HttpsCert' -session $iLOsession

    $validnotafter = $cert.X509CertificateInformation.ValidNotAfter
    $ValidNotBefore = $cert.X509CertificateInformation.ValidNotBefore

    If ( ([DateTime]$validnotafter - [DateTime]$ValidNotBefore).days -gt 1 ) {
        Write-host "`nNo iLO4 Self-Signed SSL certificate issue found on $($s.name) !" -ForegroundColor Green
    }

    Else {
        
        If ($s.mpFirmwareVersion -lt "2.55") {
            Write-host "`niLO4 Self-Signed SSL certificate issue on $($s.name) has been found but the iLO is running a FW version < 2.55 that does not support RedFish web request to generate a new Self-Signed certificate!" -ForegroundColor Red
                

        }
        Else {        
            Write-host "`niLO4 Self-Signed SSL certificate issue on $($s.name) has been found ! Generating a new Self-Signed certificate, please wait..." -ForegroundColor Yellow

            $serverstoimport.Add($s)

            $iloIP = Get-OVServer -Name $s.name | where mpModel -eq iLO4 | % { $_.mpHostInfo.mpIpAddresses[-1].address }

       

            $ilosessionkey = (Get-OVServer | where { $_.mpHostInfo.mpIpAddresses[-1].address -eq $iloIP } | Get-OVIloSso -IloRestSession)."X-Auth-Token"
 
            # Creation of the header using the SSO Session Key 
            $headerilo = @{ } 
            $headerilo["Accept"] = "application/json" 
            $headerilo["X-Auth-Token"] = $ilosessionkey 

            Try {

                $error.clear()

                # # Send the request to generate a now iLO4 Self-signed Certificate

                $rest = Invoke-WebRequest -Uri "https://$iloIP/redfish/v1/Managers/1/SecurityService/HttpsCert/" -Headers $headerilo  -Method Delete  -UseBasicParsing -ErrorAction Stop #-Verbose 
    
                if ($Error[0] -eq $Null) { 
                    Write-Host "`nThe Self-Signed SSL certificate on iLo $iloIP has been regenerated. iLO is reseting..."
                }

            }

    
            Catch [System.Net.WebException] { 

                #Error returned if iLO FW is not supported
                $Error[0] | fl *
                pause
                exit
    
            }

        }
     
    }

       


}


If ($serverstoimport) {
    Sleep 60
}

#$server =$serverstoimport
ForEach ($server in $serverstoimport) {
    #Importing the new iLO certificates
    $iloIP = Get-OVServer -Name $server.name | where mpModel -eq iLO4 | % { $_.mpHostInfo.mpIpAddresses[-1].address }
    Add-OVApplianceTrustedCertificate -ComputerName $iloIP
    write-host "`nThe new generated iLO Self-Signed SSL certificate of $($server.name) using iLO $iloIP has been imported in OneView "
        
    #Refreshing Compute modules 
    Get-OVServer -Name $server.name | Update-OVServer -Async | Out-Null

    Write-host "`nOneView is refreshing $($server.name) to update the status of the server using the new certificate..." -ForegroundColor Yellow
}



Read-Host -Prompt "`nOperation done ! Hit return to close" 

Disconnect-OVMgmt