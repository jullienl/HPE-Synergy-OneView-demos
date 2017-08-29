# -------------------------------------------------------------------------------------------------------
#   by lionel.jullien@hpe.com
#   August 2017
#
#   Script to configure a Synergy environment using the HPE Image Streamer from scratch. 
#   Hardware Setup and Network settings are the two only steps that must be done first on the unconfigured Synergy Composer
#        
#   OneView administrator account is required. 
3PAR-Powershell
OneView 
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


 
#Global Variables

# Using external repo now
# $baseline1 = "C:\Kits\_HP\_SPP\874800-001.iso"
# $baseline2 = "C:\Kits\_HP\_SPP\Synergy subset\874768-001.iso"
      
$3PARlibrary = "C:\Kits\_Scripts\_PowerShell\3PAR\3PAR-Powershell-master\3PAR-Powershell"


 
#IP address of OneView
$DefaultIP = "192.168.1.110" 
Clear
$IP = Read-Host "Please enter the IP address of your OneView appliance [$($DefaultIP)]" 
$IP = ($DefaultIP,$IP)[[bool]$IP]

# OneView Credentials
$username = "Administrator" 
$defaultpassword = "password" 
$password = Read-Host "Please enter the Administrator password for OneView [$($Defaultpassword)]"
$password = ($Defaultpassword,$password)[[bool]$password]


# Import the OneView 3.1 library

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

filter Timestamp {"$(Get-Date -Format G): $_"}

#Upload custom SPP Baseline
    Add-HPOVBaseline $baseline1
    #Add-HPOVBaseline $baseline2


# Adding OneView licenses

	write-host "Adding OneView licenses"

	New-HPOVLicense -LicenseKey '9... HZL4..9-8KPGH' 
      
        New-HPOVLicense -LicenseKey '#Synergy 8Gb FC Upgrade License NFR AAAE CQAA H9PY GHXZ V2...UG33U"

        New-HPOVLicense -LicenseKey '#Synergy 8Gb FC Upgrade License NFR...6DDU"  

       
# Create the new users
    
    New-HPOVUser demopaq -fullName "demopaq"-password $Password -roles "Infrastructure administrator" 
  


# Add a SAN Manager

    $params = @{

        hostname  = "192.168.1.28";
        Type = "BNA";
        UserName = "Administrator";
    	password="password";
     
          }
    
    write-host "Importing BNA"

    Add-HPOVSanManager @params -UseSsl  | Wait-HPOVTaskComplete
   
   
#create IPv4 Pools for the Image Streamer

    #Pool for the management network
    New-HPOVAddressPoolSubnet -NetworkID 192.168.0.0 -Subnetmask 22 -Gateway 192.168.1.1 -Domain lj.mougins.net -DNSServers 192.168.2.1, 192.168.2.3
    Get-HPOVAddressPoolSubnet -NetworkID 192.168.0.0  | New-HPOVAddressPoolRange -Name 'Streamer-management' -Start 192.168.2.110 -end 192.168.2.180  

    #Pool for the deployment network
    New-HPOVAddressPoolSubnet -NetworkID 192.168.8.0 -Subnetmask 24 -Gateway 192.168.8.1 -Domain streamer-deployment.net -DNSServers 192.168.2.1
    Get-HPOVAddressPoolSubnet -NetworkID 192.168.8.0  | New-HPOVAddressPoolRange -Name 'iSCSI-Deployment' -Start 192.168.8.50 -end 192.168.8.200  


#create Ethernet networks


    Write-host "     Creating Ethernet network for Management..."

    New-HPOVNetwork -Name Management -type Ethernet -vlanId 5 -privateNetwork $False -purpose Management -smartLink $False -typicalBandwidth 2500 -VLANType Tagged
    New-HPOVNetwork -Name Management-from-Nexus -type Ethernet -vlanId 6 -privateNetwork $False -purpose Management -smartLink $False -typicalBandwidth 2500 -VLANType Tagged
    
    New-HPOVNetwork -Name Vmotion -type Ethernet -vlanId 10 -privateNetwork $False -purpose VMMigration  -smartLink $False -typicalBandwidth 2500 -VLANType Tagged 
    
    New-HPOVNetworkSet -name "Production Networks" -Networks Vmotion


