<# 

This PowerShell script generates an HPE OneView SSL certificate signed by a Certificate Authority (CA) 
for all appliances managed by HPE OneView Global Dashboard that use a self-signed or soon-to-expire CA-signed certificate. 

$days_before_expiration defined in the variable section specifies the number of days before the expiration date when the certificates should be replaced.  

Steps of this script: 
1- Find the first trusted Certification Authority server available on the network
        Note: Only works if the host from which you are running this script is in an AD domain
2- Import the CA server's root certificate into the OneView Global Dashboard trust store if it is not present
3- Collect OneView certificate information from all appliances to check if they are self-signed or soon-to-expire CA-signed certificate
4- For appliances using a self-signed or soon-to-expire CA-signed certificate:
    - Create a Certificate Signing Request in OneView using the 'Certificate Signing Request variables' (at the beginning of the script) 
    - Submit CSR to the Certificate Authority server 
    - Import new signed certificate into OneView appliances 
    - Prompt for the appliance Administrator's password and perform an appliance reconnection and refresh to re-establish the communication with the appliance 
    

Note: Common name and Alternative name are pulled from the existing self-signed certificate

Note: It is necessary to create a new certificate templates with Server Authentication and Client Authentication for OneView in the Certificate Authority server

HPE OneView Virtual appliance and HPE Synergy Composers are supported 

Requirements:
   - HPE OneView Powershell Library
   - HPE OneView administrator account 
   - PSPKI Powershell Library 


  Author: lionel.jullien@hpe.com
  Date:   March 2022
    
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
$days_before_expiration = "365"

# Certificate Signing Request variables
$city = "Houston"
$Country = "US"
$OrgName = "HPE"
$OrgUnit = "Synergy"
$State = "Texas"


# Global Dashboard information
$username = "Administrator"
$globaldashboard = "oneview-global-dashboard.lj.lab"

# Name of the certificate template on your CA for OneView and OneView Global Dashboard appliances (with Server and Client Authentication)
$CA_OneView_template = "OneViewappliances"

# MODULES TO INSTALL/IMPORT

# HPEONEVIEW
# If (-not (get-module HPEOneView.550 -ListAvailable )) { Install-Module -Name HPEOneView.550 -scope Allusers -Force }
# import-module HPEOneView.630

# PSPKI
# CA scripts -
# On Windows 7/8/8.1/10 some PSPKI cmdlets are not available so it is required to install RSAT (Remote System Administration Tools)
# Download page: https://www.microsoft.com/en-us/download/details.aspx?id=45520

If (-not (get-module PSPKI -ListAvailable )) { Install-Module -Name PSPKI -scope Allusers -Force }
import-module PSPKI

#################################################################################

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# To avoid with self-signed certificate: could not establish trust relationship for the SSL/TLS Secure Channel – Invoke-WebRequest
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

clear-host

$secpasswd = read-host  "Please enter the OneView Global Dashboard password" -AsSecureString

## Capturing X-API Version of OVGD

# Creation of the header
$headers = @{ } 
$headers["content-type"] = "application/json" 

$OVGDxapiversion = ((invoke-webrequest -Uri "https://$globaldashboard/rest/version" -Headers $headers -Method GET ).Content | Convertfrom-Json).currentVersion

$headers["X-API-Version"] = $OVGDxapiversion

$bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secpasswd)
$password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr) 

# Creation of the body
#$Body = @{userName = $username; password = $password; authLoginDomain = "lj.lab" } | ConvertTo-Json 
$Body = @{userName = $username; password = $password; domain = "local" } | ConvertTo-Json 


## Opening a login session with Global DashBoard
$session = invoke-webrequest -Uri "https://$globaldashboard/rest/login-sessions" -Headers $headers -Body $Body -Method Post 

# Capturing the OneView Global DashBoard Session ID and adding it to the header
$key = ($session.content | ConvertFrom-Json).sessionID
$headers["auth"] = $key

## Finding the first trusted Certification Authority server available on the network
# Note: this command only works if the machine from where you execute this script is in a domain

$CA = Get-CertificationAuthority | select -First 1 

