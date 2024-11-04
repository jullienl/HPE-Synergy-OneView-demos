<# 

This PowerShell script generates an SSL certificate signed by a Certificate Authority (CA) for all servers managed by HPE OneView that are currently using a self-signed certificate or have a CA-signed certificate that is soon to expire.


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

    Note: OneView automatically runs the tasks necessary to restore communication with the iLO when a certificate change is detected.
    
Gen9, Gen10 and Gen10+ servers are supported 

Requirements:
   - HPE OneView Powershell Library
   - HPE OneView administrator account 
   - PSPKI Powershell Library 


Output sample:
    Please enter the OneView password: ********
    [Frame3, bay 1 - iLO 192.168.3.186]: Analysis in progress...
    [Frame3, bay 1 - iLO 192.168.3.186]: iLO self-signed certificate detected. Generating a new CA-signed certificate...
    [Frame3, bay 1 - iLO 192.168.3.186]: Creating a certificate signing request.
    [Frame3, bay 1 - iLO 192.168.3.186]: iLO reset in progress to activate the new certificate...
    [Frame3, bay 1 - iLO 192.168.3.186]: The old iLO certificate has been successfully removed from the Oneview trust store
    [Frame3, bay 1 - iLO 192.168.3.186]: Operation completed successfully!
    [Frame3, bay 10 - iLO 192.168.3.183]: Analysis in progress...
    [Frame3, bay 10 - iLO 192.168.3.183]: The iLO uses a signed certificate with an expiration date greater than 90 days. No action is required as expiration = 2650 days
    [Frame3, bay 11 - iLO 192.168.3.181]: Analysis in progress...
    [Frame3, bay 11 - iLO 192.168.3.181]: The iLO uses a signed certificate with an expiration date greater than 90 days. No action is required as expiration = 1214 days
    Operation completed successfully! All iLOs with a self-signed certificate have been successfully updated.


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
$State = "PACA"

# CA assigned Certificate template to be used for iLO certificates. Can be retrieved using: (get-catemplate <CertificateAuthority>).templates.name
$CertificateTemplate = "iLOWebServer"

# OneView 
$OneView_username = "Administrator"
$OneView_IP = "composer.lab"


# MODULES TO INSTALL/IMPORT

# Check if the HPE OneView PowerShell module is installed and install it if not
try {
    
    $APIversion = Invoke-RestMethod -Uri "https://$IP/rest/version" -Method Get | select -ExpandProperty currentVersion
    
    switch ($APIversion) {
        "3800" { [decimal]$OneViewVersion = "6.6" }
        "4000" { [decimal]$OneViewVersion = "7.0" }
        "4200" { [decimal]$OneViewVersion = "7.1" }
        "4400" { [decimal]$OneViewVersion = "7.2" }
        "4600" { [decimal]$OneViewVersion = "8.0" }
        "4800" { [decimal]$OneViewVersion = "8.1" }
        "5000" { [decimal]$OneViewVersion = "8.2" }
        "5200" { [decimal]$OneViewVersion = "8.3" }
        "5400" { [decimal]$OneViewVersion = "8.4" }
        "5600" { [decimal]$OneViewVersion = "8.5" }
        "5800" { [decimal]$OneViewVersion = "8.6" }
        "6000" { [decimal]$OneViewVersion = "8.7" }
        "6200" { [decimal]$OneViewVersion = "8.8" }
        "6400" { [decimal]$OneViewVersion = "8.9" }
        "6600" { [decimal]$OneViewVersion = "9.0" }
        "6800" { [decimal]$OneViewVersion = "9.1" }
        "7000" { [decimal]$OneViewVersion = "9.2" }
        Default { $OneViewVersion = "Unknown" }
    }

    Write-Verbose "Appliance running HPE OneView $OneViewVersion"

    If ($OneViewVersion -ne "Unknown" -and -not (get-module HPEOneView* -ListAvailable )) { 
        
        Find-Module HPEOneView* | Where-Object version -le $OneViewVersion | Sort-Object version | Select-Object -last 1 | Install-Module -scope CurrentUser -Force -SkipPublisherCheck

    }
}
catch {

    Write-Error "Error: Unable to contact HPE OneView to retrieve the API version. The OneView PowerShell module cannot be installed."
}



