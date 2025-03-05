<# 

This PowerShell script automates the process of enabling Automatic Certificate Enrollment on HPE iLOs managed by HPE OneView. 
It leverages NDES (Network Device Enrollment Service) to request certificates from a Microsoft Certification Authority server using SCEP (Simple Certificate Enrollment Protocol). 

The script performs the following steps:
1. Defines necessary variables and parameters.
2. Installs required PowerShell modules if they are not already installed.
3. Connects to HPE OneView and retrieves the list of managed servers.
4. Retrieves the challenge password from the NDES server.
5. Retrieves the CA certificate from the Certification Authority.
6. Configures iLO Automatic Certificate Enrollment for each server:
    a. Retrieves iLO SSO session key.
    b. Retrieves the time difference between iLO and the computer.
    c. Retrieves iLO Automatic Certificate Enrollment information.
    d. If the -Check parameter is used, verifies the current status and decides if reconfiguration is needed.
    e. If the -Check parameter is not used, configures iLO for Automatic Certificate Enrollment:
        i. Disables Automatic Certificate Enrollment if the status is not 'Success'.
        ii. Imports SCEP CA certificate to establish trust between iLO and SCEP server.
        iii. Captures a new NDES challenge password if the current one is older than 60 minutes.
        iv. Enables Automatic Certificate Enrollment in iLO.
        v. Resets iLO to activate the new certificate.
7. Generates output and exports the status of the operation to a CSV file.

Note: OneView automatically runs the tasks necessary to restore communication with the iLO when a certificate change is detected.

Supported servers: Gen10, Gen10+ and Gen11.

Requirements:
- PowerShell 7 (including both console and core editions)
- HPE OneView PowerShell Library
- HPE OneView administrator account
- PSPKI PowerShell Library
- A Microsoft Certification Authority server with NDES role installed and configured must be available on the network
- A NDES server account with the necessary permissions to request certificates
- A certificate template supporting server authentication must be available for generating iLO certificates
- The computer executing this script must be part of a Microsoft Active Directory domain

    
Output sample when -check parameter is used:

    & '.\Enable iLO automatic certificate enrollment.ps1' -NDESServerFQDN "ndes_server.lab" -OneViewFQDN composer.lab -ckeck

    [Frame3, bay 2 - iLO 192.168.3.188]: Automatic Certificate Enrollment is enabled - Status: [Success] => Skipping server.

    [Frame3, bay 3 - iLO 192.168.0.46]: Automatic Certificate Enrollment is enabled - Status: [Failed] => Script will need to reconfigure the iLO.
    
    [Frame3, bay 4 - iLO 192.168.3.193]: Automatic Certificate Enrollment is not enabled => Script will configure the iLO.

    The status of the check has been exported to 'iLO_Automatic_Certificate_Enrollment_Status.csv'

Output sample when -check parameter is not used:

    & '.\Enable iLO automatic certificate enrollment.ps1' -NDESServerFQDN "ndes_server.lab" -OneViewFQDN composer.lab 

    [Frame3, bay 7 - iLO 192.168.0.11]: Automatic Certificate Enrollment is not enabled => Configuring the iLO...
    [Frame3, bay 7 - iLO 192.168.0.11]: Automatic Certificate Enrollment has been enabled successfully! Awaiting issuance of the certificate...
    [Frame3, bay 7 - iLO 192.168.0.11]: Operation completed successfully! iLO reset in progress to activate new certificate...

    [Frame3, bay 1 - iLO 192.168.0.12]: Automatic Certificate Enrollment service is enabled with status: [Success]. Skipping server.
    
    [Frame3, bay 3 - iLO 192.168.0.46]: Automatic Certificate Enrollment is enabled but status is [Failed] => Disabling service in iLO...
    [Frame3, bay 3 - iLO 192.168.0.46]: Automatic Certificate Enrollment is not enabled => Configuring the iLO...
    [Frame3, bay 3 - iLO 192.168.0.46]: Automatic Certificate Enrollment has been enabled successfully! Awaiting issuance of the certificate...
    [Frame3, bay 3 - iLO 192.168.0.46]: Unable to complete SSL certificate enrollment since SCEP server denied to issue the certificate. Recommended action: 1. Check if challenge password is correct. 2. Check server logs for more information on the error. Re-enable (disable and enable) the certificate enrollment service to trigger the process again. Contact support if the problem persists.

    One or more servers have the Automatic Certificate Enrollment service disabled! Resolve any issues and run this script again.
    The status of the operation has been exported to 'iLO_Automatic_Certificate_Enrollment_Status.csv'
  
  Author: lionel.jullien@hpe.com
  Date:   Feb 2025
    
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
    [string]$NDESServerFQDN, 
    [string]$NDESUsername = "NdesSvc", 
    [string]$OneViewFQDN, 
    [string]$OneViewUsername = "Administrator", 
    [switch]$Check,
    [switch]$Verbose
)


