﻿<#
Examples of iLO interaction using different methods and HPE PowerShell libraries:
1- HPEiLOCmdlets
2- HPEBIOSCmdlets
3- HPERedfishCmdlets
4- Native API calls


 Author: lionel.jullien@hpe.com
 Date:   Oct 2023
    
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


# iLO information
$iLO_IP = "192.168.3.52"
$iLO_username = "Administrator"

# Ask for iLO password
$secpasswd = read-host  "Please enter the iLO password" -AsSecureString
$ilocreds = New-Object System.Management.Automation.PSCredential ($iLO_username, $secpasswd)



######################################## Using HPEiLOCmdlets ################################################
# Requirements: HPEiLOCmdlets (currently not supported with Synergy Gen11 servers!)
# install-module HPEiLOCmdlets -Scope CurrentUser


# List of cmdlets
Get-command -Module HPEiLOCmdlets

# Connection
$connection = Connect-HPEiLO -Address $iLO_IP -Credential $ilocreds  -DisableCertificateAuthentication 

# Examples
(Get-HPEiLOUser -Connection  $connection).userinformation.count
Get-HPEiLOServerInfo -Connection $connection




######################################## Using HPEBIOSCmdlets ################################################
# Requirements: HPEBIOSCmdlets 
# install-module HPEBIOSCmdlets -Scope CurrentUser


# List of cmdlets
Get-command -Module HPEBIOSCmdlets
Get-command -Module HPEBIOSCmdlets | ? name -match "security"


# Connection
$connection = Connect-HPEBIOS -Address $iLO_IP -Credential $ilocreds -DisableCertificateAuthentication 


# Examples
Get-HPEBIOSServerSecurity -Connection $connection
Get-HPEBIOSAdvancedSecurityOption -Connection $connection | fl
Set-HPEBIOSServerSecurity -Connection $connection -F11BootMenuPrompt Enabled -IntelligentProvisioningF10Prompt Enabled -IntelTxtSupport Enabled -ProcessorAESNISupport Enabled





######################################## Using HPERedfishCmdlets ################################################
# Requirements: HPERedfishCmdlets 
# install-module HPERedfishCmdlets -Scope CurrentUser


# List of cmdlets
Get-command -Module HPERedfishCmdlets

# Connection
$session = Connect-HpeRedfish -Address $iLO_IP -Credential $ilocreds -DisableCertificateAuthentication


# Examples
Get-HPERedfishDataRaw -Session $session -Odataid "/redfish/v1/Chassis/1/Thermal" -DisableCertificateAuthentication

$setting = @{'IndicatorLED' = 'Lit' }
$ret = Set-HPERedfishData -Odataid /redfish/v1/systems/1/ -Setting $setting -Session $session
$ret.error




######################################## Using full Redfish operations ################################################
# Requirements: NONE

# if using untrusted iLO certificate, you must use with PowerShell 5.x:
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

# With PowerShell 7.x: just add -SkipCertificateCheck parameter to all your web requests


######################## Connection ############################

$headers = @{} 
$headers["OData-Version"] = "4.0"
$headers["Content-Type"] = "application/json"

$body = "{`"UserName`": `"$iLO_username`",`n`"Password`": `"$ilo_password`"}`n"

$session = Invoke-RestMethod "https://$iLO_IP/redfish/v1/SessionService/Sessions/" -Method 'POST' -Headers $headers -Body $body # for PowerShell 7: -SkipCertificateCheck 
$token = $session.headers | % X-Auth-Token

$headers["X-Auth-Token"] = $token


######################## GET Example ############################


# iLO5 Redfish URI
$uri = "/redfish/v1/Managers/1/SecurityService"

# Method
$method = "Get"

# Request
$response = Invoke-RestMethod -Uri "https://$iLO_IP$uri" -Headers $headers -Method $method -ErrorAction Stop # for PowerShell 7: -SkipCertificateCheck 

# Response
$response
$response.SecurityState
$response.TLSVersion


######################## PATCH Example ###########################


# iLO5 Redfish URI
$uri = "/redfish/v1/Managers/1/SecurityService"

# Body
$Body = @{} 
$body["SecurityState"] = "HighSecurity"

# Method
$method = "Patch"

# Request
try {
    $response = Invoke-RestMethod -Uri "https://$iLO_IP$uri" -Headers $headers -body $Body -Method $method -ErrorAction Stop # for PowerShell 7: -SkipCertificateCheck 
}
catch {
    $err = (New-Object System.IO.StreamReader( $_.Exception.Response.GetResponseStream() )).ReadToEnd() 
    $msg = ($err | ConvertFrom-Json ).error.'@Message.ExtendedInfo'.MessageId
    Write-Host -BackgroundColor:Black -ForegroundColor:Red "iLO $($iloip) Patch operation failure ! Message returned: [$($msg)]"
    continue
}

# Response
$response
