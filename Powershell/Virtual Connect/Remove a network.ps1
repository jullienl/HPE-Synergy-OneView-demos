# -------------------------------------------------------------------------------------------------------
#   by lionel.jullien@hpe.com
#   June 2016
#
#   This PowerShell script removes a network resource from a Synergy environment and unpresents this network to all Compute Modules using a Network Set.    
#   The network name defined in OneView/Virtual Connect deleted by this script is always a `prefixname`+`VLAN ID` like `Production-400`.   
#   The script also removes the network resource from the LIG uplinkset and from the network set present in OneView.    
#   
#   This script can be used in conjunction with 'Add a network.ps1". See https://github.com/jullienl/HPE-Synergy-OneView-demos/blob/master/Powershell/Virtual Connect/Add a network.ps1
#   
#   With this script, you can demonstrate that with a single line of code, you can unpresent easily and quickly a network VLAN from all Compute Modules present in the Synergy frames managed by HPE OneView. 
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

$LIG="LIG-MLAG"
$Uplinkset="M-LAG-Comware"
$Networkprefix="Production-"
$NetworkSet="Production Networks"

# OneView Credentials and IP
$username = "Administrator" 
$password = "password" 
$IP = "192.168.1.110" 




# Import the OneView 3.10 library

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

    if (-not (get-module HPOneview.310)) 
    {  
    Import-module HPOneview.310
    }

   
$PWord = ConvertTo-SecureString –String $password –AsPlainText -Force
$cred = New-Object –TypeName System.Management.Automation.PSCredential –ArgumentList $Username, $PWord


# Connection to the Synergy Composer

If ($connectedSessions -and ($connectedSessions | ?{$_.name -eq $IP}))
{
    Write-Verbose "Already connected to $IP."
}

Else
{
    Try 
    {
        Connect-HPOVMgmt -appliance $IP -PSCredential $cred | Out-Null
    }
    Catch 
    {
        throw $_
    }
}

               
import-HPOVSSLCertificate -ApplianceConnection ($connectedSessions | ?{$_.name -eq $IP})


#################################################################################
#                       Removing Network from Network Set                       #
#################################################################################


clear-host
write-host "`nThe following Production networks are available:"

Get-HPOVNetwork -type Ethernet  | where {$_.Name -match $Networkprefix} | Select-Object @{Name="Network name";Expression={$_.Name}}, @{Name="VLAN ID";Expression={$_.vlanid}} | Out-Host


$VLAN = Read-Host "`n`nPlease enter the VLAN ID you want to remove" 
 

$NetToRemoveUri = (Get-HPOVNetwork -Name ($networkprefix + $VLAN)).uri


Write-host "`nRemoving Network: " -NoNewline 
Write-Host -f Cyan ($networkprefix + $VLAN) -NoNewline
Write-host " from the network set: " -NoNewline
Write-Host -f Cyan $NetworkSet


$NetSet = Get-HPOVNetworkSet -Name $NetworkSet
$NewNets = ( $NetSet.networkUris | where { $_ -ne $NetToRemoveUri } ) | % { Send-HPOVRequest -Uri $_ }
Set-HPOVNetworkSet -NetworkSet $NetSet -Networks $NewNets | Wait-HPOVTaskComplete



#################################################################################
#                     Removing Network from LIG Uplink Set                      #
#################################################################################


Write-host "`nRemoving Network: " -NoNewline
Write-Host -f Cyan ($networkprefix + $VLAN) -NoNewline  
Write-host  " from the LIG Uplinkset: " -NoNewline
Write-Host -f Cyan $Uplinkset
Write-host  "Please wait..."



$MyLIG = Get-HPOVLogicalInterconnectGroup -Name $LIG 
$MyLI = ((Get-HPOVLogicalInterconnect) | ? logicalInterconnectGroupUri -eq $MyLIG.uri)


$Myuplinkset = $MyLIG.uplinkSets | where-Object {$_.name -eq $Uplinkset} 

