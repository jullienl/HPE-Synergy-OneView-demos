<#
This PowerShell script generates a CSV report with the iLO IP addresses and corresponding MAC addresses of each server managed by HPE OneView.

To get the MAC address of the iLO, the script extracts the IPv6 of the iLO from the server's hardware resource and uses a public API to convert an IPv6 address into a MAC address.


"iLO_IP","MAC_Address"
"192.168.0.xx","xx:xx:xx:67:2C:xx"
"192.168.0.xx","xx:xx:xx:67:2C:xx"
"192.168.0.xx","xx:xx:xx:67:1C:xx"
-------------------------------------------------------------------------------------------------------

Requirements:
   - HPE OneView Powershell Library
   - HPE OneView administrator account 
   - Access to internet


Author: lionel.jullien@hpe.com
Date:   March 2022

--------------------------------------------------------------------------------------------------------

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

# Name of the CSV report (without extension) that the script will generate in the local directory 
$file = "iLO_MAC_Address_Report"


# OneView Credentials and IP
$OV_username = "Administrator"
$OV_IP = "composer.lj.lab"


# MODULES TO INSTALL

# HPEOneView
# If (-not (get-module HPEOneView.630 -ListAvailable )) { Install-Module -Name HPEOneView.630 -scope Allusers -Force }


Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

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
clear-host

if (! $connectedsessions) {
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
}

# Capture iLO4 and iLO5 IP adresses managed by OneView
$servers = Get-OVServer # | select -first 3
# Gen10
#   $server = Get-OVServer | ? name -eq "Frame1, bay 5"
# Gen9
#  $server = Get-OVServer | ? name -eq "Frame1, bay 2"

"iLO_IP,MAC_Address" | Out-File ("$file" + ".txt") 

write-host "Generating report, please wait..."

foreach ($server in $servers) {
    
    $iloIP = $server.mpHostInfo.mpIpAddresses | ? { $_.type -ne "LinkLocal" } | % address
    $iloIPv6 = ([ipaddress]($server.mpHostInfo.mpIpAddresses | ? { $_.type -eq "LinkLocal" } | % address)).IPAddressToString

    $MAC = Invoke-WebRequest -Uri "https://ben.akrin.com/ipv6_link_local_to_mac_address_converter/?mode=api&ipv6=$iloIPv6" | % Content

    # $name = (Get-OVServer -name $server.name ).name
    
    "$iloIP,$MAC" | Out-File ("$file" + ".txt") -Append

}

import-csv ("$file" + ".txt")   | export-csv ("$file" + ".csv") -NoTypeInformation
remove-item ("$file" + ".txt") -Confirm:$false


write-host "MAC Address report has been generated in $pwd\$file.csv" -ForegroundColor Yellow


#Read-Host -Prompt "Operation done ! Hit return to close" 



