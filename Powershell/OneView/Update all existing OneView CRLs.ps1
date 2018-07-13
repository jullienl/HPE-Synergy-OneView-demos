# -------------------------------------------------------------------------------------------------------
# by lionel.jullien@hpe.com
# July 2018
#
# This POSH script updates all existing CRLs (Certificate Revocation List) present in Oneview identified as expired
#   
# 
# OneView administrator account is required. 
# An internet connection is required by the script to download the CRLs
# 
# Note: CRLs update takes effect immediately, but it can take up to an hour for the manage 
# certificates dialog box to show an OK state rather than CRL Expired.
#
# --------------------------------------------------------------------------------------------------------



# OneView Credentials and IP

$username = "Administrator" 
$password = "password" 
$IP = "192.168.1.110" 



Function MyImport-Module {
    
    # Import a module that can be imported
    # If it cannot, the module is installed
    # When -update parameter is used, the module is updated 
    # to the latest version available on the PowerShell library
    
    # $module = "HPOneview.400"

    param ( 
        $module, 
        [switch]$update 
    )
   
    if (get-module $module -ListAvailable)
    {
        if ($update.IsPresent) {
            # Updates the module to the latest version
            [string]$Moduleinstalled = (Get-Module -Name $module).version
            [string]$ModuleonRepo = (Find-Module -Name $module -ErrorAction SilentlyContinue).version

            $Compare = Compare-Object $Moduleinstalled $ModuleonRepo -IncludeEqual

            If (-not ($Compare.SideIndicator -eq '==')) {
                Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
                Update-Module -Name $module -confirm:$false | Out-Null
           
            }
            Else {
                Write-host "You are using the latest version of $module" 
            }
        }
            
        Import-module $module
            
    }

    Else
    {
        Write-Warning "$Module is not present"
        Write-host "`nInstalling $Module ..." 

        Try {
            If ( !(get-PSRepository).name -eq "PSGallery" )
            {Register-PSRepository -Default}
            Install-Module –Name $module -Scope CurrentUser –Force -ErrorAction Stop | Out-Null
            Import-Module $module
        }
        Catch {
            Write-Warning "$Module cannot be installed" 
            $error[0] | FL * -force
        }
    }

}

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



# Modules to import

MyImport-Module HPOneview.400 # -update
MyImport-Module PSPKI
#MyImport-Module PowerShellGet
#MyImport-Module FormatPX
#MyImport-Module SnippetPX
#MyImport-Module PoshRSJob




Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

#Connecting to the Synergy Composer

if ($connectedSessions -and ($connectedSessions | ? {$_.name -eq $IP})) {
    Write-Verbose "Already connected to $IP."
}

else {
    Try {
        Connect-HPOVMgmt -appliance $IP -UserName $username -Password $password | Out-Null
    }
    Catch {
        throw $_
    }
}

               
import-HPOVSSLCertificate -ApplianceConnection ($connectedSessions | ? {$_.name -eq $IP})

<#
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

#>
   


# Creation of the header
  
$headers = @{} 
$headers["Accept"] = "application/json" 
$headers["X-API-Version"] = "600"
$key = $ConnectedSessions[0].SessionID 
$headers["Auth"] = $key


# List of CA Certificates available in OneView
<#
$certVeriSign1 = "VeriSign Class 3 Public Primary Certification Authority - G5"
$certVeriSign2 = "VeriSign Universal Root Certification Authority"
$certSymantec1 = "Symantec Class 3 Secure Server CA - G4"
$certSymantec2 = "Symantec Class 3 Secure Server SHA256 SSL CA"
#>

$certificates = ((get-HPOVApplianceTrustedCertificate).certificateDetails | ? keyusage -eq "keyCertSign,cRLSign").aliasname

Foreach ($certificate in $certificates) {

    $uri = (Get-HPOVApplianceTrustedCertificate).certificateDetails | ? aliasname -match $certificate | % uri
    [DateTime]$CRLexpirationdate = ( Get-HPOVApplianceTrustedCertificate | ? {$_.certificateDetails.aliasname -match $certificate} ).certRevocationConfInfo.crlExpiry
    $date = Get-Date
    
    If (($CRLexpirationdate - $date).days -lt 0  )
    {
    
        $expiration = - ($CRLexpirationdate - $date).days
    
        Write-host "`n'$certificate' CRL expired $expiration days ago, let's upload the new CRL !" -ForegroundColor Green
        # Finding the URL of the CRL 
        $CRLdistributionpoint = ( Get-HPOVApplianceTrustedCertificate | ? {$_.certificateDetails.aliasname -match $certificate} ).certRevocationConfInfo.crlconf.crldplist
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

            $result = Invoke-RestMethod -Uri "https://$IP$uri/crl" -Headers $headers -Body $bodyLines -ContentType "multipart/form-data; boundary=$boundary" -Method PUT # -Verbose  
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