#create FC networks

   New-HPOVNetwork -Name FC-A -type FC -fabricType FabricAttach 
   Get-HPOVNetwork -Name "FC-A" | Set-HPOVNetwork -ManagedSan Brocade-16G
   New-HPOVNetwork -Name FC-B -type FC -fabricType FabricAttach 
   Get-HPOVNetwork -Name "FC-B" | Set-HPOVNetwork -ManagedSan Brocade-16G

    
#Associate Management Pool subnet to Management network for Streamers 

    $sub1 = Get-HPOVAddressPoolSubnet -NetworkId 192.168.0.0 
    Get-HPOVNetwork -Name Management | Set-HPOVNetwork  -IPv4Subnet $sub1

# Create a Deployment network for the Streamers    
    
    $sub2 = Get-HPOVAddressPoolSubnet -NetworkId 192.168.8.0 
    New-HPOVNetwork -Name iSCSI-Deployment -type Ethernet -VLANType Tagged -VlanId 8 -Purpose ISCSI -Subnet $sub2 


# Change frames names - MAX 3 frames
# Name change cannot be done during a frame refresh

    $numberofframes = @(Get-HPOVEnclosure).count

    if ($numberofframes -gt 0) {
    $interconnects =  Get-HPOVInterconnect     
    $whosframe1 = $interconnects | where {$_.partNumber -match "794502-B23" -and $_.name -match "interconnect 3"} | % {$_.enclosurename}
    $frame1SN = Get-HPOVEnclosure -Name $whosframe1 |  % {$_.serialnumber}
    if ($whosframe1 -ne "Frame1-$frame1SN") {
        $frame1 = get-hpovenclosure -Name $whosframe1 
        Set-HPOVEnclosure -Name "Frame1-$frame1SN" -Enclosure $frame1
        }
    }

    if ($numberofframes -gt 1) {
    $whosframe2 = $interconnects | where {$_.partNumber -match "794502-B23" -and $_.name -match "interconnect 6"} |  % {$_.enclosurename}
    $frame2SN = Get-HPOVEnclosure -Name $whosframe2 |  % {$_.serialnumber}
    if ($whosframe2 -ne "Frame2-$frame2SN") {
        $frame2 = get-hpovenclosure -Name $whosframe2
        Set-HPOVEnclosure -Name "Frame2-$frame2SN" -Enclosure $frame2
        }
    }

    if ($numberofframes -gt 2) {
    $frameswithsatellites = $interconnects | where -Property Partnumber -EQ -value "779218-B21" 
    $whosframe3 = $frameswithsatellites | group-object -Property enclosurename |  ?{ $_.Count -gt 1 } | % {$_.name}  
    $frame3SN = Get-HPOVEnclosure -Name $whosframe3 |  % {$_.serialnumber}
    if ($whosframe3 -ne "Frame3-$frame3SN") {
        $frame3 = get-hpovenclosure -Name $whosframe3
        Set-HPOVEnclosure -Name "Frame3-$frame3SN" -Enclosure $frame3
        }
    }

    if ($numberofframes -gt 3) { Write-Host "This script does not support more than 3 frames to change frame names"}


#create Logical interconnect group

    Write-host
    Write-host "     Creating M-LAG Logical Interconnect Group.."

    $LIG_M_LAG_Name = "LIG-MLAG"

    $VCbays =  @{Frame1 = @{Bay3 = 'SEVC40f8' ; Bay6 = 'SE20ILM'};Frame2 = @{Bay3 = 'SE20ILM'; Bay6 = 'SEVC40f8' };Frame3 = @{Bay3 = 'SE20ILM'; Bay6 = 'SE20ILM'}}

    New-HPOVLogicalInterconnectGroup -Name $LIG_M_LAG_Name -InterconnectBaySet 3 -frameCount 3 -Bays $VCbays -FabricModuleType SEVC40F8 -FabricRedundancy HighlyAvailable


    Write-host
    Write-host "     Creating SAS Logical Interconnect Group.."

    $LIG_SAS_Name = "LIG-SAS"

    $SASbays =  @{
    Frame1 = @{Bay1 = 'SE12SAS' ; Bay4 = 'SE12SAS'} } 

    New-HPOVLogicalInterconnectGroup -Name $LIG_SAS_Name -frameCount 1 -InterconnectBaySet 1 -Bays $SASbays -FabricModuleType SAS 


