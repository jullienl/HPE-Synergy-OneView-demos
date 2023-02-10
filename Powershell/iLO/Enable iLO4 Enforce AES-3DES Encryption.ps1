<# 

PowerShell script to enforce AES/3DES encryption on all iLO4 managed by HPE OneView. 

When enabled, the management processor accepts only connections that use AES or 3DES ciphers. 

Once the state is set, the iLO automatically resets to activate the Enforce AES/3DES Encryption.

Gen9 servers are supported. Gen10/Gen10+ servers are skipped by the script.

 Requirements:
   - HPE OneView Powershell Library
   - HPE OneView administrator account 

 Author: lionel.jullien@hpe.com
 Date:   Fev 2023
    
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


# OneView Credentials and IP
$OV_username = "Administrator"
$OV_IP = "composer.lj.lab"


# MODULES TO INSTALL

# HPEOneView
# If (-not (get-module HPEOneView.630 -ListAvailable )) { Install-Module -Name HPEOneView.630 -scope Allusers -Force }


#################################################################################

if (! $ConnectedSessions) {
    
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

    # Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
}

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


#################################################################################

# Capture iLO4 server hardware managed by HPE OneView
$SH = Search-OVIndex -Category server-hardware | ? { $_.Attributes.mpModel -eq "iLO4" } #| select -first 1

clear

if ($SH) {
    write-host ""
    if (! $SH.count) { 
        Write-host "1 x iLO4 is going to be configured with Enforce AES/3DES Encryption to enable:" 
    }
    else {
        Write-host $SH.Count "x iLO4 are going to be configured with Enforce AES/3DES Encryption to enable:" 
    } 
    $SH.name | Format-Table -autosize | Out-Host

}
else {
    Write-Warning "No iLO4 server found ! Exiting... !"
    Disconnect-OVMgmt
    exit
}


# Request content to enable iLO High Security state
$body = @"
{
    "Oem”: {
        
        “Hp”:
    	
         {“EnforceAES3DESEncryption”: true}
   	}

}
"@


# Creation of the headers  
$headers = @{} 
$headers["OData-Version"] = "4.0"

# iLO4 Redfish URI
$uri = "/redfish/v1/Managers/1/NetworkService/"

# Method
$method = "patch"

#####################################################################################################################

foreach ($item in $SH) {

    $iLOIP = $item.multiAttributes.mpIpAddresses |  ? { $_ -NotMatch "fe80" }

    # Capture of the SSO Session Key
    try {
        $ilosessionkey = ($item | Get-OVIloSso -IloRestSession)."X-Auth-Token"
        $headers["X-Auth-Token"] = $ilosessionkey 
    }
    catch {
        Write-Warning "`niLO [$iLOIP] cannot be found ! Fix any communication problem you have in OneView with this iLO/server hardware !"
        continue
    }

    
    # Enabling iLO High Security state
    try {
        $response = Invoke-WebRequest -Uri "https://$iLOIP$uri" -Body $body -ContentType "application/json" -Headers $headers -Method $method -ErrorAction Stop
        $msg = ($response.Content | ConvertFrom-Json).error.'@Message.ExtendedInfo'.MessageId
        write-host "`niLO $($iloip) Enforce AES/3DES Encryption state is now enabled... API response: [$($msg)]"
    }
    catch {
        $err = (New-Object System.IO.StreamReader( $_.Exception.Response.GetResponseStream() )).ReadToEnd() 
        $msg = ($err | ConvertFrom-Json ).error.'@Message.ExtendedInfo'.MessageId
        Write-Host -BackgroundColor:Black -ForegroundColor:Red "iLO $($iloip) Enforce AES/3DES Encryption state configuration error ! Message returned: [$($msg)]"
        continue
      
    }

}

write-host ""
Read-Host -Prompt "Operation done ! Hit return to close" 
Disconnect-OVMgmt