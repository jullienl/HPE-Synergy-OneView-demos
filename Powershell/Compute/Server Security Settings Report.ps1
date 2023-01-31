<#-------------------------------------------------------------------------------------------------------

This PowerShell script generates a report on security settings for all servers managed by HPE Oneview.
A csv file is also generated in $path. 


Note: Only Gen10/Gen10+ servers with iLO5 is supported.

Requirements:
   - HPE OneView Powershell Library
   - HPE OneView administrator account 
 

Output sample:
-------------------------------------------------------------------------------------------------------

    Name                              : Frame3, bay 2
    SerialNumber                      : CZ212406GM
    Model                             : Synergy 480 Gen10
    iLOIP                             : 192.168.3.188
    SecurityOverrideSwitchState       : Off
    IPMIDCMIOverLANState              : Disabled
    MinimumPasswordLengthState        : Ok
    RequireLoginforiLORBSUState       : Disabled
    AuthenticationFailureLoggingState : Enabled
    SecureBootState                   : Disabled
    PasswordComplexityState           : Disabled
    LastFirmwareScanResultState       : Ok
    RequireHostAuthenticationState    : Disabled
    SNMPv1State                       : Disabled
    DefaultSSLCertificateInUseState   : False
    SecurityServiceState              : Production
    TLS10                             : Enabled
    TLS11                             : Enabled
    TLS12                             : Enabled
    CurrentCipher                     : ECDHE-RSA-AES256-GCM-SHA384
    LoginSecurityBanner               : False
    SecureBoot                        : False
    iLOSelfSignedCert                 : False
    CertificateLoginEnabled           : False

    Name                              : Frame3, bay 3
    SerialNumber                      : CZ212406GJ
    Model                             : Synergy 480 Gen10
    iLOIP                             : 192.168.3.191
    SecurityOverrideSwitchState       : Off
    IPMIDCMIOverLANState              : Disabled
    MinimumPasswordLengthState        : Ok
    RequireLoginforiLORBSUState       : Disabled
    AuthenticationFailureLoggingState : Enabled
    SecureBootState                   : Disabled
    PasswordComplexityState           : Disabled
    LastFirmwareScanResultState       : Ok
    RequireHostAuthenticationState    : Disabled
    SNMPv1State                       : Disabled
    DefaultSSLCertificateInUseState   : False
    SecurityServiceState              : Production
    TLS10                             : Enabled
    TLS11                             : Enabled
    TLS12                             : Enabled
    CurrentCipher                     : ECDHE-RSA-AES256-GCM-SHA384
    LoginSecurityBanner               : False
    SecureBoot                        : False
    iLOSelfSignedCert                 : False
    CertificateLoginEnabled           : False



CSV file generated:


Name	SerialNumber	Model	iLOIP	SecurityOverrideSwitchState	IPMIDCMIOverLANState	MinimumPasswordLengthState	RequireLoginforiLORBSUState	...
Frame3, bay 2	CZ212406GM	Synergy 480 Gen10	192.168.3.188	Off	Disabled	Ok	Disabled	Enabled	Disabled	Disabled	Ok	Disabled	...
Frame3, bay 3	CZ212406GJ	Synergy 480 Gen10	192.168.3.191	Off	Disabled	Ok	Disabled	Enabled	Disabled	Disabled	Ok	Disabled	...
Frame3, bay 4	CZ212406GK	Synergy 480 Gen10	192.168.3.193	Off	Disabled	Ok	Disabled	Enabled	Disabled	Disabled	Ok	Disabled	...
Frame3, bay 5	CZ212406GG	Synergy 480 Gen10	192.168.3.194	Off	Disabled	Ok	Disabled	Enabled	Disabled	Disabled	Ok	Disabled	...


#>

# -------------------------------------------------------------------------------------------------------
#
#  Author: lionel.jullien@hpe.com
#  Date:   Jan 2023
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

# OneView Credentials and IP
$OV_username = "Administrator"
$OV_IP = "composer.lj.lab"

# Location of the folder to generate the CSV file
# $path = '.\Powershell\Compute'
$path = $PSScriptRoot


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

Clear-Host

# Write-host "Searching for servers with a security status of the system at risk. Please wait... "

# Capture iLO5 server hardware managed by HPE OneView with the "Overall security status of the system is at risk" alert 
$SHiLO5s = Search-OVIndex -Category server-hardware | ? { $_.Attributes.mpModel -eq "iLO5" } | select -first 4


$SecurityReports = @()

