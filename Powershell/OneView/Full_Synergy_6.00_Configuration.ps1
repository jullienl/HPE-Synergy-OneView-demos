##############################################################################
#
#  Example script for configuring the HPE Synergy Appliance and infrastructure
#
#   AUTHORS
#   Inspired from daveolker/Populate-HPE-Synergy GitHub repository
#
# (C) Copyright 2019 Hewlett Packard Enterprise Development LP
##############################################################################
<#
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
#>

# ------------------ Parameters
Param ( [String]$OVApplianceIP = "hol-synergy-01.lj.lab",
    [String]$OVAdminName = "Administrator",
    [String]$OVAuthDomain = "Local",
    [String]$OneViewModule = "HPEOneView.550"
)


# Deployments variables
$prod_subnet = "192.168.3.0"
#$prod_gateway = "192.168.56.1"
$prod_pool_start = "192.168.3.200"
$prod_pool_end = "192.168.3.254"
#$prod_mask = "255.255.255.0"
$deploy_subnet = "10.1.1.0"
$deploy_gateway = "10.1.1.1"
$deploy_pool_start = "10.1.1.2"
$deploy_pool_end = "10.1.1.254"
$deploy_mask = "255.255.255.0"

function Add_Remote_Enclosures {
    Write-Output "Adding Remote Enclosures" | Timestamp
    Send-OVRequest -uri "/rest/enclosures" -method POST -body @{'hostname' = 'fe80::2:0:9:7%eth2' } | Wait-OVTaskComplete
    Write-Output "Remote Enclosures Added" | Timestamp
    #
    # Sleep for 10 seconds to allow remote enclosures to quiesce
    #
    Start-Sleep 10
}


function Configure_Address_Pools {
    Write-Output "Configuring Address Pools for MAC, WWN, and Serial Numbers" | Timestamp
    New-OVAddressPoolRange -PoolType vmac -RangeType Generated
    New-OVAddressPoolRange -PoolType vwwn -RangeType Generated
    New-OVAddressPoolRange -PoolType vsn -RangeType Generated
    Write-Output "Address Pool Ranges Configuration Complete" | Timestamp
}


function Configure_SAN_Managers {
    Write-Output "Configuring SAN Managers" | Timestamp
    Add-OVSanManager -Hostname 172.18.20.1 -SnmpUserName dcs-SHA-AES128 -SnmpAuthLevel AuthAndPriv -SnmpAuthPassword dcsdcsdcs -SnmpAuthProtocol sha -SnmpPrivPassword dcsdcsdcs -SnmpPrivProtocol aes-128 -Type Cisco -Port 161 | Wait-OVTaskComplete
    Add-OVSanManager -Hostname 172.18.20.2 -SnmpUserName dcs-SHA-AES128 -SnmpAuthLevel AuthAndPriv -SnmpAuthPassword dcsdcsdcs -SnmpAuthProtocol sha -SnmpPrivPassword dcsdcsdcs -SnmpPrivProtocol aes-128 -Type Cisco -Port 161 | Wait-OVTaskComplete
    Write-Output "SAN Manager Configuration Complete" | Timestamp
}


function Configure_Networks {
    Write-Output "Adding IPv4 Subnets" | Timestamp
    #New-OVAddressPoolSubnet -Domain "mgmt.lan" -Gateway $prod_gateway -NetworkId $prod_subnet -SubnetMask $prod_mask
    Get-OVAddressPoolSubnet -NetworkId $prod_subnet | Set-OVAddressPoolSubnet -Domain "mgmt.lan" 
    New-OVAddressPoolSubnet -Domain "deployment.lan" -Gateway $deploy_gateway -NetworkId $deploy_subnet -SubnetMask $deploy_mask

    Write-Output "Adding IPv4 Address Pool Ranges" | Timestamp
    Get-OVAddressPoolSubnet -NetworkId $prod_subnet | New-OVAddressPoolRange -Name Mgmt -Start $prod_pool_start -End $prod_pool_end
    Get-OVAddressPoolSubnet -NetworkId $deploy_subnet | New-OVAddressPoolRange -Name Deployment -Start $deploy_pool_start -End $deploy_pool_end

    Write-Output "Adding Networks" | Timestamp
    New-OVNetwork -Name "ESX Mgmt" -MaximumBandwidth 20000 -Purpose Management -Type Ethernet -TypicalBandwidth 2500 -VlanId 1131 -VLANType Tagged
    New-OVNetwork -Name "ESX vMotion" -MaximumBandwidth 20000 -Purpose VMMigration -Type Ethernet -TypicalBandwidth 2500 -VlanId 1132 -VLANType Tagged
    New-OVNetwork -Name Prod_1101 -MaximumBandwidth 20000 -Purpose General -Type Ethernet -TypicalBandwidth 2500 -VlanId 1101 -VLANType Tagged
    New-OVNetwork -Name Prod_1102 -MaximumBandwidth 20000 -Purpose General -Type Ethernet -TypicalBandwidth 2500 -VlanId 1102 -VLANType Tagged
    New-OVNetwork -Name Prod_1103 -MaximumBandwidth 20000 -Purpose General -Type Ethernet -TypicalBandwidth 2500 -VlanId 1103 -VLANType Tagged
    New-OVNetwork -Name Prod_1104 -MaximumBandwidth 20000 -Purpose General -Type Ethernet -TypicalBandwidth 2500 -VlanId 1104 -VLANType Tagged
    New-OVNetwork -Name Deployment -MaximumBandwidth 20000 -Purpose General -Type Ethernet -TypicalBandwidth 2500 -VlanId 1500 -VLANType Tagged
    New-OVNetwork -Name Mgmt -MaximumBandwidth 20000 -Purpose Management -Type Ethernet -TypicalBandwidth 2500 -VlanId 100 -VLANType Tagged
    New-OVNetwork -Name SVCluster-1 -MaximumBandwidth 20000 -Purpose ISCSI -Type Ethernet -TypicalBandwidth 2500 -VlanId 301 -VLANType Tagged
    New-OVNetwork -Name SVCluster-2 -MaximumBandwidth 20000 -Purpose ISCSI -Type Ethernet -TypicalBandwidth 2500 -VlanId 302 -VLANType Tagged
    New-OVNetwork -Name SVCluster-3 -MaximumBandwidth 20000 -Purpose ISCSI -Type Ethernet -TypicalBandwidth 2500 -VlanId 303 -VLANType Tagged

    $Deploy_AddrPool = Get-OVAddressPoolSubnet -NetworkId $deploy_subnet
    Get-OVNetwork -Name Deployment | Set-OVNetwork -IPv4Subnet $Deploy_AddrPool
    $Prod_AddrPool = Get-OVAddressPoolSubnet -NetworkId $prod_subnet
    Get-OVNetwork -Name Mgmt | Set-OVNetwork -IPv4Subnet $Prod_AddrPool

    New-OVNetwork -Name "SAN A FC" -Type "Fibre Channel" -FabricType FabricAttach -LinkStabilityTime 30 -ManagedSan VSAN20 -MaximumBandwidth 20000 -TypicalBandwidth 8000
    New-OVNetwork -Name "SAN B FC" -Type "Fibre Channel" -FabricType FabricAttach -LinkStabilityTime 30 -ManagedSan VSAN21 -MaximumBandwidth 20000 -TypicalBandwidth 8000
    New-OVNetwork -Name "SAN A FCoE" -VlanId 10 -ManagedSan VSAN10 -MaximumBandwidth 20000 -Type FCoE -TypicalBandwidth 8000
    New-OVNetwork -Name "SAN B FCoE" -VlanId 11 -ManagedSan VSAN11 -MaximumBandwidth 20000 -Type FCoE -TypicalBandwidth 8000

    Write-Output "Adding Network Sets" | Timestamp
    New-OVNetworkSet -Name Prod -Networks Prod_1101, Prod_1102, Prod_1103, Prod_1104 -MaximumBandwidth 20000 -TypicalBandwidth 2500

    Write-Output "Networking Configuration Complete" | Timestamp
}