# PSPKI
# CA scripts -
# On Windows 7/8/8.1/10 some PSPKI cmdlets are not available so it is required to install RSAT (Remote System Administration Tools)
# Download page: https://www.microsoft.com/en-us/download/details.aspx?id=45520

If (-not (get-module PSPKI -ListAvailable )) { Install-Module -Name PSPKI -scope CurrentUser -Force }

# Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force


#################################################################################

Clear-Host

if (! $ConnectedSessions) {
    
    $secpasswd = read-host  "Please enter the OneView password" -AsSecureString
 
    # Connection to the Synergy Composer
    $credentials = New-Object System.Management.Automation.PSCredential ($OneView_username, $secpasswd)
    
    try {
        Connect-OVMgmt -Hostname $OneView_IP -Credential $credentials | Out-Null
    }
    catch {
        Write-Warning "Cannot connect to '$OneView_IP'! Exiting... "
        return
    }
}

# Getting all servers managed by Oneview
$servers = Get-OVServer  

# $servers = Get-OVServer | ? { $_.mpModel -eq "iLO5" -or $_.mpModel -eq "iLO6" }
# $servers = Get-OVServer | ? { $_.mpModel -eq "iLO4" }
# $servers = Get-OVServer | ? name -eq "Frame1, bay 1"

## Finding the first trusted Certification Authority server available on the network
## Note: this command only works if the machine from where you execute this script is in a domain
try {
    $CA = Get-CertificationAuthority | select -First 1 
    
}
catch {
    Write-Error "Error, failed to retreive a certificate Authority Server"
    return
}