#Create Ethernet Uplink Sets 

    $AllNetworks = "Management","Vmotion"
    
    $interconnects =  Get-HPOVInterconnect     
    $whosframe1 = $interconnects | where {$_.partNumber -match "794502-B23" -and $_.name -match "interconnect 3"} | % {$_.enclosurename}
    $whosframe2 = $interconnects | where {$_.partNumber -match "794502-B23" -and $_.name -match "interconnect 6"} |  % {$_.enclosurename}
    $frameswithsatellites = $interconnects | where -Property Partnumber -EQ -value "779218-B21" 
    $whosframe3 = $frameswithsatellites | group-object -Property enclosurename |  ?{ $_.Count -gt 1 } | % {$_.name}  

   
    # MLAG Uplink Sets   
    $management = Get-HPOVNetwork -Name Management   
    Get-HPOVLogicalInterconnectGroup -name $LIG_M_LAG_Name | New-HPOVUplinkSet -Name "M-LAG-Comware" -Type Ethernet -Networks $management -UplinkPorts "Enclosure1:Bay3:Q1","Enclosure2:Bay6:Q1" 
    $Nexusmanagement = Get-HPOVNetwork -Name Management-from-Nexus   
    Get-HPOVLogicalInterconnectGroup -name $LIG_M_LAG_Name | New-HPOVUplinkSet -Name "M-LAG-Nexus" -Type Ethernet -Networks $Nexusmanagement -UplinkPorts "Enclosure1:Bay3:Q5","Enclosure2:Bay6:Q5" 

    # FC Uplink Sets
    # Enclosure1 must be removed in new version
    $fca = Get-HPOVNetwork -Name "FC-A"   
    Get-HPOVLogicalInterconnectGroup -name $LIG_M_LAG_Name | New-HPOVUplinkSet -Name "FC-A"  -Type FibreChannel -Networks $fca -UplinkPorts "Enclosure1:Bay3:Q4.1" 
    $fcb = Get-HPOVNetwork -Name "FC-B"   
    Get-HPOVLogicalInterconnectGroup -name $LIG_M_LAG_Name | New-HPOVUplinkSet -Name "FC-B" -Type FibreChannel -Networks $fcb -UplinkPorts "Enclosure2:Bay6:Q4.1" 

    
    
#Create an uplink Set for the Image Streamer (Internal) 

    $ImageStreamerDeploymentNetwork = Get-HPOVNetwork -Name "iSCSI-Deployment" -ErrorAction Stop
   
    Get-HPOVLogicalInterconnectGroup -Name $LIG_M_LAG_Name -ErrorAction Stop | New-HPOVUplinkSet -Name 'Image Streamer Uplink Set' -Type ImageStreamer -Networks $ImageStreamerDeploymentNetwork -UplinkPorts "Enclosure1:Bay3:Q2.1","Enclosure1:Bay3:Q3.1","Enclosure2:Bay6:Q2.1","Enclosure2:Bay6:Q3.1"



# Add Deployment Server

    # Takes 10mn to run but 30-40mn to create in the background !
    # Make sure each streamer is started and showing an Active status under the maintenance console 

    $ImageStreamerManagementNetwork = Get-HPOVNetwork -Name "Management" -ErrorAction Stop

    Get-HPOVImageStreamerAppliance | Select -First 1 | New-HPOVOSDeploymentServer -Name "OSDeploymentServer-1" -ManagementNetwork $ImageStreamerManagementNetwork


#create Enclosure Group 


        $LIGMLAG = Get-HPOVLogicalInterconnectGroup -name $LIG_M_LAG_Name
        $LIGSAS = Get-HPOVLogicalInterconnectGroup -name $LIG_SAS_Name



