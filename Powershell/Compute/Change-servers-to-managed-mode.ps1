<# 
  Script to move all DL servers monitored by HPE OneView to OneView managed mode 

    - Monitored mode does not require a license and allows only basic monitoring features                                               
    - Managed mode (requires a OneView Advanced license) unlocks all features available in OneView                                     
                                                                                                                                     
  This move requires servers to be removed from OneView management then added back in OneView in managed mode                         
  This script does not re-import the server in the same rack and same U position, see the other script in the repository if you need this option     

  Requirement:
   - HPE OneView Powershell Library
   - HPE OneView administrator account 
   - iLO Administrator account


  Author: lionel.jullien@hpe.com
  Date:   March 2020
    
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

#Set here the OneView license type: 
$ilolicensetype = "OneView"
# 'OneView' for OneView with iLO Advanced
# 'OneViewNoiLO'for OneView without iLO Advanced
#  Note: Rack mount servers without an iLO Advanced license cannot access the remote console.


# OneView Credentials and IP
$OV_username = "Administrator"
$OV_IP = "composer2.lj.lab"

# iLO administrator account
$ilousername = "Administrator"
$ilopassword = "password"

# MODULES TO INSTALL

# HPEOneView
# If (-not (get-module HPEOneView.630 -ListAvailable )) { Install-Module -Name HPEOneView.630 -scope Allusers -Force }


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


$servers = Get-OVServer | where-object { $_.model -match "DL" -and $_.licensingIntent -eq "OneViewStandard" }

foreach ($server in $servers) {
    $serverIP = $server.mpHostInfo.mpIpAddresses | ? type -ne "LinkLocal" | % address
    write-host "`nRemoving from OneView management: " -NoNewline; Write-Host $server.name -f Cyan
    write-host "Please wait..."
    Remove-OVServer $server.name -confirm:$false -force | Wait-OVTaskComplete
    Add-OVServer -hostname $serverIP -Credential $ilocredentials  -LicensingIntent $ilolicensetype 
    write-host "`n$($server.name)" -f Cyan -NoNewline; Write-Host " has been moved from monitored to managed mode !"
}

Disconnect-OVMgmt
