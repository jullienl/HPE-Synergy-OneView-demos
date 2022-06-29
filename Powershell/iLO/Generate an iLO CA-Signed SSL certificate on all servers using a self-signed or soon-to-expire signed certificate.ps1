<# 

This PowerShell script generates an iLO SSL certificate signed by a Certificate Authority (CA) 
for all servers managed by HPE OneView that use a self-signed certificate or soon-to-expire CA-signed certificate. 

$days_before_expiration defined in the variable section specifies the number of days before the expiration date when the certificates should be replaced.  

Steps of this script: 
1- Find the first trusted Certification Authority server available on the network
        Note: Only works if the host from which you are running this script is in an AD domain
2- Import the CA server's root certificate into the OneView trust store if it is not present
3- Collect iLO certificate information from all servers to check if they are self-signed or soon-to-expire CA-signed certificate (using RedFish)
4- For servers using a self-signed or soon-to-expire CA-signed certificate:
    - Create a Certificate Signing Request in iLO using the 'Certificate Signing Request variables' (at the beginning of the script) 
    - Submit CSR to the Certificate Authority server 
    - Import new CA-signed certificate into iLOs (triggers an iLO reset)
    - Remove old iLO self-signed certificate from the OneView trust store
    - Perform a server hardware refresh to re-establish the communication with the iLO (only with OneView < 6.10)
    - Make sure the alert 'network connectivity has been lost' is cleared (only with OneView < 6.10)

Gen9 and Gen10 servers are supported 

Requirements:
   - HPE OneView Powershell Library
   - HPE OneView administrator account 
   - PSPKI Powershell Library 


Output sample:
-------------------------------------------------------------------------------------------------------
Please enter the OneView password: ********
The trusted CA root certificate has been found in the OneView trust store, skipping the add operation.
                                                                                                                                                                                                           
[Frame1, bay 1 - iLO: 192.168.0.35]: work in progress...                                                                                                                                                           
        iLO self-signed certificate detected                                                                                                                                                         
        Generating a new CA-signed certificate                                                                                                                                                             
        Creating a Certificate Signing Request (can take several minutes on iLO4)                                                                                                                          
        A reset of the iLO is going to take place to activate the new certificate...
        Once the iLO reset is complete, the CA-signed certificate will be available
        The old iLO certificate has been successfully removed from the Oneview trust store
        Operation completed successfully !

[Frame1, bay 2 - iLO: 192.168.0.36]: work in progress...
        The iLO uses a CA-signed certificate with an expiration date greater than 90 days
        No action required

[Frame1, bay 3 - iLO: 192.168.0.38]: work in progress...
        iLO CA-signed certificate detected that will expire in less than 90 days
        Generating a new CA-signed certificate
        Creating a Certificate Signing Request (can take several minutes on iLO4)
        A reset of the iLO is going to take place to activate the new certificate...
        Once the iLO reset is complete, the CA-signed certificate will be available
        The old iLO certificate has been successfully removed from the Oneview trust store
        Operation completed successfully !

[Frame3, bay 2 - iLO: 192.168.3.188]: work in progress...
        Error ! Server cannot be found. Resolve any issues as per the resolution steps provided in the alerts and retry the operation.
        Skipping server...
        
Operation completed with errors ! Not all iLOs with a self-signed certificate or an expired CA-signed certificate have been successfully updated!
Resolve any issues found in OneView and run this script again !
-------------------------------------------------------------------------------------------------------


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
# Number of days before the certificate expiration date when the signed certificate must be replaced. 
$days_before_expiration = "90"

# Certificate Signing Request variables
$city = "Mougins"
$Country = "FR"
$OrgName = "HPE"
$OrgUnit = "Synergy"
$State = "Paca"

# CA assigned Certificate template to be used for iLO certificates. Can be retrieved using: (get-catemplate <CertificateAuthority>).templates.name
$CertificateTemplate = "iLOWebServer"

# OneView 
$username = "Administrator"
$IP = "composer.lj.lab"


# MODULES TO INSTALL/IMPORT

# HPEONEVIEW
# If (-not (get-module HPEOneView.630 -ListAvailable )) { Install-Module -Name HPEOneView.630 -scope Allusers -Force }
# import-module HPEOneView.630

# PSPKI
# CA scripts -
# On Windows 7/8/8.1/10 some PSPKI cmdlets are not available so it is required to install RSAT (Remote System Administration Tools)
# Download page: https://www.microsoft.com/en-us/download/details.aspx?id=45520