function Add_Storage {
    Write-Output "Adding 3PAR Storage Systems" | Timestamp
    Add-OVStorageSystem -Hostname 172.18.11.11 -Password dcs -Username dcs -Domain TestDomain | Wait-OVTaskComplete
    Add-OVStorageSystem -Hostname 172.18.11.12 -Password dcs -Username dcs -Domain TestDomain | Wait-OVTaskComplete

    Write-Output "Adding 3PAR Storage Pools" | Timestamp
    $SPNames = @("CPG-SSD", "CPG-SSD-AO", "CPG_FC-AO", "FST_CPG1", "FST_CPG2")
    for ($i = 0; $i -lt $SPNames.Length; $i++) {
        Get-OVStoragePool -Name $SPNames[$i] -ErrorAction Stop | Set-OVStoragePool -Managed $true | Wait-OVTaskComplete
    }
    
    Write-Output "Adding 3PAR Storage Volume Templates" | Timestamp
    Get-OVStoragePool CPG-SSD -StorageSystem ThreePAR-1 | New-OVStorageVolumeTemplate -Capacity 100 -Name SVT-3PAR-Shared-1 -ProvisionType Thin -Shared
    Get-OVStoragePool CPG-SSD -StorageSystem ThreePAR-2 | New-OVStorageVolumeTemplate -Capacity 100 -Name SVT-3PAR-Shared-2 -ProvisionType Thin -Shared
    Get-OVStoragePool CPG-SSD -StorageSystem ThreePAR-1 | New-OVStorageVolumeTemplate -Capacity 100 -Name SVT-Demo-Shared-TPDD-1 -ProvisionType Thin -EnableDeduplication $true -Shared #-EnableCompression $true
    Get-OVStoragePool CPG-SSD -StorageSystem ThreePAR-2 | New-OVStorageVolumeTemplate -Capacity 100 -Name SVT-Demo-Shared-TPDD-2 -ProvisionType Thin -EnableDeduplication $true -Shared #-EnableCompression $true

    Write-Output "Adding 3PAR Storage Volumes" | Timestamp
    Get-OVStoragePool FST_CPG1 -StorageSystem ThreePAR-1 | New-OVStorageVolume -Capacity 200 -Name Demo-Volume-1 | Wait-OVTaskComplete
    Get-OVStoragePool FST_CPG1 -StorageSystem ThreePAR-2 | New-OVStorageVolume -Capacity 200 -Name Shared-Volume-1 -Shared | Wait-OVTaskComplete
    Get-OVStoragePool FST_CPG1 -StorageSystem ThreePAR-2 | New-OVStorageVolume -Capacity 200 -Name Shared-Volume-2 -Shared | Wait-OVTaskComplete

    Write-Output "Adding StoreVirtual Storage Systems" | Timestamp
    $SVNet1 = Get-OVNetwork -Name SVCluster-1 -ErrorAction Stop
    Add-OVStorageSystem -Hostname 172.18.30.1 -Family StoreVirtual -Password dcs -Username dcs -VIPS @{ "172.18.30.1" = $SVNet1 } | Wait-OVTaskComplete
    $SVNet2 = Get-OVNetwork -Name SVCluster-2 -ErrorAction Stop
    Add-OVStorageSystem -Hostname 172.18.30.2 -Family StoreVirtual -Password dcs -Username dcs -VIPS @{ "172.18.30.2" = $SVNet2 } | Wait-OVTaskComplete
    $SVNet3 = Get-OVNetwork -Name SVCluster-3 -ErrorAction Stop
    Add-OVStorageSystem -Hostname 172.18.30.3 -Family StoreVirtual -Password dcs -Username dcs -VIPS @{ "172.18.30.3" = $SVNet3 } | Wait-OVTaskComplete

    Write-Output "Adding StoreVirtual Storage Volume Templates" | Timestamp
    Get-OVStoragePool Cluster-1 -StorageSystem Cluster-1 | New-OVStorageVolumeTemplate -Capacity 100 -Name SVT-StoreVirt-1 -ProvisionType Thin -Shared
    Get-OVStoragePool Cluster-2 -StorageSystem Cluster-2 | New-OVStorageVolumeTemplate -Capacity 100 -Name SVT-StoreVirt-2 -ProvisionType Thin -Shared
    Get-OVStoragePool Cluster-3 -StorageSystem Cluster-3 | New-OVStorageVolumeTemplate -Capacity 100 -Name SVT-StoreVirt-3 -ProvisionType Thin -Shared

    Write-Output "Storage Configuration Complete" | Timestamp
}


