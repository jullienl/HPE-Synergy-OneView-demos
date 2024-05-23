# -------------------------------------------------------------------------------------------------------
#
# This PowerShell script detects all servers with an "Overall security status of the system is at risk" alert
# and sets the Security Dashboard parameters to ignore the state of a security feature as defined in the variable section  
#
#
# Note: The iLO security dashboard is only available on server models Gen10 and above.
#
# Requirements:
#    - PowerShell 7
#    - HPE OneView Powershell Library
#    - HPE OneView administrator account 
  
#
# Output sample:
# -------------------------------------------------------------------------------------------------------
#
#   Searching for servers with a security status of the system at risk. Please wait...
#   [Frame3, bay 6 - iLO 192.168.3.195]: Testing iLO connection...
#   [Frame3, bay 6 - iLO 192.168.3.195]: Overall security status is 'Risk'
#   [Frame3, bay 11 - iLO 192.168.3.181]: Testing iLO connection...
#   [Frame3, bay 11 - iLO 192.168.3.181]: Overall security status is 'Ignored'
#   ...
# 
#   2 x computes have been found with the 'security status is at risk' alert:
# 
#   name           status Model             Serial Number
#   ----           ------ -----             -------------
#   Frame3, bay 11 OK     Synergy 480 Gen10 CZ221705V1
#   Frame3, bay 10 OK     Synergy 480 Gen10 CZ221705V7
#
#   [Frame3, bay 6 - iLO 192.168.3.195]: 'Require Login for iLO RBSU' iLO security parameter changed successfully to 'Ignored'!
#   [Frame3, bay 6 - iLO 192.168.3.195]: 'Secure Boot' iLO security parameter changed successfully to 'Ignored'!            
#   [Frame3, bay 6 - iLO 192.168.3.195]: 'Password Complexity' iLO security parameter changed successfully to 'Ignored'!    
#   [Frame3, bay 6 - iLO 192.168.3.195]: 'Default SSL Certificate In Use' iLO security parameter changed successfully to 'Ignored'!
#   [Frame3, bay 6 - iLO 192.168.3.195]: 'SNMPv1' iLO security parameter changed successfully to 'Ignored'!                 
#   [Frame3, bay 7 - iLO 192.168.3.198]: 'Require Login for iLO RBSU' iLO security parameter changed successfully to 'Ignored'!
#   [Frame3, bay 7 - iLO 192.168.3.198]: 'Secure Boot' iLO security parameter changed successfully to 'Ignored'!            
#   [Frame3, bay 7 - iLO 192.168.3.198]: 'Password Complexity' iLO security parameter changed successfully to 'Ignored'!    
#   [Frame3, bay 7 - iLO 192.168.3.198]: 'Default SSL Certificate In Use' iLO security parameter changed successfully to 'Ignored'!
#   [Frame3, bay 7 - iLO 192.168.3.198]: 'SNMPv1' iLO security parameter changed successfully to 'Ignored'!  
#
# -------------------------------------------------------------------------------------------------------
#
#  Author: lionel.jullien@hpe.com
#  Date:   May 2022
#
#
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


# VARIABLES

# Security dashboard parameter to be ignored - All parameters defined with $true will be set as ignored in the Security Dashboard 

# - Security parameters that raise a risk alert by default:
$IgnoreRequireLoginforiLORBSU = $true
$IgnoreSecureBoot = $true
$IgnorePasswordComplexity = $True
$Ignoresnmpv1 = $true
$IgnoreDefaultSSLInUse = $True

# - Security parameters that do not raise a risk alert by default:
$IgnoreSecurityOverrideSwitch = $false
$IgnoreIPMIDCMIOverLAN = $false
$IgnoreMinimumPasswordLength = $false
$IgnoreAuthenticationFailureLogging = $false
$IgnoreLastFirmwareScanResult = $false
$IgnoreRequireHostAuthentication = $false



# OneView Credentials and IP
$OV_username = "Administrator"
$OV_IP = "composer.lj.lab"


# MODULES TO INSTALL

