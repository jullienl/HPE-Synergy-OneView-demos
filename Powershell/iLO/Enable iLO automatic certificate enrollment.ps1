<# 

This PowerShell script generates an SSL certificate signed by a Certificate Authority (CA) for all servers managed by HPE OneView that are currently using a self-signed certificate or a CA-signed certificate that is about to expire.

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
    - PowerShell 7 (including both console and core editions)
    - HPE OneView PowerShell Library
    - HPE OneView administrator account
    - PSCertificateEnrollment Library
    
    - A Microsoft Certification Authority server with NDES role installed and configured must be available on the network


    - A certificate template supporting server authentication must be available for generating iLO certificates
    - PSPKI PowerShell Library
    - The computer executing this script must be part of a Microsoft Active Directory domain

Output sample:

    & '.\Generate an iLO CA-Signed SSL certificate on all servers using a self-signed or soon-to-expire signed certificate.ps1' -Check


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

param(
    [string]$NDESServerFQDN = "liogw.lj.lab",
    [string]$NDESUsername = "NdesSvc",
    [switch]$Check
)


#Region -------------------------------------------------------- Variables definition -----------------------------------------------------------------------------------------
# Number of days before the certificate expiration date when the signed certificate must be replaced. 
$days_before_expiration = "3630"

# Certificate Signing Request (CSR) variables
$city = "Mougins"
$Country = "FR"
$OrgName = "HPE"
$OrgUnit = "Compute"
$State = "PA"

# Name of the certificate template available in the Certification Authority (CA) to be used to generate iLO certificates.
# This template can be retrieved using 'Get-CertificateTemplate' and must support the server authentication application policy.
$CertificateTemplate = "iLOWebServer"

# OneView 
$OneView_username = "Administrator"
$OneView_IP = "composer.lj.lab"
#EndRegion


#Region -------------------------------------------------------- Modules to install --------------------------------------------------------------------------------------------

# Check if the HPE OneView PowerShell module is installed and install it if not
If (-not (get-module HPEOneView.* -ListAvailable )) {
    
    try {
        
        $APIversion = Invoke-RestMethod -Uri "https://$OneView_IP/rest/version" -Method Get | Select-Object -ExpandProperty currentVersion
        
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
        Return
    }
}


# PSPKI
# CA scripts -
# On Windows 7/8/8.1/10 some PSPKI cmdlets are not available so it is required to install RSAT (Remote System Administration Tools)
# Download page: https://www.microsoft.com/en-us/download/details.aspx?id=45520

If (-not (get-module PSPKI -ListAvailable )) { Install-Module -Name PSPKI -scope CurrentUser -Force -SkipPublisherCheck }

# Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force+

# Check if the script is running in PowerShell 7
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Error "This script requires PowerShell 7. Please run this script in PowerShell 7."
    exit
}

#EndRegion


#Region -------------------------------------------------------- Connection to HPE OneView -------------------------------------------------------------------------------------

Clear-Host