function Rename_Enclosures {
    Write-Output "Renaming Enclosures" | Timestamp
    $Enc = Get-OVEnclosure -Name 0000A66101 -ErrorAction SilentlyContinue
    Set-OVEnclosure -Name Synergy-Encl-1 -Enclosure $Enc | Wait-OVTaskComplete

    $Enc = Get-OVEnclosure -Name 0000A66102 -ErrorAction SilentlyContinue
    Set-OVEnclosure -Name Synergy-Encl-2 -Enclosure $Enc | Wait-OVTaskComplete

    $Enc = Get-OVEnclosure -Name 0000A66103 -ErrorAction SilentlyContinue
    Set-OVEnclosure -Name Synergy-Encl-3 -Enclosure $Enc | Wait-OVTaskComplete

    # $Enc = Get-OVEnclosure -Name 0000A66104 -ErrorAction SilentlyContinue
    # Set-OVEnclosure -Name Synergy-Encl-4 -Enclosure $Enc | Wait-OVTaskComplete

    # $Enc = Get-OVEnclosure -Name 0000A66105 -ErrorAction SilentlyContinue
    # Set-OVEnclosure -Name Synergy-Encl-5 -Enclosure $Enc | Wait-OVTaskComplete

    Write-Output "All Enclosures Renamed" | Timestamp
}


function Create_Uplink_Sets {
    Write-Output "Adding Fibre Channel and FCoE Uplink Sets" | Timestamp
    $LIGFlex = Get-OVLogicalInterconnectGroup -Name "LIG-FlexFabric"
    $SAN_A_FC = Get-OVNetwork -Name "SAN A FC"
    New-OVUplinkSet -Resource $LIGFlex -Name "SAN-A-FC" -Type FibreChannel -Networks $SAN_A_FC -UplinkPorts "Enclosure1:BAY3:Q2.1" | Wait-OVTaskComplete

    $LIGFlex = Get-OVLogicalInterconnectGroup -Name "LIG-FlexFabric"
    $SAN_B_FC = Get-OVNetwork -Name "SAN B FC"
    New-OVUplinkSet -Resource $LIGFlex -Name "SAN-B-FC" -Type FibreChannel -Networks $SAN_B_FC -UplinkPorts "Enclosure2:BAY6:Q2.1" | Wait-OVTaskComplete

    Write-Output "Adding FlexFabric Uplink Sets" | Timestamp
    $LIGFlex = Get-OVLogicalInterconnectGroup -Name "LIG-FlexFabric"
    $Mgmt = Get-OVNetwork -Name "Mgmt"
    New-OVUplinkSet -Resource $LIGFlex -Name "Mgmt" -Type Ethernet -Networks $Mgmt -UplinkPorts "Enclosure1:Bay3:Q1.2", "Enclosure2:Bay6:Q1.2" | Wait-OVTaskComplete

    $LIGFlex = Get-OVLogicalInterconnectGroup -Name "LIG-FlexFabric"
    $Prod_Nets = Get-OVNetwork -Name "Prod*"
    New-OVUplinkSet -Resource $LIGFlex -Name "Prod" -Type Ethernet -Networks $Prod_Nets -UplinkPorts "Enclosure1:Bay3:Q1.4", "Enclosure2:Bay6:Q1.4" | Wait-OVTaskComplete

    # Write-Output "Adding ImageStreamer Uplink Sets" | Timestamp
    # $ImageStreamerDeploymentNetworkObject = Get-OVNetwork -Name "Deployment" -ErrorAction Stop
    # Get-OVLogicalInterconnectGroup -Name "LIG-FlexFabric" -ErrorAction Stop | New-OVUplinkSet -Name "US-Image Streamer" -Type ImageStreamer -Networks $ImageStreamerDeploymentNetworkObject -UplinkPorts "Enclosure1:Bay3:Q5.1", "Enclosure1:Bay3:Q6.1", "Enclosure2:Bay6:Q5.1", "Enclosure2:Bay6:Q6.1" | Wait-OVTaskComplete

    Write-Output "All Uplink Sets Configured" | Timestamp
}


function Create_Enclosure_Group {
    $3FrameVCLIG = Get-OVLogicalInterconnectGroup -Name LIG-FlexFabric
    $SasLIG = Get-OVLogicalInterconnectGroup -Name LIG-SAS
    $FcLIG = Get-OVLogicalInterconnectGroup -Name LIG-FC
    New-OVEnclosureGroup -name "EG-Synergy-Local" -LogicalInterconnectGroupMapping @{Frame1 = $3FrameVCLIG, $SasLIG, $FcLIG; Frame2 = $3FrameVCLIG, $SasLIG, $FcLIG; Frame3 = $3FrameVCLIG, $SasLIG, $FcLIG } -EnclosureCount 3 -IPv4AddressType External # -DeploymentNetworkType Internal

    Write-Output "Enclosure Group Created" | Timestamp
}