If ($CA -eq $Null) {
    Write-Error "Error, a certificate Authority Server cannot be found on the network ! Canceling task..."
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

        $iloIP = $server.mpHostInfo.mpIpAddresses | ? type -ne LinkLocal | % address
        $servername = $server.name
        $RootUri = "https://{0}" -f $iloIP
        
        $Ilohostname = $server | % { $_.mpHostInfo.mpHostName }
        $iloModel = $server | % mpmodel

        "[{0} - iLO {1}]: Analysis in progress..." -f $servername, $iloIP | write-host 

        try {         
            
            $iloSession = $server | Get-OVIloSso -IloRestSession -SkipCertificateCheck
        }
        catch {
            "[{0} - iLO {1}]: Error! Server cannot be found. Resolve any issues as per the resolution steps provided in the alerts and retry the operation. Skipping server!" -f $servername, $iloIP | Write-Host -ForegroundColor Red
            $generate_error = $true
            continue
        }
        
        # Collecting iLO certificate information
        try {
            
            $Location = '/redfish/v1/Managers/1/SecurityService/HttpsCert/'

            $certificate = Invoke-RestMethod -uri ($RootUri + $Location ) -Headers @{'Odata-Version' = "4.0"; 'X-Auth-Token' = $ilosession.'X-Auth-Token' } -SkipCertificateCheck
            
        }
        catch {
            "[{0} - iLO {1}]: Error ! The iLO certificate information cannot be collected! Skipping server!" -f $servername, $iloIP | Write-Host -ForegroundColor Red
            $generate_error = $true
            continue
    
        }

        $serialnumber = $certificate.X509CertificateInformation.SerialNumber.replace(":", "")
        $issuer = $certificate.X509CertificateInformation.Issuer
        $ValidNotAfter = $certificate.X509CertificateInformation.ValidNotAfter
        $expiresInDays = [math]::Ceiling((([datetime]$ValidNotAfter) - (Get-Date)).TotalDays)

        if ($issuer -match "Default Issuer" -or [int]$expiresInDays -lt $days_before_expiration ) {

            $found = $true

            if ($issuer -match "Default Issuer") {
                "[{0} - iLO {1}]: iLO self-signed certificate detected. Generating a new CA-signed certificate..." -f $servername, $iloIP | write-host 
            }
            else {
                "[{0} - iLO {1}]: iLO CA-signed certificate detected that will expire in less than {2} days. Generating a new CA-signed certificate..." -f $servername, $iloIP, $days_before_expiration | write-host 
            }

            # Creation of the body content to pass to iLO to request a CSR

            # Certificate Signing Request information
            $CommonName = $Ilohostname
 
            # Sending the request to iLO to generate a CSR
            "[{0} - iLO {1}]: Creating a certificate signing request." -f $servername, $iloIP | write-host 
 
            Try {
   
                # iLO5/6
                if ($iloModel -eq "iLO5" -or $iloModel -eq "iLO6") {

                    $bodyilo5Params = @{
                        City       = $city;
                        CommonName = $CommonName;
                        Country    = $Country;
                        OrgName    = $OrgName;
                        OrgUnit    = $OrgUnit;
                        State      = $State; 
                        IncludeIP  = $true
                    } | ConvertTo-Json 

                    $Location = '/redfish/v1/Managers/1/SecurityService/HttpsCert/Actions/HpeHttpsCert.GenerateCSR'

                    $response = Invoke-RestMethod -uri ($RootUri + $Location ) -Method POST -Headers @{'Odata-Version' = "4.0"; 'X-Auth-Token' = $ilosession.'X-Auth-Token'; 'Content-Type' = 'application/json' } -Body $bodyilo5Params -SkipCertificateCheck 
                            
                }
                
                # iLO4
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

                    $Location = '/redfish/v1/Managers/1/SecurityService/HttpsCert/'

                    $Response = Invoke-RestMethod -uri ($RootUri + $Location ) -Method POST -Headers @{'Odata-Version' = "4.0"; 'X-Auth-Token' = $ilosession.'X-Auth-Token'; 'Content-Type' = 'application/json' } -Body $bodyilo4Params -SkipCertificateCheck -verbose
                }

                if ($response.error.'@Message.ExtendedInfo'.MessageId) {

                    if ($response.error.'@Message.ExtendedInfo'.MessageId -notmatch "GeneratingCertificate") {
                        "[{0} - iLO {1}]: Error! Failed to create the certificate signing request! Message returned: {2} - Skipping server!" -f $servername, $iloIP, $response.error.'@Message.ExtendedInfo'.MessageId | Write-Host -ForegroundColor Red
                        $generate_error = $true
                        continue
                    }
                }
            }
            Catch { 
            
                "[{0} - iLO {1}]: Error! Failed to create the certificate signing request! Message returned: {2} - Skipping server!" -f $servername, $iloIP, $_.Exception.Response | Write-Host -ForegroundColor Red
                $generate_error = $true
                continue
            }     
     
            # Collecting CSR from iLO

            do {
    
                try {

                    $Location = '/redfish/v1/Managers/1/SecurityService/HttpsCert/'

                    $restCSR = Invoke-RestMethod -uri ($RootUri + $Location ) -Headers @{'Odata-Version' = "4.0"; 'X-Auth-Token' = $ilosession.'X-Auth-Token' } -SkipCertificateCheck

                    $CertificateSigningRequest = $restCSR.CertificateSigningRequest 
                    sleep 3
                
                }
                catch {
                    "[{0} - iLO {1}]: Error! Failed to retrieve the certificate signing request. Message returned: {2} - Skipping server!" -f $servername, $iloIP, $restCSR.error.'@Message.ExtendedInfo'.MessageId | Write-Host -ForegroundColor Red
                    $generate_error = $true
                    continue 
                }

            }
            until ($CertificateSigningRequest)

            # Saving CSR to a local file in the execution directory
            $CertificateSigningRequest | Out-File $PSScriptRoot\Request.csr 

            # Generating CA-Signed certificate from an available CA using the iLO CSR

            ## Submitting the CSR using the default webServer certificate template
            Submit-CertificateRequest -path $CSRfilePath -CertificationAuthority (Get-CertificationAuthority $CA_computername) -Attribute CertificateTemplate:$CertificateTemplate | Out-Null
            ### To get the correct certificate template name for the $CertificateTemplate name, use: 
            ### (get-catemplate -CertificationAuthority $ca).Templates.Name

            ## Building the certificate 
            "-----BEGIN CERTIFICATE-----" | Out-File $PSScriptRoot\Newcert.cer
            ( Get-IssuedRequest -CertificationAuthority (Get-CertificationAuthority $CA_computername) -Property "RawCertificate" | ? CommonName -eq $CommonName | select -last 1 ).RawCertificate.trim("`r`n") | Out-File $PSScriptRoot\Newcert.cer -Append #-Encoding ascii
            "-----END CERTIFICATE-----" | Out-File $PSScriptRoot\Newcert.cer -Append


            ## Formatting the built certificate for the JSON body content
            $certificate = Get-Content $PSScriptRoot\Newcert.cer -raw

            $bodyiloParams = ConvertTo-Json  @{ Certificate = "$certificate" }

            # Importing new certificate in iLO

            Try {
                $Location = '/redfish/v1/Managers/1/SecurityService/HttpsCert/Actions/HpeHttpsCert.ImportCertificate/'

                $rest = Invoke-RestMethod -uri ($RootUri + $Location ) -Method POST -Headers @{'Odata-Version' = "4.0"; 'X-Auth-Token' = $ilosession.'X-Auth-Token'; 'Content-Type' = 'application/json' } -Body $bodyiloParams -SkipCertificateCheck

            }
            Catch { 
                "[{0} - iLO {1}]: Error! Failed to import the new certificate! Message returned: {2} - Skipping server!" -f $servername, $iloIP, $rest.error.'@Message.ExtendedInfo'.MessageId | Write-Host -ForegroundColor Red
                $generate_error = $true
                continue 
            }

            "[{0} - iLO {1}]: iLO reset in progress to activate the new certificate..." -f $servername, $iloIP | Write-Host 
    
            # Remove the old certificate from the OneView trust store (if any)
            if (Get-OVApplianceTrustedCertificate | ? { $_.certificate.serialnumber -eq $serialnumber } ) {

                try {
                    Get-OVApplianceTrustedCertificate | ? { $_.certificate.serialnumber -eq $serialnumber } | Remove-OVApplianceTrustedCertificate -Confirm:$false | Wait-OVTaskComplete | Out-Null  
                    "[{0} - iLO {1}]: The old iLO certificate has been successfully removed from the Oneview trust store" -f $servername, $iloIP | Write-Host 
                }
                catch {
                    "[{0} - iLO {1}]: Error! The old iLO certificate cannot be removed from the Oneview trust store! Skipping server!" -f $servername, $iloIP | Write-Host -ForegroundColor Red
                    $generate_error = $true
                    continue 
                
                }
            }
        
            "[{0} - iLO {1}]: Operation completed successfully!" -f $servername, $iloIP | Write-Host           
    
        } 
        else {
            "[{0} - iLO {1}]: The iLO uses a signed certificate with an expiration date greater than {2} days. No action is required as expiration = {3} days" -f $servername, $iloIP, $days_before_expiration, $expiresInDays | Write-Host 
        
        }
    }
        
    if (-not $found) {
        "Operation completed! No action is required as all servers use an unexpired iLO certificate signed by a certificate authority." | Write-Host -ForegroundColor Cyan

    }
    elseif ($generate_error) {
        "Operation completed with errors! Not all iLOs with a self-signed certificate or an expired CA-signed certificate have been successfully updated! Resolve any issues found in OneView and run this script again." | Write-Host -ForegroundColor Cyan

    }
    else {
        "Operation completed successfully! All iLOs with a self-signed certificate or an expired CA-signed certificate have been successfully updated." | Write-Host -ForegroundColor Cyan

    }
    
    
    # Cleaning working files
    if (Get-ChildItem $PSScriptRoot\Request.csr -ErrorAction SilentlyContinue) {
        
        remove-item -Path "$PSScriptRoot\Request.csr"
    }
    
    if (Get-ChildItem $PSScriptRoot\Newcert.cer -ErrorAction SilentlyContinue) {
        
        remove-item -Path "$PSScriptRoot\Newcert.cer" 
    }
}
    
    
Disconnect-OVMgmt
Read-Host -Prompt "Hit return to close" 
