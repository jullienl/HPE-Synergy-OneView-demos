<# 

This PowerShell script generates an iLO SSL certificate signed by a Certificate Authority (CA) for all servers managed by HPE OneView that are using a self-signed certificate.

Steps of this script: 
1- Find the first trusted Certification Authority server available on the network
        Note: Only works if the machine from where you execute this script is in an AD domain
2- Add the root certificate of the Certification Authority server to the Oneview trust store if it is not present
3- Collect iLO certificate information from all servers to check if they are self-signed (using RedFish)
4- For servers using a self-signed certificate:
    - Create a Certificate Signing Request in iLO using the 'Certificate Signing Request variables' (at the begining of the script) 
    - Submit CSR to the Certificate Authority server 
    - Import new CA-signed certificate on iLOs
    - Remove old iLO self-signed certificate to the OneView trust store
    - Add new iLO CA-signed certificate to the Oneview trust store
    - Perform a server hartdware refresh to re-establish the communication with the iLO
    - Make sure the alert 'network connectivty has been lost' is cleared

Gen9 and Gen10 servers are supported 

Requirements: 
- Latest HPEOneView and PSPKI libraries 
- OneView administrator account.


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

# Certificate Signing Request variables
$city = "Houston"
$Country = "US"
$OrgName = "HPE"
$OrgUnit = "Synergy"
$State = "Texas"

# OneView 
$username = "Administrator"
$IP = "composer.lj.lab"


# MODULES TO INSTALL/IMPORT

# HPEONEVIEW
# If (-not (get-module HPEOneView.550 -ListAvailable )) { Install-Module -Name HPEOneView.550 -scope Allusers -Force }
# import-module HPEOneView.550

# PSPKI
# CA scripts -
# On Windows 7/8/8.1/10 some PSPKI cmdlets are not available so it is required to install RSAT (Remote System Administration Tools)
# Download page: https://www.microsoft.com/en-us/download/details.aspx?id=45520

If (-not (get-module PSPKI -ListAvailable )) { Install-Module -Name PSPKI -scope Allusers -Force }
import-module PSPKI


$secpasswd = read-host  "Please enter the OneView password" -AsSecureString
 
# Connection to the Synergy Composer
$credentials = New-Object System.Management.Automation.PSCredential ($username, $secpasswd)
Connect-OVMgmt -Hostname $IP -Credential $credentials | Out-Null

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

#import-OVSSLCertificate -ApplianceConnection ($connectedSessions | ? { $_.name -eq $IP }) 

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

$servers = Get-OVServer
# $servers = Get-OVServer | select -first 1
# $servers = Get-OVServer -Name "Frame1, bay 6"

## Finding the first trusted Certification Authority server available on the network
## Note: this command only works if the machine from where you execute this script is in a domain

$CA = Get-CertificationAuthority | select -First 1 