function Create_Enclosure_Group_Remote {
    $2FrameVCLIG_1 = Get-OVLogicalInterconnectGroup -Name LIG-FlexFabric-Remote-1
    $2FrameVCLIG_2 = Get-OVLogicalInterconnectGroup -Name LIG-FlexFabric-Remote-2
    $FcLIG = Get-OVLogicalInterconnectGroup -Name LIG-FC-Remote
    New-OVEnclosureGroup -name "EG-Synergy-Remote" -LogicalInterconnectGroupMapping @{Frame1 = $FcLIG, $2FrameVCLIG_1, $2FrameVCLIG_2; Frame2 = $FcLIG, $2FrameVCLIG_1, $2FrameVCLIG_2 } -EnclosureCount 2

    Write-Output "Enclosure Group Created" | Timestamp
}


function Create_Logical_Enclosure {
    Write-Output "Creating Local Logical Enclosure" | Timestamp
    $EG = Get-OVEnclosureGroup -Name EG-Synergy-Local
    $Encl = Get-OVEnclosure -Name Synergy-Encl-1
    New-OVLogicalEnclosure -EnclosureGroup $EG -Name LE-Synergy-Local -Enclosure $Encl | Wait-OVTaskComplete
    Write-Output "Logical Enclosure Created" | Timestamp
}


function Create_Logical_Enclosure_Remote {
    Write-Output "Creating Remote Logical Enclosure" | Timestamp
    $EG = Get-OVEnclosureGroup -Name EG-Synergy-Remote
    $Encl = Get-OVEnclosure -Name Synergy-Encl-4
    New-OVLogicalEnclosure -EnclosureGroup $EG -Name LE-Synergy-Remote -Enclosure $Encl | Wait-OVTaskComplete
    Write-Output "Logical Enclosure Created" | Timestamp
}


function Create_Logical_Interconnect_Groups {
    Write-Output "Creating Local Logical Interconnect Groups" | Timestamp
    New-OVLogicalInterconnectGroup -Name "LIG-SAS" -FrameCount 1 -InterconnectBaySet 1 -FabricModuleType "SAS" -Bays @{Frame1 = @{Bay1 = "SE12SAS" ; Bay4 = "SE12SAS" } }
    New-OVLogicalInterconnectGroup -Name "LIG-FC" -FrameCount 1 -InterconnectBaySet 2 -FabricModuleType "SEVCFC" -Bays @{Frame1 = @{Bay2 = "SEVC16GbFC" ; Bay5 = "SEVC16GbFC" } }
    New-OVLogicalInterconnectGroup -Name "LIG-FlexFabric" -FrameCount 3 -InterconnectBaySet 3 -FabricModuleType "SEVC40F8" -Bays @{Frame1 = @{Bay3 = "SEVC40f8" ; Bay6 = "SE20ILM" }; Frame2 = @{Bay3 = "SE20ILM"; Bay6 = "SEVC40f8" }; Frame3 = @{Bay3 = "SE20ILM"; Bay6 = "SE20ILM" } } -FabricRedundancy "HighlyAvailable"
    Write-Output "Logical Interconnect Groups Created" | Timestamp
}


function Create_Logical_Interconnect_Groups_Remote {
    Write-Output "Creating Remote Logical Interconnect Groups" | Timestamp
    New-OVLogicalInterconnectGroup -Name "LIG-FC-Remote" -FrameCount 1 -InterconnectBaySet 1 -FabricModuleType "SEVCFC" -Bays @{Frame1 = @{Bay1 = "SEVC16GbFC" ; Bay4 = "SEVC16GbFC" } }
    New-OVLogicalInterconnectGroup -Name "LIG-FlexFabric-Remote-1" -FrameCount 2 -InterconnectBaySet 2 -FabricModuleType "SEVC40F8" -Bays @{Frame1 = @{Bay2 = "SEVC40f8" ; Bay5 = "SE20ILM" }; Frame2 = @{Bay2 = "SE20ILM"; Bay5 = "SEVC40F8" } } -FabricRedundancy "HighlyAvailable"
    New-OVLogicalInterconnectGroup -Name "LIG-FlexFabric-Remote-2" -FrameCount 2 -InterconnectBaySet 3 -FabricModuleType "SEVC40F8" -Bays @{Frame1 = @{Bay3 = "SEVC40f8" ; Bay6 = "SE20ILM" }; Frame2 = @{Bay3 = "SE20ILM"; Bay6 = "SEVC40F8" } } -FabricRedundancy "HighlyAvailable"
    Write-Output "Logical Interconnect Groups Created" | Timestamp
}

function Add_Licenses {
    Write-Output "Adding OneView and Synergy FC Licenses" | Timestamp

    $License_File = Read-Host -Prompt "Optional: Enter Filename Containing OneView and Synergy FC Licenses"
    if ($License_File) {
        New-OVLicense -File $License_File
    }

    Write-Output "All Licenses Added" | Timestamp
            
}


function Add_Firmware_Bundle {
    Write-Output "Adding Firmware Bundles" | Timestamp
    $firmware_bundle = Read-Host "Optional: Specify location of Service Pack for ProLiant ISO file"
    if ($firmware_bundle) {
        if (Test-Path $firmware_bundle) {
            Add-OVBaseline -File $firmware_bundle | Wait-OVTaskComplete
        }
        else {
            Write-Output "Service Pack for ProLiant file '$firmware_bundle' not found.  Skipping firmware upload."
        }
    }

    Write-Output "Firmware Bundle Added" | Timestamp
}


