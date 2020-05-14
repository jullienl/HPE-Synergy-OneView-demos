# -------------------------------------------------------------------------------------------------------
# by lionel.jullien@hpe.com
# April 2020
#
# Delete a User account in iLO4/iLO5 managed by OneView without using the iLO Administrator local account
#
# OneView administrator account is required. 
# iLO modification is done through OneView and iLO SSOsession key using REST POST method
# --------------------------------------------------------------------------------------------------------

#################################################################################
#        (C) Copyright 2018 Hewlett Packard Enterprise Development LP           #
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
$username = "Administrator" 
$password = "password" 
$IP = "192.168.1.110"


# iLO User to remove 
$iLOLoginName = "Ilouser"


Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# Connection to the Synergy Composer
$secpasswd = ConvertTo-SecureString $password -AsPlainText -Force
$credentials = New-Object System.Management.Automation.PSCredential ($username, $secpasswd)
Connect-HPOVMgmt -Hostname $IP -Credential $credentials | Out-Null

Clear-Host
               
import-HPOVSSLCertificate -ApplianceConnection ($connectedSessions | ? { $_.name -eq $IP })

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

    
# Capture iLO4 and iLO5 IP adresses managed by OneView
$servers = Get-HPOVServer
$iloIPs = $servers | where { $_.mpModel -eq "iLO4" -or "iLO5" } | % { $_.mpHostInfo.mpIpAddresses[1].address }

$nbilo4 = ($servers | where mpModel -eq "iLO4" ).count
$nbilo5 = ($servers | where mpModel -eq "iLO5" ).count

write-host "`n $($iloIPs.count) iLO found : $nbilo4 x iLO4 - $nbilo5 x iLO5 " -f Green
# write-host "`nAddress(es): $iloIPs"


Foreach ($iloIP in $iloIPs) {
    # Capture of the SSO Session Key
 
    $ilosessionkey = ($servers | where { $_.mpHostInfo.mpIpAddresses[1].address -eq $iloIP } | Get-HPOVIloSso -IloRestSession)."X-Auth-Token"
    $iloModel = $servers | where { $_.mpHostInfo.mpIpAddresses[1].address -eq $iloIP } | % mpModel

    # Creation of the header using the SSO Session Key 
    $headerilo = @{ } 
    $headerilo["X-Auth-Token"] = $ilosessionkey 

    Try {

        $error.clear()
        $users = Invoke-WebRequest -Uri "https://$iloIP/redfish/v1/AccountService/Accounts/" -Headers $headerilo -Method GET -UseBasicParsing 
        
        $accountids = (($users.Content | ConvertFrom-Json ).members)."@odata.id" -split '\r?\n'
        
        $foundFlag = $False

        # Finding the account ID of our iLO User
        foreach ($userid in $accountids) { 
            $user = Invoke-WebRequest -Uri "https://$iloIP$userid" -Headers $headerilo -Method GET -UseBasicParsing 

            $username = ($user.Content | ConvertFrom-Json ).Username
          
            if ($username -eq $iLOLoginName) { 
                $id = ($user.Content | ConvertFrom-Json ).id 
                $foundFlag = $True
            }
          
        }
        #
           
        If ($foundFlag -eq $False) {
            write-host "`nUser [$iLOLoginName] does not exist in iLO [$iloIP] and will not be deleted !" 
        }
        Else {

            if ($iloModel -eq "iLO4") {
                $rest = Invoke-WebRequest -Uri "https://$iloIP/redfish/v1/AccountService/Accounts/$id/" -Headers $headerilo -ContentType "application/json" -Method DELETE -UseBasicParsing
            }
            
            if ($iloModel -eq "iLO5") {
                $rest = Invoke-WebRequest -Uri "https://$iloIP/redfish/v1/AccountService/Accounts/$id" -Headers $headerilo -ContentType "application/json" -Method DELETE -UseBasicParsing
            }

            Write-Host "`n[$iLOLoginName] has been deleted successfuly in iLo [$iloIP]" -ForegroundColor Green
        }
        
     
    }


    catch [System.Net.WebException] {    
        
        write-host ""
        Write-Warning "[$iLOLoginName] cannot be deleted in iLO [$iloIP] !" 
    }   

 
}


write-host ""
Read-Host -Prompt "Operation done ! Hit return to close" 
Disconnect-HPOVMgmt