$NewUplinkSet = ($Myuplinkset.networkUris | where { $_ -ne $NetToRemoveUri } ) 

$Myuplinkset.networkUris = $NewUplinkSet

Set-HPOVResource $MyLIG | Wait-HPOVTaskComplete  #| Out-Null


#################################################################################
#                        Removing the Network resource                          #
#################################################################################

# This step could take time like 2-3mn ! 

Write-host  "`nRemoving Network: " -NoNewline
Write-Host -f Cyan ($networkprefix + $VLAN) -NoNewline  
Write-host  " from OneView" 
Write-host  "Please wait..."

$task = Get-HPOVNetwork -name ($networkprefix + $VLAN) |  remove-HPOVNetwork -Confirm:$false | Wait-HPOVTaskComplete | Out-Null

# do {$newnetworks= (Get-HPOVNetwork -Name ($networkprefix + $VLAN) -ErrorAction Ignore) } until ($newnetworks -eq $Null)
   

#################################################################################
#                            Updating LI from LIG                               #
#################################################################################

   
# This steps takes time (average 5mn for 3 frames) 
$Updating = Read-Host "`n`nDo you want to apply the new LIG configuration to the Synergy frames [y] or [n] (This step takes times ! Average 5mn with 3 frames) ?" 

if ($Updating -eq "y")
    {

        # Making sure the LI is not in updating state before we run a LI Update
        $Interconnectstate=(((Get-HPOVInterconnect) | ? productname -match "Virtual Connect") | ? logicalInterconnectUri -EQ $MyLI.uri).state  
        if ($Interconnectstate -notcontains "Configured")
        {
            Write-host "`nWaiting for the running Interconnect configuration task to finish, please wait...`n" 
        }
        
        do { $Interconnectstate=(((Get-HPOVInterconnect) | ? productname -match "Virtual Connect") | ? logicalInterconnectUri -EQ $MyLI.uri).state }

        until ($Interconnectstate -notcontains "Adding" -and $Interconnectstate -notcontains  "Imported" -and $Interconnectstate -notcontains "Configuring")


        Write-host "`nUpdating the Logical Interconnect from the Logical Interconnect group: " -NoNewline
        Write-Host -f Cyan $LIG   
        Write-host  "`nPlease wait...`n"
                       
        try {
            $task = Get-HPOVLogicalInterconnect -Name $MyLI.name | Update-HPOVLogicalInterconnect -confirm:$false -ErrorAction Stop | Wait-HPOVTaskComplete | Out-Null
            }
        catch
            {
            echo $_ #.Exception
            }
               
    }


if  ((Get-HPOVLogicalInterconnect).consistencyStatus -eq "consistent" -and $Updating -eq "y")   # Get-HPOVNetworkSet -Name $NetworkSet).networkUris  -ccontains $vlanuri

    {
    Write-host "`nThe network VLAN ID: " -NoNewline
    Write-host -f Cyan $vlan -NoNewline
    Write-host " has been successfully removed and unpresented to all server profiles using the Network Set: " -NoNewline
    Write-host -f Cyan $networkset 
    Write-host ""
    return
    }

if ($Updating -eq "n" -and ((Get-HPOVNetworkSet -Name $NetworkSet).networkUris  -notcontains $vlanuri))
    {
    Write-host "`nThe network VLAN ID: " -NoNewline
    Write-host -f Cyan $vlan -NoNewline
    Write-host " has been removed successfully to all Server profiles using the Network Set: " -NoNewline
    Write-host -f Cyan $networkset 
    Write-host "but the Virtual Connect Modules have not been configured yet`n"
    write-warning "The Logical Interconnect is inconsistent with the logical interconnect group: $LIG"

    return
    }

if (Get-HPOVNetwork -Name ($networkprefix + $VLAN) -ErrorAction Ignore )
    {
    Write-Warning "`nThe network VLAN ID: $vlan has NOT been removed successfully, check the status of your Logical Interconnect ressource`n" 
    }
