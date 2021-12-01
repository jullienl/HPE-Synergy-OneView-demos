
# -------------------------------------------------------------------------------------------------------
#   by lionel.jullien@hpe.com
#   December 2019
#
#   This PowerShell script adds all network resource defined in a CSV file to a Synergy environment and presents this network to all Compute Modules using the specified Network Set.    
#   The script also adds all networks to the specified uplinkset defined in OneView.   
#
#   The network name and VLAN ID are taken from the NetName/VLAN_ID columns of the CSV file. Notice that a file example is available in this GitHub folder.
#
#   CSV File content: 
#
#   NetName VLAN_ID
#   ------- -------
#   prod-1  1000
#   prod-2  1001
#   prod-3  1002
#   prod-4  1003
#   prod-5  1004
#   prod-6  1005
#
#  
#   With this script, you can demonstrate that with a single line of code, you can present easily and quickly a network VLAN to all Compute Modules present in the Synergy frames managed by HPE OneView. 
#          
#   OneView administrator account is required. Global variables (i.e. OneView details, LIG, UplinkSet, Network Set names, etc.) must be modified with your own environment information.
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

# CSV File  
$csvfile = "networks_creation.csv"
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

try {
    Connect-OVMgmt -Hostname $OV_IP -Credential $credentials -ErrorAction stop | Out-Null    
}
catch {
    write-warning "Cannot connect to '$OV_IP'! Exiting... "
    return
}

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force


#################################################################################

# Import of the CSV file containing VLAN name and VLAN ID
$data = (Import-Csv $csvfile)


# Testing resources defined
try {
    $networkset = Get-OVNetworkSet -Name $networksetname -Erroraction stop    
}
catch {
    write-warning "Cannot find a network set resource named '$networksetname' ! Exiting... "
    disconnect-ovMgmt 
    return
}


try {
    $MyLIG = Get-OVLogicalInterconnectGroup -Name $LIG -ErrorAction Stop
}
catch {
    write-warning "Cannot find a Logical Interconnect group resource named '$LIG' ! Exiting... "
    disconnect-ovMgmt 
    return
}


$MyLI = ((Get-OVLogicalInterconnect) | where-object logicalInterconnectGroupUri -eq $MyLIG.uri) 

if (-not $MyLI) {
    
    write-warning "Cannot find a Logical Interconnect resource used by '$LIG' ! Exiting... "
    disconnect-ovMgmt 
    return
}

$uplink_set = $MyLIG.uplinkSets | where-Object { $_.name -eq $uplinkset } 

if (-not $uplink_set) {
    
    write-warning "Cannot find an uplink set resource named '$uplinkset' ! Exiting... "
    disconnect-ovMgmt 
    return
}



#################################################################################
#              Creating Networks and adding them to the LIG uplink Set          #
#################################################################################

#$LIGname = (Get-OVLogicalInterconnectGroup | where { $_.uri -eq (Get-OVLogicalInterconnect).logicalInterconnectGroupUri }).name
# $LIGURI = (Get-OVLogicalInterconnect).logicalInterconnectGroupUri

#$NewNetwork = Get-OVNetwork -Name "Produc*"  #Get the Network resource

# $LIG = Get-OVLogicalInterconnectGroup | Where-Object { $_.uri -eq $LIGURI }


# if (!(($LIG | Measure-Object).Count -eq 1 )) { Write-Host "Failed to filter down to one LIG" -ForegroundColor Red | Break }


ForEach ($VLAN In $data) {

    try {
        $network_present = get-ovnetwork -Name $VLAN.NetName -ErrorAction Stop 
    }
    catch {
        $network_present = $false
    }
    
    if ( $network_present) {
        write-warning "Network '$($VLAN.NetName)' already exist ! Jumping to next one... "
        continue
    }
    else {
        
        New-OVNetwork -Name $VLAN.NetName -Type Ethernet -VLANId $VLAN.VLAN_ID -VLANType "Tagged" -purpose General -typicalBandwidth $preferred_Bandwidth -maximumBandwidth $maximum_Bandwidth |  Out-Null
        Write-host "Creating Network: " -NoNewline
        Write-host -f Cyan ($VLAN.netName) -NoNewline

        # Add new Network to the networkUris Array
        
        $uplink_Set.networkUris += (Get-OVNetwork -Name ($VLAN.NetName)).uri

        Write-host " Adding Network: " -NoNewline
        Write-host -f Cyan ($VLAN.netName) -NoNewline
        Write-host " to Uplink Set: " -NoNewline
        Write-host -f Cyan $uplinkset
    }

}

try {
    Set-OVResource $MyLIG -ErrorAction Stop | Wait-OVTaskComplete | Out-Null
}
catch {
    write-ouput $_ #.Exception
    disconnect-ovMgmt 
    return
}


#################################################################################
#                            Updating LI from LIG                               #
#################################################################################

$LI = ((Get-OVLogicalInterconnect) | where-object logicalInterconnectGroupUri -eq $MyLIG.uri)

# Making sure the LI is not in updating state before we run a LI Update

do {
    $Interconnectstate = (((Get-OVInterconnect) | where-object productname -match "Virtual Connect") | where-object logicalInterconnectUri -EQ $LI.uri).state 

    if ($Interconnectstate -notcontains "Configured") {

        Write-host "`nWaiting for the running Interconnect configuration task to finish, please wait...`n" 
    }

}

until ($Interconnectstate -notcontains "Adding" -and $Interconnectstate -notcontains "Imported" -and $Interconnectstate -notcontains "Configuring")



Write-host "`nUpdating all Logical Interconnects from the Logical Interconnect Group: " -NoNewline
Write-host -f Cyan $LIG.name
Write-host "Please wait..." 


try {
    Get-OVLogicalInterconnect -Name $LI.name | Update-OVLogicalInterconnect -confirm:$false -ErrorAction Stop | Wait-OVTaskComplete | Out-Null
}
catch {
    Write-Output $_ #.Exception
}


#################################################################################
#                       Adding Network to Network Set                           #
#################################################################################

ForEach ($VLAN In $data) {

    Write-host "`nAdding Network: " -NoNewline
    Write-host -f Cyan ($VLAN.netName) -NoNewline
    Write-host " to NetworkSet: " -NoNewline
    Write-host -f Cyan $networksetname
         
    $networkset.networkUris += (Get-OVNetwork -Name $VLAN.NetName).uri
}

try {
    Set-OVNetworkSet $networkset -ErrorAction Stop | Wait-OVTaskComplete | Out-Null
}
catch {
    $error[0]
}
 
Write-host "`nAll $($data.count) networks have been added successfully to all Server Profiles that are using the Network Set: " -NoNewline
Write-host -f Cyan $networksetname 
    
Disconnect-OVMgmt
 