if (! $ConnectedSessions) {
    
    $secpasswd = read-host  "Please enter the HPE OneView password for $OneView_username" -AsSecureString
 
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
#EndRegion


# Retrieve all servers managed by HPE OneView
$servers = Get-OVServer | Where-Object { $_.mpModel -eq "iLO5" -or $_.mpModel -eq "iLO6" } | Select-Object -First 9

# $servers = Get-OVServer
# $servers = Get-OVServer | Where-Object { $_.mpModel -eq "iLO5" -or $_.mpModel -eq "iLO6" } | Where-Object { $_.name -ne "Frame3, bay 6" -and $_.name -ne "Frame3, bay 2" -and $_.name -ne "Frame3, bay 3" }
# $servers = Get-OVServer | Where-Object name -eq "Frame1, bay 1"





# Define the NDES server URL
$ndesUrl = "https://$NDESServerFQDN/certsrv/mscep_admin/"

# Password: QS#43fd2^TTtY
$PasswordLength = 8





###### Obtain the challenge password from the SCEP server #######

# Define the credentials for accessing the NDES server
$secPassword = read-host  "Please enter the NDES account password for $ndesUsername" -AsSecureString
$ndesCredential = New-Object System.Management.Automation.PSCredential ($ndesUsername, $secPassword)

# Define the request parameters
$requestParams = @{
    "operation" = "GetCACaps"
}

# Send the request to the NDES server
$NdesResponse = Invoke-Webrequest -Uri $ndesUrl -Method Post -Credential $ndesCredential -Body $requestParams

# Convert the HTML Output to Unicode
$HTML = [System.Text.Encoding]::Unicode.GetString($NdesResponse.RawContentStream.ToArray())

# Get the Password from the HTML Output
$Otp = ($HTML -split '\s+') -match "^[A-F0-9]{$($PasswordLength*2)}" | Select-Object -First 1

If ($null -eq $Otp) {
    Write-Warning "No OTP found in HTTP Response. Check your Permissions and the PasswordLength."
    return
}
else {
    Write-Host "The enrollment challenge password is: $Otp"
}






####### Configure iLO with SCEP server and challenge password. Customize CSR subject fields ########

####### Import the CA certificate of the SCEP server. ########


# Retrieve the CA object
$CA = Get-CertificationAuthority | Select-Object -First 1

# Get the CA certificate
$caCert = Get-CACertificate -CertificationAuthority $CA

# Define the path to save the CA certificate
$caCertPath = "C:\Temp\caCert.cer"

# Export the CA certificate to a file
$caCert | Export-Certificate -FilePath $caCertPath -Type CERT

Write-Output "CA certificate saved to $caCertPath"



# Define the URL of the CA certificate
$caCertUrl = "https://$NDESServerFQDN/certsrv/mscep/mscep.dll?operation=GetCACert&message=CA"

# Define the path to save the downloaded CA certificate
$caCertPath = "C:\Temp\caCert.cer"

# Download the CA certificate
Invoke-WebRequest -Uri $caCertUrl -OutFile $caCertPath

# Define the path to save the PEM formatted certificate
$caCertPemPath = "C:\Temp\caCert.pem"

# Load the downloaded certificate using the constructor
try {
    $certBytes = [System.IO.File]::ReadAllBytes($caCertPath)
    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 -ArgumentList $certBytes
}
catch {
    Write-Error "Failed to load the certificate: $_"
    return
}

# Convert the certificate to PEM format
$certPem = "-----BEGIN CERTIFICATE-----`n" + [System.Convert]::ToBase64String($cert.RawData, 'InsertLineBreaks') + "`n-----END CERTIFICATE-----"

# Save the PEM formatted certificate to a file
Set-Content -Path $caCertPemPath -Value $certPem

Write-Output "CA certificate in PEM format saved to $caCertPemPath"

####### Click on Enable to initiate Certificate Enrollment process ########
####### Check Certificate Enrollment status and reset iLO ########

return









#Region Finding the first Enterprise Certification Authority from a current Active Directory forest
# Note: this command only works if the machine from where you execute this script is in an Active Directory domain

# Check if the machine is part of an Active Directory domain
if (-not (Get-WmiObject -Class Win32_ComputerSystem).PartOfDomain) {
    Write-Error "Error: This machine is not part of an Active Directory domain. The script requires domain membership to retrieve a Certification Authority."
    return
}

try {
    $CA = Get-CertificationAuthority | Select-Object -First 1
}
catch {
    Write-Error "Error: Failed to retrieve a Certification Authority from the current Active Directory forest."
    return
}

if ($null -eq $CA) {
    Write-Error "Error: No Certification Authority Server can be found on the network! Canceling task..."
    return
}
else {

    $CA_computername = $CA | ForEach-Object Computername
    $CA_displayname = $CA | ForEach-Object displayname

    $TemplateFound = Get-CertificateTemplate -Name $CertificateTemplate -ErrorAction SilentlyContinue

    if (-not $TemplateFound) {
        Write-Error "Error, the certificate template '$CertificateTemplate' cannot be found ! Verify your Certificate Authority (CA) ! Canceling task..."
        return
    }
    
    #EndRegion

    #Region Is the CA root certificate present in the OneView Trust store?
    $CA_cert_in_OV_Store = Get-OVApplianceTrustedCertificate -Name $CA_displayname -ErrorAction SilentlyContinue

    if (-not $CA_cert_in_OV_Store) {

        write-host "The trusted CA root certificate is not found in the OneView trust store, adding it now..."
    
        ## Collecting trusted CA root certificate 
        $CA.Certificate | ForEach-Object { set-content -value $($_.Export([Security.Cryptography.X509Certificates.X509ContentType]::Cert)) -encoding byte -path "$directorypath\CAcert.cer" }
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
    else {
        # Skipping the add operation if certificate found
        write-host "The trusted CA root certificate has been found in the OneView trust store, skipping the add operation."
    }


    $error_found = $false
    $iLO_found = $false

    #EndRegion

    #Region -------------------------------------------------------- Generating new certificates -------------------------------------------------------------------------------------
    
    ForEach ($server in $servers) {
    
        #Region Capture iLO SSO session key
        $iloIP = $server.mpHostInfo.mpIpAddresses | Where-Object type -ne LinkLocal | ForEach-Object address
        $servername = $server.name
        $iloModel = $server | ForEach-Object mpmodel
        $Ilohostname = $server | ForEach-Object { $_.mpHostInfo.mpHostName }
        
        $RootUri = "https://{0}" -f $iloIP
        
        "[{0} - iLO {1}]: Analysis in progress..." -f $servername, $iloIP | write-host 
        
        $XAPIVersion = (Invoke-RestMethod https://$OneView_IP/rest/version).currentVersion

        $Headers = @{}
        $Headers['X-API-Version'] = $XAPIVersion 
        $Headers['Auth'] = $ConnectedSessions.SessionID 

        try {         
            
            # $iloSession = $server | Get-OVIloSso -IloRestSession -SkipCertificateCheck # Abandoned due to problems when iLO uses a self-signed certificate, fix is planned in OV 9.20 library
          
            # Get the iLO SSO URL
            $iloSsoUrl = Invoke-RestMethod -Uri "https://$OneView_IP/$($server.uri)/iloSsoUrl" -Method Get -Headers $Headers | Select-Object -ExpandProperty iloSsoUrl
            # Perform the REST method and store the session information
            Invoke-RestMethod $iloSsoUrl -Headers $Headers -SkipCertificateCheck  -SessionVariable session | Out-Null
            # Extract the session key from the cookies
            $iloSession = $session.Cookies.GetCookies($iloSsoUrl)["sessionKey"].Value 

        }
        catch {
            "[{0} - iLO {1}]: Error: Server cannot be contacted at this time. Resolve any issues found in OneView and run this script again. Skipping server!" -f $servername, $iloIP | Write-Host -ForegroundColor Red
            $error_found = $true
            continue
        }
        #EndRegion
        
        #Region Collecting iLO certificate information
        $Location = '/redfish/v1/Managers/1/SecurityService/HttpsCert/'
        
        try {  

            $certificate = Invoke-RestMethod -uri ($RootUri + $Location ) -Headers @{'Odata-Version' = "4.0"; 'X-Auth-Token' = $ilosession } -SkipCertificateCheck
            # $certificate = Invoke-RestMethod -uri ($RootUri + $Location ) -Headers @{'Odata-Version' = "4.0"; 'X-Auth-Token' = $ilosession.'X-Auth-Token' } -SkipCertificateCheck
            
        }
        catch {
            "[{0} - iLO {1}]: Error ! The iLO certificate information cannot be collected! Skipping server!" -f $servername, $iloIP | Write-Host -ForegroundColor Red
            $error_found = $true
            continue
    
        }

        $serialnumber = $certificate.X509CertificateInformation.SerialNumber.replace(":", "")
        $issuer = $certificate.X509CertificateInformation.Issuer
        $ValidNotAfter = $certificate.X509CertificateInformation.ValidNotAfter
        $expiresInDays = [math]::Ceiling((([datetime]$ValidNotAfter) - (Get-Date)).TotalDays)

        
        if ($Check) {
            
            if ($issuer -notmatch "Default Issuer" -and [int]$expiresInDays -le $days_before_expiration) {
                "[{0} - iLO {1}]: CA-signed certificate detected that will expire in {2} days. A new CA-signed certificate will be generated." -f $servername, $iloIP, $expiresInDays | Write-Host -ForegroundColor Green
            }
            elseif ($issuer -match "Default Issuer") {
                "[{0} - iLO {1}]: Self-signed certificate detected. A new CA-signed certificate will be generated." -f $servername, $iloIP | Write-Host -ForegroundColor Green
            }
            else {
                "[{0} - iLO {1}]: CA-signed certificate detected that will expire in {2} days. The server will be skipped." -f $servername, $iloIP, $expiresInDays | Write-Host
            }
            
        }
        #EndRegion

        #Region Generate a new iLO signed certificate if the iLO uses a self-signed certificate or a certificate with an expiration date less than or equal to $days_before_expiration.
        elseif ($issuer -match "Default Issuer" -or [int]$expiresInDays -le $days_before_expiration ) {

            #Region Creation of the Certificate Signing Request (CSR)
            
            $iLO_found = $true

            if ($issuer -match "Default Issuer") {
                "[{0} - iLO {1}]: Self-signed certificate detected. Generating a new CA-signed certificate..." -f $servername, $iloIP | Write-Host -ForegroundColor Green
            }
            else {
                "[{0} - iLO {1}]: CA-signed certificate detected that will expire in {2} days. Generating a new CA-signed certificate..." -f $servername, $iloIP, $days_before_expiration | Write-Host -ForegroundColor Green
            }
            
            # Creation of the body content to pass to iLO to request a CSR

            # Certificate Signing Request information
            $CommonName = $Ilohostname
 
            # Sending the request to iLO to generate a CSR
            "[{0} - iLO {1}]: Creating a certificate signing request." -f $servername, $iloIP | write-host 
 
            # Warning about including IP addresses in certificates: 
            #  - Expose to security risks or compliance issues. Many organizations and regulatory standards have policies that restrict the inclusion of IP addresses in certificates.
            #  - Many Certificate Authorities reject the IncludeIP=True input parameter
            #  - IP addresses can change over time due to network reconfigurations, DHCP leases, or other reasons. If a certificate includes an IP address that changes, the certificate may become invalid, leading to service disruptions.
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
                        IncludeIP  = $false
                    } | ConvertTo-Json 

                    $Location = '/redfish/v1/Managers/1/SecurityService/HttpsCert/Actions/HpeHttpsCert.GenerateCSR'

                    $response = Invoke-RestMethod -uri ($RootUri + $Location ) -Method POST -Headers @{'Odata-Version' = "4.0"; 'X-Auth-Token' = $ilosession; 'Content-Type' = 'application/json' } -Body $bodyilo5Params -SkipCertificateCheck 
                    # $response = Invoke-RestMethod -uri ($RootUri + $Location ) -Method POST -Headers @{'Odata-Version' = "4.0"; 'X-Auth-Token' = $ilosession.'X-Auth-Token'; 'Content-Type' = 'application/json' } -Body $bodyilo5Params -SkipCertificateCheck 
                            
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
                        IncludeIP  = $false
                    } | ConvertTo-Json 

                    $Location = '/redfish/v1/Managers/1/SecurityService/HttpsCert/'

                    $Response = Invoke-RestMethod -uri ($RootUri + $Location ) -Method POST -Headers @{'Odata-Version' = "4.0"; 'X-Auth-Token' = $ilosession; 'Content-Type' = 'application/json' } -Body $bodyilo4Params -SkipCertificateCheck -verbose
                    # $Response = Invoke-RestMethod -uri ($RootUri + $Location ) -Method POST -Headers @{'Odata-Version' = "4.0"; 'X-Auth-Token' = $ilosession.'X-Auth-Token'; 'Content-Type' = 'application/json' } -Body $bodyilo4Params -SkipCertificateCheck -verbose
                }

                if ($response.error.'@Message.ExtendedInfo'.MessageId) {

                    if ($response.error.'@Message.ExtendedInfo'.MessageId -notmatch "GeneratingCertificate") {
                        "[{0} - iLO {1}]: Error! Failed to create the certificate signing request! Message returned: {2} - Skipping server!" -f $servername, $iloIP, $response.error.'@Message.ExtendedInfo'.MessageId | Write-Host -ForegroundColor Red
                        $error_found = $true
                        continue
                    }
                }
            }
            Catch { 
            
                "[{0} - iLO {1}]: Error! Failed to create the certificate signing request! Message returned: {2} - Skipping server!" -f $servername, $iloIP, $_.Exception.Response | Write-Host -ForegroundColor Red
                $error_found = $true
                continue
            }     
            #EndRegion
     
            #Region Collecting CSR from iLO

            do {
    
                try {

                    $Location = '/redfish/v1/Managers/1/SecurityService/HttpsCert/'

                    $restCSR = Invoke-RestMethod -uri ($RootUri + $Location ) -Headers @{'Odata-Version' = "4.0"; 'X-Auth-Token' = $ilosession } -SkipCertificateCheck
                    # $restCSR = Invoke-RestMethod -uri ($RootUri + $Location ) -Headers @{'Odata-Version' = "4.0"; 'X-Auth-Token' = $ilosession.'X-Auth-Token' } -SkipCertificateCheck

                    $CertificateSigningRequest = $restCSR.CertificateSigningRequest 
                    Start-Sleep 3
                
                }
                catch {
                    "[{0} - iLO {1}]: Error! Failed to retrieve the certificate signing request. Message returned: {2} - Skipping server!" -f $servername, $iloIP, $restCSR.error.'@Message.ExtendedInfo'.MessageId | Write-Host -ForegroundColor Red
                    $error_found = $true
                    continue 
                }

            }
            until ($CertificateSigningRequest)

            # Saving CSR to a local file in the execution directory
            $CertificateSigningRequest | Out-File $PSScriptRoot\Request.csr 

            #EndRegion

            #Region Generating a signed certificate from the CA using the iLO CSR

            ## Submitting the CSR using the specified certificate template to the certification autority server
            Submit-CertificateRequest -path $PSScriptRoot\Request.csr -CertificationAuthority (Get-CertificationAuthority $CA_computername) -Attribute CertificateTemplate:$CertificateTemplate | Out-Null

            ## Building the certificate 
            "-----BEGIN CERTIFICATE-----" | Out-File $PSScriptRoot\Newcert.cer
            ( Get-IssuedRequest -CertificationAuthority (Get-CertificationAuthority $CA_computername) -Property "RawCertificate" | Where-Object CommonName -eq $CommonName | Select-Object -last 1 ).RawCertificate.trim("`r`n") | Out-File $PSScriptRoot\Newcert.cer -Append #-Encoding ascii
            "-----END CERTIFICATE-----" | Out-File $PSScriptRoot\Newcert.cer -Append


            ## Formatting the built certificate for the JSON body content
            $certificate = Get-Content $PSScriptRoot\Newcert.cer -raw

            $bodyiloParams = ConvertTo-Json  @{ Certificate = "$certificate" }

            #EndRegion

            #Region Importing new certificate in iLO

            Try {
                $Location = '/redfish/v1/Managers/1/SecurityService/HttpsCert/Actions/HpeHttpsCert.ImportCertificate/'

                $rest = Invoke-RestMethod -uri ($RootUri + $Location ) -Method POST -Headers @{'Odata-Version' = "4.0"; 'X-Auth-Token' = $ilosession; 'Content-Type' = 'application/json' } -Body $bodyiloParams -SkipCertificateCheck
                # $rest = Invoke-RestMethod -uri ($RootUri + $Location ) -Method POST -Headers @{'Odata-Version' = "4.0"; 'X-Auth-Token' = $ilosession.'X-Auth-Token'; 'Content-Type' = 'application/json' } -Body $bodyiloParams -SkipCertificateCheck

            }
            Catch { 
                "[{0} - iLO {1}]: Error! Failed to import the new certificate! Message returned: {2} - Skipping server!" -f $servername, $iloIP, $rest.error.'@Message.ExtendedInfo'.MessageId | Write-Host -ForegroundColor Red
                $error_found = $true
                continue 
            }

            "[{0} - iLO {1}]: iLO reset in progress to activate the new certificate..." -f $servername, $iloIP | Write-Host 
            #EndRegion
    
            #Region Remove the old certificate from the OneView trust store (if any)
            if (Get-OVApplianceTrustedCertificate | Where-Object { $_.certificate.serialnumber -eq $serialnumber } ) {

                try {
                    Get-OVApplianceTrustedCertificate | Where-Object { $_.certificate.serialnumber -eq $serialnumber } | Remove-OVApplianceTrustedCertificate -Confirm:$false | Wait-OVTaskComplete | Out-Null  
                    "[{0} - iLO {1}]: The old iLO certificate has been successfully removed from the Oneview trust store" -f $servername, $iloIP | Write-Host 
                }
                catch {
                    "[{0} - iLO {1}]: Error! The old iLO certificate cannot be removed from the Oneview trust store! Skipping server!" -f $servername, $iloIP | Write-Host -ForegroundColor Red
                    $error_found = $true
                    continue 
                
                }
            }
        
            "[{0} - iLO {1}]: Operation completed successfully!" -f $servername, $iloIP | Write-Host     
            
            #EndRegion
            
    
        } 
        else {
            "[{0} - iLO {1}]: CA-signed certificate detected that will only expire in {2} days. Skipping server." -f $servername, $iloIP, $expiresInDays | Write-Host 
        
        }
        #EndRegion
    }

    #Region Generating output 

    # Define the messages based on the operation results    
    if (-not $Check) {

        if (-not $iLO_found -and -not $error_found) {
            "Operation completed! No action is required as all servers use an iLO certificate signed by a certificate authority that is not within the soon-to-expire validity period." | Write-Host -ForegroundColor Cyan
        }
        elseif (-not $iLO_found -and $error_found) {
            "Operation completed with errors! Resolve any issues found in OneView and run this script again." | Write-Host -ForegroundColor Cyan
        }
        elseif ($iLO_found -and $error_found) {
            "Operation completed with errors! Not all iLOs with a self-signed certificate or a CA-signed certificate within the soon-to-expire validity period have been successfully updated! Resolve any issues found in OneView and run this script again." | Write-Host -ForegroundColor Cyan
        }
        elseif ($iLO_found -and -not $error_found) {
            "Operation completed successfully! All iLOs with a self-signed certificate or a CA-signed certificate within the soon-to-expire validity period have been successfully updated." | Write-Host -ForegroundColor Cyan
        }
        #EndRegion
        
        #Region Cleaning working files
        if (Get-ChildItem $PSScriptRoot\Request.csr -ErrorAction SilentlyContinue) {
            
            remove-item -Path "$PSScriptRoot\Request.csr"
        }
        
        if (Get-ChildItem $PSScriptRoot\Newcert.cer -ErrorAction SilentlyContinue) {
            
            remove-item -Path "$PSScriptRoot\Newcert.cer" 
        }
    }
    #EndRegion
}
    
    
# Disconnect-OVMgmt
# Read-Host -Prompt "Hit return to close" 
#EndRegion