If (-not (get-module PSPKI -ListAvailable )) { Install-Module -Name PSPKI -scope Allusers -Force }
import-module PSPKI

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
  
#################################################################################

Clear-Host

if (! $ConnectedSessions) {
    
    $secpasswd = read-host  "Please enter the OneView password" -AsSecureString
 
    # Connection to the Synergy Composer
    $credentials = New-Object System.Management.Automation.PSCredential ($username, $secpasswd)
    Connect-OVMgmt -Hostname $IP -Credential $credentials | Out-Null
}


$servers = Get-OVServer 

# $servers = Get-OVServer | select -Last 2
# $servers = Get-OVServer -Name "Frame3, bay 7"

# $server = Get-OVServer | select -first 1
# $server = Get-OVServer -Name "Frame1, bay 2"

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

    # Is the CA root certificate present in the OneView Trust store?
    $CA_cert_in_OV_Store = Get-OVApplianceTrustedCertificate -Name $CA_displayname -ErrorAction SilentlyContinue

    if (-not $CA_cert_in_OV_Store) {
        write-host "The trusted CA root certificate is not found in the OneView trust store, adding it now..."
    
        ## Collecting trusted CA root certificate 
        $CA.Certificate | % { set-content -value $($_.Export([Security.Cryptography.X509Certificates.X509ContentType]::Cert)) -encoding byte -path "$directorypath\CAcert.cer" }
        $cerBytes = Get-Content "$directorypath\CAcert.cer" -Encoding Byte
        [System.Convert]::ToBase64String($cerBytes) | Out-File $directorypath\CAcert.cer
        
        # Adding trusted CA root certificate to OneView trust store
        $addcerttask = Get-ChildItem $directorypath\cacert.cer | Add-OVApplianceTrustedCertificate 
    
        if ($addcerttask.taskstate -eq "Completed" ) {
            write-host "Trusted CA root certificated added successfully to OneView trust store !"   
        }
        else {
            Write-Warning "Error ! Trusted CA root certificated cannot be added to the OneView trust store !"
            $addcerttask.taskErrors
            return
        }

    }
    # Skipping the add operation if certificate found
    else {
        write-host "The trusted CA root certificate has been found in the OneView trust store, skipping the add operation."
    }

    $generate_error = $false
    $found = $false

    ForEach ($server in $servers) {

        #$iloIP = $server  | % { $_.mpHostInfo.mpIpAddresses[-1].address }
        $iloIP = $server.mpHostInfo.mpIpAddresses | ? type -ne LinkLocal | % address
        
        $Ilohostname = $server  | % { $_.mpHostInfo.mpHostName }
        $iloModel = $server  | % mpmodel

        write-host "`n[$($server.name) - iLO: $iloIP]: work in progress..."

        try {
            $iloSession = $server | Get-OVIloSso -IloRestSession
        }
        catch {
            Write-host "`tError ! Server cannot be found. Resolve any issues as per the resolution steps provided in the alerts and retry the operation." -ForegroundColor red
            Write-host "`tSkipping server..." -ForegroundColor red
            $generate_error = $true
            continue
        }
          
        
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
            Write-host "`tError ! The iLO certificate information cannot be collected!" -ForegroundColor red
            Write-host "`tSkipping server..." -ForegroundColor red
            $generate_error = $true
            # $certificate.Content
            continue
    
        }

        $serialnumber = ($certificate.Content | Convertfrom-Json).X509CertificateInformation.SerialNumber.replace(":", "")
        
        $issuer = ($certificate.Content | Convertfrom-Json).X509CertificateInformation.Issuer
        $ValidNotAfter = ($certificate.Content | Convertfrom-Json).X509CertificateInformation.ValidNotAfter
        $expiresInDays = [math]::Ceiling((([datetime]$ValidNotAfter) - (Get-Date)).TotalDays)

        if ($issuer -match "Default Issuer" -or [int]$expiresInDays -lt $days_before_expiration ) {

            $found = $true

            if ($issuer -match "Default Issuer") {
                write-host "`tiLO self-signed certificate detected"
                write-host "`tGenerating a new CA-signed certificate"
            }
            else {
                Write-Host "`tiLO CA-signed certificate detected that will expire in less than $days_before_expiration days"  
                write-host "`tGenerating a new CA-signed certificate"
            }

            # Creation of the body content to pass to iLO to request a CSR

            # Certificate Signing Request information
            $CommonName = $Ilohostname
 
            # Sending the request to iLO to generate a CSR
            Write-Host "`tCreating a Certificate Signing Request (can take several minutes on iLO4)"
 
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


            }
            Catch { 
                $err = (New-Object System.IO.StreamReader( $_.Exception.Response.GetResponseStream() )).ReadToEnd() 
                $msg = ($err | ConvertFrom-Json ).error.'@Message.ExtendedInfo'.MessageId
                Write-Host -BackgroundColor:Black -ForegroundColor:Red "`tCertificate Signing Request failure ! Message returned: [$($msg)]"
                continue
            }     
     
            # Collecting CSR from iLO

            do {
      
                $restCSR = Invoke-WebRequest -Uri "https://$iloIP/redfish/v1/Managers/1/SecurityService/HttpsCert/" -Headers $headerilo -Method Get 
                $CertificateSigningRequest = ($restCSR.Content | ConvertFrom-Json).CertificateSigningRequest 
                sleep 3
   
            }
            until ($CertificateSigningRequest)
    
            # Saving CSR to a local file in the execution directory
            $directorypath = Split-Path $MyInvocation.MyCommand.Path

            $CertificateSigningRequest | Out-File "$directorypath\request.csr"

            # Generating CA-Signed certificate from an available CA using the iLO CSR
 
            ## Submitting the CSR using the default webServer certificate template
            Submit-CertificateRequest -path $directorypath\request.csr -CertificationAuthority (Get-CertificationAuthority $CA_computername) -Attribute CertificateTemplate:$CertificateTemplate | Out-Null
            ### To get the correct certificate template name for the $CertificateTemplate name, use: 
            ### (get-catemplate -CertificationAuthority $ca).Templates.Name
  
            ## Building the certificate 
            "-----BEGIN CERTIFICATE-----" | Out-File $directorypath\mycert.cer
            ( Get-IssuedRequest -CertificationAuthority (Get-CertificationAuthority $CA_computername) -Property "RawCertificate" | ? CommonName -eq $CommonName | select -last 1 ).RawCertificate.trim("`r`n") | Out-File $directorypath\mycert.cer -Append #-Encoding ascii
            "-----END CERTIFICATE-----" | Out-File $directorypath\mycert.cer -Append


            ## Formatting the built certificate for the JSON body content
            $certificate = Get-Content $directorypath\mycert.cer -raw

            $bodyiloParams = ConvertTo-Json  @{ Certificate = "$certificate" }

            # Importing new certificate in iLO
  
            Try {
                $rest = Invoke-WebRequest -Uri "https://$iloIP/redfish/v1/Managers/1/SecurityService/HttpsCert/Actions/HpeHttpsCert.ImportCertificate/" -Headers $headerilo -Body $bodyiloParams -Method Post  
            }
            Catch { 
                $err = (New-Object System.IO.StreamReader( $_.Exception.Response.GetResponseStream() )).ReadToEnd() 
                $msg = ($err | ConvertFrom-Json ).error.'@Message.ExtendedInfo'.MessageId
                Write-Host -BackgroundColor:Black -ForegroundColor:Red "`tCertificate import failure ! Message returned: [$($msg)]"
                continue 
            }

            Write-Host "`tA reset of the iLO is going to take place to activate the new certificate..."
            Write-Host "`tOnce the iLO reset is complete, the CA-signed certificate will be available"
       
            # Remove the old certificate from the OneView trust store
            try {
                              
                Get-OVApplianceTrustedCertificate | ? { $_.certificate.serialnumber -eq $serialnumber } | Remove-OVApplianceTrustedCertificate -Confirm:$false | Wait-OVTaskComplete | Out-Null  
                Write-Host "`tThe old iLO certificate has been successfully removed from the Oneview trust store"
            }
            catch {
                Write-Host "`tError ! Old iLO certificate cannot be removed from the Oneview trust store !" -ForegroundColor red
            }
            

            # Wait for OneView to raise a task after the certificate change 
            $appliancename = ${Global:ConnectedSessions} | % name
            $applianceversion = Get-OVVersion | % $appliancename | % ApplianceVersion
            
            $ovversion = [string]$applianceversion.major + "." + [string]$applianceversion.Minor
            
            # If OV < 6.00
            # Procedure for HPE OneView 5.x ONLY
            if ($ovversion -lt 6.00 ) {

                # Importing the new iLO certificates in OneView
                ## This step is not required as long as the CA certificate is present in the OV trust store 
                ## Add-OVApplianceTrustedCertificate -ComputerName $iloIP

                ## Waiting for the iLO reset to complete
                $nowminus20mn = ((get-date).AddMinutes(-20))
    
                Do {
                    $successfulresetalert = Get-OVServer -Name $server.name | `
                        Get-OValert -Start (get-date -UFormat "%Y-%m-%d") | `
                        ? description -match "Network connectivity has been restored" | Where-Object { (get-date $_.created -Format FileDateTimeUniversal) -ge (get-date $nowminus20mn -Format FileDateTimeUniversal) }
                }
                Until ($successfulresetalert)
    
                ## Waiting for the new refresh to complete
                Write-host "`tOneView is refreshing '$($server.name)' to update the status of the server using the new certificate..." 
                Do {
                    $Runningrefreshtask = Get-OVServer -Name $server.name | Get-OVtask -Name Refresh -State Running -ErrorAction SilentlyContinue
                }
                Until ($Runningrefreshtask)
                
                write-host "`tOperation completed successfully !" -ForegroundColor Cyan 

            }
            
            # If OV = 6.00
            # Procedure for HPE OneView 6.0 ONLY
            elseif ($ovversion -eq 6.00 ) {
                
                # Wait for OneView to issue an alert about a communication issue with the iLO due to invalid iLO certificate
                Do {
                    # Collect data for the 'Unable to establish secure communication with server' alert
                    $ilocertalert = `
                    ( $server  | Get-OVAlert -severity Critical -AlertState Locked | Where-Object { 
                            $_.description -Match "Unable to establish secure communication with the server" 
                        }) 

                    sleep 2
                }
                until ( $ilocertalert )

                # Add new iLO CA-signed certificate to the OneView trust store
                $addcerttask = Add-OVApplianceTrustedCertificate -ComputerName $iloIP -force | Wait-OVTaskComplete

                if ($addcerttask.taskstate -eq "Completed" ) {
                    write-host "`tiLO CA-signed certificate added successfully to the OneView trust store !"   
                }
                else {
                    Write-Warning "`tError ! iLO CA-signed certificate cannot be added to the OneView trust store !"
                    $addcerttask.taskErrors
                    return
                }

                # Perform a server hardware refresh to re-establish the communication with the iLO
                try {
                    write-host "`t$($SH.name) refresh in progress..."
                    $refreshtask = $server | Update-OVServer | Wait-OVTaskComplete
                }
                catch {
                    Write-Warning "`tError ! $($SH.name) refresh cannot be completed!"
                    $refreshtask.taskErrors
                    return
                }

                # Check that the alert 'network connectivity has been lost' has been cleared.
                $networkconnectivityalertresult = Send-OVRequest -uri $ilocertalert.uri

                if ($networkconnectivityalertresult.alertState -eq "Cleared" ) {
                    write-host "`tOperation completed successfully and communication with server has been restored with Oneview !" -ForegroundColor Cyan 
                }
                else {
                    write-host "`tError ! Communication with server cannot be restored with Oneview !" -ForegroundColor Yellow
                }
            }
         
            # If OV >= 6.10
            # Procedure for HPE OneView 6.10 and later ONLY
            # Starting with 6.10, OV detects the certificate change and no action is required
            elseif ( $ovversion -ge 6.10 ) {

                write-host "`tOperation completed successfully !" -ForegroundColor Cyan 
                
            }
        } 
        else {
            Write-Host "`tThe iLO uses a CA-signed certificate with an expiration date greater than $days_before_expiration days"
            write-host "`tNo action required" -ForegroundColor Cyan
           
        }
      
    }

    if (-not $found) {
        write-host "`nOperation completed ! No action is required as all servers use an unexpired iLO certificate signed by a certificate authority."
    }
    elseif ($generate_error) {
        write-host "`nOperation completed with errors ! Not all iLOs with a self-signed certificate or an expired CA-signed certificate have been successfully updated!" 
        write-host "Resolve any issues found in OneView and run this script again !"

    }
    else {
        write-host "`nOperation completed successfully ! All iLOs with a self-signed certificate or an expired CA-signed certificate have been successfully updated!"
    }
}
        
Disconnect-OVMgmt

# Cleaning working files
remove-item -Path "$directorypath\request.csr", "$directorypath\mycert.cer" 

Read-Host -Prompt "Hit return to close" 