#Region -------------------------------------------------------- Variables definition -----------------------------------------------------------------------------------------

# Certificate Signing Request (CSR) variables
$city = "Mougins"
$Country = "FR"
$OrgName = "HPE"
$OrgUnit = "Compute"
$State = "PACA"



#EndRegion



#Region -------------------------------------------------------- Modules to install --------------------------------------------------------------------------------------------

if ($Verbose) { $VerbosePreference = "Continue" }

# Check if the HPE OneView PowerShell module is installed and install it if not
If (-not (get-module HPEOneView.* -ListAvailable )) {
    
    try {
        
        $APIversion = Invoke-RestMethod -Uri "https://$OneViewFQDN/rest/version" -Method Get | Select-Object -ExpandProperty currentVersion
        
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

Import-Module PSPKI

# Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force+

# Check if the script is running in PowerShell 7
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Error "This script requires PowerShell 7. Please run this script in PowerShell 7."
    exit
}

#EndRegion



#Region -------------------------------------------------------- Connection to HPE OneView and collecting servers -------------------------------------------------------------------------------------

Clear-Host

if (! $ConnectedSessions) {
    
    $secpasswd = read-host  "Please enter the HPE OneView password for $OneViewUsername" -AsSecureString
 
    # Connection to the Synergy Composer
    $credentials = New-Object System.Management.Automation.PSCredential ($OneViewUsername, $secpasswd)
    
    try {
        Connect-OVMgmt -Hostname $OneViewFQDN -Credential $credentials | Out-Null
    }
    catch {
        Write-Warning "Cannot connect to '$OneViewFQDN'! Exiting... "
        return
    }
}


# Retrieve all servers managed by HPE OneView
$servers = Get-OVServer | Where-Object { $_.mpModel -eq "iLO5" -or $_.mpModel -eq "iLO6" }   

# Filter servers examples
# $servers = Get-OVServer | Where-Object { $_.mpModel -eq "iLO5" -or $_.mpModel -eq "iLO6" } | Select-Object -First 2
# $servers = Get-OVServer | Where-Object { $_.mpModel -eq "iLO5" -or $_.mpModel -eq "iLO6" } | Where-Object { $_.name -ne "Frame3, bay 6" -and $_.name -ne "Frame3, bay 2" -and $_.name -ne "Frame3, bay 3" }
# $servers = Get-OVServer | Where-Object name -eq "Frame1, bay 1"

#EndRegion



#Region -------------------------------------------------------- Retreiving the challenge password from the NDES server ---------------------------------------------------------


# Define the NDES server URLs
$NDES_Management_URL = "https://$NDESServerFQDN/certsrv/mscep_admin/"
$NDES_URL = "https://$NDESServerFQDN/certsrv/mscep/mscep.dll"
$PasswordLength = 16

# Define the credentials for accessing the NDES server
$secPassword = read-host  "Please enter the NDES account password for $ndesUsername" -AsSecureString
$ndesCredential = New-Object System.Management.Automation.PSCredential ($ndesUsername, $secPassword)

# Define the request parameters
$NDES_Challenge_Password_RequestParams = @{
    "operation" = "GetCACaps"
}

# Define the date when the challenge password was created as it will be used to check if the password is older than 60 minutes (NDES requirement)
$NDES_Challenge_Password_Creation_Date = Get-Date

# Send the request to the NDES server
try {
    $NdesResponse = Invoke-Webrequest -Uri $NDES_Management_URL -Method Post -Credential $ndesCredential -Body $NDES_Challenge_Password_RequestParams -Verbose:$Verbose
    
}
catch {
    Write-Warning "The NDES server cannot be contacted. Check your variables set in this script."
    return
}

# Convert the HTML Output to Unicode
$HTML = [System.Text.Encoding]::Unicode.GetString($NdesResponse.RawContentStream.ToArray())

# Get the Password from the HTML Output
$NDES_Challenge_Password = ($HTML -split '\s+') -match "^[A-F0-9]{$($PasswordLength)}" | Select-Object -First 1

# Detect the NDES password cache is full in HTML Response
$NDES_Password_Cache_Full = $HTML -match "The password cache is full"

if ($NDES_Password_Cache_Full) {
    Write-Warning "NDES password cache is full detected in HTTP Response. Resolution: Wait until one of the passwords expires or restart IIS using 'iisreset' from cmd."
    return
}
elseif ($null -eq $NDES_Challenge_Password) {
    Write-Warning "No NDES challenge password found in HTTP Response. Check your Permissions in NDES and the PasswordLength set in this script."
    return
}

#EndRegion



#Region -------------------------------------------------------- Retreiving CA certificate -------------------------------------------------------------------------------------

# Check if the machine is part of an Active Directory domain
if (-not (Get-CimInstance -Class Win32_ComputerSystem).PartOfDomain) {
    Write-Error "Error: This machine is not part of an Active Directory domain. The script requires domain membership to retrieve a Certification Authority."
    return
}

# Finding the first Enterprise Certification Authority from a current Active Directory forest
try {
    # Note: this command only works if the machine from where you execute this script is in an Active Directory domain
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

    # Converting trusted CA root certificate to PEM format
    $certPem = $CA.Certificate | ForEach-Object {
        $certBytes = $_.Export([Security.Cryptography.X509Certificates.X509ContentType]::Cert)
        "-----BEGIN CERTIFICATE-----`n" + [System.Convert]::ToBase64String($certBytes, 'InsertLineBreaks') + "`n-----END CERTIFICATE-----"
    } | Out-String

    "Content of the CA certificate in PEM format: `n{0}" -f $certPem | Write-Verbose
}



#EndRegion



#Region -------------------------------------------------------- Configuring iLO Automatic Certificate Enrollment -------------------------------------------------------------------------------------

# Creating object to store status of the operation
$operationStatus = [System.Collections.ArrayList]::new()

ForEach ($server in $servers) { 

    Write-Host ""
    
    #Region Retrieving iLO SSO session key
    
    $iloIP = $server.mpHostInfo.mpIpAddresses | Where-Object type -ne LinkLocal | ForEach-Object address
    $servername = $server.name
    # $iloModel = $server | ForEach-Object mpmodel
    
    # Build object for the output
    $objStatus = [pscustomobject]@{

        iLO        = $iloIP
        servername = $servername
        Status     = $Null
        Details    = $Null
        Exception  = $Null
        
    }
    
    $RootUri = "https://{0}" -f $iloIP
        
    "[{0} - iLO {1}]: Analysis in progress..." -f $servername, $iloIP | Write-Verbose 
        
    try {
        $XAPIVersion = (Invoke-RestMethod https://$OneViewFQDN/rest/version).currentVersion
    }
    catch {
        Write-Warning "Cannot connect to '$OneViewFQDN'! Exiting... "
        return
    }

    $Headers = @{}
    $Headers['X-API-Version'] = $XAPIVersion 
    $Headers['Auth'] = $ConnectedSessions.SessionID 

    try {         
            
        # $iloSession = $server | Get-OVIloSso -IloRestSession -SkipCertificateCheck # Abandoned due to problems when iLO uses a self-signed certificate, fix is planned in OV 9.20 library
          
        # Get the iLO SSO URL
        $iloSsoUrl = Invoke-RestMethod -Uri "https://$OneViewFQDN/$($server.uri)/iloSsoUrl" -Method Get -Headers $Headers -Verbose:$Verbose | Select-Object -ExpandProperty iloSsoUrl
        # Perform the REST method and store the session information
        Invoke-RestMethod $iloSsoUrl -Headers $Headers -SkipCertificateCheck  -SessionVariable session | Out-Null
        # Extract the session key from the cookies
        $iloSession = $session.Cookies.GetCookies($iloSsoUrl)["sessionKey"].Value 

    }
    catch {
        "[{0} - iLO {1}]: Error: iLO cannot be contacted at this time. Resolve any issues found in OneView and run this script again. Error: {2}" -f $servername, $iloIP, $_ | Write-Host -ForegroundColor Red
        $objStatus.Status = "Failed"
        $objStatus.Details = "iLO cannot be contacted at this time. Resolve any issues found in OneView and run this script again."
        $objStatus.Exception = $_
        $operationStatus.Add($objStatus) | Out-Null
        continue
    }
    #EndRegion

    #Region Retrieving the time difference between iLO and computer

    # Define the location to get the iLO time
    $Location = "/redfish/v1/Managers/1/DateTime"
    
    # Retrieve the current time from the iLO
    try {
        $iloTimeResponse = Invoke-RestMethod -Uri ($RootUri + $Location) -Method Get -Headers @{'Odata-Version' = "4.0"; 'X-Auth-Token' = $ilosession } -SkipCertificateCheck -Verbose:$Verbose
        $iloTime = [DateTime]::Parse($iloTimeResponse.DateTime)
        # Write-Output "iLO Time: $iloTime"
    }
    catch {
        "[{0} - iLO {1}]: Failed to retrieve the iLO time! Error: {2}" -f $servername, $iloIP, $_ | Write-Host -ForegroundColor Red
        $objStatus.Status = "Failed"
        $objStatus.Details = "Failed to retrieve the iLO time!" 
        $objStatus.Exception = $_
        $operationStatus.Add($objStatus) | Out-Null
        continue
    }

    # Calculate the time difference from computer to iLO
    $timeDifference = ((Get-Date) - $iloTime).TotalHours
    "[{0} - iLO {1}]: iLO Time difference with computer: {2}" -f $servername, $iloIP, $timeDifference | Write-Verbose


    #endregion
        
    #Region Retrieving iLO Automatic Certificate Enrollment information
    $Location = '/redfish/v1/Managers/1/SecurityService/AutomaticCertificateEnrollment/'
        
    try {  

        $AutomaticCertificateEnrollment = Invoke-RestMethod -uri ($RootUri + $Location ) -Headers @{'Odata-Version' = "4.0"; 'X-Auth-Token' = $ilosession } -SkipCertificateCheck -Verbose:$Verbose
            
    }
    catch {
        "[{0} - iLO {1}]: Error ! The iLO Automatic Certificate Enrollment information cannot be collected! Error: {2}" -f $servername, $iloIP, $_ | Write-Host -ForegroundColor Red
        $objStatus.Status = "Failed"
        $objStatus.Details = "The iLO Automatic Certificate Enrollment information cannot be collected!"
        $objStatus.Exception = $_
        $operationStatus.Add($objStatus) | Out-Null
        continue
    
    }

    $CommonName = $AutomaticCertificateEnrollment.HttpsCertCSRSubjectValue.CommonName
    $ServiceEnabled = $AutomaticCertificateEnrollment.AutomaticCertificateEnrollmentSettings.ServiceEnabled # False or True
    $CertificateEnrollmentStatus = $AutomaticCertificateEnrollment.AutomaticCertificateEnrollmentSettings.CertificateEnrollmentStatus # Disabled, Success, Failed, InProgress, Unknown

    if ($Check) {
            
        if ($ServiceEnabled -eq $False) {
            "[{0} - iLO {1}]: Automatic Certificate Enrollment is not enabled => Script will configure the iLO." -f $servername, $iloIP | Write-Host 
            $objStatus.Status = "Failed"
            $objStatus.Details = "Automatic Certificate Enrollment service is not enabled. The script will configure the iLO to enable Automatic Certificate Enrollment."
            
        }
        elseif ($ServiceEnabled -eq $True -and $CertificateEnrollmentStatus -notmatch "Success") {
            "[{0} - iLO {1}]: Automatic Certificate Enrollment is enabled but status is [{2}] => Script will need to reconfigure the iLO." -f $servername, $iloIP, $CertificateEnrollmentStatus | Write-Host -ForegroundColor Yellow
            $objStatus.Status = "Warning"
            $objStatus.Details = "Automatic Certificate Enrollment service is enabled but the current status is $CertificateEnrollmentStatus. The script will reconfigure the iLO to enable Automatic Certificate Enrollment."

        }
        else {
            "[{0} - iLO {1}]: Automatic Certificate Enrollment is enabled with status: [{2}] => Skipping server." -f $servername, $iloIP, $CertificateEnrollmentStatus | Write-Host -ForegroundColor Green
            $objStatus.Status = "Complete"
            $objStatus.Details = "Automatic Certificate Enrollment service is enabled. Skipping server."
        }            
    }
    else {
        #EndRegion

        #Region Disabling Automatic Certificate Enrollment in iLO if status is not 'Success'
        if ($ServiceEnabled -eq $True -and $CertificateEnrollmentStatus -notmatch "Success") {

            $date = Get-Date

            "[{0} - iLO {1}]: Automatic Certificate Enrollment is enabled but status is [{2}] => Disabling service in iLO..." -f $servername, $iloIP, $CertificateEnrollmentStatus | Write-Host 

            #Region Disabling Automatic Certificate Enrollment in iLO
            
            # Define the body 
            $bodyParams = @{
                AutomaticCertificateEnrollmentSettings = @{
                    ServiceEnabled = $false
                }
            } | ConvertTo-Json

            "[{0} - iLO {1}]: Body content: `n{2}" -f $servername, $iloIP, $bodyParams | Write-Verbose
    
            # Define the location to disable the iLO Automatic Certificate Enrollment
            $Location = '/redfish/v1/Managers/1/SecurityService/AutomaticCertificateEnrollment'
    
            $response = Invoke-RestMethod -uri ($RootUri + $Location ) -Method Patch -Headers @{'Odata-Version' = "4.0"; 'X-Auth-Token' = $ilosession; 'Content-Type' = 'application/json' } -Body $bodyParams -SkipCertificateCheck -Verbose:$Verbose
    
            if ($response.error.'@Message.ExtendedInfo'.MessageId -match "Success") {

                $ServiceDisabled = $False
               
                # Check the iLO security logs to wait for the 'Certificate enrollment service is disabled' message
                
                # "[{0} - iLO {1}]: Automatic Certificate Enrollment process disabled successfully!" -f $servername, $iloIP | Write-Verbose
                $Location = "/redfish/v1/Systems/1/LogServices/SL/Entries/?`$filter=Created gt '" + $date.AddHours( - ($timeDifference)).ToString("yyyy-MM-ddTHH:mm:ssZ") + "'"

                "[{0} - iLO {1}]: URL to get iLO security logs: {2}" -f $servername, $iloIP, $Location | Write-Verbose

                $timeout = 60 # Timeout in seconds
                $elapsedTime = 0
                $interval = 1 # Interval in seconds

                do {
                    try {
                        $response = Invoke-RestMethod -uri ($RootUri + $Location ) -Method Get -Headers @{'Odata-Version' = "4.0"; 'X-Auth-Token' = $ilosession; 'Content-Type' = 'application/json' } -SkipCertificateCheck -Verbose:$Verbose
                       
                        "[{0} - iLO {1}]: iLO security logs: `n{2}" -f $servername, $iloIP, ($response.Members | Out-String) | Write-Verbose

                        $ServiceDisabled = $response.Members | Where-Object { $_.Message -match "Certificate enrollment service is disabled" } | Select-Object -ExpandProperty Message
                    
                        Start-Sleep -Seconds $interval
                        $elapsedTime += $interval

                        "[{0} - iLO {1}]: Elapsed time while waiting for iLO security logs message: {2} seconds" -f $servername, $iloIP, $elapsedTime | Write-Verbose
                        
                    }
                    catch {
                        "[{0} - iLO {1}]: Failed to retrieve the iLO security logs!" -f $servername, $iloIP | Write-Host -ForegroundColor Red
                        $objStatus.Status = "Failed"
                        $objStatus.Details = "Failed to retrieve the iLO security logs!"
                        $objStatus.Exception = $_
                        $operationStatus.Add($objStatus) | Out-Null
                        continue
                    }
    
                } until ($ServiceDisabled -or $elapsedTime -ge $timeout)

                if (-not $ServiceDisabled) {
                    "[{0} - iLO {1}]: Timeout reached while waiting for the service to be disabled." -f $servername, $iloIP | Write-Host -ForegroundColor Red
                    $objStatus.Status = "Failed"
                    $objStatus.Details = "Timeout reached while waiting for the service to be disabled."
                    $operationStatus.Add($objStatus) | Out-Null
                    continue
                }
                
                Start-Sleep -Seconds 5

                $ServiceEnabled = $False 
            
                #EndRegion
            }
            else {
                "[{0} - iLO {1}]: Failed to disable the Automatic Certificate Enrollment! Message: {2}" -f $servername, $iloIP, $response.error.'@Message.ExtendedInfo'.MessageId | Write-Host -ForegroundColor Red
                $objStatus.Status = "Failed"
                $objStatus.Details = "Failed to disable the Automatic Certificate Enrollment!" 
                $objStatus.Exception = $_
                $operationStatus.Add($objStatus) | Out-Null
                continue
            }
        }
        #EndRegion

        #Region Configuring iLO for Automatic Certificate Enrollment
        if ($ServiceEnabled -eq $False) {

            "[{0} - iLO {1}]: Automatic Certificate Enrollment is not enabled => Configuring the iLO..." -f $servername, $iloIP | Write-Host 

            #Region Importing SCEP CA Certificate to establish trust between iLO and SCEP server

            $bodyParams = @{
                Action      = "HpeCertAuth.ImportCACertificate";
                Certificate = $certPem;
            } | ConvertTo-Json 

            "[{0} - iLO {1}]: Body content: `n{2}" -f $servername, $iloIP, $bodyParams | Write-Verbose

            $Location = '/redfish/v1/Managers/1/SecurityService/AutomaticCertificateEnrollment/Actions/HpeAutomaticCertEnrollment.ImportCACertificate'

            $response = Invoke-RestMethod -uri ($RootUri + $Location ) -Method POST -Headers @{'Odata-Version' = "4.0"; 'X-Auth-Token' = $ilosession; 'Content-Type' = 'application/json' } -Body $bodyParams -SkipCertificateCheck -Verbose:$Verbose
                  
            if ($response.error.'@Message.ExtendedInfo'.MessageId -match "ImportCertSuccessful") {
                "[{0} - iLO {1}]: The CA certificate of the SCEP server has been successfully imported into the iLO trust store!" -f $servername, $iloIP | Write-Verbose
            }
            else {
                "[{0} - iLO {1}]: Failed to import the CA certificate of the SCEP server into the iLO trust store! Message: {2}" -f $servername, $iloIP, $response.error.'@Message.ExtendedInfo'.MessageId | Write-Host -ForegroundColor Red
                $objStatus.Status = "Failed"
                $objStatus.Details = "Failed to import the CA certificate of the SCEP server into the iLO trust store" 
                $operationStatus.Add($objStatus) | Out-Null
                continue
            }

            #EndRegion

            #Region Capturing the NDES challenge password if older than 60 minutes

            # If the NDES challenge password is older than 60 minutes, request a new one
            if ((Get-Date) -gt $NDES_Challenge_Password_Creation_Date.AddMinutes(60)) {
            
                # Send the request to the NDES server
                $NDES_Challenge_Password_Creation_Date = Get-Date
                $NdesResponse = Invoke-Webrequest -Uri $NDES_Management_URL -Method Post -Credential $ndesCredential -Body $NDES_Challenge_Password_RequestParams -Verbose:$Verbose

                # Convert the HTML Output to Unicode
                $HTML = [System.Text.Encoding]::Unicode.GetString($NdesResponse.RawContentStream.ToArray())

                # Get the Password from the HTML Output
                $NDES_Challenge_Password = ($HTML -split '\s+') -match "^[A-F0-9]{$($PasswordLength)}" | Select-Object -First 1

                # Detect the NDES password cache is full in HTML Response
                $NDES_Password_Cache_Full = $HTML -match "The password cache is full"

                if ($NDES_Password_Cache_Full) {
                    Write-Warning "NDES password cache is full detected in HTTP Response. Resolution: Wait until one of the passwords expires or restart IIS using 'iisreset' from cmd."
                    return
                }
                elseif ($null -eq $NDES_Challenge_Password) {
                    Write-Warning "No NDES challenge password found in HTTP Response. Check your Permissions in NDES and the PasswordLength set in this script."
                    return
                }
            }
            #EndRegion

            #Region Enabling Automatic Certificate Enrollment in iLO

            # Warning about including IP addresses in certificates: 
            #  - Expose to security risks or compliance issues. Many organizations and regulatory standards have policies that restrict the inclusion of IP addresses in certificates.
            #  - Many Certificate Authorities reject the IncludeIP=True input parameter
            #  - IP addresses can change over time due to network reconfigurations, DHCP leases, or other reasons. If a certificate includes an IP address that changes, the certificate may become invalid, leading to service disruptions.
        
            $date = Get-Date

            # Define the body (set IncludeIP with your own value)
            $bodyParams = @{
                AutomaticCertificateEnrollmentSettings = @{
                    ServiceEnabled    = $true
                    ServerUrl         = $NDES_URL
                    ChallengePassword = $NDES_Challenge_Password

                }
                HttpsCertCSRSubjectValue               = @{
                    CommonName = $CommonName
                    City       = $city
                    Country    = $Country
                    OrgName    = $OrgName
                    OrgUnit    = $OrgUnit
                    State      = $State
                    IncludeIP  = $true

                }
            } | ConvertTo-Json

            "[{0} - iLO {1}]: Body content: `n{2}" -f $servername, $iloIP, $bodyParams | Write-Verbose
            
            # Define the location to set the iLO Automatic Certificate Enrollment
            $Location = '/redfish/v1/Managers/1/SecurityService/AutomaticCertificateEnrollment'

            # Enable automatic certificate enrollment
            $response = Invoke-RestMethod -uri ($RootUri + $Location ) -Method Patch -Headers @{'Odata-Version' = "4.0"; 'X-Auth-Token' = $ilosession; 'Content-Type' = 'application/json' } -Body $bodyParams -SkipCertificateCheck -Verbose:$Verbose

            if ($response.error.'@Message.ExtendedInfo'.MessageId -match "Success") {

                $ErrorMessage = $false
                $ResetIloMessage = $false
            
                # Check the iLO security logs to verify the certificate enrollment status
                "[{0} - iLO {1}]: Automatic Certificate Enrollment has been enabled successfully! Awaiting issuance of the certificate..." -f $servername, $iloIP | Write-Host

                # Build the location to retrieve the iLO security logs filtered by the creation date of the certificate enrollment
                $Location = "/redfish/v1/Systems/1/LogServices/SL/Entries/?`$filter=Created gt '" + $date.AddHours( - ($timeDifference)).ToString("yyyy-MM-ddTHH:mm:ssZ") + "'"
                
                "[{0} - iLO {1}]: URL to get iLO security logs: {2}" -f $servername, $iloIP, $Location | Write-Verbose

                $timeout = 600 # Timeout in seconds
                $elapsedTime = 0
                $interval = 2 # Interval in seconds

                do {
                    try {
                        $response = Invoke-RestMethod -uri ($RootUri + $Location ) -Method Get -Headers @{'Odata-Version' = "4.0"; 'X-Auth-Token' = $ilosession; 'Content-Type' = 'application/json' } -SkipCertificateCheck -Verbose:$Verbose
                        
                        if ($response.Members) {
                            "[{0} - iLO {1}]: iLO security logs: `n{2}" -f $servername, $iloIP, ($response.Members | Out-String) | Write-Verbose
                        }
                        else {
                            "[{0} - iLO {1}]: No security logs found!" -f $servername, $iloIP | Write-Verbose
                        }
                        
                        # Check the iLO security logs to wait for the 'SSL certificate enrollment is successful' message
                        $ResetIloMessage = $response.Members | Where-Object { $_.Message -match "SSL certificate enrollment is successful. Reset iLO to use the new certificate" } | Select-Object -ExpandProperty Message
                        # Check the iLO security logs to wait for the 'Unable to complete SSL certificate enrollment' message
                        $ErrorMessage = $response.Members | Where-Object { $_.Message -match "Unable to complete SSL certificate enrollment" } | Select-Object -ExpandProperty Message
                
                        start-sleep -Seconds $interval
                        $elapsedTime += $interval

                        "[{0} - iLO {1}]: Elapsed time while waiting for iLO security logs message: {2} seconds" -f $servername, $iloIP, $elapsedTime | Write-Verbose
                    
                    }
                    catch {
                        "[{0} - iLO {1}]: Error! Failed to retrieve the iLO security logs!" -f $servername, $iloIP | Write-Host -ForegroundColor Red
                        $objStatus.Status = "Failed"
                        $objStatus.Details = "Failed to retrieve the iLO security logs!" 
                        $objStatus.Exception = $_
                        $operationStatus.Add($objStatus) | Out-Null
                        continue
                    }

                } until ($ResetIloMessage -or $ErrorMessage -or $elapsedTime -ge $timeout)

                if (-not $ResetIloMessage -and -not $ErrorMessage) {
                    "[{0} - iLO {1}]: Timeout reached while waiting for the certificate enrollment status." -f $servername, $iloIP | Write-Host -ForegroundColor Red
                    $objStatus.Status = "Failed"
                    $objStatus.Details = "Timeout reached while waiting for the certificate enrollment status."
                    $operationStatus.Add($objStatus) | Out-Null
                    continue
                }          
                elseif ($ResetIloMessage) {

                    # "[{0} - iLO {1}]: {2}" -f $servername, $iloIP, $ResetIloMessage | Write-Verbose 
                    
                    # Reset iLO to activate the new certificate 
                    $Location = '/redfish/v1/Managers/1/Actions/Manager.Reset'

                    try {
                        $response = Invoke-RestMethod -uri ($RootUri + $Location ) -Method Post -Headers @{'Odata-Version' = "4.0"; 'X-Auth-Token' = $ilosession; 'Content-Type' = 'application/json' } -SkipCertificateCheck -Verbose:$Verbose
                    }
                    catch {
                        "[{0} - iLO {1}]: Error! Failed to reset the iLO. The new certificate is not activated!" -f $servername, $iloIP | Write-Host -ForegroundColor Red
                        $objStatus.Status = "Failed"
                        $objStatus.Details = "Failed to reset the iLO. The new certificate is not activated!" 
                        $objStatus.Exception = $_
                        $operationStatus.Add($objStatus) | Out-Null
                        continue
                    }


                    if ($response.error.'@Message.ExtendedInfo'.MessageId -match "ResetInProgress") {
                        "[{0} - iLO {1}]: Operation completed successfully! iLO reset in progress to activate new certificate..." -f $servername, $iloIP | Write-Host -ForegroundColor Green
                        $objStatus.Status = "Complete"
                        $objStatus.Details = "iLO reset in progress... Operation completed successfully!" 

                    }
                    else {
                        "[{0} - iLO {1}]: iLO reset failed!" -f $servername, $iloIP | Write-Host -ForegroundColor Red
                        $objStatus.Status = "Failed"
                        $objStatus.Details = "Failed to reset the iLO. The new certificate is not activated!" 
                        $objStatus.Exception = $response.error.'@Message.ExtendedInfo'.MessageId 
                        $operationStatus.Add($objStatus) | Out-Null
                        continue
                    }
                }
                elseif ($ErrorMessage) {
                    $RecommendedAction = ($response.Members | Where-Object { $_.Message -match "Unable to complete SSL certificate enrollment" }).Oem.Hpe.RecommendedAction
                    "[{0} - iLO {1}]: {2} Recommended action: {3}!" -f $servername, $iloIP, ($ErrorMessage | Out-String), ($RecommendedAction | Out-String) | Write-Host -ForegroundColor Red
                    $objStatus.Status = "Failed"
                    $objStatus.Details = ($ErrorMessage | Out-String) + " Recommended action:" + ($RecommendedAction | Out-String)
                    $operationStatus.Add($objStatus) | Out-Null
                    continue
                }            
            }    
            else {
                "[{0} - iLO {1}]: Error! Failed to enable the Automatic Certificate Enrollment! Message returned: {2}" -f $servername, $iloIP, $response.error.'@Message.ExtendedInfo'.MessageId | Write-Host -ForegroundColor Red
                $objStatus.Status = "Failed"
                $objStatus.Details = "Failed to enable the Automatic Certificate Enrollment!" 
                $objStatus.Exception = $response.error.'@Message.ExtendedInfo'.MessageId 
                $operationStatus.Add($objStatus) | Out-Null
                continue
            }     
            #EndRegion 

        }  
        #EndRegion 

        #Region Skipping server if Automatic Certificate Enrollment is already enabled
        elseif ($ServiceEnabled -eq $True -and $CertificateEnrollmentStatus -match "Success") {
            "[{0} - iLO {1}]: Automatic Certificate Enrollment service is enabled with status: [{2}]. Skipping server." -f $servername, $iloIP, $CertificateEnrollmentStatus | Write-Host -ForegroundColor Green
            $objStatus.Status = "Complete"
            $objStatus.Details = "Automatic Certificate Enrollment service is already enabled and functioning correctly!" 
            
        }
    
        #EndRegion
    }

    $operationStatus.Add($objStatus) | Out-Null
}

#EndRegion



#Region -------------------------------------------------------- Generating output -------------------------------------------------------------------------------------

# Define the messages based on the operation results  
if (-not $Check) {

    if ($operationStatus | Where-Object { $_.Status -eq "Failed" }) {
  
        write-Host "`nOne or more servers have the Automatic Certificate Enrollment service disabled! Resolve any issues and run this script again." -ForegroundColor Yellow

    }
    elseif ($operationStatus | Where-Object { $_.Status -eq "Warning" }) {
        
        write-Host "`nOne or more servers have the Automatic Certificate Enrollment service enabled but showing a status not equal to 'success'! Resolve any issues and run this script again." -ForegroundColor Yellow
    }
    else {
        write-host "`nOperation completed successfully! All servers have the Automatic Certificate Enrollment service enabled." -ForegroundColor Cyan
    }
   
    Write-Host "The status of the operation has been exported to 'iLO_Automatic_Certificate_Enrollment_Status.csv'" -ForegroundColor Cyan
}
else {
    Write-Host "`nThe status of the check has been exported to 'iLO_Automatic_Certificate_Enrollment_Status.csv'" -ForegroundColor Cyan
}
    
# Export the status of the operation to csv file
$operationStatus | Export-Csv -Path "iLO_Automatic_Certificate_Enrollment_Status.csv" -NoTypeInformation -Force
    
        
#EndRegion
    
    
    
# Disconnect-OVMgmt
Read-Host -Prompt "Hit return to close" 