foreach ($SHiLO5 in $SHiLO5s) {

    write-host "Please wait..."
    
    $SecurityReport = @{}

    $iLOIP = $SHiLO5.multiAttributes.mpIpAddresses |  ? { $_ -NotMatch "fe80" }

    try {
        $ilosessionkey = ($SHiLO5 | Get-OVIloSso -IloRestSession)."X-Auth-Token"
        $headers = @{} 
        $headers["OData-Version"] = "4.0"
        $headers["X-Auth-Token"] = $ilosessionkey 

        # Security dashboard
        $url = "https://{0}/redfish/v1/Managers/1/SecurityService/SecurityDashboard/SecurityParams{1}" -f $iLOIP, '?$expand=.'
        $securitydashboard = Invoke-RestMethod -Uri $url -Headers $headers -Method GET 
        
        $SecurityOverrideSwitchState = $securitydashboard.Members | ? name -eq "Security Override Switch" | % State

        $IPMIDCMIOverLANState = $securitydashboard.Members | ? name -eq "IPMI/DCMI Over LAN" | % State

        $MinimumPasswordLengthState = $securitydashboard.Members | ? name -eq "Minimum Password Length" | % State
      
        $RequireLoginforiLORBSUState = $securitydashboard.Members | ? name -eq "Require Login for iLO RBSU" | % State
        
        $AuthenticationFailureLoggingState = $securitydashboard.Members | ? name -eq "Authentication Failure Logging" | % State
        
        $SecureBootState = $securitydashboard.Members | ? name -eq "Secure Boot" | % State

        $PasswordComplexityState = $securitydashboard.Members | ? name -eq "Password Complexity" | % State

        $LastFirmwareScanResultState = $securitydashboard.Members | ? name -eq "Last Firmware Scan Result" | % State

        $RequireHostAuthenticationState = $securitydashboard.Members | ? name -eq "Require Host Authentication" | % State

        $SNMPv1State = $securitydashboard.Members | ? name -eq "SNMPv1" | % State

        $DefaultSSLCertificateInUseState = $securitydashboard.Members | ? name -eq "Default SSL Certificate In Use" | % State

        # Security service
        $url = $iLOIP + "/redfish/v1/Managers/1/SecurityService"
        $SecurityService = (Invoke-RestMethod -Uri $url -Headers $headers -Method GET )

        $SecurityServiceState = $SecurityService.SecurityState
      
        # TLS Versions
        $TLS10 = $SecurityService.TLSVersion.TLS1_0

        $TLS11 = $SecurityService.TLSVersion.TLS1_1

        $TLS12 = $SecurityService.TLSVersion.TLS1_2
        
        # Ciphers
        $CurrentCipher = $SecurityService.CurrentCipher
        
        #Login banner
        $LoginSecurityBanner = $SecurityService.LoginSecurityBanner.IsEnabled 

        # Secure boot
        $url = $iLOIP + "/redfish/v1/Systems/1/secureboot"
        $SecureBoot = (Invoke-RestMethod -Uri $url -Headers $headers -Method GET ).SecureBootEnable

        # iLO Self Signed certificate  .X509CertificateInformation.Issuer -match  "Default Issuer (Do not trust)"
        $url = $iLOIP + "/redfish/v1/Managers/1/SecurityService/HttpsCert/"
        $iLOSelfSignedCert = ((Invoke-RestMethod -Uri $url -Headers $headers -Method GET ).X509CertificateInformation.Issuer) -match "Default Issuer (Do not trust)"

        # certificate authentication 
        $url = $iLOIP + "/redfish/v1/Managers/1/SecurityService/CertificateAuthentication"
        $CertificateLoginEnabled = (Invoke-RestMethod -Uri $url -Headers $headers -Method GET ).CertificateLoginEnabled

        $SecurityReport = [PSCustomObject]@{
            Name                              = $SHiLO5.name
            SerialNumber                      = $SHiLO5.attributes.serial_number
            Model                             = $SHiLO5.attributes.model
            iLOIP                             = $iLOIP
            SecurityOverrideSwitchState       = $SecurityOverrideSwitchState
            IPMIDCMIOverLANState              = $IPMIDCMIOverLANState
            MinimumPasswordLengthState        = $MinimumPasswordLengthState
            RequireLoginforiLORBSUState       = $RequireLoginforiLORBSUState
            AuthenticationFailureLoggingState = $AuthenticationFailureLoggingState
            SecureBootState                   = $SecureBootState
            PasswordComplexityState           = $PasswordComplexityState
            LastFirmwareScanResultState       = $LastFirmwareScanResultState
            RequireHostAuthenticationState    = $RequireHostAuthenticationState
            SNMPv1State                       = $SNMPv1State
            DefaultSSLCertificateInUseState   = $DefaultSSLCertificateInUseState
            SecurityServiceState              = $SecurityServiceState
            TLS10                             = $TLS10
            TLS11                             = $TLS11
            TLS12                             = $TLS12
            CurrentCipher                     = $CurrentCipher
            LoginSecurityBanner               = $LoginSecurityBanner
            SecureBoot                        = $SecureBoot
            iLOSelfSignedCert                 = $iLOSelfSignedCert
            CertificateLoginEnabled           = $CertificateLoginEnabled

        }

        $SecurityReports += $SecurityReport



    }
    catch {
        Write-Warning "[$($SHiLO5.name)]: iLO cannot be contacted to check the security status ! Fix any communication problem you have in OneView with this iLO/server hardware !"
        continue
    }  
}


# $SH_DB.GetEnumerator() | Select-Object -Property @{N = 'Compute Names'; E = { $_.Key } }, @{N = 'Serial Numbers'; E = { $_.Value } } |   Export-Csv -NoTypeInformation "$path\Computes_Report.csv"



# Export to csv file

$SecurityReports | Sort-Object { $_.name } | Export-Csv -NoTypeInformation "$path\Compute_Security_Settings_Report.csv"

return $SecurityReports | Sort-Object { $_.name } 

#####################################################################################################################

write-host ""
Read-Host -Prompt "Operation done ! CSV file generated in $path\Compute_Security_Settings_Report.csv" 
Disconnect-OVMgmt