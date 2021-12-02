<# 

Script to disable Bios secure boot on HPE Gen9 and Gen10 server

Requires the HPE Bios Cmdlets for Windows PowerShell (HPEBIOSCmdlets library), see https://www.hpe.com/us/en/product-catalog/detail/pip.5440657.html 

Servers must be restarted to disable Secure Boot. 

This script only turns on servers that are powered-off to disable Secure Boot but it does not restart servers that are running. 

Requirements:
   - HPE OneView Powershell Library
   - HPE OneView administrator account 
   - HPE BIOS Cmdlets PowerShell Library (HPEBIOSCmdlets)
   - iLO Administrator account


  Author: lionel.jullien@hpe.com
  Date:   March 2018
    
#################################################################################
#                         Server FW Inventory in rows.ps1                       #
#                                                                               #
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


# OneView Credentials and IP
$OV_username = "Administrator"
$OV_IP = "composer2.lj.lab"

# iLO administrator account
$ilousername = "Administrator"
$ilopassword = "password"

# MODULES TO INSTALL

# HPEOneView
# If (-not (get-module HPEOneView.630 -ListAvailable )) { Install-Module -Name HPEOneView.630 -scope Allusers -Force }

# HPEBIOSCmdlets
# If (-not (get-module HPEBIOSCmdlets -ListAvailable )) { Install-Module -Name HPEBIOSCmdlets -scope Allusers -Force }

#################################################################################

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

$secilopasswd = ConvertTo-SecureString $ilopassword -AsPlainText -Force
$ilocredentials = New-Object System.Management.Automation.PSCredential ($ilousername, $secilopasswd)


################################################################################# 



#Capturing iLO IP adresses managed by HPE OneView
$iloIPs = Get-OVServer | % { $_.mpHostInfo.mpIpAddresses[1].address }


#Checking Secure Boot on all iLOst
Foreach ($iloIP in $iLOIPs) {
    Try { 
        $connection = Connect-HPEBIOS -IP $iloIP -Username $ilousername -Password $ilopassword -DisableCertificateAuthentication -ErrorAction Stop
    
        $sbs = get-HPEBIOSSecureBootState -Connection $connection  -ErrorAction Stop
        
        if ($sbs.SecureBootState -eq 'Enabled') {
            Try {
                Set-HPEBIOSSecureBootState -Connection $connection -SecureBootState Disabled -ErrorAction Stop
            }
            Catch {
                echo ($error[0] | FL)
                return
            }

            write-host "`nSecure Boot on iLO: $iloIP has been disabled" 

            $server = Get-OVServer | where { $_.mpHostInfo.mpIpAddresses[1].address -eq $iloIP } 
                       
            
            if ($server.powerState -eq "Off") { 
                write-host "`nStarting server: $($server.name) to enable the change..."

                Start-OVServer -Server $server | Wait-OVTaskComplete
            }
            else {
                write-host "`n $($server.name) is running. You need to restart the server to enable the change..." -ForegroundColor Yellow
  
            }

        }
        else {
            write-host "Secure Boot on iLO: $iloIP is already disabled" 
        }
   
    }
    Catch {
        write-host "Error disabling Secure boot on iLO: $iloIP"
        echo ($error[0] | fl)
    }

}

Disconnect-OVMgmt