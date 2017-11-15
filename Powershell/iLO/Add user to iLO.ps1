# -------------------------------------------------------------------------------------------------------
# by lionel.jullien@hpe.com
# July 2015
#
# Create a User account in all iLOs managed by OneView without using the iLO Administrator local account
#
# OneView administrator account is required. 
# iLO modification is done through OneView and iLO SSOsession key using REST POST method
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


#IP address of OneView
$DefaultIP = "192.168.1.110" 
Clear
$IP = Read-Host "Please enter the IP address of your OneView appliance [$($DefaultIP)]" 
$IP = ($DefaultIP,$IP)[[bool]$IP]

# OneView Credentials
$username = "Administrator" 
$defaultpassword = "password" 
$password = Read-Host "Please enter the Administrator password for OneView [$($Defaultpassword)]"
$password = ($Defaultpassword,$password)[[bool]$password]


# Import the OneView 3.10 library

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

    if (-not (get-module HPOneview.310)) 
    {  
    Import-module HPOneview.310
    }

   
   
$PWord = ConvertTo-SecureString –String $password –AsPlainText -Force
$cred = New-Object –TypeName System.Management.Automation.PSCredential –ArgumentList $Username, $PWord


    # Connection to the Synergy Composer
    if ((test-path Variable:ConnectedSessions) -and ($ConnectedSessions.Count -gt 1)) {
        Write-Host -ForegroundColor red "Disconnect all existing HPOV / Composer sessions and before running script"
        exit 1
        }
    elseif ((test-path Variable:ConnectedSessions) -and ($ConnectedSessions.Count -eq 1) -and ($ConnectedSessions[0].Default) -and ($ConnectedSessions[0].Name -eq $IP)) {
        Write-Host -ForegroundColor gray "Reusing Existing Composer session"
        }
    else {
        #Make a clean connection
        Disconnect-HPOVMgmt -ErrorAction SilentlyContinue
        $Appplianceconnection = Connect-HPOVMgmt -appliance $IP -PSCredential $cred
        }

                
import-HPOVSSLCertificate


# Creation of the header

    $postParams = @{userName=$username;password=$password} | ConvertTo-Json 
    $headers = @{} 
    #$headers["Accept"] = "application/json" 
    $headers["X-API-Version"] = "300"

    # Capturing the OneView Session ID and adding it to the header
    
    $key = $ConnectedSessions[0].SessionID 

    $headers["auth"] = $key



# Capture iLO IP adresses managed by OneView
$iloIPs = Get-HPOVServer | where mpModel -eq iLO4 | % {$_.mpHostInfo.mpIpAddresses[1].address }

# Capture and display iLO IP adresses not supporting REST
$unsupportediLO = Get-HPOVServer | where mpModel -ne iLO4 | % {$_.mpHostInfo.mpIpAddresses[1].address }


$iloIPs
pause
clear


if ($unsupportediLO) {
write-host ""
Write-warning "The following iLO(s) do not support REST API (only iLO 4 are supported) :"
$unsupportediLO}

# Capture iLO User/password to create 
$Defaultuser = "demopaq"
$Defaultuserpassword = "password"

write-host ""
$user = Read-Host "Please enter the user you want to add to all iLos [$($Defaultuser)]"
$user = ($Defaultuser,$user)[[bool]$user]

write-host ""
$userpassword = Read-Host "Please enter the password for $user [$($Defaultuserpassword)]"
$userpassword = ($Defaultuserpassword,$userpassword)[[bool]$userpassword]

#Creation of the body content to pass to iLO
$bodyiloParams = '{"UserName": "'+ $user + '", "Password": "' + $userpassword + '", "Oem": {"Hp": {"Privileges": {"RemoteConsolePriv": true, "VirtualMediaPriv": true, "UserConfigPriv": true, "iLOConfigPriv": true, "VirtualPowerAndResetPriv": true}, "LoginName": "'+ $user + '"}}}'

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


Foreach($iloIP in $iloIPs)
{
# Capture of the SSO Session Key
 
$ilosessionkey = (Get-HPOVServer | where {$_.mpHostInfo.mpIpAddresses[1].address -eq $iloIP} | Get-HPOVIloSso -IloRestSession)."X-Auth-Token"

# Creation of the header using the SSO Session Key
$headerilo = @{} 
$headerilo["Accept"] = "application/json" 
$headerilo["X-API-Version"] = "3"
$headerilo["X-Auth-Token"] = $ilosessionkey 


#Creation of the user account using the hearder and body created previously
Try {

$error.clear()
$testuser = Invoke-WebRequest -Uri "https://$iloIP/rest/v1/AccountService/Accounts" -ContentType "application/json" -Headers $headerilo -Method GET -UseBasicParsing 

if ($Error[0] -eq $Null) 

   { 

        # User account created if not present
        if ($testuser.Content.Contains($user) -ne $True)
        {
        write-host ""
        write-host "User [$user] does not exist in iLO : $iloIP and will be created !"

        $rest = Invoke-WebRequest -Uri "https://$iloIP/rest/v1/AccountService/Accounts" -Body $bodyiloParams -ContentType "application/json" -Headers $headerilo -Method POST -UseBasicParsing
                
        write-host ""
        Write-Host "[$user] has been created in iLo: $iloIP"
        }
        
        # User account not created if already present
        else
        {
        write-host ""
        write-warning "User [$user] already exists in iLO : $iloIP !"
        
        }

     }
   }
   
 #Error is returned if iLO FW is not supported
 catch [System.Net.WebException] { 
 write-host ""
 Write-Warning "The firmware of iLO: $iloIP might be too old ! [$User] has not been added !" }
 
}


write-host ""
Read-Host -Prompt "Operation done ! Hit return to close" 
