
 
#Global Variables

 
$baseline1 = "C:\Kits\_HP\_SPP\874800-001.iso"
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


# Import the OneView 3.0 library

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

    if (-not (get-module HPOneview.300)) 
    {  
    Import-module HPOneview.300
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
        Connect-HPOVMgmt -appliance $IP -PSCredential $cred -Verbose| Out-Null
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
		New-HPOVLicense -LicenseKey '9CDG B9MA H9PQ GHVZ V7B5 HWWB Y9JL KMPL 74GE PDF4 DXAU 2CSM GHTG L762 VFC3 VU59 KJVT D5KM EFVW DT5J 6T3J 6Q8S 9K2P 3EW2 NJY4 HU5F TZZP AB6X 82Z5 WHEF GE4C LUE3 BKT8 WXDG NK6Y C4GA HZL4 XBE7 3VJ6 2MSU 4ZU9 9WGG CZU7 WE4X YN44 CH55 KZLG 2F4N A8RJ UKEC 3F9V JQY5 "424546858 HPOV-NFR1 HP_OneView_16_Seat_NFR GYY4AAEHD5UT"_3Q962-7X8X6-KDLQR-S56L9-8KPGH' 
      
        New-HPOVLicense -LicenseKey '#Synergy 8Gb FC Upgrade License NFR
YAYE AQAA H9PY KHUY V2B4 HWWV Y9JL KMPL 8QWE 5G5Y DXAU 2CSM GHTG L762 H3V3 UYJQ KJVT D5KM EFVW TSNJ BE9K M4WS UL2J 9FG6 SJBZ EVCZ FXP8 45S7 SZ6Z LADY JH7D HNYD JV8M M428 T84U R42A E8K5 XAKD EKSB T4AN XZLU FMXS FKS6 KKCE 4NMU FGN5 N8CG Z2HX SSTP 4F9G NQT8 2UYW N88K HX9E "424743391 N3R43A_NFR Synergy_8Gb_FC_Upgrade_License_NFR 5GEEACCJDD92"
'

        New-HPOVLicense -LicenseKey '#Synergy 8Gb FC Upgrade License NFR
9A9G BQAA H9P9 CHWY V2B4 HWWV Y9JL KMPL 6QGG 4G5Y DXAU 2CSM GHTG L762 X3V5 U3JM KJVT D5KM EFVW TSNJ ZEYK P4WS UP2J 9FG2 SJBZ AVCZ E28G 455D SZ6Z LADY JH7D HNYD JV8M M428 T84U R42A E8K5 XAKD EKSB T4AN XZLU FMXS FKS6 KKCE 4NMU FGN5 N8CG Z2HX SSTP 4F9G NQT8 2UYW N88K HX9E "424743391 N3R43A_NFR Synergy_8Gb_FC_Upgrade_License_NFR TGEAACCJ33J2"
'
 

       
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
   
    
    #Add-HPOVSanManager -type HP -Hostname 192.168.1.33 -SnmpUserName oneview -SnmpAuthLevel AuthAndPriv -SnmpPrivProtocol aes-128 -SnmpAuthPassword password -SnmpAuthProtocol md5 -SnmpPrivPassword password  | Wait-HPOVTaskComplete 




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

    # Get-HPOVLogicalInterconnectGroup -name $LIG_M_LAG_Name -ErrorAction Stop | New-HPOVUplinkSet -Name "iSCSI-Deployment" -Type ImageStreamer -Networks "iSCSI-Deployment" -UplinkPorts "Enclosure1:Bay3:Q2.1","Enclosure1:Bay3:Q3.1","Enclosure2:Bay6:Q2.1","Enclosure2:Bay6:Q3.1" #| Wait-HPOVTaskComplete


    $ImageStreamerDeploymentNetwork = Get-HPOVNetwork -Name "iSCSI-Deployment" -ErrorAction Stop
   
    Get-HPOVLogicalInterconnectGroup -Name $LIG_M_LAG_Name -ErrorAction Stop | New-HPOVUplinkSet -Name 'Image Streamer Uplink Set' -Type ImageStreamer -Networks $ImageStreamerDeploymentNetwork -UplinkPorts "Enclosure1:Bay3:Q2.1","Enclosure1:Bay3:Q3.1","Enclosure2:Bay6:Q2.1","Enclosure2:Bay6:Q3.1"




# Add Deployment Server

    # Takes 10mn to run but 30-40mn to create in the background !
    # Make sure each streamer is started and showing an Active status under the maintenance console 

    $ImageStreamerManagementNetwork = Get-HPOVNetwork -Name "Management" -ErrorAction Stop

    Get-HPOVImageStreamerAppliance | Select -First 1 | New-HPOVOSDeploymentServer -Name "OSDeploymentServers-1" -ManagementNetwork $ImageStreamerManagementNetwork


#create Enclosure Group 


        $LIGMLAG = Get-HPOVLogicalInterconnectGroup -name $LIG_M_LAG_Name
        $LIGSAS = Get-HPOVLogicalInterconnectGroup -name $LIG_SAS_Name



$LogicalInterConnectGroupMapping = @{
Frame1 = $LIGSAS   , $LIGMLAG ;
Frame2 = $LIGMLAG  ;
Frame3 = $LIGMLAG  ; } 


New-HPOVEnclosureGroup -name "EG" -LogicalInterconnectGroupMapping $LogicalInterConnectGroupMapping -DeploymentNetworkType Internal -EnclosureCount 3 -IPv4AddressType DHCP 

#New-HPOVEnclosureGroup -name "EG" -LogicalInterconnectGroupMapping $LogicalInterConnectGroupMapping  -EnclosureCount 3 -IPv4AddressType DHCP 

    
        


#Add SY 3PAR System
#Connected with 0:0:1 and 1:0:1

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
    
    
    # Import 3PAR volumes
    $volumeID1 = Get-3PARVolumes -name $volume1 |  % {$_.wwn}
    #$volumeID2 = Get-3PARVolumes -name $volume2 | % {$_.wwn}
    $StorageDeviceName1 = Get-3PARVolumes -name $volume1 | % {$_.name}   
    #$StorageDeviceName2 = Get-3PARVolumes -name $volume2 | % {$_.name}

    Get-HPOVStorageSystem -SystemName "3par.lj.mougins.net"  |  Add-HPOVStorageVolume   -VolumeName $volume1 -StorageDeviceName $StorageDeviceName1 -Shared | Wait-HPOVTaskComplete
    #Get-HPOVStorageSystem -SystemName VBE_V400 |  Add-HPOVStorageVolume   -VolumeName $volume2 -StorageDeviceName $StorageDeviceName2 -shared | Wait-HPOVTaskComplete


    #To ensure the creation of AMVM during the logical enclosure creation, perform the following steps before you create a logical enclosure:
    #Login to the I3S Service console
    #Execute the command mkdir -p /var/tmp/i3s/




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
    Set-HPOVAutomaticBackupConfig -Hostname 192.168.0.2 -Username root -Password (ConvertTo-SecureString password -AsPlainText -Force) -Directory "composer_backup" -HostSSHKey $HostSSHKey -Protocol SFTP -Interval Weekly -Days 'SUN' -Time 18:00

    # Create a backup manually
    # New-HPOVBackup
    


# Add an external repository
# in 3.10 only !



#create Logical Enclosure LE-3-frames  !

    $interconnects =  Get-HPOVInterconnect     
    $whosframe1 = $interconnects | where {$_.partNumber -match "794502-B23" -and $_.name -match "interconnect 3"} | % {$_.enclosurename}

    $baseline = Get-HPOVBaseline | where {$_.name -like "Custom*"}
    $EG = Get-HPOVEnclosureGroup -Name "EG"

    write-output "Creating the Logical Enclosure 'LE'" | Timestamp
    Get-HPOVEnclosure -Name  $whosframe1 | New-HPOVLogicalEnclosure -Name 'LE' -EnclosureGroup $EG -FirmwareBaseline $baseline -ForceFirmwareBaseline $true 
    write-output "Logical Enclosure 'LE' created " | Timestamp





#create a SPT for ESX using Image Streamer (not working with latest POSH library ! )

        Write-Output "Creating Local Server Profile Template using the Image Streamer" | Timestamp

        if (get-HPOVServerProfileTemplate -Name "ESXi for I3S" -ErrorAction SilentlyContinue) { Remove-HPOVServerProfileTemplate -ServerProfileTemplate "ESXi for I3S" }

        $serverprofiletemplate = "ESXi for I3S"
        $SY460SHT = Get-HPOVServerHardwareTypes -name "SY 480 Gen9 1"
        $enclosuregroup = Get-HPOVEnclosureGroup | ? {$_.osDeploymentSettings.manageOSDeployment -eq $True} | select -First 1 
        
        
        
        # $ImageStreamerCon1 =  Get-HPOVNetwork -Name 'ImageStreamer Network' | New-HPOVServerProfileConnection -ConnectionID 1 -ConnectionType Ethernet -name "ImageStreamer Connection 1" -Bootable -Priority Primary
        # $ImageStreamerCon2 =  Get-HPOVNetwork -Name 'ImageStreamer Network' | New-HPOVServerProfileConnection -ConnectionID 1 -ConnectionType Ethernet -name "ImageStreamer Connection 2" -Bootable -Priority Secondary
        
        
        
        
        
        $con1 = Get-HPOVNetwork | ? purpose -eq ISCSI | New-HPOVServerProfileConnection -connectionId 1 -ConnectionType Ethernet -Bootable -Priority IscsiPrimary # -IscsiIPv4SubnetMask 255.255.255.0
        $con2 = Get-HPOVNetwork | ? purpose -eq ISCSI | New-HPOVServerProfileConnection -connectionId 2 -ConnectionType Ethernet -Bootable -Priority IscsiSecondary # -IscsiIPv4SubnetMask 255.255.255.0
        $con3 = Get-HPOVNetwork | ? {$_.purpose -match "Management" -and $_.SubnetUri -ne $Null} | New-HPOVServerProfileConnection -connectionId 3
        $con4 = Get-HPOVNetwork | ? {$_.purpose -match "Management" -and $_.SubnetUri -ne $Null}  | New-HPOVServerProfileConnection -connectionId 4
        $con5 = Get-HPOVNetwork | ? fabricType -match "FabricAttach" | select -Index 0 |  New-HPOVServerProfileConnection -ConnectionID 5 -ConnectionType FibreChannel 
        $con6 = Get-HPOVNetwork | ? fabricType -match "FabricAttach" | select -Index 1 | New-HPOVServerProfileConnection -ConnectionID 6 -ConnectionType FibreChannel
       # $volume1 = Get-HPOVStorageVolume | ? shareable -eq $True  | New-HPOVServerProfileAttachVolume # -LunIdType Manual -LunID 0
        $volume1 = Get-HPOVStorageVolume -Name "vSphere-datastore"  | New-HPOVServerProfileAttachVolume # -LunIdType Manual -LunID 0
  
        $params = @{
            Name                = $serverprofiletemplate;
            Description         = "Server Profile Template for HPE Synergy 480 Gen9 Compute Module using the Image Streamer";
            ServerHardwareType  = $SY460SHT;
            ServerProfileDescription = "Server Profile for HPE Synergy 480 Gen9 Compute Module using the Image Streamer";
            Affinity            = "Bay";
            Enclosuregroup      = $enclosuregroup;
            Connections         = $con1, $con2, $con3, $con4, $con5, $con6;
            Manageboot          = $True;
            BootMode            = "UEFIOptimized";
            BootOrder           = "HardDisk";
            HideUnusedFlexnics  = $True;
            SANStorage          = $True;
            OS                  = 'VMware';
            StorageVolume       = $volume1;
                }
        
       
       $err = New-HPOVServerProfileTemplate @params -ErrorAction Stop | Wait-HPOVTaskComplete
        if ($err.taskErrors -match "Error")
       {
       
       clear
       Write-Warning "Task error ! "
       write-host ""
       $err.taskErrors.message
       $err.taskErrors.recommendedActions
       $err.taskErrors.errorcode

       }
       else
       {
        Write-Output "Local Storage Server Profile Template using Image Streamer Created" | Timestamp

        get-HPOVServerProfileTemplate
       }