function Create_OS_Deployment_Server {
    Write-Output "Configuring OS Deployment Servers" | Timestamp
    $ManagementNetwork = Get-OVNetwork -Type Ethernet -Name "Mgmt"
    Get-OVImageStreamerAppliance | Select-Object -First 1 | New-OVOSDeploymentServer -Name "LE1 Image Streamer" -ManagementNetwork $ManagementNetwork -Description "Image Streamer for Logical Enclosure 1" | Wait-OVTaskComplete
    Write-Output "OS Deployment Server Configured" | Timestamp
}


function Create_Server_Profile_Template_SY480_Gen9_RHEL_Local_Boot {
    Write-Output "Creating SY480 Gen9 with Local Boot for RHEL Server Profile Template" | Timestamp

    $SHT = Get-OVServerHardwareTypes -Name "SY 480 Gen9 1" -ErrorAction Stop
    $EnclGroup = Get-OVEnclosureGroup -Name "EG-Synergy-Local" -ErrorAction Stop
    $Eth1 = Get-OVNetwork -Name "Mgmt" | New-OVServerProfileConnection -ConnectionID 1 -Name 'Mgmt-1' 
    $Eth2 = Get-OVNetwork -Name "Mgmt" | New-OVServerProfileConnection -ConnectionID 2 -Name 'Mgmt-2' 
    $Eth3 = Get-OVNetworkSet -Name "Prod" | New-OVServerProfileConnection -ConnectionID 3 -Name 'Prod-NetworkSet-1' 
    $Eth4 = Get-OVNetworkset -Name "Prod" | New-OVServerProfileConnection -ConnectionID 4 -Name 'Prod-NetworkSet-2' 
    $LogicalDisk = New-OVServerProfileLogicalDisk -Name "SAS RAID1 SSD" -RAID RAID1 -NumberofDrives 2 -DriveType SASSSD -Bootable $True
    $StorageController = New-OVServerProfileLogicalDiskController -ControllerID Embedded -Mode RAID -Initialize -LogicalDisk $LogicalDisk

    $params = @{
        Affinity                 = "Bay";
        BootMode                 = "BIOS";
        BootOrder                = "HardDisk";
        Connections              = $Eth1, $Eth2, $Eth3, $Eth4;
        Description              = "Server Profile Template for HPE Synergy 480 Gen9 Compute Module with Local Boot for RHEL";
        EnclosureGroup           = $EnclGroup;
        Firmware                 = $False;
        FirmwareMode             = "FirmwareOffline";
        HideUnusedFlexNics       = $True;
        LocalStorage             = $True;
        HostOStype               = "RHEL";
        ManageBoot               = $True;
        Name                     = "HPE Synergy 480 Gen9 with Local Boot for RHEL Template";
        SANStorage               = $False;
        ServerHardwareType       = $SHT;
        ServerProfileDescription = "Server Profile for HPE Synergy 480 Gen9 Compute Module with Local Boot for RHEL";
        StorageController        = $StorageController;
        StorageVolume            = $LogicalDisk
    }

    New-OVServerProfileTemplate @params | Wait-OVTaskComplete
    Write-Output "SY480 Gen9 with Local Boot for RHEL Server Profile Template Created" | Timestamp
}


function Create_Server_Profile_SY480_Gen9_RHEL_Local_Boot {
    Write-Output "Creating SY480 Gen9 Local Boot for RHEL Server Profile" | Timestamp

    $SHT = Get-OVServerHardwareTypes -Name "SY 480 Gen9 1" -ErrorAction Stop
    $Template = Get-OVServerProfileTemplate -Name "HPE Synergy 480 Gen9 with Local Boot for RHEL Template" -ErrorAction Stop
    $Server = Get-OVServer -ServerHardwareType $SHT -NoProfile -ErrorAction Stop | Select-Object -First 1

    $params = @{
        AssignmentType        = "Server";
        Description           = "HPE Synergy 480 Gen9 Server with Local Boot for RHEL";
        Name                  = "SY480-Gen9-RHEL-Local-Boot";
        Server                = $Server;
        ServerProfileTemplate = $Template
    }

    New-OVServerProfile @params | Wait-OVTaskComplete
    Write-Output "SY480 Gen9 Local Boot for RHEL Server Profile Created" | Timestamp
}


function Create_Server_Profile_Template_SY660_Gen9_Windows_SAN_Storage {
    Write-Output "Creating SY660 Gen9 with Local Boot and SAN Storage for Windows Server Profile Template" | Timestamp

    $SHT = Get-OVServerHardwareTypes -Name "SY 660 Gen9 1" -ErrorAction Stop
    $EnclGroup = Get-OVEnclosureGroup -Name "EG-Synergy-Local" -ErrorAction Stop
    $Eth1 = Get-OVNetworkSet -Name "Prod" | New-OVServerProfileConnection -ConnectionID 1 -Name 'Prod-NetworkSet-1' #-PortId "Mezz 3:1-c"
    $Eth2 = Get-OVNetworkset -Name "Prod" | New-OVServerProfileConnection -ConnectionID 2 -Name 'Prod-NetworkSet-2' #-PortId "Mezz 3:2-c"
    $FC1 = Get-OVNetwork -Name 'SAN A FC' | New-OVServerProfileConnection -connectionId 3
    $FC2 = Get-OVNetwork -Name 'SAN B FC' | New-OVServerProfileConnection -connectionId 4
    $LogicalDisk = New-OVServerProfileLogicalDisk -Name "SAS RAID5 SSD" -RAID RAID5 -NumberofDrives 3 -DriveType SASSSD -Bootable $True
    $SANVol = Get-OVStorageVolume -Name "Shared-Volume-2" | New-OVServerProfileAttachVolume -VolumeID 1 
    $StorageController = New-OVServerProfileLogicalDiskController -ControllerID Embedded -Mode RAID -Initialize -LogicalDisk $LogicalDisk

    $params = @{
        Affinity                 = "Bay";
        BootMode                 = "BIOS";
        BootOrder                = "HardDisk";
        Connections              = $Eth1, $Eth2, $FC1, $FC2;
        Description              = "Server Profile Template for HPE Synergy 660 Gen9 Compute Module with Local Boot and SAN Storage for Windows";
        EnclosureGroup           = $EnclGroup;
        Firmware                 = $False;
        FirmwareMode             = "FirmwareOffline";
        HideUnusedFlexNics       = $True;
        LocalStorage             = $True;
        HostOStype               = "Win2k12";
        ManageBoot               = $True;
        Name                     = "HPE Synergy 660 Gen9 with Local Boot and SAN Storage for Windows Template";
        SANStorage               = $True;
        ServerHardwareType       = $SHT;
        ServerProfileDescription = "Server Profile for HPE Synergy 660 Gen9 Compute Module with Local Boot and SAN Storage for Windows";
        StorageController        = $StorageController;
        StorageVolume            = $SANVol
    }

    New-OVServerProfileTemplate @params | Wait-OVTaskComplete
    Write-Output "SY660 Gen9 with Local Boot and SAN Storage for Windows Server Profile Template Created" | Timestamp
}


