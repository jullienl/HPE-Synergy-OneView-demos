
<# 

This PowerShell script creates a user account in the iLO of all servers managed by HPE OneView without using the local iLO Administrator account.

The iLO modification is performed through OneView using an iLO SSO session key and the REST POST method.

The script prompts for the password of the iLO account to be created and displays the list of iLOs found in the OneView appliance.

Requirements:
    - PowerShell 7 or later
    - HPE OneView PowerShell Library
    - HPE OneView administrator account


Author: lionel.jullien@hpe.com
Date:   April 2020

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
#>

# iLO User to create 
$newiLOLoginName = "demopaq"
# $newiLOLoginName = "iLOadmin"


# OneView Credentials and IP
$OneView_username = "Administrator"
$OneView_IP = "composer.lj.lab"


# MODULES TO INSTALL


# Check if the HPE OneView PowerShell module is installed and install it if not
If (-not (get-module HPEOneView.* -ListAvailable )) {
    
    try {
        
        $APIversion = Invoke-RestMethod -Uri "https://$OneView_IP/rest/version" -Method Get | select -ExpandProperty currentVersion
        
        switch ($APIversion) {
            "3800" { [decimal]$OneViewVersion = "6.6" }
            "4000" { [decimal]$OneViewVersion = "7.0" }
            "4200" { [decimal]$OneViewVersion = "7.1" }
            "4400" { [decimal]$OneViewVersion = "7.2" }
            "4600" { [decimal]$OneViewVersion = "8.0" }
            "4800" { [decimal]$OneViewVersion = "8.1" }
            "5000" { [decimal]$OneViewVersion = "8.2" }
            "5200" { [decimal]$OneViewVersion = "8.3" }
            "5400" { [decimal]$OneViewVersion = "8.4" }
            "5600" { [decimal]$OneViewVersion = "8.5" }
            "5800" { [decimal]$OneViewVersion = "8.6" }
            "6000" { [decimal]$OneViewVersion = "8.7" }
            "6200" { [decimal]$OneViewVersion = "8.8" }
            "6400" { [decimal]$OneViewVersion = "8.9" }
            "6600" { [decimal]$OneViewVersion = "9.0" }
            "6800" { [decimal]$OneViewVersion = "9.1" }
            "7000" { [decimal]$OneViewVersion = "9.2" }
            Default { $OneViewVersion = "Unknown" }
        }
        
        Write-Verbose "Appliance running HPE OneView $OneViewVersion"
        
        If ($OneViewVersion -ne "Unknown" -and -not (get-module HPEOneView* -ListAvailable )) { 
            
            Find-Module HPEOneView* | Where-Object version -le $OneViewVersion | Sort-Object version | Select-Object -last 1 | Install-Module -scope CurrentUser -Force -SkipPublisherCheck
            
        }
    }
    catch {
        
        Write-Error "Error: Unable to contact HPE OneView to retrieve the API version. The OneView PowerShell module cannot be installed."
        Return
    }
}


# Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force


#################################################################################

Clear-Host

if (! $ConnectedSessions) {
    
    $secpasswd = read-host  "Please enter the OneView password" -AsSecureString
 
    # Connection to the Synergy Composer
    $credentials = New-Object System.Management.Automation.PSCredential ($OneView_username, $secpasswd)
    
    try {
        Connect-OVMgmt -Hostname $OneView_IP -Credential $credentials | Out-Null
    }
    catch {
        Write-Warning "Cannot connect to '$OneView_IP'! Exiting... "
        return
    }
}

#################################################################################


# Capture server hardware managed by HPE OneView
$computes = Get-OVServer

$nbilo4 = ($computes | where mpModel -eq "iLO4" ).count
$nbilo5 = ($computes | where mpModel -eq "iLO5" ).count

Clear-Host

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

# Creation of the headers  
$headers = @{} 
$headers["OData-Version"] = "4.0"

$error_found = $false


#########################################################################################################

$newiLOsecpasswd = read-host  "Please enter the password for [$($newiLOLoginName)]" -AsSecureString
$bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($newiLOsecpasswd)
$newiLOPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr) 


Foreach ($compute in $computes) {

    $iloIP = $compute.mpHostInfo.mpIpAddresses | ? type -ne LinkLocal | % address
    $servername = $Compute.name
    $iloModel = $compute.MPModel

    $RootUri = "https://{0}" -f $iloIP

    # Capture of the SSO Session Key
    try {

        $ilosessionkey = ($Compute | Get-OVIloSso -IloRestSession -SkipCertificateCheck).'X-Auth-Token'
        $headers["X-Auth-Token"] = $ilosessionkey
    }
    catch {
        "[{0} - iLO {1}]: Error: Server cannot be contacted at this time. Resolve any issues found in OneView and run this script again. Skipping server!" -f $servername, $iloIP | Write-Host -ForegroundColor Red
        $error_found = $true
        continue 
    }

    
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
    elseif ($iloModel -eq "iLO5" -or $iloModel -eq "iLO6") { 
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

    $Location = "/redfish/v1/AccountService/Accounts/"

    Try {

        # Finding all present users 
        $users = Invoke-RestMethod -Uri ($RootUri + $Location) -Headers $headers -ErrorAction Stop -SkipCertificateCheck 

        # If user to create is found in user list, flag is raised
        $foundFlag = $False
        
        foreach ($accOdataId in $users.Members.'@odata.id') {

            $Location = $accOdataId
            $acc = Invoke-RestMethod -Uri ($RootUri + $Location) -Headers $headers -ErrorAction Stop -SkipCertificateCheck

            if ($acc.Username -eq $newiLOLoginName) {
                $foundFlag = $true
                # Write-Host "$newiLOLoginName found!" -f Green
            }
        }

        # User account created if not present

        if ($foundFlag -ne $True) {

            $Location = "/redfish/v1/AccountService/Accounts/"
            $method = "post"

            $response = Invoke-RestMethod -Uri ($RootUri + $Location) -Body $bodyiloParams -ContentType "application/json" -Headers $headers -Method $method -ErrorAction Stop -SkipCertificateCheck
            
            if ($response.error.'@Message.ExtendedInfo'.MessageId) {

                "[{0} - iLO {1}]: New account '{2}' has been created successfuly. API response: {3}" -f $servername, $iloIP, $newiLOLoginName, $response.error.'@Message.ExtendedInfo'.MessageId | Write-Host 
            }
        }
        
        # User account not created if already present
        
        else {

            "[{0} - iLO {1}]: Account '{2}' already exists" -f $servername, $iloIP, $newiLOLoginName | Write-Host 

        }
    }


    catch [System.Net.WebException] {    
        
        "[{0} - iLO {1}]: Error! Failed to create account '{2}'" -f $servername, $iloIP, $newiLOLoginName | Write-Host -ForegroundColor Red
        $error_found = $true
        continue
    }   

 
}


if ($error_found) {
    Write-Host -ForegroundColor Red "One or more errors occurred during the configuration. Please review the output above."
}
else {
    Write-Host "All iLOs have been configured successfully."
}

Disconnect-OVMgmt
Read-Host -Prompt "Operation completed ! Hit return to close" 