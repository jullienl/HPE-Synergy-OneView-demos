# -------------------------------------------------------------------------------------------------------
# by lionel.jullien@hpe.com
# Feb 2019
#
# This POSH script uploads an artifact bundle in HPE Image Streamer  
#   
# 
# OneView administrator account is required. 
# --------------------------------------------------------------------------------------------------------



# OneView Credentials and IP
$username = "Administrator" 
$password = "password" 
$IP = "192.168.1.110" 

# Path of the Artifact bundle ZIP FILE
$filePath = 'D:\Kits\HPE-Windows-2018-08-28.zip'


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


Import-Module HPOneview.410 #-update

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

#Connecting to the Synergy Composer

if ($connectedSessions -and ($connectedSessions | ? {$_.name -eq $IP})) {
    Write-Verbose "Already connected to $IP."
}

else {
    Try {
        $ApplianceConnection = Connect-HPOVMgmt -appliance $IP -UserName $username -Password $password 
    }
    Catch {
        throw $_
    }
}

               
import-HPOVSSLCertificate -ApplianceConnection ($connectedSessions | ? {$_.name -eq $IP})



# Capturing OS Deployment Server IP address managed by OneViews     
                   
$I3sIP = (Get-HPOVOSDeploymentServer).primaryipv4

# Added these lines to avoid the error: "The underlying connection was closed: Could not establish trust relationship for the SSL/TLS secure channel."
# due to an invalid Remote Certificate
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


# Creation of the header
$headers = @{} 
$headers["Accept"] = "application/json" 
$headers["X-API-Version"] = "800"
$key = $ConnectedSessions[0].SessionID 
$headers["Auth"] = $key


# Creation of the body
$fileBin = [IO.File]::ReadAllBytes($filePath)
$enc = [System.Text.Encoding]::GetEncoding("iso-8859-1")
$fileEnc = $enc.GetString($fileBin)

$boundary = [System.Guid]::NewGuid().ToString()
$LF = "`r`n"

    
$bodyLines = (
    "--$boundary",
    "Content-Disposition: form-data; name=`"file`"; filename=$filepath$LF",
    $fileEnc,
    "Content-Type: application/zip$LF",
    "--$boundary--$LF"
) -join $LF


# Creation of the webrequest       

Try {
    $result = Invoke-RestMethod -Uri "https://$I3sIP/rest/artifact-bundles" -Headers $headers -Body $bodyLines -ContentType "multipart/form-data; boundary=$boundary" -Method POST # -Verbose  
    write-host "`nArtifact bundle '$filepath' has been uploaded successfully !" -ForegroundColor Green

}
catch {
    failure
}

