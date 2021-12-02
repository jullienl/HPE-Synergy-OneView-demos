<# 
  Script to move all DL servers monitored by HPE OneView to OneView managed mode and place the server back to its rack location

    - Monitored mode does not require a license and allows only basic monitoring features                                               
    - Managed mode (requires a OneView Advanced license) unlocks all features available in OneView                                     
                                                                                                                                     
  This move requires servers to be removed from OneView management then added back in OneView in managed mode                         
  This script re-import the server in the same rack and same U position     

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


#$models = Get-OVServer | select model

do {
    clear
    write-host "Which model do you want to move to managed mode?"
    write-host "1 - ProLiant DL360 Gen10"
    write-host "2 - ProLiant DL380 Gen10"
    write-host ""
    write-host "X - Exit"
    write-host ""
    write-host -nonewline "Type your choice and press Enter: "
        
    $modeltomove = read-host
        
    write-host ""
        
    $ok = $modeltomove -match '^[12x]+$'
        
    if ( -not $ok) {
        write-host "Invalid selection"
        write-host ""
    }
   
} until ( $ok )



if ($modeltomove -eq 1) { $model = "ProLiant DL360 Gen10" }

if ($modeltomove -eq 2) { $model = "ProLiant DL380 Gen10" }

Write-host "`nSelected Model: " -NoNewline ; write-host $model -ForegroundColor Cyan


$serverstomove = Get-OVServer | where-object { $_.model -match $model -and $_.licensingIntent -eq "OneViewStandard" }
$nbservers = ($serverstomove | measure).count

if ($nbservers -eq $False) {
    Write-host "`nNo server found !"
}
else {
    Write-host "`nNumber of servers that will be moved: " -NoNewline ; write-host $nbservers -ForegroundColor Cyan
    Write-host "Server(s) found:"
    $serverstomove.name
}



foreach ($server in $serverstomove) {
    $serverIP = $server.mpHostInfo.mpIpAddresses | ? type -ne "LinkLocal" | % address
   
    $rack = Get-OVRack | Where-Object { $_.rackMounts.mountUri -eq $server.uri }
 
    $rackname = $rack.name
    $servertopUSlot = ($rack.rackMounts | Where-Object mountUri -eq $server.uri ).topUSlot

    write-host "`nRemoving from OneView management: " -NoNewline; Write-Host $server.name -f Cyan
    write-host "Please wait..."
    
    try {
        Remove-OVServer $server.name -confirm:$false -force | Wait-OVTaskComplete | out-null
    }
    catch {
        write-host "$($server.name)" -f Cyan -NoNewline; Write-Host " cannot be removed from OneView !" -ForegroundColor red
        break
    }

    try { 
        write-host "Adding back to OneView management in managed mode"
        write-host "Please wait..."
        Add-OVServer -hostname $serverIP -Credential $ilocredentials  -LicensingIntent $ilolicensetype | Wait-OVTaskComplete | out-Null 
    }
    catch {
        write-warning "iLO credentials are invalid ! Server cannot be added back to OneView !"
        write-host "$($server.name)" -f Cyan -NoNewline; Write-Host " cannot be moved from monitored to managed mode !" -ForegroundColor red
        break
    }

    if ($rack -eq $Null) {
        write-host ""
        write-warning "The server cannot be found in any rack ! Adding the server back to rack cannot be completed !"
        write-host "$($server.name)" -f Cyan -NoNewline; Write-Host " has been moved from monitored to managed mode !"
    } 
    else {
        # Add back to rack in the same location
        Try {
            
            Add-OVResourceToRack -Rack $rack -ULocation $servertopUSlot -InputObject $server | Out-Null
      
            write-host "$($server.name)" -f Cyan -NoNewline; Write-Host " has been added successfully in managed mode and placed back in rack " -NoNewline; write-host $rackname -f cy -NoNewline; write-host " in location U " -NoNewline; write-host $servertopUSlot -f Cyan
        }
        catch { 
            
            write-host "$($server.name)" -f Cyan -NoNewline; Write-Host " has been added successfully in managed mode but could not be placed back in rack " -NoNewline; write-host $rackname -f cy 
 
        }
    }

}

Disconnect-OVMgmt
