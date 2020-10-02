<# 

This PowerShell script adds all servers managed by OneView in iLO Amplifier Pack.
Support both Synergy Compute modules and DL servers in either Managed or Monitored mode.

Requirements: 
- HPEOneView library 5.30 or later
- OneView and iLO Amplifier Pack administrator account.
- iLO Username and password that will be created for iLO Amplifier Pack authentication must be personalized.


  Author: lionel.jullien@hpe.com
  Date:   Oct 2020
    
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


# HPEONEVIEW Library
If (-not (get-module HPEOneView.530 -ListAvailable )) { Install-Module -Name HPEOneView.530 -scope Allusers -Force }
import-module HPEOneView.530


# OneView Credentials and IP
$username = "Administrator" 
$password = "P@ssw0rd" 
$IP = "192.168.1.110"

# iLO Username and password to create in iLO for iLO Amplifier Pack authentication
$newiLOLoginName = "iLO_Amplifier"
$newiLOPassword = "iLO_Amplifier_password"

# iLO Amplifier Credentials and IP
$iLOAmplifierusername = "Administrator" 
$iLOAmplifierpassword = "P@ssw0rd" 
$iLOAmplifierIP = "192.168.0.5"


Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# Connection to the Synergy Composer
$secpasswd = ConvertTo-SecureString $password -AsPlainText -Force
$credentials = New-Object System.Management.Automation.PSCredential ($username, $secpasswd)
Connect-OVMgmt -Hostname $IP -Credential $credentials | Out-Null

Clear-Host

import-OVSSLCertificate -ApplianceConnection ($connectedSessions | ? { $_.name -eq $IP })

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

# Get all Compute Modules managed by OneView
$computes = Get-OVServer #| select -First 4


#Creating object with iLO information
$iLOList = New-Object System.Collections.ArrayList
     
if ($computes) {

    # CREATING ILO USER IN ILO TO LATER ADD COMPUTE IN ILO AMPLIFIER PACK
    foreach ($compute in $computes) {
        
        $iLOip = $compute  | select -ExpandProperty mpHostInfo | Select -ExpandProperty mpIpAddresses | Where { $_.type -ne "LinkLocal" } | Select -ExpandProperty address
        
        # Adding iLO IP to iLOList object
        [void]$iLOList.Add($iLOip)
        
        $iloModel = $compute | % mpModel
        $token = ($compute | Get-OVIloSso -IloRestSession).'X-Auth-Token'
    
       
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
        $headerilo["X-Auth-Token"] = $token 

        # Creating iLO account for iLO Amplifier
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
            
                Write-Host "`niLO user [$newiLOLoginName] has been created successfuly in iLO: $iloIP" -ForegroundColor Green
                
            }
        
            # User account not created if already present
        
            else {

                write-host ""
                write-warning "User [$newiLOLoginName] already exists in iLO : $iloIP !"

            }
        }


        catch [System.Net.WebException] {    
        
            write-host ""
            Write-Warning "Error ! [$newiLOLoginName] has not been added in iLO [$iloIP] !" 
        }   
    }


    # ADDING COMPUTE IN ILO AMPLIFIER PACK
     
    $headeriloAmplifier = @{
        "UserName" = $iLOAmplifierusername;
        "Password" = $iLOAmplifierpassword
    } | ConvertTo-Json
        
    #iLO Amplifier Authentication

    try {
           
        $error.clear()
        $iLOAmplifiersession = Invoke-WebRequest -Uri "https://$iLOAmplifierIP/redfish/v1/SessionService/Sessions/" -body $headeriloAmplifier -ContentType "application/json"  -Method POST  
        $iloAmplifier_token = $iLOAmplifiersession.headers["X-Auth-Token"]

    }
    catch {
        write-warning "Cannot connect to iLO Amplifier !"
        break
    }

    $header = @{
        "Content-Type" = "application/json";
        "X-Auth-Token" = $iloAmplifier_token 
    } 

    foreach ($item in $iLOList) {
        try {
               
            $body = @{
                    
                "ManagerAddress" = $item ;
                "UserName"       = $newiLOLoginName ;
                "Password"       = $newiLOPassword 
            } | ConvertTo-Json

            $response = Invoke-WebRequest -Uri "https://$iLOAmplifierIP/redfish/v1/AggregatorService/ManagedSystems/" -body $body -Headers $header -ContentType "application/json" -Method POST  
            Write-Host "`niLO [$item] has been added successfuly in iLO Amplifier" -ForegroundColor Green

        }
        catch [System.Net.WebException] {
            write-warning "Cannot add iLO $($item) to iLO Amplifier !"

        }
                
    }
            
}
 

else {
    Write-Warning "Cannot find any Compute Modules managed by OneView!"

}

Disconnect-OVMgmt