function Create_Server_Profile_SY660_Gen9_Windows_SAN_Storage {
    Write-Output "Creating SY660 Gen9 with Local Boot and SAN Storage for Windows Server Profile" | Timestamp

    $SHT = Get-OVServerHardwareTypes -Name "SY 660 Gen9 1" -ErrorAction Stop
    $Template = Get-OVServerProfileTemplate -Name "HPE Synergy 660 Gen9 with Local Boot and SAN Storage for Windows Template" -ErrorAction Stop
    $Server = Get-OVServer -ServerHardwareType $SHT -NoProfile -ErrorAction Stop | Select-Object -First 1

    $params = @{
        AssignmentType        = "Server";
        Description           = "HPE Synergy 660 Gen9 Server with Local Boot and SAN Storage for Windows";
        Name                  = "SY660-Gen9-Windows-Local-Boot-and-SAN-Storage";
        Server                = $Server;
        ServerProfileTemplate = $Template
    }

    New-OVServerProfile @params | Wait-OVTaskComplete
    Write-Output "SY660 Gen9 with Local Boot and SAN Storage for Windows Server Profile Created" | Timestamp
}


function Create_Server_Profile_Template_SY480_Gen9_ESX_SAN_Boot {
    Write-Output "Creating SY480 Gen9 with SAN Boot for ESX Server Profile Template" | Timestamp

    $SHT = Get-OVServerHardwareTypes -Name "SY 480 Gen9 2" -ErrorAction Stop
    $EnclGroup = Get-OVEnclosureGroup -Name "EG-Synergy-Local" -ErrorAction Stop
    $Eth1 = Get-OVNetworkSet -Name "Prod" | New-OVServerProfileConnection -ConnectionID 1 -Name 'Prod-NetworkSet-1' -PortId "Mezz 3:1-c"
    $Eth2 = Get-OVNetworkset -Name "Prod" | New-OVServerProfileConnection -ConnectionID 2 -Name 'Prod-NetworkSet-2' -PortId "Mezz 3:2-c"
    $FC1 = Get-OVNetwork -Name 'SAN A FC' | New-OVServerProfileConnection -ConnectionID 3 -Bootable -Priority Primary -BootVolumeSource ManagedVolume -ConnectionType FibreChannel
    $FC2 = Get-OVNetwork -Name 'SAN B FC' | New-OVServerProfileConnection -ConnectionID 4 -Bootable -Priority Secondary -BootVolumeSource ManagedVolume -ConnectionType FibreChannel
    $StoragePool = Get-OVStoragePool -Name FST_CPG1 -StorageSystem ThreePAR-1 -ErrorAction Stop
    $SANVol = New-OVServerProfileAttachVolume -Name BootVol -StoragePool $StoragePool -BootVolume -Capacity 100 -LunIdType Auto

    $params = @{
        Affinity                 = "Bay";
        BootMode                 = "BIOS";
        BootOrder                = "HardDisk";
        Connections              = $Eth1, $Eth2, $FC1, $FC2;
        Description              = "Server Profile Template for HPE Synergy 480 Gen9 Compute Module with SAN Boot for ESX";
        EnclosureGroup           = $EnclGroup;
        Firmware                 = $False;
        FirmwareMode             = "FirmwareOffline";
        HideUnusedFlexNics       = $True;
        LocalStorage             = $True;
        HostOStype               = "VMware";
        ManageBoot               = $True;
        Name                     = "HPE Synergy 480 Gen9 with SAN Boot for ESX Template";
        SANStorage               = $True;
        ServerHardwareType       = $SHT;
        ServerProfileDescription = "Server Profile for HPE Synergy 480 Gen9 Compute Module with SAN Boot for ESX";
        StorageVolume            = $SANVol
    }

    New-OVServerProfileTemplate @params | Wait-OVTaskComplete
    Write-Output "SY480 Gen9 with SAN Boot for ESX Server Profile Template Created" | Timestamp
}


function Create_Server_Profile_SY480_Gen9_ESX_SAN_Boot {
    Write-Output "Creating SY480 Gen9 SAN Boot for ESX Server Profile" | Timestamp

    $SHT = Get-OVServerHardwareTypes -Name "SY 480 Gen9 2" -ErrorAction Stop
    $Template = Get-OVServerProfileTemplate -Name "HPE Synergy 480 Gen9 with SAN Boot for ESX Template" -ErrorAction Stop
    $Server = Get-OVServer -ServerHardwareType $SHT -NoProfile -ErrorAction Stop | Select-Object -First 1

    $params = @{
        AssignmentType        = "Server";
        Description           = "HPE Synergy 480 Gen9 Server with SAN Boot for ESX";
        Name                  = "SY480-Gen9-ESX-SAN-Boot";
        Server                = $Server;
        ServerProfileTemplate = $Template
    }

    New-OVServerProfile @params | Wait-OVTaskComplete
    Write-Output "SY480 Gen9 with SAN Boot for ESX Server Profile Created" | Timestamp
}


