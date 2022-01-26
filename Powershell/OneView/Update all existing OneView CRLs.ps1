# -------------------------------------------------------------------------------------------------------
# by lionel.jullien@hpe.com
# July 2018
#
# This script updates all existing CRLs (Certificate Revocation List) present in Oneview identified as expired
#   
#  Requirement:
#    - PSPKI PowerShell library
#    - HPE OneView Powershell Library
#    - HPE OneView administrator account 
#    - An internet connection is required by the script to download the CRLs
# 
# Note: CRLs update takes effect immediately, but it can take up to an hour for the manage 
# certificates dialog box to show an OK state rather than CRL Expired.
#
# This script is only supported with the HPE OneView PowerShell library version 4.00
# The 4.10 library will natively provide cmdlets to update the OneView CRLs
# To learn how to proceed with 4.10 : help Update-OVApplianceTrustedAuthorityCrl -Examples
#
# --------------------------------------------------------------------------------------------------------


#################################################################################
#                                Global Variables                               #
#################################################################################

# Pool range
$vlanRangeStart = "4035"
$vlanRangeLength = "60"



# OneView Credentials and IP
$OV_username = "Administrator"
$OV_IP = "composer2.lj.lab"


# MODULES TO INSTALL

# HPEOneView
# If (-not (get-module HPEOneView.630 -ListAvailable )) { Install-Module -Name HPEOneView.630 -scope Allusers -Force }

# PSPKI
# Import-ModuleAdv PSPKI


#################################################################################

$secpasswd = read-host  "Please enter the OneView password" -AsSecureString
 
# Connection to the OneView / Synergy Composer
$credentials = New-Object System.Management.Automation.PSCredential ($OV_username, $secpasswd)

try {
    Connect-OVMgmt -Hostname $OV_IP -Credential $credentials -ErrorAction stop | Out-Null    
}
catch {
    Write-Warning "Cannot connect to '$OV_IP'! Exiting... "
    return
}

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force



function Failure {
    $global:helpme = $bodyLines
    $global:helpmoref = $moref
    $global:result = $_.Exception.Response.GetResponseStream()
    $global:reader = New-Object System.IO.StreamReader($global:result)
    $global:responseBody = $global:reader.ReadToEnd();
    Write-Host -BackgroundColor:Black -ForegroundColor:Red "Status: A system exception was caught."
    Write-Host -BackgroundColor:Black -ForegroundColor:Red $global:responsebody
    Write-Host -BackgroundColor:Black -ForegroundColor:Red "The request body has been saved to `$global:helpme"
    #break
}


Clear-Host

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


#############################################################################################################   

# Creation of the header
  
$headers = @{ } 
$headers["Accept"] = "application/json" 
$headers["X-API-Version"] = "2300"
$key = $ConnectedSessions[0].SessionID 
$headers["Auth"] = $key


# List of CA Certificates available in OneView
<#
$certVeriSign1 = "VeriSign Class 3 Public Primary Certification Authority - G5"
$certVeriSign2 = "VeriSign Universal Root Certification Authority"
$certSymantec1 = "Symantec Class 3 Secure Server CA - G4"
$certSymantec2 = "Symantec Class 3 Secure Server SHA256 SSL CA"
#>

$certificates = ((get-OVApplianceTrustedCertificate).certificateDetails | ? keyusage -eq "keyCertSign,cRLSign").aliasname

Foreach ($certificate in $certificates) {

    $uri = (Get-OVApplianceTrustedCertificate).certificateDetails | ? aliasname -match $certificate | % uri
    [DateTime]$CRLexpirationdate = ( Get-OVApplianceTrustedCertificate | ? { $_.certificateDetails.aliasname -match $certificate } ).certRevocationConfInfo.crlExpiry
    $date = Get-Date
    
    If (($CRLexpirationdate - $date).days -lt 0  ) {
    
        $expiration = - ($CRLexpirationdate - $date).days
    
        Write-host "`n'$certificate' CRL expired $expiration days ago, let's upload the new CRL !" -ForegroundColor Green
        # Finding the URL of the CRL 
        $CRLdistributionpoint = ( Get-OVApplianceTrustedCertificate | ? { $_.certificateDetails.aliasname -match $certificate } ).certRevocationConfInfo.crlconf.crldplist
        $CRLdistributionpoint = $CRLdistributionpoint -join ''
        $CRL = "$certificate.crl"
    
        # Downloading the CRL
        Invoke-WebRequest -Uri $CRLdistributionpoint -OutFile $env:USERPROFILE\$CRL 
        $filePath = "$env:USERPROFILE\$CRL" # -replace '\\', '/'
    
   
        #Creating the body

        $fileBin = [IO.File]::ReadAllBytes($filePath)
        $enc = [System.Text.Encoding]::GetEncoding("iso-8859-1")
        $fileEnc = $enc.GetString($fileBin)
                  
        $boundary = [System.Guid]::NewGuid().ToString()
        $LF = "`r`n"

    
        $bodyLines = (
            "--$boundary",
            "Content-Disposition: form-data; name=`"File`"$LF",
            $fileEnc,
            "Content-Type: application/pkix-crl$LF",
            #$CRLContents,
            "--$boundary--$LF"
        ) -join $LF

        try {

            $result = Invoke-RestMethod -Uri "https://$OV_IP$uri/crl" -Headers $headers -Body $bodyLines -ContentType "multipart/form-data; boundary=$boundary" -Method PUT # -Verbose  
            write-host "`n'$certificate' has been uploaded successfully !" -ForegroundColor Green
        }

        catch {
        
            write-host "`nError - '$certificate' cannot be uploaded !" -ForegroundColor Red
            write-host "`n$_"
            failure
        }   

    
    
        Remove-Item $filePath -Confirm:$false

    }
    Else {
        Write-Host "`nThe CRL for '$certificate' is valid until $CRLexpirationdate - No change will be made!" -ForegroundColor Green
    }

}


Disconnect-OVMgmt
