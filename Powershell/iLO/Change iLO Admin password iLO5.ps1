# -------------------------------------------------------------------------------------------------------
# by lionel.jullien@hpe.com
# Jan 2019
#
# Change the default Administrator account password in all iLOs managed by OneView without using any iLO local account
#
# iLO5 modification is done through OneView and iLO SSO session key using REST POST method
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


# OneView information
$username = "Administrator"
$IP = "composer.lj.lab"
$secpasswd = read-host  "Please enter the OneView password" -AsSecureString
 
# Connection to the Synergy Composer
$credentials = New-Object System.Management.Automation.PSCredential ($username, $secpasswd)
Connect-OVMgmt -Hostname $IP -Credential $credentials | Out-Null


# Capture iLO5 IP adresses managed by OneView
$computes = Get-OVServer | where mpModel -eq iLO5


clear

if ($computes) {
    write-host ""
    Write-host $computes.Count "iLO5 can support REST API commands and will be configured with password complexity to enable:" 
    $computes | Format-Table -autosize | Out-Host

}
else {
    Write-Warning "No iLO5 server found ! Exiting... !"
    Disconnect-OVMgmt
    exit
}


# Capture iLO Administrator account password
$Defaultadmpassword = "password"
$secuadmpassword = Read-Host "Please enter the password you want to assign to all iLos for the user Administrator [$($Defaultadmpassword)]" -AsSecureString

$bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secuadmpassword)
$admpassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)

$admpassword = ($Defaultadmpassword, $admpassword)[[bool]$admpassword]

#Creation of the body content to pass to iLO
$bodyiloParams = @{Password = $admpassword } | ConvertTo-Json 

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

#####################################################################################################################

Foreach ($compute in $computes) {

    # Capture of the SSO Session Key
    $iloSession = $compute | Get-OVIloSso -IloRestSession
    $ilosessionkey = $iloSession."X-Auth-Token"

    $iloIP = $compute.mpHostInfo.mpIpAddresses | ? type -ne LinkLocal | % address
 
    # Creation of the header using the SSO Session Key 
    $headerilo = @{ } 
    $headerilo["X-Auth-Token"] = $ilosessionkey 


    
    # Modification of the Administrator password
    try {
        $response = Invoke-WebRequest -Uri "https://$iloIP/redfish/v1/accountservice/accounts/1/" -Body $bodyiloParams -ContentType "application/json" -Headers $headerilo -Method PATCH -UseBasicParsing -ErrorAction Stop
        $msg = ($response.Content | ConvertFrom-Json).error.'@Message.ExtendedInfo'.MessageId
        Write-Host "Administrator password has been changed in iLO $iloIP, message returned: [$($msg)]"

    }
    catch {
        $err = (New-Object System.IO.StreamReader( $_.Exception.Response.GetResponseStream() )).ReadToEnd() 
        $msg = ($err | ConvertFrom-Json ).error.'@Message.ExtendedInfo'.MessageId
        Write-Host -BackgroundColor:Black -ForegroundColor:Red "iLO $($iloIP): Error ! Password cannot be changed ! Message returned: [$($msg)]"
        continue
    }
 
}

write-host ""
Read-Host -Prompt "Operation done ! Hit return to close" 
Disconnect-OVMgmt