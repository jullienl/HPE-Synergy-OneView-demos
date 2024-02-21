<# 

Typical example of a PowerShell script that does not use the HPE OneView PowerShell library but uses native OneView API requests. 
Very useful to understand the mechanics of session creation, headers and payloads needed to interact with the HPE OneView RestFul API.  

This PowerShell script shows an example of how to disable TLS1.0 and 1.1 protocols on an HPE Synergy Composer or HPE OneView appliance. 

Important note: Enabling/Disabling TLS protocols reboots the appliance automatically for the changes to take effect. 
This reboot does not affect Compute modules and Interconnect Modules, only the management plane is impacted.

Requirements: 
- OneView administrator account.


  Author: lionel.jullien@hpe.com
  Date:   July 2021
    
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

# OneView information
$OVusername = "Administrator"
$OVpassword = "xxxxxxxxxxxx"
$OVIP = "composer.lj.lab"


# MODULES TO INSTALL
# NONE

#################################################################################

# Get-X-API-Version
$response = Invoke-RestMethod "https://$OVIP/rest/version" -Method GET 
$currentVersion = $response.currentVersion

# Headers creation
$headers = @{} 
$headers["X-API-Version"] = "$currentVersion"
$headers["Content-Type"] = "application/json"

# Payload creation
$body = @"
{
  "authLoginDomain": "Local",
  "password": "$OVpassword",
  "userName": "$OVusername"
}
"@

# Connection to OneView / Synergy Composer
$response = Invoke-RestMethod "https://$OVIP/rest/login-sessions" -Method POST -Headers $headers -Body $body

# Capturing the OneView Session ID
$sessionID = $response.sessionID

# Policy settings and self-signed certificate policy validation
# Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

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

#########################################################################################################

# Modification of the TLS settings

# Add AUTH to Headers
$headers["auth"] = $sessionID

# Payload creation
$body = @"
[
  {
    "protocolName":"TLSv1",
    "enabled":false
  },
  {
    "protocolName":"TLSv1.1",
    "enabled":false
  },
  {
    "protocolName":"TLSv1.2",
    "enabled":true
  }
]
"@

# Protocols PUT request 
try {
  $response = Invoke-RestMethod "https://$OVIP/rest/security-standards/protocols" -Method PUT -Headers $headers -Body $body
  $response
}
catch {
  $response | ConvertTo-Json 
}


write-host "OneView is now rebooting..."