If ($CA -eq $Null) {
    write-warning "Error, a certificate Authority Server cannot be found on the network ! Canceling task..."
    return
}
else {

    $CA_computername = $CA | % Computername
    $CA_displayname = $CA | % displayname
    
    $headers["X-API-Version"] = "1000"
    $headers["If-Req-CertDetails"] = "true"
    
    # Is the CA root certificate present in the OneView Global Dashboard Trust store?

    $certificates_in_OVGD_Store = ((invoke-webrequest -Uri "https://$globaldashboard/rest/certificates/ca" -Headers $headers -Method GET) | ConvertFrom-Json).members
    
    $CA_cert_in_OVGD_Store = $certificates_in_OVGD_Store.certificateDetails | ? commonname -eq $CA_displayname

    if (! $CA_cert_in_OVGD_Store) {
        
        # Adding trusted CA root certificate to OneView Global Dashboard trust store

        write-host "`n$globaldashboard : The trusted CA root certificate is not found in the OneView Global Dashboard trust store, adding it now..."
    
        ## Collecting CA certificate 
        $CA.Certificate | % { set-content -value $($_.Export([Security.Cryptography.X509Certificates.X509ContentType]::Cert)) -encoding byte -path "C:\Temp\CAcert.cer" }
        $cerBytes = Get-Content "C:\Temp\CAcert.cer" -Encoding Byte

        ## Formating CA certificate using PEM 
        "-----BEGIN CERTIFICATE-----" | Out-File C:\temp\CAcert.cer #-NoNewline
        [System.Convert]::ToBase64String($cerBytes) | Out-File C:\Temp\CAcert.cer -Append #-NoNewline
        "-----END CERTIFICATE-----" | Out-File C:\temp\CAcert.cer -Append #-NoNewline

        ## Formatting the built certificate for the JSON body content
        $CAcertificate = Get-Content C:\temp\CAcert.cer -raw

        $body = ConvertTo-Json -Depth 5  @{ members = @( @{ type = "CertificateAuthorityInfo"; certificateDetails = @{ base64Data = "$CAcertificate"; type = "CertificateDetailV2" } } ) ; type = "CertificateAuthorityInfoCollection" }

        # Importing CA certificate into the OVGD trust store
  
        Try {
            $rest = Invoke-WebRequest -Uri "https://$globaldashboard/rest/certificates/ca" -Headers $headers -Body $body -Method Post  
        }
        Catch { 
            $err = (New-Object System.IO.StreamReader( $_.Exception.Response.GetResponseStream() )).ReadToEnd() 
            $msg = ($err | ConvertFrom-Json )
            Write-Host -BackgroundColor:Black -ForegroundColor:Red "$globaldashboard : Failure ! Cannot import Root CA certificate into OneView Global Dashboard trust store ! $($msg.errorCode): $($msg.message) "
            break 
        }

        Write-Host "$globaldashboard : CA root Certificate successful imported into the appliance trust store" -ForegroundColor Yellow

    }
    # Skipping the add trusted CA root certificate operation as certificate is found
    else {
        write-host "`n$globaldashboard : Trusted CA root certificate has been found in the OneView Global Dashboard trust store, skipping the import operation."
    }
    
    $found = $false

    ## Capturing managed appliances
    $headers["X-API-Version"] = $OVGDxapiversion
    $ManagedAppliances = (invoke-webrequest -Uri "https://$globaldashboard/rest/appliances" -Headers $headers -Method GET) | ConvertFrom-Json

    $OVappliances = $ManagedAppliances.members
    write-host "`n$($OVappliances.count) appliances found !"

    foreach ($OVappliance in $OVappliances) {

        $OVIP = $OVappliance.applianceLocation
        $ID = $OVappliance.id
        $apiversion = $OVappliance.currentApiVersion

        #Creation of the header
        $OVheaders = @{ } 
        $OVheaders["content-type"] = "application/json" 
        $OVheaders["X-API-Version"] = $apiversion
    

        $headers["X-API-Version"] = $OVGDxapiversion

        try {
            $OVssoid = ( ( invoke-webrequest -Uri "https://$globaldashboard/rest/appliances/$ID/sso" -Headers $headers -Method GET  ) | ConvertFrom-Json).sessionID
            
        }
        catch {
            write-host $error[0]
        }

        
        $OVheaders["auth"] = $OVssoid

        #Opening a login session with Composer
        $OVcertificate = invoke-webrequest -Uri "https://$OVIP/rest/certificates/https" -Headers $OVheaders -Method Get | ConvertFrom-Json 

        # Check if the appliances uses a self-signed certificate or if the signed certificate will expire within the number of days defined in the variable
        if ( $OVcertificate.commonName -eq $OVcertificate.issuer -or [int]$OVcertificate.expiresInDays -lt $days_before_expiration ) {
            
            $found = $True

            if ($OVcertificate.commonName -eq $OVcertificate.issuer) {
            
                Write-Host $OVIP -f Green -NoNewline ; Write-Host ": Self-signed certificate detected, generating a new CA-Signed certificate..."
               
            }
            else {
            
                Write-Host $OVIP -f Green -NoNewline ; Write-Host ": The CA-signed certificate will expire in less than $days_before_expiration days, generating a new CA-Signed certificate..."
               
            }
        

            # Process to generate a CA-signed certificate for the OneView apppliance

            # Create Certificate Signing Request body
            $CSRbody = ConvertTo-Json @{
                country            = "$Country";
                state              = "$State";
                locality           = "$City";
                organization       = "$OrgName";
                organizationalUnit = "$OrgUnit";
                commonName         = "$($OVcertificate.commonName)";
                alternativeName    = "$($OVcertificate.alternativeName)" 
            }

            # Generate appliance Certificate Signing Request 

            Try {
                $OVCSR = invoke-webrequest -Uri "https://$OVIP/rest/certificates/https/certificaterequest" -Headers $OVheaders -Body $CSRbody -Method POST | ConvertFrom-Json 
               
            }
            Catch { 
                $err = (New-Object System.IO.StreamReader( $_.Exception.Response.GetResponseStream() )).ReadToEnd() 
                $msg = ($err | ConvertFrom-Json )
                Write-Host $OVIP -f Green -NoNewline ; Write-Host -BackgroundColor:Black -ForegroundColor:Red ": Certificate Signing request failure ! $($msg.errorCode): $($msg.message) "
                continue 
            }

            # Saving CSR to a local file
            Set-Content -path "C:\temp\request.csr" -value $OVCSR.base64Data -Force
            
            # Generating CA-Signed certificate from an available CA using the OneView CSR
 
            ## Submitting the CSR using the default webServer certificate template
            Submit-CertificateRequest -path "C:\temp\request.csr" -CertificationAuthority $CA -Attribute CertificateTemplate:$CA_OneView_template | Out-Null
            ### To get the correct certificate template name, use: 
            ### (get-catemplate -CertificationAuthority $ca).Templates.Name
  
            ## Building the certificate 
            "-----BEGIN CERTIFICATE-----" | Out-File C:\temp\mycert.cer
            ( Get-IssuedRequest -CertificationAuthority $CA -Property "RawCertificate" | ? CommonName -eq $OVcertificate.commonName | select -last 1 ).RawCertificate.trim("`r`n") | Out-File C:\Temp\mycert.cer -Append #-Encoding ascii
            "-----END CERTIFICATE-----" | Out-File C:\temp\mycert.cer -Append


            ## Formatting the built certificate for the JSON body content
            $certificate = Get-Content C:\temp\mycert.cer -raw

            $body = ConvertTo-Json  @{ base64Data = "$certificate" }


            # Importing new signed certificate into OneView appliance

            Try {
                $task = invoke-webrequest -Uri "https://$OVIP/rest/certificates/https/certificaterequest" -Headers $OVheaders -Body $body -Method PUT | ConvertFrom-Json 
               
            }
            Catch { 
                $err = (New-Object System.IO.StreamReader( $_.Exception.Response.GetResponseStream() )).ReadToEnd() 
                $msg = ($err | ConvertFrom-Json )
                Write-Host $OVIP -f Green -NoNewline ; Write-Host -BackgroundColor:Black -ForegroundColor:Red ": Certificate import failure ! $($msg.errorCode): $($msg.message) "
                Continue 
            }

            $taskuri = $task.uri
           
            do {
                $progress = invoke-webrequest -Uri "https://$OVIP$taskuri" -Headers $OVheaders -Method GET
                sleep 2
                
            } until (($progress.content | Convertfrom-Json).percentComplete -eq 100)
            
           
            if (($progress.content | Convertfrom-Json).taskstate -eq "Error") {
             
                Write-Host $OVIP -f Green -NoNewline ; write-host ": Error ! $(($progress.content | Convertfrom-Json).taskErrors.message): $(($progress.content | Convertfrom-Json).taskErrors.details) " -ForegroundColor red
            }
            else {

                Write-Host $OVIP -f Green -NoNewline ; write-host ": $(($progress.content | Convertfrom-Json).progressUpdates | sort id | select -last 1 | % statusUpdate) " -ForegroundColor Yellow

            }

            # Removing self-signed certificate from the OneView Global Dashboard appliance trust store
            Write-Host $OVIP -f Green -NoNewline ; write-host ": Removing self-signed certificate from the OneView Global Dashboard appliance trust store..."
            try {
                invoke-webrequest -Uri "https://$globaldashboard/rest/certificates/servers/$($OVcertificate.commonName)" -Headers $headers -Method DELETE  | Out-Null
                Write-Host $OVIP -f Green -NoNewline ; write-host ": Self-signed certificate removed successfully!" -ForegroundColor Yellow
            }
            catch {
                Write-Host $OVIP -f Green -NoNewline ; write-host ": Error ! Self-signed certificate cannot be removed!" -ForegroundColor Red
                
            }
            
            sleep 15

            # Reconnecting appliance to update the new certificate
            $OVsecpasswd = read-host "`tReconnecting appliance to import new certificate, please enter the Administrator password" -AsSecureString
            $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($OVsecpasswd)
            $password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr) 

            try {
                $headers["content-type"] = "application/json-patch+json"
                $body = ConvertTo-Json  @( @{ op = "replace"; path = "/credential"; value = @{ username = "Administrator"; password = "$password"; loginDomain = "local" } }) -Depth 5
                invoke-webrequest -Uri "https://$globaldashboard/rest/appliances/$ID" -Headers $headers -Body $body -Method PATCH | out-null
                Write-Host $OVIP -f Green -NoNewline ; write-host ": The reconnection was successful!" -ForegroundColor Yellow
            }
            catch {
                $err = (New-Object System.IO.StreamReader( $_.Exception.Response.GetResponseStream() )).ReadToEnd() 
                $msg = ($err | ConvertFrom-Json )
                Write-Host $OVIP -f Green -NoNewline ; Write-Host -BackgroundColor:Black -ForegroundColor:Red ": appliance refresh failure ! $($msg.errorCode): $($msg.message) - $($msg.recommendedActions) "
                Continue 
            }

            sleep 15

            # Refreshing appliance 
            Write-Host $OVIP -f Green -NoNewline ; write-host ": Refreshing appliance..."
            try {
                $headers["content-type"] = "application/json-patch+json"
                $body = ConvertTo-Json @(@{op = "replace"; path = "/status"; value = "refreshPending" })
                invoke-webrequest -Uri "https://$globaldashboard/rest/appliances/$ID" -Headers $headers -Body $body -Method PATCH | out-null

            }
            catch {
                $err = (New-Object System.IO.StreamReader( $_.Exception.Response.GetResponseStream() )).ReadToEnd() 
                $msg = ($err | ConvertFrom-Json )
                Write-Host $OVIP -f Green -NoNewline ; Write-Host -BackgroundColor:Black -ForegroundColor:Red ": appliance refresh failure ! $($msg.errorCode): $($msg.message) - $($msg.recommendedActions) "
                Continue 
            }
 
            Write-Host $OVIP -f Green -NoNewline ; Write-Host -BackgroundColor:Black -ForegroundColor:Yellow ": The appliance certificate change is completed!"

        }
        else {
            Write-Host $OVIP -f Green -NoNewline ; Write-Host ": CA-signed certificate detected with an expiration date greater than $days_before_expiration days, no action required..."
           
        }
     
    }

}

if (-not $found) {
    write-host "Operation completed! All appliances use an unexpired certificate signed by the certificate authority!"
}
else {
    write-host "Operation completed ! All other appliances use an unexpired certificate signed by the certification authority!"
}

        
Read-Host -Prompt "Hit return to close" 
