# -------------------------------------------------------------------------------------------------------
#   by lionel.jullien@hpe.com
#   September 2017
#
#   This PowerShell Script is an example of how to create a Server Profile using the HPE 
#   Image Streamer with OS Deployment Plan Attributes.
#   
#   A Server Profile Template is not required. 
#     
#   OneView administrator account is required. 
#   
#   Latest OneView POSH Library must be used.
# 
# --------------------------------------------------------------------------------------------------------
   
#################################################################################
#                         New-ESXiserverprofile.ps1                             #
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


[string]$HPOVMinimumVersion = "3.10.1471.1581"


function Check-HPOVVersion {
    # Check HPE OneView POSH library version
    # Encourage people to run the latest version    
    $arrMinVersion = $HPOVMinimumVersion.split(".")
    $arrHPOVVersion=((Get-HPOVVersion ).LibraryVersion)
    if ( ($arrHPOVVersion.Major -gt $arrMinVersion[0]) -or
        (($arrHPOVVersion.Major -eq $arrMinVersion[0]) -and ($arrHPOVVersion.Minor -gt $arrMinVersion[1])) -or
        (($arrHPOVVersion.Major -eq $arrMinVersion[0]) -and ($arrHPOVVersion.Minor -eq $arrMinVersion[1]) -and ($arrHPOVVersion.Build -gt $arrMinVersion[2])) -or
        (($arrHPOVVersion.Major -eq $arrMinVersion[0]) -and ($arrHPOVVersion.Minor -eq $arrMinVersion[1]) -and ($arrHPOVVersion.Build -eq $arrMinVersion[2]) -and ($arrHPOVVersion.Revision -ge $arrMinVersion[3])) )
        {
        #HPOVVersion the same or newer than the minimum required
        }
    else {
        Write-Error "You are running a version of POSH-HPOneView that do not support this script. Please update your HPOneView POSH from: https://github.com/HewlettPackard/POSH-HPOneView/releases"
        pause
        exit
        }
    }




#################################################################################
#                                Global Variables                               #
#################################################################################


$serverprofilename = "ESXi-I3S"

$OSDeploymentplanname = "ESXi - deploy with multiple management NIC HA config+FCoE"

# This can be found using Get-HPOVServerHardwareTypes
$ServerHardwareType = "SY 480 Gen9 1"


#datastore present amd managed by OneView (get-hpovstoragevolume)
$datastore = "vSphere-datastore"


# OneView Credentials
$username = "Administrator" 
$password = "password" 
$IP = "192.168.1.110" 




#################################################################################



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
        Connect-HPOVMgmt -appliance $IP -PSCredential $cred| Out-Null
    }
    Catch 
    {
        throw $_
    }
}

               
import-HPOVSSLCertificate -ApplianceConnection ($connectedSessions | ?{$_.name -eq $IP})


# Check oneview version

Check-HPOVVersion



filter Timestamp {"$(Get-Date -Format G): $_"}


        
Write-Output "Creating Server Profile using the Image Streamer" | Timestamp


# Selecting an available compute resource

$server = Get-HPOVServer -NoProfile -InputObject $spt | Select -first 1

$enclosuregroup = Get-HPOVEnclosureGroup | ? {$_.osDeploymentSettings.manageOSDeployment -eq $True} | select -First 1 

$SY480SHT = Get-HPOVServerHardwareTypes -name $ServerHardwareType

$ManagementURI = Get-HPOVNetwork | ? {$_.purpose -match "Management" -and $_.SubnetUri -ne $Null} | % Uri