function Create_Server_Profile_Template_SY480_Gen10_ESX_SAN_Boot {
    Write-Output "Creating SY480 Gen10 with SAN Boot for ESX Server Profile Template" | Timestamp

    $SHT = Get-OVServerHardwareTypes -Name "SY 480 Gen10 1" -ErrorAction Stop
    $EnclGroup = Get-OVEnclosureGroup -Name "EG-Synergy-Local" -ErrorAction Stop
    $Eth1 = Get-OVNetworkSet -Name "Prod" | New-OVServerProfileConnection -ConnectionID 1 -Name 'Prod-NetworkSet-1' -PortId "Mezz 3:1-c"
    $Eth2 = Get-OVNetworkset -Name "Prod" | New-OVServerProfileConnection -ConnectionID 2 -Name 'Prod-NetworkSet-2' -PortId "Mezz 3:2-c"
    $FC1 = Get-OVNetwork -Name 'SAN A FC' | New-OVServerProfileConnection -ConnectionID 3 -Bootable -Priority Primary -BootVolumeSource ManagedVolume -ConnectionType FibreChannel
    $FC2 = Get-OVNetwork -Name 'SAN B FC' | New-OVServerProfileConnection -ConnectionID 4 -Bootable -Priority Secondary -BootVolumeSource ManagedVolume -ConnectionType FibreChannel
    $StoragePool = Get-OVStoragePool -Name FST_CPG1 -StorageSystem ThreePAR-2 -ErrorAction Stop
    $SANVol = New-OVServerProfileAttachVolume -Name BootVol-Gen10 -StoragePool $StoragePool -BootVolume -Capacity 100 -LunIdType Auto

    #
    # Check if firmware bundles are installed.  If there are, select the last one
    # and modify the firmware-related variables in the Server Profile Template
    #
    $FW = Get-OVBaseline | Measure-Object
    if ($FW.Count -ge 1) {
        $FWBaseline = Get-OVBaseline | Select-Object -Last 1
        $params = @{
            Affinity                 = "Bay";
            Baseline                 = $FWBaseline;
            BootMode                 = "BIOS";
            BootOrder                = "HardDisk";
            Connections              = $Eth1, $Eth2, $FC1, $FC2;
            Description              = "Server Profile Template for HPE Synergy 480 Gen10 Compute Module with SAN Boot for ESX";
            EnclosureGroup           = $EnclGroup;
            Firmware                 = $True;
            FirmwareMode             = "FirmwareOffline";
            HideUnusedFlexNics       = $True;
            LocalStorage             = $True;
            HostOStype               = "VMware";
            ManageBoot               = $True;
            Name                     = "HPE Synergy 480 Gen10 with SAN Boot for ESX Template";
            SANStorage               = $True;
            ServerHardwareType       = $SHT;
            ServerProfileDescription = "Server Profile for HPE Synergy 480 Gen10 Compute Module with SAN Boot for ESX";
            StorageVolume            = $SANVol
        }
    }
    else {
        $params = @{
            Affinity                 = "Bay";
            BootMode                 = "BIOS";
            BootOrder                = "HardDisk";
            Connections              = $Eth1, $Eth2, $FC1, $FC2;
            Description              = "Server Profile Template for HPE Synergy 480 Gen10 Compute Module with SAN Boot for ESX";
            EnclosureGroup           = $EnclGroup;
            Firmware                 = $False;
            HideUnusedFlexNics       = $True;
            LocalStorage             = $True;
            HostOStype               = "VMware";
            ManageBoot               = $True;
            Name                     = "HPE Synergy 480 Gen10 with SAN Boot for ESX Template";
            SANStorage               = $True;
            ServerHardwareType       = $SHT;
            ServerProfileDescription = "Server Profile for HPE Synergy 480 Gen10 Compute Module with SAN Boot for ESX";
            StorageVolume            = $SANVol
        }
    }

    New-OVServerProfileTemplate @params | Wait-OVTaskComplete
    Write-Output "SY480 Gen10 with SAN Boot for ESX Server Profile Template Created" | Timestamp
}


function Create_Server_Profile_SY480_Gen10_ESX_SAN_Boot {
    Write-Output "Creating SY480 Gen10 SAN Boot for ESX Server Profile" | Timestamp

    $SHT = Get-OVServerHardwareTypes -Name "SY 480 Gen10 1" -ErrorAction Stop
    $Template = Get-OVServerProfileTemplate -Name "HPE Synergy 480 Gen10 with SAN Boot for ESX Template" -ErrorAction Stop
    $Server = Get-OVServer -ServerHardwareType $SHT -NoProfile -ErrorAction Stop | Select-Object -First 1

    $params = @{
        AssignmentType        = "Server";
        Description           = "HPE Synergy 480 Gen10 Server with SAN Boot for ESX";
        Name                  = "SY480-Gen10-ESX-SAN-Boot";
        Server                = $Server;
        ServerProfileTemplate = $Template
    }

    New-OVServerProfile @params | Wait-OVTaskComplete
    Write-Output "SY480 Gen10 with SAN Boot for ESX Server Profile Created" | Timestamp
}


function PowerOff_All_Servers {
    Write-Output "Powering Off All Servers" | Timestamp

    $Servers = Get-OVServer

    $Servers | ForEach-Object {
        if ($_.PowerState -ne "Off") {
            Write-Host "Server $($_.Name) is $($_.PowerState).  Powering off..." | Timestamp
            Stop-OVServer -Server $_ -Force -Confirm:$false | Wait-OVTaskComplete
        }
    }

    Write-Output "All Servers Powered Off" | Timestamp
}


