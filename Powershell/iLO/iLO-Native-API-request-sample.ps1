<# 

PowerShell script to set the high security mode on all iLO5 managed by HPE OneView. 

Once the state is set, the iLO automatically resets to activate the high security mode.

Gen10/Gen10+ servers are supported. Gen9 servers are skipped by the script.

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


$SH = Search-OVIndex -Category server-hardware 


foreach ($item in $SH) {

    $iLOIP = $item.multiAttributes.mpIpAddresses |  ? { $_ -NotMatch "fe80" }

    $iloModel = $item.Attributes.mpModel

    if ($iloModel -match "ilo4") {
        write-host "niLO [$iLOIP] is an iLO4 ! High Security state is not supported, skipping server..."
        continue
    }

    try {
        $ilosessionkey = ($item | Get-OVIloSso -IloRestSession)."X-Auth-Token"
    }
    catch {
        Write-Warning "`niLO [$iLOIP] cannot be found ! Fix any communication problem you have in OneView with this iLO/server hardware !"
        continue
    }


    # Creation of the header using the SSO Session Key 
    $headerilo = @{ } 
    $headerilo["X-Auth-Token"] = $ilosessionkey 
    $headerilo["OData-Version"] = "4.0"

    # Creation of the body for the iLO factory reset
    $bodyiloParams = @{ } 
    $bodyiloParams["SecurityState"] = "HighSecurity"
    $bodyiloParams = $bodyiloParams | ConvertTo-Json  

    
    $url = "/redfish/v1/Managers/1/SecurityService"
    
    #Setting iLO High Security state
    try {
        $rest = Invoke-WebRequest -Uri "https://$iLOIP$url" -Body $bodyiloParams -Headers $headerilo -ContentType "application/json" -Method PATCH -UseBasicParsing 
        write-host "`niLO $($iloip) High Security state is now enabled... API response: [$(($rest.Content | convertfrom-json).error.'@Message.ExtendedInfo'.MessageId)]"
    }
    catch {
        $err = (New-Object System.IO.StreamReader( $_.Exception.Response.GetResponseStream() )).ReadToEnd() 
        $msg = ($err | ConvertFrom-Json ).error.'@Message.ExtendedInfo'.MessageId
        Write-Host -BackgroundColor:Black -ForegroundColor:Red "iLO $($iloip) high security state configuration error ! Message returned: [$($msg)]"
        continue
      
    }

}


Disconnect-OVMgmt