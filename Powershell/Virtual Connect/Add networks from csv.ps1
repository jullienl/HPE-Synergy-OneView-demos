
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

#IP address of OneView
$IP = "192.168.1.110" 

# OneView Credentials
$username = "Administrator" 
$password = "password"

$LIG_UplinkSet = "M-LAG-Nexus"
$networksetname = "Production_network_set"


#################################################################################


$secpasswd = ConvertTo-SecureString $password -AsPlainText -Force
$credentials = New-Object System.Management.Automation.PSCredential ($username, $secpasswd)

# MODULES TO INSTALL/IMPORT

# HPEONEVIEW
If (-not (get-module HPEOneView.530 -ListAvailable )) { Install-Module -Name HPEOneView.530 -scope Allusers -Force }
import-module HPEOneView.530

# Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -Confirm:$false 

# Connection to the Synergy Composer
Connect-OVMgmt -Hostname $IP -Credential $credentials | Out-Null

# Import of the CSV file containing VLAN name and VLAN ID
$data = (Import-Csv $csvfile)


#################################################################################
#              Creating Networks and adding them to the LIG uplink Set          #
#################################################################################

#$LIGname = (Get-OVLogicalInterconnectGroup | where { $_.uri -eq (Get-OVLogicalInterconnect).logicalInterconnectGroupUri }).name
$LIGURI = (Get-OVLogicalInterconnect).logicalInterconnectGroupUri

#$NewNetwork = Get-OVNetwork -Name "Produc*"  #Get the Network resource

$LIG = Get-OVLogicalInterconnectGroup | Where-Object { $_.uri -eq $LIGURI }


if (!(($LIG | Measure-Object).Count -eq 1 )) { Write-Host "Failed to filter down to one LIG" -ForegroundColor Red | Break }


ForEach ($VLAN In $data) {
    New-OVNetwork -Name $VLAN.NetName -Type Ethernet -VLANId $VLAN.VLAN_ID -SmartLink $True | out-Null
    Write-host "`nCreating Network: " -NoNewline
    Write-host -f Cyan ($VLAN.netName) -NoNewline

    (($LIG.uplinkSets | where-object name -eq $LIG_UplinkSet | Where-Object { $_.ethernetNetworkType -eq "Tagged" }).networkUris) += (Get-OVNetwork -Name $VLAN.NetName).uri #Add NewNetwork to the networkUris Array
    Write-host "`nAdding Network: " -NoNewline
    Write-host -f Cyan ($VLAN.netName) -NoNewline
    Write-host " to Uplink Set: " -NoNewline
    Write-host -f Cyan $LIG_UplinkSet

}



try {
    Set-OVResource $LIG -ErrorAction Stop | Wait-OVTaskComplete | Out-Null
}
catch {
    Write-Output $_ #.Exception
}



#################################################################################
#                            Updating LI from LIG                               #
#################################################################################

$LI = ((Get-OVLogicalInterconnect) | where-object logicalInterconnectGroupUri -eq $LIG.uri)


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
Write-host "`nPlease wait..." 


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
  
    
    $VLANuri = (Get-OVNetwork -Name $VLAN.NetName).uri
    $networkset = Get-OVNetworkSet -Name $networksetname
   
    $networkset.networkUris += (Get-OVNetwork -Name $VLAN.NetName).uri

  
    try {
        Set-OVNetworkSet $networkset -ErrorAction Stop | Wait-OVTaskComplete | Out-Null
    }
    catch {
        Write-Output $_
    }
 
 
 
    if ( (Get-OVNetworkSet -Name $NetworkSetname).networkUris -ccontains $VLANuri) {
        Write-host "`nThe network VLAN ID: " -NoNewline
        Write-host -f Cyan $VLAN.NetName -NoNewline
        Write-host " has been added successfully to all Server Profiles that are using the Network Set: " -NoNewline
        Write-host -f Cyan $networksetname 
    }
    else {
        Write-Warning "`nThe network VLAN ID: $($VLAN.VLAN_ID) has NOT been added successfully, check the status of your Logical Interconnect resource`n" 
    }

}
    
Disconnect-OVMgmt
 