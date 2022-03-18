<# 

Script to fetch the 5 latest alerts and the number of all alerts available in HPE OneView Global Dashboard


Requirements:
   - HPE Global Dashboard administrator account 


  Author: lionel.jullien@hpe.com
  Date:   March 2018
    
#################################################################################
#                         Server FW Inventory in rows.ps1                       #
#                                                                               #
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



# Global Dashboard information
$username = "Administrator"
$globaldashboard = "oneview-global-dashboard.lj.lab"
 

#################################################################################

$secpasswd = read-host  "Please enter the OneView Global Dashboard password" -AsSecureString
 
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

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

#Creation of the header
$headers = @{ } 
$headers["content-type"] = "application/json" 

# Capturing X-API Version
$xapiversion = ((invoke-webrequest -Uri "https://$globaldashboard/rest/version" -Headers $headers -Method GET ).Content | Convertfrom-Json).currentVersion

$headers["X-API-Version"] = $xapiversion


$bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secpasswd)
$password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr) 

#Creation of the body
#$Body = @{userName = $username; password = $password; authLoginDomain = "lj.lab" } | ConvertTo-Json 
$Body = @{userName = $username; password = $password; domain = "local" } | ConvertTo-Json 


#Opening a login session with Global DashBoard
$session = invoke-webrequest -Uri "https://$globaldashboard/rest/login-sessions" -Headers $headers -Body $Body -Method Post 

#Capturing the OneView Global DashBoard Session ID and adding it to the header
$key = ($session.content | ConvertFrom-Json).sessionID
$headers["auth"] = $key

#Capturing the OneView Global DashBoard alerts
$resourcealerts = (invoke-webrequest -Uri "https://$globaldashboard/rest/resource-alerts" -Headers $headers -Method GET) | ConvertFrom-Json

Clear-Host

if (($resourcealerts.total) -eq "0") {
    Write-host "No alert found !`n"
    
}
else {

    Write-host "`nThe number of alerts is " -NoNewline; write-host $resourcealerts.count -ForegroundColor Green
    Write-host "`nThe latest 5 alerts are: "
    $resourcealerts.members | select -First 5 | Format-List -Property severity, description, correctiveAction
}