   
# -------------------------------------------------------------------------------------------------------
# by lionel.jullien@hpe.com
# Sept 2016
#
# Upgrade/downgrade the firmware of all iLOs managed by HPE OneView using a local iLO account with administrative privileges.
# To select specific servers, you can filter the iLOs by modifying the $iLOserverIPs query. Several examples of filters are shown below.
# 
# Note that you can use 'Add User to iLO.ps1' located in this repository to create this user via HPE OneView. 
# https://github.com/jullienl/HPE-Synergy-OneView-demos/blob/master/Powershell/iLO/Add%20user%20to%20iLO.ps1
#
# Important note: This script supports Proliant servers and Synergy computes, but for Synergy, it is important to note that upgrading
# the iLO only could break the SPP/SSP support matrix, so before upgrading your iLOs, please consult the following customer advisory 
# with detailed compatibility information and installation instructions:
# https://support.hpe.com/hpsc/doc/public/display?docId=emr_na-a00114985en_us
# 
#
# Requirements:
# - OneView administrator account 
# - iLO Administrator account 
# - HPE iLO PowerShell Cmdlets (install-module HPEiLOCmdlets)
# - HPEOneView library 
# 
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


# Location of the Synergy hotfix for iLO 5 firmware version
$Location = "D:\\Kits\\_HPE\\iLO\\iLO5\\ilo5_244.bin" 
# Location of the Synergy hotfix for iLO 4 firmware version
# $Location = "D:\\Kits\\_HPE\\iLO\\iLO4\\ilo4_278.bin" 

$ilocreds = Get-Credential -UserName Administrator -Message "Please enter the iLO password" 

# OneView information
$username = "Administrator"
$IP = "composer.lj.lab"
$secpasswd = read-host  "Please enter the OneView password" -AsSecureString
 
# Connection to the Synergy Composer
$credentials = New-Object System.Management.Automation.PSCredential ($username, $secpasswd)
Connect-OVMgmt -Hostname $IP -Credential $credentials | Out-Null


# Get the IP addresses of the iLOs we want to upgrade
$iLOserverIPs = Get-OVServer | ? mpModel -eq "ilo5" | % { $_.mpHostInfo.mpIpaddresses[1].address } # | select -first 1 

<#
  - To retrieve the iLO IP of a single server, you can use:
    $iLOserverIPs = Get-OVServer -name "Encl1, bay 1" | % { $_.mpHostInfo.mpIpaddresses[1].address }  

  - To retrieve the iLO IPs of the servers that have an iLO version 2.33 or lower, you can use:  
    $iLOserverIPs = (Get-OVServer | ? mpModel -eq "ilo5" | ? {$_.mpFirmwareVersion.SubString(0,4) -le 2.33 }) | % { $_.mpHostInfo.mpIpaddresses[1].address }  

  - To retrieve the iLO IPs of the servers impacted by the new SHT change issue: https://support.hpe.com/hpesc/public/docDisplay?docId=emr_na-a00113315en_us 
    $impactedservers = (Get-OVAlert -severity Critical -AlertState Active | Where-Object { 
            $_.description -Match "serial number of the server hardware" 
            -and $_.description -match "originally used to create this server profile" 
            -and $_.description -match "expected serverhardware type"
        }).associatedResource.resourcename
    $iLOserverIPs = foreach ($item in $impactedservers) { Get-OVServer -Name $item | % { $_.mpHostInfo.mpIpaddresses[1].address } }
#>

foreach ($item in $iLOserverIPs) {

  $connection = connect-hpeilo -Credential $ilocreds -Address $item 
  $task = Update-HPEiLOFirmware -Location $Location -Connection $connection -Confirm:$False -Force
  Write-Host "iLO $item : $($task.statusinfo.message)"
  Disconnect-HPEiLO -Connection $connection
    
}
   
Disconnect-OVMgmt 





