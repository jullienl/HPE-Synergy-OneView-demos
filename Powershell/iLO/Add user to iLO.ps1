# -------------------------------------------------------------------------------------------------------
# by lionel.jullien@hpe.com
# April 2020
#
# Create a User account in iLO4/iLO5 managed by HPE OneView without using the iLO Administrator local account
#
# iLO modification is done through OneView and iLO SSO session key using REST POST method
#
# The iLO password must be provided at runtime.  
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

# iLO User to create 
$newiLOLoginName = "iLOadmin"


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


#########################################################################################################

$newiLOsecpasswd = read-host  "Please enter the password for [$($newiLOLoginName)]" -AsSecureString
$bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($newiLOsecpasswd)
$newiLOPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr) 


# Capture iLO4 and iLO5 IP adresses managed by OneView
$computes = Get-OVServer


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
    
    if ($iloModel -eq "iLO4") {
        # creating iLO4 user object
        # add permissions
        $priv = @{ }
        $priv.Add('RemoteConsolePriv', $True)
        $priv.Add('iLOConfigPriv', $True)
        $priv.Add('VirtualMediaPriv', $True)
        $priv.Add('UserConfigPriv', $True)
        $priv.Add('VirtualPowerAndResetPriv', $True)
        # add login name
        $hp = @{ }
        $hp.Add('LoginName', $newiLOLoginName)
        $hp.Add('Privileges', $priv)
        $oem = @{ }
        $oem.Add('Hp', $hp)
    }
    if ($iloModel -eq "iLO5") { 
        # creating iLO5 user object
        # add permissions
        $priv = @{ }
        $priv.Add('RemoteConsolePriv', $True)
        $priv.Add('iLOConfigPriv', $True)
        $priv.Add('VirtualMediaPriv', $True)
        $priv.Add('UserConfigPriv', $True)
        $priv.Add('VirtualPowerAndResetPriv', $True)
        $priv.Add('HostBIOSConfigPriv', $True)
        $priv.Add('HostNICConfigPriv', $True)
        $priv.Add('HostStorageConfigPriv', $True)
        # add login name
        $hp = @{ }
        $hp.Add('LoginName', $newiLOLoginName)
        $hp.Add('Privileges', $priv)
        $oem = @{ } 
        $oem.Add('Hpe', $hp) 
    }

    # add username and password for access
    $user = @{ }
    $user.Add('UserName', $newiLOLoginName)
    $user.Add('Password', $newiLOPassword)
    $user.Add('Oem', $oem)


    $bodyiloParams = $user | ConvertTo-Json -Depth 99
    # Creation of the header using the SSO Session Key 

    $headerilo = @{ } 
    $headerilo["X-Auth-Token"] = $ilosessionkey 


    Try {

        $error.clear()
        $users = Invoke-WebRequest -Uri "https://$iloIP/redfish/v1/AccountService/Accounts/" -Headers $headerilo -Method GET -UseBasicParsing 

        # Finding all present users 

        $usersarray = $users.Content | ConvertFrom-Json 

        # If user to create is found in user list, flag is raised
        $foundFlag = $False

        foreach ($accOdataId in $usersarray.Members.'@odata.id') {

            $id = $accOdataId.Substring(36)
            $acc = Invoke-WebRequest -Uri "https://$iloIP/redfish/v1/AccountService/Accounts/$id" -Headers $headerilo -Method GET -UseBasicParsing 
            $accarray = $acc.Content | ConvertFrom-Json 

            # $accarray.Username | Out-Host
           
            if ($accarray.Username -eq $newiLOLoginName) {
                $foundFlag = $true
                # Write-Host "$newiLOLoginName found!" -f Green
            }
        }

        # User account created if not present

        if ($foundFlag -ne $True) {
            
            if ($iloModel -eq "iLO5") {
                $rest = Invoke-WebRequest -Uri "https://$iloIP/redfish/v1/AccountService/Accounts/" -Body $bodyiloParams  -Headers $headerilo -ContentType "application/json" -Method POST -UseBasicParsing
            }

            if ($iloModel -eq "iLO4") {
                $rest = Invoke-WebRequest -Uri "https://$iloIP/redfish/v1/AccountService/Accounts/" -Body $bodyiloParams  -Headers $headerilo -ContentType "application/json" -Method POST -UseBasicParsing
            }
            
            write-host ""
            Write-Host "[$newiLOLoginName] has been created successfuly in iLO: $iloIP" -ForegroundColor Green
        }
        
        # User account not created if already present
        
        else {

            write-host ""
            write-warning "User [$newiLOLoginName] already exists in iLO : $iloIP !"

        }
    }


    catch [System.Net.WebException] {    
        
        write-host ""
        Write-Warning "Error ! [$newiLOLoginName] cannot be created in iLO [$iloIP] !" 
        continue
    }   

 
}


write-host ""
Read-Host -Prompt "Operation done ! Hit return to close" 
Disconnect-OVMgmt