﻿   
# -------------------------------------------------------------------------------------------------------
# by lionel.jullien@hpe.com
# Feb 2019
#
# This script updates the firmware of servers managed by HPE OneView Composer using a FW package file (i.e. System ROM, Smart Array, etc.) 
# It requires an iLO local/LDAP account to connect to the iLO4 to make the upgrade
# 
# Note that the following script can be used to easily create an iLO account: 
# https://github.com/jullienl/HPE-Synergy-OneView-demos/blob/master/Powershell/iLO/Add%20user%20to%20iLO.ps1
#
# Important note: This script supports Proliant servers and Synergy computes, but for Synergy, it is important to note that upgrading
# the System ROM or iLO only could break the SPP/SSP support matrix, so before upgrading your servers, please consult the following customer advisory 
# with detailed compatibility information and installation instructions: https://support.hpe.com/hpsc/doc/public/display?docId=emr_na-a00114985en_us 
#
# Requirements:
#    - HPE OneView Powershell Library
#    - HPE OneView administrator account 
#    - HPE iLO PowerShell Library (HPEiLOCmdlets)
# --------------------------------------------------------------------------------------------------------

   
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

#Global variables


#iLO Credentials
$ilousername = "Administrator" 
$ilopassword = "password" 

#location of FW package
#Locate and download the server firmware package from google, search for:  [  server model "Online ROM Flash Component for Windows x64" ]
#Execute the downloaded firmware package CPxxxxxx.exe and extract the package to a local folder.
#Supported image extensions are the following: 
# - ROM: .full or .flash 
# - CPLD: .vme 
# - PowerPIC: .hex

#$serverFWlocation = "D:\Kits\_Scripts\_PowerShell\Compute\I37_2.64_10_17_2018.signed.flash"
$serverFWlocation = "D:\Kits\_Scripts\_PowerShell\Compute\I42_1.46_10_05_2018.signed.flash"
# $iloFWlocation = "D:\Kits\_Scripts\_PowerShell\Compute\ilo4_261.bin"


# OneView Credentials and IP
$OV_username = "Administrator"
$OV_IP = "composer.lj.lab"


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


#################################################################################


$servers = Get-OVServer | Where-Object { $_.mpModel -eq "iLO4" }
# $servers = Get-OVServer | ? model -match "480 Gen9" | select -first 1


ForEach ($compute in $servers) {
  
    $connection = Connect-HPEiLO -IP $iloIP -Username $ilousername -Password $ilopassword 
    
    # To update a System ROM
    $task = Update-HPEiLOFirmware -Connection $connection -Location $serverFWlocation -Force -Confirm:$False #-DisableCertificateAuthentication
       
    # To update ilo FW :     
    # $task = Update-HPEiLOFirmware -Connection $connection -Location $iloFWlocation -Force -Confirm:$False
  
    Write-host -f Cyan ($task.IP) -NoNewline
    Write-host " [" -NoNewline
    Write-host -f Cyan ($task.hostname) -NoNewline
    Write-host "]: Message returned by the update task: " -NoNewline
    Write-host -f Cyan ($task.StatusInfo.Message) 

}

Disconnect-OVMgmt










