# -------------------------------------------------------------------------------------------------------
#
# This PowerShell script detects all servers with an "Overall security status of the system is at risk" alert
# and sets the Security Dashboard parameters to ignore the state of a security feature as defined in the variable section  
#
#
# Note: The Security Dashboard is only available on Gen10/Gen10+ servers with iLO5
#
# Requirements:
#    - HPE OneView Powershell Library
#    - HPE iLO PowerShell Cmdlets (install-module HPEiLOCmdlets)
#    - HPE OneView administrator account 
#  
#
# Output sample:
# -------------------------------------------------------------------------------------------------------
#
# 2 x computes have been found with the 'security status is at risk' alert:
# 
# Name          ServerName      Status  Power Serial Number Model        ROM                    iLO       Server Profile License   
# ----          ----------      ------  ----- ------------- -----        ---                    ---       -------------- -------            
# Frame1, bay 8 WIN-DOQJO87FKIK Warning On    MXQ828049J    SY 480 Gen10 I42 v2.58 (11/24/2021) iLO5 2.60 Win-1          NotApplicable                                  
# Frame1, bay 6 ESX-1.lj.lab    Warning On    MXQ828048J    SY 480 Gen10 I42 v2.58 (11/24/2021) iLO5 2.60 ESX-1          NotApplicable
#
# [Frame1, bay 6 - iLO:192.168.0.10]: iLO security dashboard parameters changed successfully!
# [Frame1, bay 8 - iLO:192.168.0.2]: iLO security dashboard parameters changed successfully!
#
# -------------------------------------------------------------------------------------------------------
#
#  Author: lionel.jullien@hpe.com
#  Date:   MAy 2022
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



#################################################################################


# Capture iLO5 server hardware managed by HPE OneView with the "Overall security status of the system is at risk" alert 
$SHiLO5 = Search-OVIndex -Category server-hardware | ? { $_.Attributes.mpModel -eq "iLO5" } #| select -first 1

$SHiLO5WithAlerts = ( $SHiLO5  | Get-OVAlert -AlertState Active | Where-Object { 
        $_.description -Match "Overall security status of the system is at risk"     
    }).associatedResource.resourceName

$SH = @()

foreach ($item in $SHiLO5WithAlerts) {
    $SH += get-ovserver -name $item

}


Clear-Host

if ($SH) {
    write-host ""
    if (! $SH.count) { 
        Write-host "1 x compute has been found with the 'security status is at risk' alert:" 
    }
    else {
        Write-host $SH.Count "x computes have been found with the 'security status is at risk' alert:" 
    } 
    $SH | Out-Host

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

    $iloIP = $compute.mpHostInfo.mpIpAddresses | ? type -ne LinkLocal | % address


    # Connection to iLO using HPEiLOCmdlets
    $connection = Connect-HPEiLO -Address $iloIP -XAuthToken $ilosessionkey -DisableCertificateAuthentication

    # Modification of the security dashboard parameters using HPEiLOCmdlets
    $connection | Enable-HPEiLOSecurityDashboardSetting @parametersToIgnore
    
    # Modification of the security dashboard snmpv1 parameter using native API call
    # Enable-HPEiLOSecurityDashboardSetting does not support ignoresnmpv1, so we need to create a native iLO API request 
    if ($snmpv1) {

        # Request content to ignore iLO SNMPv1 security dashboard warning
        $body = @{}
        $body["Ignore"] = $True
        $body = $body | ConvertTo-Json  
        # $body = ConvertTo-Json @{ Ignore =  $true } -Depth 99

        # Creation of the headers  
        $headers = @{} 
        $headers["OData-Version"] = "4.0"
        $headers["X-Auth-Token"] = $ilosessionkey 

        # iLO5 Redfish URI
        $uri = "/redfish/v1/Managers/1/SecurityService/SecurityDashboard/SecurityParams/9"

        # Method
        $method = "patch"

        try {
            $response = Invoke-WebRequest -Uri "https://$iloIP$uri" -Body $body -ContentType "application/json" -Headers $headers -Method $method -ErrorAction Stop
        }
        catch {
            $err = (New-Object System.IO.StreamReader( $_.Exception.Response.GetResponseStream() )).ReadToEnd() 
            $msg = ($err | ConvertFrom-Json ).error.'@Message.ExtendedInfo'.MessageId
            Write-Host -BackgroundColor:Black -ForegroundColor:Red "[$iloIP]: SNMPv1 security parameter modification error! Message returned: [$($msg)]"
            continue
        }

        # Clearing the "Overall security status of the system is at risk" alert
        $compute  | Get-OVAlert -AlertState Active | Where-Object { $_.description -Match "Overall security status of the system is at risk" } | Set-OVAlert -Cleared | out-null

        Write-Host "[$($compute.name) - iLO:$iloIP]: iLO security dashboard parameters changed successfully!"

    }
}

write-host ""
Read-Host -Prompt "Operation done ! Hit return to close" 
Disconnect-OVMgmt