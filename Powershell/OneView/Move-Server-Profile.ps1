<# 

This PowerShell script can be used to move an HPE OneView Server Profile from one appliance to another. 
All server profile settings are captured on a source OneView appliance and exported to a destination appliance

The captured settings consist of all server profile parameters. 

The target data (network names, enclosure name, SPT, etc.) must be provided in the variable section for the settings to be portable.

Note: Dependent resources like networks, private SAN volumes, licenses, etc. are not moved during the process and must available on the target appliance.

The script ensures that the source server is shut down before the migration and once the server profile creation is successfully completed 
on the destination appliance, the source server profile is deleted on demand or renamed '<ProfileName> [migrated]'. 

If necessary, the WWNN, WWPN, MAC addresses and Serial Numbers of the source server profile can be preserved, in which case you should comment/uncomment some lines 
in the CONNECTION SETTINGS and SERIAL NUMBER sections.

Requirements: 
- OneView administrator account.


  Author: thomas.elsholz@hpe.com / lionel.jullien@hpe.com
  Date:   December 2022
    
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
#>

# Variables

# Name of the server profile to move
$SP = "ESX01"

# TARGET APPLIANCE INFORMATION
# Name of the target Server Profile Template
$SPT = "SPT ESX1"
# Name of the target server hardware type
$SHT = "SY 480 Gen10 2"
# Name of the target Enclosure Group
$EG = "2F VC"
#Name of the target Enclosure where the profile will be assigned
$enclosure = "0000A66101"
# Bay number in the target enclosure where the profile will be assigned
$bay = "3"
# Name of the Networks to connect
$net1 = "Management 100"
$net2 = "vMotion 800"
$faba = "FCoE Fabric A"
$fabb = "FCoE Fabric B"

# OneView information
$OV_username = "Administrator"
$source_appliance = "composer.lj.lab"
$destination_appliance = "oneview.lj.lab"



# MODULES TO INSTALL

# HPEOneView
If (-not (get-module HPEOneView.800 -ListAvailable )) { Install-Module -Name HPEOneView.800 -scope Allusers -Force }
Import-Module HPEOneView.800


#################################################################################


# Connection to the source OneView appliance

if (! $ConnectedSessions) {

    $secpasswd = read-host  "Please enter the OneView password" -AsSecureString
  
    $credentials = New-Object System.Management.Automation.PSCredential ($OV_username, $secpasswd)

    try {
        Connect-OVMgmt -Hostname $source_appliance -Credential $credentials -ErrorAction stop | Out-Null    
    }
    catch {
        Write-Warning "Cannot connect to '$source_appliance'! Exiting... "
        return
    }
}


# Retrieve source Server profile information
try {
    $MyProfile = Get-OVServerProfile -Name $SP -ErrorAction Stop 
    
}
catch {
    Write-Warning "Server profile $($SP) not found on the source appliance ! Exiting..."
    Disconnect-OVMgmt
    return
}

# Power off source Server hardware
$MyProfile | Stop-OVServer -Force -Confirm:$false | Wait-OVTaskComplete

# Connect to destination appliance

try {
    Connect-OVMgmt -Hostname $destination_appliance -Credential $credentials -ErrorAction stop | Out-Null    
}
catch {
    Write-Warning "Cannot connect to '$destination_appliance'! Exiting... "
    return
}

# Change the server profile settings to match the destination appliance.
$MyProfile.uri = $null
$MyProfile.profileUUID = $null
$MyProfile.serverProfileTemplateUri = Get-OVServerProfileTemplate -Name $SPT -ApplianceConnection $Global:ConnectedSessions[1] | % uri
$MyProfile.serverHardwareTypeUri = Get-OVServerHardwareType -Name $SHT -ApplianceConnection $Global:ConnectedSessions[1] | % uri
$MyProfile.enclosureGroupUri = Get-OVEnclosureGroup -name $EG -ApplianceConnection $Global:ConnectedSessions[1] | % uri
$MyProfile.enclosureUri = Get-OVEnclosure -name $enclosure -ApplianceConnection $Global:ConnectedSessions[1] | % uri
$MyProfile.enclosureBay = $bay
$sh = $enclosure + ", bay " + $bay
$MyProfile.associatedServer = (Get-OVServer -ApplianceConnection $Global:ConnectedSessions[1] | ? name -eq $sh).uri
$MyProfile.templateCompliance = "Unknown"
$MyProfile.connectionSettings.connections[0].networkUri = Get-OVNetwork -name $net1 -ApplianceConnection $Global:ConnectedSessions[1] | % uri