If ($CA -eq $Null) {
    write-warning "Error, a certificate Authority Server cannot be found on the network ! Canceling task..."
    return
}
else {

    $CA_computername = $CA | % Computername
    $CA_displayname = $CA | % displayname

    # Is the CA root certificate present in the Oneview Trust store?
    $CA_cert_in_OV_Store = Get-OVApplianceTrustedCertificate -Name $CA_displayname -ErrorAction SilentlyContinue

    if (-not $CA_cert_in_OV_Store) {
        write_host "The trusted CA root certificate is not found in the OneView trust store, adding it now..."
    
        ## Collecting the PEM CA certificate 
        ( Get-IssuedRequest -CertificationAuthority $CA -Property "RawCertificate" | ? CommonName -eq $CA_displayname).RawCertificate.trim("`r`n") | Out-File C:\Temp\CAcert.cer 
        
        # Adding trusted CA root certificate to OneView trust store
        $addcerttask = Get-ChildItem C:\temp\cacert.cer  | Add-OVApplianceTrustedCertificate 
    
        if ($addcerttask.taskstate -eq "Completed" ) {
            write-host "Trusted CA root certificated added successfully yo OneView trust store !"   
        }
        else {
            Write-Warning "Error - Trusted CA root certificated cannot be added to the OneView trust store !"
            $addcerttask.taskErrors
            return
        }

    }

    ForEach ($server in $servers) {

        $iloSession = $server | Get-OVIloSso -IloRestSession
  
        $iloIP = $server  | % { $_.mpHostInfo.mpIpAddresses[-1].address }
        $Ilohostname = $server  | % { $_.mpHostInfo.mpHostName }
        $iloModel = $server  | % mpmodel
        
        $ilosessionkey = $iloSession."X-Auth-Token"
 
        # Creation of the header using the SSO Session Key 

        $headerilo = @{} 
        $headerilo["Content-Type"] = "application/json" 
        $headerilo["X-Auth-Token"] = $ilosessionkey 
        $headerilo["OData-Version"] = "4.0"
       

        #Collecting iLO certificate information
        try {
            $certificate = Invoke-WebRequest -Uri "https://$iloIP/redfish/v1/Managers/1/SecurityService/HttpsCert/"  -Headers $headerilo -ContentType "application/json" -Method GET -UseBasicParsing 
            

        }
        catch {
            Write-Warning "Error ! The iLO certificate information cannot be collected for server [$($server.name)] " 
            $certificate.Content
            break
    
        }

        $issuer = (($certificate.Content | Convertfrom-Json).X509CertificateInformation.Issuer)
        
        if ($issuer -match "Default Issuer" ) {

            $found = $true
            write-host "`n[$($server.name)] uses an iLO self-signed certificate, generating a new CA-signed certificate..."
            
            # Creation of the body content to pass to iLO to request a CSR

            # Certificate Signing Request information
            $CommonName = $Ilohostname
 
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


                Write-Host "`tGenerating CSR on iLo $iloIP. Please wait..."
            }
            Catch { 
                failure
                write-host "`t$($server.name) - iLO $iloIP :" -f Cyan -NoNewline; Write-Host " Generate Certificate Signing Request failure !" -ForegroundColor red
                break
            }     
     
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
 
            ## Submitting the CSR using the default webServer certificate template
            Submit-CertificateRequest -path C:\temp\request.csr -CertificationAuthority (Get-CertificationAuthority $CA_computername) -Attribute CertificateTemplate:WebServer | Out-Null
            ### To get the correct certificate template name, use: 
            ### (get-catemplate -CertificationAuthority $ca).Templates.Name
  
            ## Building the certificate 
            "-----BEGIN CERTIFICATE-----" | Out-File C:\temp\mycert.cer
            ( Get-IssuedRequest -CertificationAuthority (Get-CertificationAuthority $CA_computername) -Property "RawCertificate" | select -Last 1 ).RawCertificate.trim("`r`n") | Out-File C:\Temp\mycert.cer -Append
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
            Catch { 
                failure
                write-host "`n$($server.name) - iLO $iloIP :" -f Cyan -NoNewline; Write-Host " Import CA-Signed certificate failure !" -ForegroundColor red
                break 
            }

            Write-Host "`tImport Certificate Successful on iLo $iloIP `n`tPlease wait, iLO Reset in Progress..."
       
            # Remove the old iLO self-signed certificate from the Oneview trust store
            Get-OVApplianceTrustedCertificate -Name $Ilohostname | Remove-OVApplianceTrustedCertificate -Confirm:$false | Wait-OVTaskComplete | Out-Null
            
            # Wait for OneView to issue an alert about a communication issue with the iLO due to invalid iLO certificate
            Do {
                # Collect data for the 'Unable to establish secure communication with server' alert
                $ilocertalert = ( $server  | Get-OVAlert -severity Critical -AlertState Locked | Where-Object { 
                        $_.description -Match "Unable to establish secure communication with the server"  
                    })

                sleep 2
            }
            until ( $ilocertalert )
            
          

            
            #############################################################################
            # The following is working with OneView 6.0 and later ONLY
            ##############################################################################

            # Add new iLO CA-signed certificate to the Oneview trust store
            $addcerttask = Add-OVApplianceTrustedCertificate -ComputerName $iloIP -force | Wait-OVTaskComplete

            if ($addcerttask.taskstate -eq "Completed" ) {
                write-host "`tiLO CA-signed certificate added successfully to the Oneview trust store !"   
            }
            else {
                Write-Warning "`tError - iLO CA-signed certificate cannot be added to the OneView trust store !"
                $addcerttask.taskErrors
                return
            }

            # Perform a server hardware refresh to re-establish the communication with the iLO
            try {
                write-host "`t$($SH.name) refresh in progress..."
                $refreshtask = $server | Update-OVServer | Wait-OVTaskComplete
            }
            catch {
                Write-Warning "`tError - $($SH.name) refresh cannot be completed!"
                $refreshtask.taskErrors
                return
            }

            # Check that the alert 'network connectivty has been lost' has been cleared.
            $networkconnectivityalertresult = Send-OVRequest -uri $ilocertalert.uri

            if ($networkconnectivityalertresult.alertState -eq "Cleared" ) {
                write-host "`tiLO [$($iloIP)] CA-signed certificate operation completed successfully and communication with [$($server.name)] has been restored with Oneview !" -ForegroundColor Cyan 
            }
            else {
                write-warning "`tError ! Communication with [$($SH.name)] cannot be restored with Oneview !"
            }

            <#############################################################################
            # The following was working with OneView 5.x but not with 6.x 
            ##############################################################################
            # Importing the new iLO certificates in OneView
  
            ## This step is not required as long as the CA certificate in 
            # done automatically when OneView detects an iLO reset
            ## Add-OVApplianceTrustedCertificate -ComputerName $iloIP

            ## Waiting for the iLO reset to complete
            $nowminus20mn = ((get-date).AddMinutes(-20))
  
            Do {
                $successfulresetalert = Get-OVServer -Name $server.name | `
                    Get-OValert -Start (get-date -UFormat "%Y-%m-%d") | `
                    ? description -match "Network connectivity has been restored" | Where-Object { (get-date $_.created -Format FileDateTimeUniversal) -ge (get-date $nowminus20mn -Format FileDateTimeUniversal) }
            }
            Until ($successfulresetalert)
  
            Write-Host "`tiLO Reset completed"

            ## Waiting for the new refresh to complete
            Do {
                $Runningrefreshtask = Get-OVServer -Name $server.name | Get-OVtask -Name Refresh -State Running -ErrorAction SilentlyContinue
            }
            Until ($Runningrefreshtask)

            Write-host "`tOneView is refreshing '$($server.name)' to update the status of the server using the new certificate..." -ForegroundColor Yellow
            #>


        }
      
    }

    if (-not $found) {
        write-host "Operation completed ! All servers use iLO CA-signed certificate ! "
    }
    else {
        write-host "Operation completed ! All other servers use iLO CA-signed certificate ! "
    }
}
        
Disconnect-OVMgmt

Read-Host -Prompt "Hit return to close" 