$LogicalInterConnectGroupMapping = @{
Frame1 = $LIGSAS   , $LIGMLAG ;
Frame2 = $LIGMLAG  ;
Frame3 = $LIGMLAG  ; } 


New-HPOVEnclosureGroup -name "EG" -LogicalInterconnectGroupMapping $LogicalInterConnectGroupMapping -DeploymentNetworkType Internal -EnclosureCount 3 -IPv4AddressType DHCP 

    
#Add SY 3PAR System
# Connected with 0:0:1 and 1:0:1

    Add-HPOVStorageSystem -hostname "3par.lj.mougins.net" -username 3paradm -password 3pardata  | Wait-HPOVTaskComplete 
    Add-HPOVStoragePool -StorageSystem "3par.lj.mougins.net" -Pool "FC_r5", "SSD_r5"  | Wait-HPOVTaskComplete


    
    #Import 3PAR library
    if (-not (get-module 3PAR-Powershell)) 
    {
    Import-Module  $3PARlibrary
    }
    
    $3PARcreds = Get-Credential -UserName 3paradm -Message "Please enter the 3PAR password"  
    Connect-3PAR -Server "3par.lj.mougins.net"  -Credentials $3PARcreds

    
    #3PAR Volumes to import in OneView

    $volume1 = 'vSphere-datastore'
    #$volume2 = 'LJ-vSphere-Datastore'
    
    
    # Import 3PAR volume
    $volumeID1 = Get-3PARVolumes -name $volume1 |  % {$_.wwn}
    $StorageDeviceName1 = Get-3PARVolumes -name $volume1 | % {$_.name}   
   
    Get-HPOVStorageSystem -SystemName "3par.lj.mougins.net"  |  Add-HPOVStorageVolume   -VolumeName $volume1 -StorageDeviceName $StorageDeviceName1 -Shared | Wait-HPOVTaskComplete
   
    
# New Datacenter
    $NewDCParams = @{
    
    Name             = 'Sophia-Antipolis';
        Width            = 10668;
        Depth            = 13716;
        Millimeters      = $True;
        DefaultVoltage   = 220;
        PowerCosts       = 0.10;
        CoolingCapacity  = 350;
        Address1         = 'Marco Polo – Bat. B';
        Address2         = '790 Avenue du Docteur Donat';
        City             = 'Mougins';
        Country          = 'France';
        PostCode         = '06254';
        TimeZone         = 'GMT+1';
    
    }
    New-HPOVDataCenter  @NewDCParams
    
# Remove default datacenter 
   Get-HPOVDataCenter -Name "Datacenter 1" | remove-HPOVDataCenter -Confirm:$false



# Creating a rack
     
     $Params = @{
    
        Name         = 'Rack-Synergy';
        ThermalLimit = 10000;
        SerialNumber = 'AABB1122CCDD';
        PartNumber   = 'AF046A';
        Depth        = 1075;
        Height       = 2032;
        UHeight      = 36;
        Width        = 600
                   }

    New-HPOVRack @Params


# Adding frame ressources to rack
    $frame3 = Get-HPOVenclosure | ? {$_.name -match "Frame3"}
    $frame2 = Get-HPOVenclosure | ? {$_.name -match "Frame2"}
    $frame1 = Get-HPOVenclosure | ? {$_.name -match "Frame1"}


    $Rack = Get-HPOVRack -Name Rack-Synergy -ErrorAction Stop
    $_U = 1
    Add-HPOVResourceToRack -InputObject $frame3 -Rack $Rack -ULocation $_U
    $_U += 10
    Add-HPOVResourceToRack -InputObject $frame2 -Rack $Rack -ULocation $_U
    $_U += 10
    Add-HPOVResourceToRack -InputObject $frame1 -Rack $Rack -ULocation $_U

    

