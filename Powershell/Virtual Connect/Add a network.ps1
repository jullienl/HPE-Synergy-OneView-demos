 
# -------------------------------------------------------------------------------------------------------
#   by lionel.jullien@hpe.com
#   June 2016
#
#   This PowerShell script adds a network resource to a Synergy environment and presents this network to all Compute Modules using a Network Set.    
# 
#   Requirement:
#    - A network Set must be defined and presented to the Server Profiles
#    - HPE OneView administrator account is required
#
#   This playbook performs the following steps:
#    - Creates a new ethernet network using the variables defined in the vars section
#    - Adds the new Ethernet network to the uplink set defined in the selected Logical Interconnect Group
#    - Updates the logical interconnect from the new logical interconnect group definition
#    - Adds the new ethernet network to the defined network set
#
#  
#   Global variables (i.e. OneView information, network name and vlan ID you want to create, LIG, UplinkSet, Network Set) 
#   must be modified with your own environment information.
#
#   This script can be used in conjunction with 'Remove a network.ps1". 
#   See https://github.com/jullienl/HPE-Synergy-OneView-demos/blob/master/Powershell/Virtual Connect/Remove a network.ps1
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


#################################################################################
#                                Global Variables                               #
#################################################################################

# Network to add
$Network_name = "Production-1500"
$Network_vlan_id = "1500"
$maximum_Bandwidth = 25000 # Maximum bandwidth: 25Gb/s
$preferred_Bandwidth = 2500 # Preferred bandwidth: 2.5Gb/s


$LIG = "LIG-MLAG"
$Uplinkset = "MLAG-Nexus"
$NetworkSet = "Production_Network_set"


# OneView Credentials and IP
$OV_username = "Administrator"
$OV_IP = "composer2.lj.lab"


# MODULES TO INSTALL

# HPEOneView
# If (-not (get-module HPEOneView.630 -ListAvailable )) { Install-Module -Name HPEOneView.630 -scope Allusers -Force }


#################################################################################

$secpasswd = read-host  "Please enter the OneView password" -AsSecureString
 
# Connection to the OneView / Synergy Composer
$credentials = New-Object System.Management.Automation.PSCredential ($OV_username, $secpasswd)
Connect-OVMgmt -Hostname $OV_IP -Credential $credentials | Out-Null



Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force


#################################################################################
#                     Creating a new Network resource                          #
#################################################################################
try {
    $network_present = get-ovnetwork -Name $Network_name -ErrorAction Stop 
}
catch { }


if ( $network_present) {
    write-warning "Network '$network_name' already exist ! Exiting... "
    return
}
else {
    New-OVNetwork -Name $Network_name -type Ethernet -vlanID $Network_vlan_id -VLANType "Tagged" -purpose General -typicalBandwidth $preferred_Bandwidth -maximumBandwidth $maximum_Bandwidth 

}
   

#################################################################################
#                       Adding Network to LIG Uplink Set                        #
#################################################################################


Write-host "`nAdding Network: " -NoNewline
Write-host -f Cyan ($Network_name) -NoNewline
Write-host " to Logical Interconnect Group: " -NoNewline
Write-host -f Cyan $LIG

try {
    $MyLIG = Get-OVLogicalInterconnectGroup -Name $LIG -ErrorAction Stop
}
catch {
    write-warning "Cannot find a Logical Interconnect group resource named '$LIG' ! Exiting... "
    return
}

$MyLI = ((Get-OVLogicalInterconnect) | where-object logicalInterconnectGroupUri -eq $MyLIG.uri) 

if (-not $MyLI) {
    
    write-warning "Cannot find a Logical Interconnect resource named '$LIG' ! Exiting... "
    return
}

$uplink_set = $MyLIG.uplinkSets | where-Object { $_.name -eq $uplinkset } 

if (-not $uplink_set) {
    
    write-warning "Cannot find an uplink set resource named '$uplinkset' ! Exiting... " 
    return
}

$uplink_Set.networkUris += (Get-OVNetwork -Name ($Network_name)).uri

try {
    Set-OVResource $MyLIG -ErrorAction Stop | Wait-OVTaskComplete | Out-Null
}
catch {
    write-ouput $_ #.Exception
    return
}

#################################################################################
#                            Updating LI from LIG                               #
#################################################################################

# This step takes time, average is 5mn for 3 frames... 

$vlanuri = (Get-OVNetwork -Name ($network_name)).uri
          
# Making sure the LI is not in updating state before we run a LI Update
$Interconnectstate = (((Get-OVInterconnect) | where-object productname -match "Virtual Connect") | where-object logicalInterconnectUri -EQ $MyLI.uri).state  
if ($Interconnectstate -notcontains "Configured") {
    Write-host "`nWaiting for the running Interconnect configuration task to finish, please wait...`n" 
}
        
do { 
    $Interconnectstate = (((Get-OVInterconnect) | where-object productname -match "Virtual Connect") | where-object logicalInterconnectUri -EQ $MyLI.uri).state 
}
until (
    $Interconnectstate -notcontains "Adding" -and $Interconnectstate -notcontains "Imported" -and $Interconnectstate -notcontains "Configuring"
)

Write-host "`nUpdating all Logical Interconnects from the Logical Interconnect Group: " -NoNewline
Write-host -f Cyan $LIG
Write-host "Please wait..." 

try {
    Get-OVLogicalInterconnect -Name $MyLI.name | Update-OVLogicalInterconnect -confirm:$false -ErrorAction Stop | Wait-OVTaskComplete | Out-Null
}
catch {
    write-ouput $_ #.Exception
    return
}


#################################################################################
#                       Adding Network to Network Set                           #
#################################################################################



Write-host "`nAdding Network: " -NoNewline
Write-host -f Cyan ($Network_name) -NoNewline
Write-host " to NetworkSet: " -NoNewline
Write-host -f Cyan $networkset


try {
    $netset = Get-OVNetworkSet -Name $NetworkSet -Erroraction stop    
}
catch {
    write-warning "Cannot find a network set resource named '$NetworkSet' ! Exiting... "
    return
}

$netset.networkUris += (Get-OVNetwork -Name $network_name).uri


try {
    Set-OVNetworkSet $netset -ErrorAction Stop | Wait-OVTaskComplete | Out-Null
}
catch {
    write-warning "Cannot add the network '$network_name' to the network set '$NetworkSet' ! Exiting... "
    return
}


Write-host "`nThe network VLAN ID: " -NoNewline
Write-host -f Cyan $Network_vlan_id -NoNewline
Write-host " has been successfully added and presented to all server profiles that are using the Network Set: " -NoNewline
Write-host -f Cyan $networkset 
Write-host ""

Disconnect-OVMgmt