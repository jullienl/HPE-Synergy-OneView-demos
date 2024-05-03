# -------------------------------------------------------------------------------------------------------
#
# This PowerShell script detects all servers with an "Overall security status of the system is at risk" alert
# and sets the Security Dashboard parameters to ignore the state of a security feature as defined in the variable section  
#
#
# Note: The Security Dashboard is only available on Gen10/Gen10+ servers with iLO5
#
# Requirements:
#    - PowerShell 7
#    - HPE OneView Powershell Library
#    - HPE iLO PowerShell Cmdlets (install-module HPEiLOCmdlets)
#    - HPE OneView administrator account 
#  
#
# Output sample:
# -------------------------------------------------------------------------------------------------------
#
#   Searching for servers with a security status of the system at risk. Please wait...
# 
#   2 x computes have been found with the 'security status is at risk' alert:
# 
#   name           status Model             Serial Number
#   ----           ------ -----             -------------
#   Frame3, bay 11 OK     Synergy 480 Gen10 CZ221705V1
#   Frame3, bay 10 OK     Synergy 480 Gen10 CZ221705V7
#
#   [Frame3, bay 10 - iLO:192.168.0.10]: iLO security dashboard parameters changed successfully!
#   [Frame3, bay 11 - iLO:192.168.0.2]: iLO security dashboard parameters changed successfully!
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

# Capture iLO5 server hardware managed by HPE OneView with the "Overall security status of the system is at risk" alert 
$SHiLO5s = Search-OVIndex -Category server-hardware | ? { $_.Attributes.mpModel -eq "iLO5" } #| select -first 1

$SH = @()

foreach ($SHiLO5 in $SHiLO5s) {
    
    $iLOIP = $SHiLO5.multiAttributes.mpIpAddresses |  ? { $_ -NotMatch "fe80" }

    try {
        $ilosessionkey = ($SHiLO5 | Get-OVIloSso -IloRestSession -SkipCertificateCheck)."X-Auth-Token"
        $headers = @{} 
        $headers["OData-Version"] = "4.0"
        $headers["X-Auth-Token"] = $ilosessionkey 

        "[0] - iLO session key: [1] " -f $iLOIP, $ilosessionkey  | Write-Verbose

        $response = (Invoke-WebRequest -SkipCertificateCheck -Uri "https://$iLOIP/redfish/v1/Managers/1/SecurityService/SecurityDashboard" -Headers $headers -Method GET).content | Convertfrom-Json
        
        "[0] - OverallSecurityStatus: [1] " -f $iLOIP, $response.OverallSecurityStatus  | Write-Verbose

        if ($response.OverallSecurityStatus -eq "Risk") {
            $SH += $SHiLO5
        }

    }
    catch {
        Write-Warning "[$($SHiLO5.name)]: iLO cannot be contacted to check the security status ! Fix any communication problem you have in OneView with this iLO/server hardware !"
        read-host
        continue
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
$parametersToIgnore = @{}

if ($IgnoreRequireLoginforiLORBSU) {
    $parametersToIgnore["IgnoreRequireLoginforiLORBSU"] = $true
}   

if ($IgnoreSecureBoot) {
    $parametersToIgnore["IgnoreSecureBoot"] = $true
}

if ($IgnorePasswordComplexity) {
    $parametersToIgnore["IgnorePasswordComplexity"] = $true
}

if ($IgnoreDefaultSSLInUse) {
    $parametersToIgnore["IgnoreDefaultSSLInUse"] = $true


}if ($IgnoreSecurityOverrideSwitch) {
    $parametersToIgnore["IgnoreSecurityOverrideSwitch"] = $true
}

if ($IgnoreIPMIDCMIOverLAN) {
    $parametersToIgnore["IgnoreIPMIDCMIOverLAN"] = $true
}

if ($IgnoreMinimumPasswordLength) {
    $parametersToIgnore["IgnoreMinimumPasswordLength"] = $true


}if ($IgnoreAuthenticationFailureLogging) {
    $parametersToIgnore["IgnoreAuthenticationFailureLogging"] = $true
}

if ($IgnoreLastFirmwareScanResult) {
    $parametersToIgnore["IgnoreLastFirmwareScanResult"] = $true
}

if ($IgnoreRequireHostAuthentication) {
    $parametersToIgnore["IgnoreRequireHostAuthentication"] = $true
}


#####################################################################################################################

Foreach ($compute in $SH) {

    # Capture of the SSO Session Key
    $iloSession = $compute  | Get-OVIloSso -IloRestSession
    $ilosessionkey = $iloSession."X-Auth-Token"

    $iloIP = $compute.multiAttributes.mpIpAddresses |  ? { $_ -NotMatch "fe80" }

    # Connection to iLO using HPEiLOCmdlets
    $connection = Connect-HPEiLO -Address $iloIP -XAuthToken $ilosessionkey -DisableCertificateAuthentication

    # Modification of the security dashboard parameters using HPEiLOCmdlets
    $connection | Enable-HPEiLOSecurityDashboardSetting @parametersToIgnore
    
    # Modification of the security dashboard snmpv1 parameter using native API call
    # Enable-HPEiLOSecurityDashboardSetting does not support ignoresnmpv1, so we need to create a native iLO API request 
    if ($Ignoresnmpv1) {

        # Creation of the headers  
        $headers = @{} 
        $headers["OData-Version"] = "4.0"
        $headers["X-Auth-Token"] = $ilosessionkey 
   
        # Collecting the snmpv1 uri security parameter
        $body = @{}
        $body['$expand'] = "."

        # iLO5 Redfish URI
        $SecurityParams = Invoke-WebRequest -SkipCertificateCheck -Uri "https://$iloIP/redfish/v1/Managers/1/SecurityService/SecurityDashboard/SecurityParams" -Method Get -Headers $headers -Body $body
        $snmp_uri = ($SecurityParams.Content | ConvertFrom-Json).Members | ? name -eq "SNMPv1" | % '@odata.id'

        # Request content to ignore iLO SNMPv1 security dashboard warning
        $body = @{}
        $body["Ignore"] = $True
        $body = $body | ConvertTo-Json  
        # $body = ConvertTo-Json @{ Ignore =  $true } -Depth 99
                
        # Method
        $method = "patch"

        try {
            $response = Invoke-WebRequest -SkipCertificateCheck -Uri "https://$iloIP$snmp_uri" -Body $body -ContentType "application/json" -Headers $headers -Method $method -ErrorAction Stop
            Write-Host "[$($compute.name) - iLO:$iloIP]: iLO security dashboard parameters changed successfully!"
        }
        catch {
            $err = (New-Object System.IO.StreamReader( $_.Exception.Response.GetResponseStream() )).ReadToEnd() 
            $msg = ($err | ConvertFrom-Json ).error.'@Message.ExtendedInfo'.MessageId
            Write-Host -BackgroundColor:Black -ForegroundColor:Red "[$iloIP]: SNMPv1 security parameter modification error! Message returned: [$($msg)]"
            continue
        }

        # Clearing the "Overall security status of the system is at risk" alert
        $compute  | Get-OVAlert -AlertState Active | Where-Object { $_.description -Match "Overall security status of the system is at risk" } | Set-OVAlert -Cleared | out-null
       

    }
}

write-host ""
Read-Host -Prompt "Operation done ! Hit return to close" 
Disconnect-OVMgmt