# Adding rack to datacenter

    $DC = Get-HPOVDataCenter 
    $X = 1000
    $Y = 1200
    Get-HPOVRack -Name Rack-Synergy -ErrorAction Stop | Add-HPOVRackToDataCenter -DataCenter $DC -X $X -Y $Y -Millimeters
 
 
 
 # Add remote backup location  
 
    $HostSSHKey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDPa4goQZ6RMNohCL+JaAtYkOhEDiuueAsW+Msh85LhYVdcXcV7QssYFiOsmoA+a0GGAyoIZrkWge3SZKBNJr4ylBaJC+T9X9nw/daNdd4mYg64CwTya+RLgi9ztxdJMLP48FnUdFcndEchj6V+ZLpJEy/tU+SP+XlHrwCU2nexSKSERLhbvHp1UiW946I2fCp4O2IcoIW2/MwXtuH/vr6wQViUFuHbXC5UHjdaM45i9xLq2OavO22KgQ7CwckNrAvlSY8/7G4WgaLR0syKNoTwLuIim7w14I2fbNopNdXsnvm6z6Bk3F0PVRdrWa34l2G8RMiFjRAe8PXsPwcaIVgr"
    Set-HPOVAutomaticBackupConfig -Hostname docker-2.lj.mougins.net -Username root -Password (ConvertTo-SecureString password -AsPlainText -Force) -Directory "composer_backup" -HostSSHKey $HostSSHKey -Protocol SFTP -Interval Weekly -Days 'SUN' -Time 18:00


# Add an external repository

   New-HPOVExternalRepository -Name liogw-kits -Hostname liogw.lj.mougins.net -Directory '_HP/_SPP/Repository' -Http


#create Logical Enclosure LE-3-frames using the latest SPP  !

    $interconnects =  Get-HPOVInterconnect     
    $whosframe1 = $interconnects | where {$_.partNumber -match "794502-B23" -and $_.name -match "interconnect 3"} | % {$_.enclosurename}

    $baseline = Get-HPOVBaseline | Sort-Object -Property @{Expression = "Version"; Descending = $True} | select -First 1
    $EG = Get-HPOVEnclosureGroup -Name "EG"

    write-output "Creating the Logical Enclosure 'LE'" | Timestamp
    Get-HPOVEnclosure -Name  $whosframe1 | New-HPOVLogicalEnclosure -Name 'LE' -EnclosureGroup $EG -FirmwareBaseline $baseline -ForceFirmwareBaseline $true 
    write-output "Logical Enclosure 'LE' created " | Timestamp



# Upload OS Deployment plan to Image Streamer
write-host "`nDownload the ESXi artifacts from https://github.com/HewlettPackard/image-streamer-esxi" -ForegroundColor Cyan
write-host "`nThen add and extract this artifact bundle on the Image Streamer"
pause
# Latest artifact bundle for ESXi : https://github.com/HewlettPackard/image-streamer-esxi/blob/master/artifact-bundles/HPE-ESXi-2017-06-13.zip 


#create a Server Profile Template for an ESX server using the Image Streamer 

Write-Output "Creating Server Profile Template using the Image Streamer" | Timestamp


$serverprofiletemplate = "ESXi for I3S OSDEPLOYMENT"
$OSDeploymentplan = 'HPE - ESXi - deploy with multiple management NIC HA config'
$datastore =   $volume1 


        $SY460SHT = Get-HPOVServerHardwareTypes -name "SY 480 Gen9 1"
        
        $enclosuregroup = Get-HPOVEnclosureGroup | ? {$_.osDeploymentSettings.manageOSDeployment -eq $True} | select -First 1 
        
        $ManagementURI = Get-HPOVNetwork | ? {$_.purpose -match "Management" -and $_.SubnetUri -ne $Null} | % Uri

        $OSDP = Get-HPOVOSDeploymentPlan -name $OSDeploymentplan
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
  

  
        $params = @{
            Name                = $serverprofiletemplate;
            Description         = "Server Profile Template for HPE Synergy 480 Gen9 Compute Module using the Image Streamer";
            ServerHardwareType  = $SY460SHT;
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
            OSDeploymentplan    = $OSDP;
            OSDeploymentPlanAttributes = $OSDeploymentPlanAttributes

            
             }


      try
          {
       
          New-HPOVServerProfileTemplate @params -ErrorAction Stop | Wait-HPOVTaskComplete

          }

      catch  
         {
       
         $error[0] | fl * -force 
               
         }
   


   Write-Output "Local Storage Server Profile Template $serverprofiletemplate using Image Streamer Created" | Timestamp

   


