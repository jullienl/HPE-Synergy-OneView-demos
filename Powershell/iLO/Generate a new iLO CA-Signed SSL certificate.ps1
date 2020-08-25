<# 

This PowerShell script generates a new iLO CA-Signed SSL certificate to all servers managed by OneView 


Steps: 

A first iLO RedFish command is used to create a Certificate Signing Request in iLO 

The CSR is submitted to an available Certificate Autority server and the new signed certificate is downloaded

A second RedFish command is used to import the new CA-Signed certificate into iLO which triggers the iLO to restart

Then the new certificate is imported into OneView and a OneView refresh takes place to update the status of the server using the new certificate.


Requirements: Latest HPEOneView and PSPKI libraries - OneView administrator account.
Management Processor support: iLO4 and iLO5


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


function Failure {
    $global:helpme = $body
    $global:helpmoref = $moref
    $global:result = $_.Exception.Response.GetResponseStream()
    $global:reader = New-Object System.IO.StreamReader($global:result)
    $global:responseBody = $global:reader.ReadToEnd();
    Write-Host -BackgroundColor:Black -ForegroundColor:Red "Status: A system exception was caught."
    Write-Host -BackgroundColor:Black -ForegroundColor:Red $global:responsebody
    Write-Host -BackgroundColor:Black -ForegroundColor:Red "The request body has been saved to `$global:helpme"
    break
}


# Filter the servers where you want to generate a new CA-Signed certificate
# Use any filter to limit to only the correct resources

$servers = Get-OVServer
# $servers = Get-OVServer | select -first 1
# $servers = Get-OVServer -Name "Frame1, bay 5"


ForEach ($server in $servers) {

    $iloSession = $server | Get-OVIloSso -IloRestSession
  
    $iloIP = $server  | % { $_.mpHostInfo.mpIpAddresses[-1].address }
    $iloModel = $server  | % mpmodel
        
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

 
    # Sending the request to iLO to generate a CSR
 
    Try {
   
        #iLO5
        if ($iloModel -eq "iLO5") {

            $bodyilo5Params = @{
                City       = $city;
                CommonName = $CommonName;
                Country    = $Country;
                OrgName    = $OrgName;
                OrgUnit    = $OrgUnit;
                State      = $State; 
                IncludeIP  = $true
            } | ConvertTo-Json 

            $rest = Invoke-WebRequest -Uri "https://$iloIP/redfish/v1/Managers/1/SecurityService/HttpsCert/Actions/HpeHttpsCert.GenerateCSR" -Headers $headerilo -Body $bodyilo5Params -Method Post  
        }

        #iLO4
        if ($iloModel -eq "iLO4") {

            $bodyilo4Params = @{
                Action     = "GenerateCSR";
                City       = $city;
                CommonName = $CommonName;
                Country    = $Country;
                OrgName    = $OrgName;
                OrgUnit    = $OrgUnit;
                State      = $State; 
                IncludeIP  = $true
            } | ConvertTo-Json 

            $rest = Invoke-WebRequest -Uri "https://$iloIP/redfish/v1/Managers/1/SecurityService/HttpsCert/" -Headers $headerilo -Body $bodyilo4Params -Method Post  
        }


        Write-Host "`nGenerating CSR on iLo $iloIP. Please wait..."
    }
    Catch { failure }     
     
    # Collecting CSR from iLO

    do {
      
        $restCSR = Invoke-WebRequest -Uri "https://$iloIP/redfish/v1/Managers/1/SecurityService/HttpsCert/" -Headers $headerilo -Method Get 
        $CertificateSigningRequest = ($restCSR.Content | ConvertFrom-Json).CertificateSigningRequest 
        sleep 3
   
    }
    until ($CertificateSigningRequest)
    
    # Saving CSR to a local file

    $CertificateSigningRequest | Out-File "C:\temp\request.csr"


    # Generating CA-Signed certificate from an available CA using the iLO CSR
  
    ## Finding the first CA server available on the network (this command only works if the machine from where you execute this script is in a domain)
    $CA = Get-CertificationAuthority | select -First 1 | % Computername
  
    ## Submitting the CSR using the default webServer certificate template
    Submit-CertificateRequest -path C:\temp\request.csr -CertificationAuthority (Get-CertificationAuthority $CA) -Attribute CertificateTemplate:WebServer | Out-Null
    ### To get the correct certificate template name, use: 
    ### (get-catemplate -CertificationAuthority $ca).Templates.Name
  
    ## Building the certificate 
    "-----BEGIN CERTIFICATE-----" | Out-File C:\temp\mycert.cer
    (Get-IssuedRequest -CertificationAuthority (Get-CertificationAuthority $CA) -Property "RawCertificate" | select -Last 1).RawCertificate.trim("`r`n") | Out-File C:\Temp\mycert.cer -Append
    "-----END CERTIFICATE-----" | Out-File C:\temp\mycert.cer -Append

    ## Formatting the built certificate for the JSON body content
    $certificate = Get-Content C:\temp\mycert.cer -raw

    $certificate = $certificate -join "`n"

    $bodyiloParams = @"
     {
        "Certificate": "$certificate"
}
"@
 

    # Importing new certificate in iLO
  
    Try {
        $rest = Invoke-WebRequest -Uri "https://$iloIP/redfish/v1/Managers/1/SecurityService/HttpsCert/Actions/HpeHttpsCert.ImportCertificate/" -Headers $headerilo -Body $bodyiloParams -Method Post  
    }
    Catch { failure }

    Write-Host "`nImport Certificate Successful on iLo $iloIP `nPlease wait, iLO Reset in Progress..."
       
 
    # Importing the new iLO certificates in OneView
  
    ## This step is done automatically when OneView detects an iLO reset
    ## Add-OVApplianceTrustedCertificate -ComputerName $iloIP
  

    ## Waiting for the iLO reset to complete
    $nowminus20mn = ((get-date).AddMinutes(-20))
  
    Do {
        $successfulresetalert = Get-OVServer -Name $server.name | `
            Get-OValert -Start (get-date -UFormat "%Y-%m-%d") | `
            ? description -match "Network connectivity has been restored" | Where-Object { (get-date $_.created -Format FileDateTimeUniversal) -ge (get-date $nowminus20mn -Format FileDateTimeUniversal) }
    }
    Until ($successfulresetalert)
  
    Write-Host "`niLO Reset completed"

    ## Waiting for the new refresh to complete
    Do {
        $Runningrefreshtask = Get-OVServer -Name $server.name | Get-OVtask -Name Refresh -State Running -ErrorAction SilentlyContinue
    }
    Until ($Runningrefreshtask)

    Write-host "`nOneView is refreshing '$($server.name)' to update the status of the server using the new certificate..." -ForegroundColor Yellow



}

Disconnect-OVMgmt

Read-Host -Prompt "`nOperation done ! Hit return to close" 
