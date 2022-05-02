# -------------------------------------------------------------------------------------------------------
# by lionel.jullien@hpe.com
# July 2019
#
# PowerShell script to set the iLO password complexity option to enable on all iLO5 managed by HPE OneView. 
#
# iLO modification is done through OneView and iLO SSO session key using REST PATCH method
#
# Requirements:
#    - HPE OneView Powershell Library
#    - HPE OneView administrator account 
# --------------------------------------------------------------------------------------------------------

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


# Capture iLO5 server hardware managed by HPE OneView
$computes = Get-OVServer | where mpModel -eq iLO5 #| select -First 1

clear

if ($computes) {
    write-host ""
    if (! $computes.count) { 
        Write-host "1 x iLO5 is going to be configured with iLO Password complexity to enable:" 
    }
    else {
        Write-host $SH.Count "x iLO5 are going to be configured with iLO Password complexity to enable:" 
    } 
    $computes.name | Format-Table -autosize | Out-Host

}
else {
    Write-Warning "No iLO5 server found ! Exiting... !"
    Disconnect-OVMgmt
    exit
}


# Request content to enable iLO password complexity
$body = ConvertTo-Json   @{ Oem = @{ Hpe = @{ EnforcePasswordComplexity = $True } } } -Depth 99

# Creation of the headers  
$headers = @{} 
$headers["OData-Version"] = "4.0"

# iLO5 Redfish URI
$uri = "/redfish/v1/accountservice"

# Method
$method = "patch"

#####################################################################################################################

Foreach ($compute in $computes) {

    $iloIP = $compute.mpHostInfo.mpIpAddresses | ? type -ne LinkLocal | % address

    # Capture of the SSO Session Key
    try {
        $ilosessionkey = ($compute | Get-OVIloSso -IloRestSession)."X-Auth-Token"
        $headers["X-Auth-Token"] = $ilosessionkey 
    }
    catch {
        Write-Warning "`niLO [$iLOIP] cannot be found ! Fix any communication problem you have in OneView with this iLO/server hardware !"
        continue
    }


    # Enabling password complexity
    try {
        $response = Invoke-WebRequest -Uri "https://$iloIP$uri" -Body $body -ContentType "application/json" -Headers $headers -Method $method -UseBasicParsing -ErrorAction Stop
        $msg = ($response.Content | ConvertFrom-Json).error.'@Message.ExtendedInfo'.MessageId
        Write-Host "iLO password complexity option has been enabled in iLo $iloIP. Message returned: [$($msg)]"

    }
    catch {
        $err = (New-Object System.IO.StreamReader( $_.Exception.Response.GetResponseStream() )).ReadToEnd() 
        $msg = ($err | ConvertFrom-Json ).error.'@Message.ExtendedInfo'.MessageId
        Write-Host -BackgroundColor:Black -ForegroundColor:Red "iLO: $($iloIP): The iLO password complexity option has not been changed ! ! Message returned: [$($msg)]"
        continue
    }

}

write-host ""
Read-Host -Prompt "Operation done ! Hit return to close" 
Disconnect-OVMgmt