# Building the OS Custom attributes


        $OSDeploymentplan = Get-HPOVOSDeploymentPlan -name $OSDeploymentplanname
        $osCustomAttributes = Get-HPOVOSDeploymentPlan -name $OSDeploymentplan -ErrorAction Stop | Get-HPOVOSDeploymentPlanAttribute
        
        $OSDeploymentPlanAttributes = $osCustomAttributes 


        ($OSDeploymentPlanAttributes | ? name -eq 'ManagementNIC.ipaddress').value = ''
        ($OSDeploymentPlanAttributes | ? name -eq 'ManagementNIC.dhcp').value = 'False'
        ($OSDeploymentPlanAttributes | ? name -eq 'ManagementNIC.connectionid').value = '3'
        ($OSDeploymentPlanAttributes | ? name -eq 'DomainName').value = 'lj.mougins.net'
        ($OSDeploymentPlanAttributes | ? name -eq 'ManagementNIC2.dhcp').value = 'False'
        ($OSDeploymentPlanAttributes | ? name -eq 'ManagementNIC2.connectionid').value = '4'

        ($OSDeploymentPlanAttributes | ? name -eq 'ManagementNIC.networkuri').value = $ManagementURI
        ($OSDeploymentPlanAttributes | ? name -eq 'ManagementNIC2.networkuri').value = $ManagementURI



# Building the network connections

                     
        $ISCSINetwork = Get-HPOVNetwork | ? {$_.purpose -match "ISCSI" -and $_.SubnetUri -ne $Null} 

        $IscsiParams1 = @{
               ConnectionID                  = 1;
               Name                          = "ImageStreamer Connection 1";
               ConnectionType                = "Ethernet";
               Network                       = $ISCSINetwork;
               Bootable                      = $true;
               Priority                      = "Primary";
               IscsiIPv4AddressSource        = "SubnetPool"
                         }

        $ImageStreamerBootConnection1 = New-HPOVServerProfileConnection @IscsiParams1
        
        $IscsiParams2 = @{
               ConnectionID                  = 2;
               Name                          = "ImageStreamer Connection 2";
               ConnectionType                = "Ethernet";
               Network                       = $ISCSINetwork;
               Bootable                      = $true;
               Priority                      = "Secondary";
               IscsiIPv4AddressSource        = "SubnetPool"
                         }

        $ImageStreamerBootConnection2 = New-HPOVServerProfileConnection @IscsiParams2

        
        $con3 = Get-HPOVNetwork | ? {$_.purpose -match "Management" -and $_.SubnetUri -ne $Null} | New-HPOVServerProfileConnection -connectionId 3
        $con4 = Get-HPOVNetwork | ? {$_.purpose -match "Management" -and $_.SubnetUri -ne $Null}  | New-HPOVServerProfileConnection -connectionId 4
        $con5 = Get-HPOVNetwork | ? fabricType -match "FabricAttach" | select -Index 0 |  New-HPOVServerProfileConnection -ConnectionID 5 -ConnectionType FibreChannel 
        $con6 = Get-HPOVNetwork | ? fabricType -match "FabricAttach" | select -Index 1 | New-HPOVServerProfileConnection -ConnectionID 6 -ConnectionType FibreChannel
        $volume1 = Get-HPOVStorageVolume -Name $datastore | New-HPOVServerProfileAttachVolume # -LunIdType Manual -LunID 0
  


# Creating the Server Profile

  
        $params = @{
            Name                = $serverprofilename;
            Description         = "Server Profile Template for HPE Synergy 480 Gen9 Compute Module using the Image Streamer";
            ServerHardwareType  = $SY480SHT;
            Affinity            = "Bay";
            Enclosuregroup      = $enclosuregroup;
            Connections         = $ImageStreamerBootConnection1, $ImageStreamerBootConnection2, $con3, $con4, $con5, $con6;
            Manageboot          = $True;
            BootMode            = "UEFIOptimized";
            BootOrder           = "HardDisk";
            HideUnusedFlexnics  = $True;
            SANStorage          = $True;
            OS                  = 'VMware';
            StorageVolume       = $volume1;
            OSDeploymentplan    = $OSDeploymentplan;
            OSDeploymentAttributes = $OSDeploymentPlanAttributes;
            Assignmenttype     = 'server';
            server              =  $server
             }


      try
          {
       
          New-HPOVServerProfile @params -ErrorAction Stop  | Wait-HPOVTaskComplete

          }

      catch  
         {
       
         $error[0] | fl * -force 
               
         }
   
      
    








