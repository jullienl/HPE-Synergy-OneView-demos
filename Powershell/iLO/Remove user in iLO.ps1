# -------------------------------------------------------------------------------------------------------
# by lionel.jullien@hpe.com
# April 2020
#
# Delete a User account in iLO4/iLO5 managed by HPE OneView without using the iLO Administrator local account
#
# iLO modification is done through OneView and iLO SSO session key using REST POST method
#
# Requirements:
#    - HPE OneView Powershell Library
#    - HPE OneView administrator account 
#
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


# iLO User to remove 
$iLOLoginName = "iLOadmin"


# OneView information
$username = "Administrator"
$IP = "oneview.lj.lab"


# MODULES TO INSTALL

# HPEOneView
# If (-not (get-module HPEOneView.630 -ListAvailable )) { Install-Module -Name HPEOneView.630 -scope Allusers -Force }


#################################################################################


$secpasswd = read-host  "Please enter the OneView password" -AsSecureString
 
# Connection to the Synergy Composer
$credentials = New-Object System.Management.Automation.PSCredential ($username, $secpasswd)
Connect-OVMgmt -Hostname $IP -Credential $credentials | Out-Null


Clear-Host


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


# Capture iLO4 and iLO5 IP adresses managed by OneView
$servers = Get-OVServer


$nbilo4 = ($computes | where mpModel -eq "iLO4" ).count
$nbilo5 = ($computes | where mpModel -eq "iLO5" ).count


clear

if ($computes) {
    write-host ""
    write-host "`n $($computes.count) iLO found : $nbilo4 x iLO4 - $nbilo5 x iLO5 " -f Green
    $computes | Format-Table -autosize | Out-Host

}
else {
    Write-Warning "No server found ! Exiting... !"
    Disconnect-OVMgmt
    exit
}


Foreach ($compute in $computes) {

    # Capture of the SSO Session Key
    $iloSession = $compute | Get-OVIloSso -IloRestSession
    $ilosessionkey = $iloSession."X-Auth-Token"
 
    $iloIP = $compute.mpHostInfo.mpIpAddresses | ? type -ne LinkLocal | % address
    $iloModel = $compute.MPModel

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

            Write-Host "`n[$iLOLoginName] has been deleted successfuly in iLO [$iloIP]" -ForegroundColor Green
        }
        
     
    }


    catch [System.Net.WebException] {    
        
        write-host ""
        Write-Warning "[$iLOLoginName] cannot be deleted in iLO [$iloIP] !" 
        continue
    }   

 
}


write-host ""
Read-Host -Prompt "Operation done ! Hit return to close" 
Disconnect-OVMgmt