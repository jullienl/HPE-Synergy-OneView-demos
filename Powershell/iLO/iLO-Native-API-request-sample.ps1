<# 

Example of a PowerShell script to illustrate a typical native API request to iLOs managed by HPE OneView. 

This script will connect to HPE OneView, get the session token, and then use that token to send a request to each iLO.

Gen9/Gen10/Gen10+ servers are supported. PowerShell 5 and 7 are supported.

This script deliberately provides a different payload/URI/method for each iLO model (iLO4,iLO5 and 6) to support queries that might differ depending on the iLO model type.
In this example, where the script changes the iLO's security mode, the payload, URI and method are the same for each iLO type, but this is not always the case.

 Requirements:
   - HPE OneView Powershell Library
   - HPE OneView administrator account 

 Author: lionel.jullien@hpe.com
 Date:   May 2022
    
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

if ($PSEdition -eq "Desktop" ) {

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
}

    

#################################################################################

# Capture iLO5 server hardware managed by HPE OneView
$Computes = Search-OVIndex -Category server-hardware 

if ($Computes) {
    write-host ""
    if (! $Computes.count) { 
        Write-host "1 x iLO is going to be configured with iLO High Security state to enable:" 
    }
    else {
        Write-host $Computes.Count "x iLO are going to be configured with iLO High Security state to enable:" 
    } 
    $Computes.name | Format-Table -autosize | Out-Host

}
else {
    Write-Warning "No iLO server found ! Exiting... !"
    Disconnect-OVMgmt
    exit
}

# Creation of the headers  
$headers = @{} 
$headers["OData-Version"] = "4.0"



#####################################################################################################################

foreach ($Compute in $Computes) {

    $iLOIP = $Compute.multiAttributes.mpIpAddresses |  ? { $_ -NotMatch "fe80" }
    $iloModel = $Compute.attributes | % mpmodel


    # Capture of the SSO Session Key
    try {
        $ilosessionkey = ($Compute | Get-OVIloSso -IloRestSession -SkipCertificateCheck)."X-Auth-Token"
        $headers["X-Auth-Token"] = $ilosessionkey 
    }
    catch {
        Write-Warning "`niLO [$iLOIP] cannot be found ! Fix any communication problem you have in OneView with this iLO/server hardware !"
        continue
    }

    # This example modifies the security mode and in this case, the payload/URI/method is the same for each iLO type (which is not always the case).

    # iLO4
    if ($iloModel -eq "ilo4") {

        # Request content to enable iLO High Security state
        $body = @{}
        $body["SecurityState"] = "HighSecurity"
        $body = $body | ConvertTo-Json  

        # iLO4 Redfish URI
        $uri = "/redfish/v1/Managers/1/SecurityService"

        # Method
        $method = "patch"

    }

    # iLO5 
    elseif ($iloModel -eq "ilo5") {
      
        # Request content to enable iLO High Security state
        $body = @{}
        $body["SecurityState"] = "HighSecurity"
        $body = $body | ConvertTo-Json  
        
        # iLO5 Redfish URI
        $uri = "/redfish/v1/Managers/1/SecurityService"
        
        # Method
        $method = "patch"
    }

    # iLO6
    elseif ($iloModel -eq "ilo6") {
    
        # Request content to enable iLO High Security state
        $body = @{}
        $body["SecurityState"] = "HighSecurity"
        $body = $body | ConvertTo-Json  
            
        # iLO6 Redfish URI
        $uri = "/redfish/v1/Managers/1/SecurityService"
            
        # Method
        $method = "patch"
    }

    # Enabling iLO High Security state
    try {
        if ($PSEdition -eq "Desktop" ) {
            $response = Invoke-WebRequest -Uri "https://$iLOIP$uri" -Body $body -ContentType "application/json" -Headers $headers -Method $method -ErrorAction Stop
        }
        if ($PSEdition -eq "Core" ) {
            $response = Invoke-WebRequest -Uri "https://$iLOIP$uri" -Body $body -ContentType "application/json" -Headers $headers -Method $method -ErrorAction Stop -SkipCertificateCheck
        }

        $msg = ($response.Content | ConvertFrom-Json).error.'@Message.ExtendedInfo'.MessageId
        write-host "`niLO $($iloip) High Security state is now enabled... API response: [$($msg)]"
    }
    catch {
        $err = (New-Object System.IO.StreamReader( $_.Exception.Response.GetResponseStream() )).ReadToEnd() 
        $msg = ($err | ConvertFrom-Json ).error.'@Message.ExtendedInfo'.MessageId
        Write-Host -BackgroundColor:Black -ForegroundColor:Red "iLO $($iloip) configuration error ! Message returned: [$($msg)]"
        continue
      
    }

}

write-host ""
Read-Host -Prompt "Operation done ! Hit return to close" 
Disconnect-OVMgmt