# HPEOneView
# If (-not (get-module HPEOneView.630 -ListAvailable )) { Install-Module -Name HPEOneView.630 -scope Allusers -Force }


#################################################################################

if (! $ConnectedSessions) {
    
    $secpasswd = read-host  "Please enter the OneView password" -AsSecureString
 
    # Connection to the OneView / Synergy Composer
    $credentials = New-Object System.Management.Automation.PSCredential ($OV_username, $secpasswd)

    try {
        Connect-OVMgmt -Hostname $OV_IP -Credential $credentials -ErrorAction stop | Out-Null    
    }
    catch {
        Write-Warning "Cannot connect to '$OV_IP'! Exiting... "
        return
    }

    # Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
}



#################################################################################

Clear-Host

Write-host "Searching for servers with a security status of the system at risk. Please wait... "

# Capture iLO5 and 6 server hardware managed by HPE OneView with the "Overall security status of the system is at risk" alert 
$SHiLOs = Search-OVIndex -Category server-hardware -Count 1024 | ? { $_.Attributes.mpModel -eq "iLO5" -or $_.Attributes.mpModel -eq "iLO6" } #| select -first 1

$SH = @()

foreach ($SHiLO in $SHiLOs) {
    
    $iLOIP = $SHiLO.multiAttributes.mpIpAddresses |  ? { $_ -NotMatch "fe80" }

    if (! $iLOIP) {

        "[{0}]: This server's iLO has no IPv4 address assigned, skipping server..." -f $SHiLO.name
        continue
    }
    else {
        "[{0} - iLO {1}]: Testing iLO connection..." -f $SHiLO.name, $iLOIP
        
        $connectionStatus = Test-Connection -Ping $iloIP -quiet -Count 1

        if ($false -eq $connectionStatus) {
            "[{0} - iLO {1}]: iLO cannot be contacted, skipping server..." -f $SHiLO.name, $iLOIP

        }
        else {

            try {
                $ilosessionkey = ($SHiLO | Get-OVIloSso -IloRestSession -SkipCertificateCheck)."X-Auth-Token"
                $headers = @{} 
                $headers["OData-Version"] = "4.0"
                $headers["X-Auth-Token"] = $ilosessionkey 

                "iLO IP: {0} - iLO session key: {1} " -f $iLOIP, $ilosessionkey  | Write-Verbose

                $response = (Invoke-WebRequest -SkipCertificateCheck -Uri "https://$iLOIP/redfish/v1/Managers/1/SecurityService/SecurityDashboard" -Headers $headers -Method GET).content | Convertfrom-Json
        
                "[{0} - iLO {1}]: Overall security status is '{2}'" -f $SHiLO.name, $iLOIP, $response.OverallSecurityStatus  

                if ($response.OverallSecurityStatus -eq "Risk") {
                    $SH += $SHiLO
                }

            }
            catch {
                Write-Warning "[$($SHiLO.name)]: iLO cannot be contacted to check the security status ! Fix any communication problem you have in OneView with this iLO/server hardware !"
                read-host
                continue
            }  
        }
    }
}

if ($SH) {
    write-host ""
    if (! $SH.count) { 
        Write-host "1 x compute has been found with the 'security status is at risk' alert:" 
    }
    else {
        Write-host $SH.Count "x computes have been found with the 'security status is at risk' alert:" 
    } 
    $SH | Select-Object name, status, @{N = "Model"; E = { $_.attributes.model } }, @{N = "Serial Number"; E = { $_.attributes.serial_number } }  | Out-Host

}
else {
    Write-Warning "No compute found with the 'security status is at risk' alert ! Exiting... !"
    Disconnect-OVMgmt
    exit
}


# Creation of an object with the Security dashboard parameter
$parametersToIgnore = @()

if ($IgnoreRequireLoginforiLORBSU) {
    $parametersToIgnore += "Require Login for iLO RBSU"
}   

if ($IgnoreSecureBoot) {
    $parametersToIgnore += "Secure Boot"
}

