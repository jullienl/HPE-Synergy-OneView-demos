# -------------------------------------------------------------------------------------------------------
#   by lionel.jullien@hpe.com
#   June 2016
#
#   This playbook removes a network resource in a Synergy environment and unassigns that network to all compute modules that use a network set.
#
#   Requirement:
#    - A network Set must be defined and presented to the Server Profiles
#    - HPE OneView administrator account is required
#
#   This script only performs the deletion of an existing ethernet network since OneView takes care of the other steps automatically.
#
#  Note: When deleting a network, OneView automatically:
#   - removes the network from the uplink set defined in the selected Logical Interconnect Group
#   - removes the network from the network set
#   - deletes the network from the Logical interconnect
#   
#   This script can be used in conjunction with 'Add a network.ps1". See https://github.com/jullienl/HPE-Synergy-OneView-demos/blob/master/Powershell/Virtual Connect/Add a network.ps1
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


# Network to remove
$Network_name = "Production-1500"
$Network_vlan_id = "1500"


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

try {
    Connect-OVMgmt -Hostname $OV_IP -Credential $credentials -ErrorAction stop | Out-Null    
}
catch {
    write-warning "Cannot connect to '$OV_IP'! Exiting... "
    return
}

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force


#################################################################################
#                        Removing the Network resource                          #
#################################################################################

Write-host  "`nRemoving Network: " -NoNewline
Write-Host -f Cyan ($network_name) -NoNewline  
Write-host  " from HPE OneView" 
Write-host  "Please wait..."

try {
    $task = Get-OVNetwork -name $network_name -ErrorAction stop |  remove-OVNetwork -Confirm:$false | Wait-OVTaskComplete | Out-Null    
}
catch {
    write-warning "Cannot find an ethernet network resource named '$network_name' ! Exiting... "
    Disconnect-OVMgmt
    return
}


Write-host "`nThe network VLAN ID: " -NoNewline
Write-host -f Cyan $Network_vlan_id -NoNewline
Write-host " has been successfully removed and unpresented to all server profiles using the Network Set: " -NoNewline
Write-host -f Cyan $networkset 
Write-host ""


Disconnect-OVMgmt