function Add_Users {
    Write-Output "Adding New Users" | Timestamp

    New-OVUser -UserName BackupAdmin -FullName "Backup Administrator" -Password BackupPasswd -Roles "Backup Administrator" -EmailAddress "backup@hpe.com" -OfficePhone "(111) 111-1111" -MobilePhone "(999) 999-9999"
    New-OVUser -UserName NetworkAdmin -FullName "Network Administrator" -Password NetworkPasswd -Roles "Network Administrator" -EmailAddress "network@hpe.com" -OfficePhone "(222) 222-2222" -MobilePhone "(888) 888-8888"
    New-OVUser -UserName ServerAdmin -FullName "Server Administrator" -Password ServerPasswd -Roles "Server Administrator" -EmailAddress "server@hpe.com" -OfficePhone "(333) 333-3333" -MobilePhone "(777) 777-7777"
    New-OVUser -UserName StorageAdmin -FullName "Storage Administrator" -Password StoragePasswd -Roles "Storage Administrator" -EmailAddress "storage@hpe.com" -OfficePhone "(444) 444-4444" -MobilePhone "(666) 666-6666"
    New-OVUser -UserName SoftwareAdmin -FullName "Software Administrator" -Password SoftwarePasswd -Roles "Software Administrator" -EmailAddress "software@hpe.com" -OfficePhone "(555) 555-5555" -MobilePhone "(123) 234-3456"

    Write-Output "All New Users Added" | Timestamp
}


function Add_Scopes {
    Write-Output "Adding New Scopes" | Timestamp

    New-OVScope -Name FinanceScope -Description "Finance Scope of Resources"
    $Resources += Get-OVNetwork -Name Prod*
    $Resources += Get-OVEnclosure -Name Synergy-Encl-1
    Get-OVScope -Name FinanceScope | Add-OVResourceToScope -InputObject $Resources

    Write-Output "All New Scopes Added" | Timestamp
}


##############################################################################
#
# Main Program
#
##############################################################################

#
# Unload any earlier versions of the HPOneView POSH modules
#
# Remove-Module -ErrorAction SilentlyContinue HPOneView.120
# Remove-Module -ErrorAction SilentlyContinue HPOneView.200
# Remove-Module -ErrorAction SilentlyContinue HPOneView.300
# Remove-Module -ErrorAction SilentlyContinue HPOneView.310
# Remove-Module -ErrorAction SilentlyContinue HPOneView.400
# Remove-Module -ErrorAction SilentlyContinue HPOneView.410
# Remove-Module -ErrorAction SilentlyContinue HPOneView.420
# Remove-Module -ErrorAction SilentlyContinue HPOneView.500
# Remove-Module -ErrorAction SilentlyContinue HPOneView.520
# Remove-Module -ErrorAction SilentlyContinue HPOneView.530
# Remove-Module -ErrorAction SilentlyContinue HPOneView.540

# if (-not (Get-Module HPEOneview.550)) {
#     Import-Module -Name HPEOneView.530
# }


if (-not $ConnectedSessions) {
    $ApplianceIP = Read-Host -Prompt "Synergy Composer IP Address [$OVApplianceIP]"
    if ([string]::IsNullOrWhiteSpace($ApplianceIP)) {
        $ApplianceIP = $OVApplianceIP
    }

    $AdminName = Read-Host -Prompt "Administrator Username [$OVAdminName]"
    if ([string]::IsNullOrWhiteSpace($AdminName)) {
        $AdminName = $OVAdminName
    }

    $AdminCred = Get-Credential -UserName $AdminName -Message "Password required for the user '$AdminName'"
    if ([string]::IsNullOrWhiteSpace($AdminCred)) {
        Write-Output "Blank Credential is not permitted.  Exiting."
        Exit
    }

    Connect-OVMgmt -Hostname $ApplianceIP -Credential $AdminCred -AuthLoginDomain $OVAuthDomain -ErrorAction Stop

    if (-not $ConnectedSessions) {
        Write-Output "Login to Synergy System failed.  Exiting."
        Exit
    }
}

filter Timestamp { "$(Get-Date -Format G): $_" }


##########################################################################
#
# Configuration of the HPE Synergy Appliance
#
##########################################################################



Write-Output "Configuring HPE Synergy Appliance" | Timestamp

Add_Firmware_Bundle
Add_Licenses
Configure_Address_Pools
# Add_Remote_Enclosures
Rename_Enclosures
PowerOff_All_Servers
Configure_SAN_Managers
Configure_Networks
Add_Storage
Add_Users
# Create_OS_Deployment_Server
Create_Logical_Interconnect_Groups
Create_Uplink_Sets
Create_Enclosure_Group
Create_Logical_Enclosure
Add_Scopes

Create_Server_Profile_Template_SY480_Gen9_RHEL_Local_Boot
Create_Server_Profile_Template_SY660_Gen9_Windows_SAN_Storage
Create_Server_Profile_Template_SY480_Gen9_ESX_SAN_Boot
Create_Server_Profile_Template_SY480_Gen10_ESX_SAN_Boot

Create_Server_Profile_SY480_Gen9_RHEL_Local_Boot
Create_Server_Profile_SY660_Gen9_Windows_SAN_Storage
Create_Server_Profile_SY480_Gen9_ESX_SAN_Boot
Create_Server_Profile_SY480_Gen10_ESX_SAN_Boot

#
# Add Second Enclosure Group for Remote Enclosures
#
# Create_Logical_Interconnect_Groups_Remote
# Create_Enclosure_Group_Remote
# Create_Logical_Enclosure_Remote

Write-Output "HPE Synergy Appliance Configuration Complete" | Timestamp

Disconnect-OVMgmt