if ($IgnorePasswordComplexity) {
    $parametersToIgnore += "Password Complexity"
}

if ($IgnoreDefaultSSLInUse) {
    $parametersToIgnore += "Default SSL Certificate In Use"
}

if ($IgnoreSecurityOverrideSwitch) {
    $parametersToIgnore += "Security Override Switch"
}

if ($IgnoreIPMIDCMIOverLAN) {
    $parametersToIgnore += "IPMI/DCMI Over LAN"
}

if ($IgnoreMinimumPasswordLength) {
    $parametersToIgnore += "Minimum Password Length"
}

if ($IgnoreAuthenticationFailureLogging) {
    $parametersToIgnore += "Authentication Failure Logging"
}

if ($IgnoreLastFirmwareScanResult) {
    $parametersToIgnore += "Last Firmware Scan Result"
}

if ($IgnoreRequireHostAuthentication) {
    $parametersToIgnore += "Require Host Authentication"
}

if ($Ignoresnmpv1) {
    $parametersToIgnore += "SNMPv1"
}


#####################################################################################################################

Foreach ($compute in $SH) {

    $iloIP = $compute.multiAttributes.mpIpAddresses |  ? { $_ -NotMatch "fe80" }

    # Capture of the SSO Session Key
    $iloSession = $compute  | Get-OVIloSso -IloRestSession -SkipCertificateCheck
    $ilosessionkey = $iloSession."X-Auth-Token"

    "iLO IP: {0} - iLO session key: {1} " -f $iLOIP, $ilosessionkey  | Write-Verbose

    # HPEiLOCmdlets do not support PowerShell 7 
    # Connection to iLO using HPEiLOCmdlets
    # $connection = Connect-HPEiLO -Address $iloIP -XAuthToken $ilosessionkey -DisableCertificateAuthentication 
    # Modification of the security dashboard parameters using HPEiLOCmdlets
    # $connection | Enable-HPEiLOSecurityDashboardSetting @parametersToIgnore

    # Creation of the headers  
    $headers = @{} 
    $headers["OData-Version"] = "4.0"
    $headers["X-Auth-Token"] = $ilosessionkey 

    # Collecting the uri security parameters
    $body = @{}
    $body['$expand'] = "."
    
    $SecurityParams = Invoke-RestMethod -SkipCertificateCheck -Uri "https://$iloIP/redfish/v1/Managers/1/SecurityService/SecurityDashboard/SecurityParams" -Method Get -Headers $headers -Body $body

    foreach ($parameter in $parametersToIgnore) {
        
        $uri = $SecurityParams.Members | ? name -eq $parameter | % '@odata.id'

        # Request content to ignore iLO security dashboard warning
        $body = @{}
        $body["Ignore"] = $True
        $body = $body | ConvertTo-Json  

        # Method
        $method = "patch"
      
        try {
            $response = Invoke-WebRequest -SkipCertificateCheck -Uri "https://$iloIP$uri" -Body $body -ContentType "application/json" -Headers $headers -Method $method -ErrorAction Stop
            "[{0} - iLO {1}]: '$parameter' iLO security parameter changed successfully to 'Ignored'!" -f $compute.name, $iLOIP
        }
        catch {
            $err = (New-Object System.IO.StreamReader( $_.Exception.Response.GetResponseStream() )).ReadToEnd() 
            $msg = ($err | ConvertFrom-Json ).error.'@Message.ExtendedInfo'.MessageId
            Write-Host -BackgroundColor:Black -ForegroundColor:Red "[$($compute.name) - iLO $iloIP]: '$parameter' iLO security parameter modification error! Message returned: [$($msg)]"
            continue
        }
    }
               

    # Clearing the "Overall security status of the system is at risk" alert
    $compute  | Get-OVAlert -AlertState Active | Where-Object { $_.description -Match "Overall security status of the system is at risk" } | Set-OVAlert -Cleared | out-null
           
}

write-host ""
Read-Host -Prompt "Operation done ! Hit return to close" 
Disconnect-OVMgmt