<# 

This PowerShell script generates an SSL certificate signed by a certificate authority (CA) on an iLO.

Steps of this script: 
1- Request the password of the iLO user defined in the variables 
2- Requests the IP address of the iLO where to generate a new certificate signed by a certification authority
3- Find the first trusted Certification Authority server available on the network
        Note: Only works if the host from which you are running this script is in an AD domain
4- Create a Certificate Signing Request in iLO using the 'Certificate Signing Request variables' (at the begining of the script) 
5- Submit the CSR to the Certificate Authority server 
6- Import new CA-signed certificate on iLOs (triggers an iLO reset)

Gen9 and Gen10 servers are supported 

Requirements:
   - HPE BIOS Cmdlets PowerShell Library (HPEBIOSCmdlets)
   - iLO Administrator account
   - PSPKI Powershell Library 

  NOTE : The iLO is reset after the certificate has been imported
  
  
  Author: lionel.jullien@hpe.com
  Date:   Fev 2022
    
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
$csrPath = "$HOME\cert.csr"
$crtPath = "$HOME\cert.cer"


# iLO Username 
$iLO_username = "Administrator"


# Certificate Signing Request variables
$city = "Houston"
$Country = "US"
$OrgName = "HPE"
$OrgUnit = "Synergy"
$State = "Texas"

# MODULES TO INSTALL/IMPORT

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

# Capture iLO Administrator account password
$seciLOpassword = Read-Host "Please enter the password for the iLO user [$($iLO_username)]" -AsSecureString

# Capture iLO IP address
$ilohost = read-host  "Please enter the iLO IP address you want to factory reset"


# Connection to the iLO
$ilocreds = New-Object System.Management.Automation.PSCredential ($iLO_username, $seciLOpassword)
$connection = Connect-HPEiLO -Credential $ilocreds -Address $iloHost -DisableCertificateAuthentication

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

    $CommonName = ( Get-HPEiLOIPv4NetworkSetting   -Connection $connection).fqdn

    # Certificate Signing Request 
    Start-HPEiLOCertificateSigningRequest -Connection $connection -IncludeiLOIP:$true -CommonName $CommonName -State $State -City $city -Country $Country -Organization $OrgName -OrganizationalUnit $OrgUnit

    sleep 30 # might need more time if iLO4...

    Get-HPEiLOCertificateSigningRequest -Connection $connection | select-object -ExpandProperty CertificateSigningRequest > $csrPath

    Submit-CertificateRequest -path $csrPath -CertificationAuthority (Get-CertificationAuthority $CA_computername) -Attribute CertificateTemplate:WebServer | Out-Null

    ## Building the certificate 
    "-----BEGIN CERTIFICATE-----" | Out-File $crtPath
    ( Get-IssuedRequest -CertificationAuthority (Get-CertificationAuthority $CA_computername) -Property "RawCertificate" | select -Last 1 ).RawCertificate.trim("`r`n") | Out-File $crtPath -Append
    "-----END CERTIFICATE-----" | Out-File $crtPath -Append

    ## Formatting the built certificate for the JSON body content
    $certificate = Get-Content $crtPath -raw

    Import-HPEiLOCertificate -Certificate $certificate -Connection $connection -Force | out-null #-verbose 
    
    write-host "iLO reset is in progress..."

    Disconnect-HPEiLO -Connection $connection 

    Read-Host -Prompt "Operation completed, hit return to close" 
}