################################################## CONNECTION SETTINGS #########################################################################
# To keep the same MAC and WWNs addresses as the source server profile, 
# uncomment all below lines with UserDefined type and comment all lines with $Null for the MAC and WWPN/WWNN

$MyProfile.connectionSettings.connections[0].mac = $Null
# $MyProfile.connectionSettings.connections[0].macType = "UserDefined"
$MyProfile.connectionSettings.connections[1].networkUri = Get-OVNetwork -name $net1 -ApplianceConnection $Global:ConnectedSessions[1] | % uri
$MyProfile.connectionSettings.connections[1].mac = $Null
# $MyProfile.connectionSettings.connections[1].macType = "UserDefined"
$MyProfile.connectionSettings.connections[2].networkUri = Get-OVNetwork -name $net2 -ApplianceConnection $Global:ConnectedSessions[1] | % uri
$MyProfile.connectionSettings.connections[2].mac = $Null
# $MyProfile.connectionSettings.connections[2].macType = "UserDefined"
$MyProfile.connectionSettings.connections[3].networkUri = Get-OVNetwork -name $net2 -ApplianceConnection $Global:ConnectedSessions[1] | % uri
$MyProfile.connectionSettings.connections[3].mac = $Null
# $MyProfile.connectionSettings.connections[3].macType = "UserDefined"
$MyProfile.connectionSettings.connections[4].networkUri = Get-OVNetwork -name $faba -ApplianceConnection $Global:ConnectedSessions[1] | % uri
$MyProfile.connectionSettings.connections[4].mac = $Null
$MyProfile.connectionSettings.connections[4].wwnn = $Null
$MyProfile.connectionSettings.connections[4].wwpn = $Null
# $MyProfile.connectionSettings.connections[4].macType = "UserDefined"
# $MyProfile.connectionSettings.connections[4].wwpnType = "UserDefined"
$MyProfile.connectionSettings.connections[5].networkUri = Get-OVNetwork -name $fabb -ApplianceConnection $Global:ConnectedSessions[1] | % uri
$MyProfile.connectionSettings.connections[5].mac = $Null
$MyProfile.connectionSettings.connections[5].wwnn = $Null
$MyProfile.connectionSettings.connections[5].wwpn = $Null
# $MyProfile.connectionSettings.connections[5].macType = "UserDefined"
# $MyProfile.connectionSettings.connections[5].wwpnType = "UserDefined"

####################################################### SERIAL NUMBER ###########################################################################
# To keep the same Serial Number as the source server profile, uncomment the line below with the UserDefined type and comment the line with $Null 

# $MyProfile.serialNumberType = "UserDefined"
$MyProfile.serialNumber = $Null
$Myprofile.uuid = $Null
################################################################################################################################################

$MyProfile.scopesUri = $null
$MyProfile.ApplianceConnection = $null
$MyProfile.eTag = $null
$new_obj = $Global:ConnectedSessions[1] | Select-Object -Property ConnectionID, name
$MyProfile.ApplianceConnection = $new_obj

try {

    # Create server profile with new definition on target appliance
    $task = New-OVResource /rest/server-profiles $MyProfile -ErrorAction Stop -ApplianceConnection $Global:ConnectedSessions[1] | Wait-OVTaskComplete 

    if ($task.taskState -eq "Completed") {
        Write-Host "`nServer Profile '$SP' has been created successfully on '$destination_appliance'!"
      
        # Ask to remove initial Server Profile
        $removeSP = read-host  "`nDo you want to delete the source server profile '$SP' on appliance '$source_appliance' [Y or N]?" 

        if ($removeSP -eq "Y") {
            Remove-OVServerProfile $MyProfile -ErrorAction stop -confirm:$false -Force -ApplianceConnection $Global:ConnectedSessions[0] | Wait-OVTaskComplete | Out-Null
            Write-Host "`nServer Profile '$SP' has been deleted successfully on '$source_appliance'! Migration completed successfully!"

        }
        else {
            $Myprofile = Get-OVServerProfile -Name $SP -ApplianceConnection $Global:ConnectedSessions[0] 
            $Myprofile.name = $SP + " [migrated]"
            Save-OVServerProfile -InputObject $MyProfile -ApplianceConnection $Global:ConnectedSessions[0] | out-Null
            Write-Host "`nMigration completed successfully ! Server Profile '$SP' was renamed '$SP [migrated]' on '$source_appliance'!"
            
        }

    }
    else {
        Write-warning "Server Profile '$SP' creation error on '$destination_appliance'!"
        $task.taskErrors
        
    }
    
    
}
catch {
    Write-warning "Server Profile '$SP' creation error on '$destination_appliance'!"
    $task.taskErrors
}


$ConnectedSessions | Disconnect-OVMgmt

