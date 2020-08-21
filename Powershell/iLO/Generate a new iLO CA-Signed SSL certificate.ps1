<# 

This PowerShell script generates a new iLO5 CA-Signed SSL certificate to all servers managed by OneView 


Steps: 

A first iLO RedFish command is used to create a Certificate Signing Request in iLO 

The CSR is submitted to an available Certificate Autority server and the new signed certificate is downloaded

A second RedFish command is used to import the new CA-Signed certificate into iLO which triggers the iLO to restart

Then the new certificate is imported into OneView and a OneView refresh takes place to update the status of the server using the new certificate.


Requirements: Latest HPEOneView and PSPKI libraries - OneView administrator account.



  Author: lionel.jullien@hpe.com
  Date:   August 2020
    
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
If (-not (get-module HPEOneView.530 -ListAvailable )) { Install-Module -Name HPEOneView.530 -scope Allusers -Force }
import-module HPEOneView.530

# PSPKI
# CA scripts -
# On Windows 7/8/8.1/10 some PSPKI cmdlets are not available so it is required to install RSAT (Remote System Administration Tools)
# Download page: https://www.microsoft.com/en-us/download/details.aspx?id=45520

If (-not (get-module PSPKI -ListAvailable )) { Install-Module -Name PSPKI -scope Allusers -Force }
import-module PSPKI



# OneView Credentials and IP
$IP = "192.168.1.10"
$username = "administrator"
$password = "password"


# ONEVIEW CONNECTION
$secpasswd = ConvertTo-SecureString $password -AsPlainText -Force
$credentials = New-Object System.Management.Automation.PSCredential ($username, $secpasswd)
Connect-OVMgmt -Hostname $IP -Credential $credentials | Out-Null

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

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





# Filter the servers where you want to generate a new CA-Signed certificate
# Use any filter to limit to only the correct resources

# $servers = Get-OVServer
$servers = Get-OVServer | select -first 1
# $servers = Get-OVServer -Name "Frame1, bay 5"


ForEach ($server in $servers) {

    $iloSession = $server | Get-OVIloSso -IloRestSession
  
    $iloIP = $server  | % { $_.mpHostInfo.mpIpAddresses[-1].address }
        
    $ilosessionkey = $iloSession."X-Auth-Token"
 
    # Creation of the header using the SSO Session Key 

    $headerilo = @{} 
    $headerilo["Content-Type"] = "application/json" 
    $headerilo["X-Auth-Token"] = $ilosessionkey 
    $headerilo["OData-Version"] = "4.0"
       
    # Creation of the body content to pass to iLO to request a CSR

    # Taking the Synergy server name "Frame1, bay 5" to generate the iLO name ilo-Frame1bay5.lj.lab
    $servername_withoutspaceandcomma = (($server.name).replace(' ', '')).replace(',', '')
    $CommonName = "ilo-" + $servername_withoutspaceandcomma + ".lj.lab"
 
    $city = "Houston"
    $Country = "US"
    $OrgName = "HPE"
    $OrgUnit = "Synergy"
    $State = "Texas"


    $bodyiloParams = @{
        City       = $city ;
        CommonName = $CommonName;
        Country    = $Country;
        OrgName    = $OrgName;
        OrgUnit    = $OrgUnit;
        State      = $State
    } | ConvertTo-Json 


 
    # Sending the request to iLO to generate a CSR
 
    $rest = Invoke-WebRequest -Uri "https://$iloIP/redfish/v1/Managers/1/SecurityService/HttpsCert/Actions/HpeHttpsCert.GenerateCSR" -Headers $headerilo -Body $bodyiloParams -Method Post  
    Write-Host "`nGenerating CSR on iLo $iloIP. Please wait..."
       
     
    # Collecting CSR from iLO

    do {
      
        $restCSR = Invoke-WebRequest -Uri "https://$iloIP/redfish/v1/Managers/1/SecurityService/HttpsCert/" -Headers $headerilo -Method Get 
        $CertificateSigningRequest = ($restCSR.Content | ConvertFrom-Json).CertificateSigningRequest 
   
    }
    until ($CertificateSigningRequest)
    
    # Saving CSR to a local file
    $CertificateSigningRequest | Out-File "C:\temp\request.csr"


    # Generating CA-Signed certificate from an available CA using the iLO CSR

    $CA = Get-CertificationAuthority | select -First 1 | % Computername
    Submit-CertificateRequest -path C:\temp\request.csr -CertificationAuthority (Get-CertificationAuthority $CA) -Attribute CertificateTemplate:WebServer

    "-----BEGIN CERTIFICATE-----" | Out-File C:\temp\mycert.cer
    (Get-IssuedRequest -CertificationAuthority (Get-CertificationAuthority $CA) -Property "RawCertificate" | select -Last 1).RawCertificate.trim("`r`n") | Out-File C:\Temp\mycert.cer -Append
    "-----END CERTIFICATE-----" | Out-File C:\temp\mycert.cer -Append

    $certificate = Get-Content C:\temp\mycert.cer -raw

    $certificate = $certificate -join "`n"

    
    # Importing new certificate in iLO

    $bodyiloParams = @"
     {
        "Certificate": "$certificate"
}
"@
 

    $rest = Invoke-WebRequest -Uri "https://$iloIP/redfish/v1/Managers/1/SecurityService/HttpsCert/Actions/HpeHttpsCert.ImportCertificate/" -Headers $headerilo -Body $bodyiloParams -Method Post  
 
    Write-Host "`nImport Certificate Successful on iLo $iloIP, Please wait, iLO Reset in Progress..."
       
    sleep 20

    # Importing the new iLO certificates in OneView
    Add-OVApplianceTrustedCertificate -ComputerName $iloIP
    write-host "`nThe new iLO CA-Signed SSL certificate of $($server.name) using iLO $iloIP has been imported in OneView "
      
    #Refreshing Compute modules 
    Get-OVServer -Name $server.name | Update-OVServer -Async | Out-Null
    Write-host "`nOneView is refreshing $($server.name) to update the status of the server using the new certificate..." -ForegroundColor Yellow

}



Read-Host -Prompt "`nOperation done ! Hit return to close" 
