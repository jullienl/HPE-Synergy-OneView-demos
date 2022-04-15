<#

This PowerShell script creates a Server Profile Template for ESXi with Boot from local storage logical drive

The Template includes:
- 1 x Local storage (RAID 1 Logical drive using embedded storage controller)
- 2 x SAN Volumes (one for the datastore - one for the cluster Heartbeat)
- 4 Network connections (2 x Management with 4% of the slot3 adapter bandwidth - 2 x NetworkSet with 32% of the slot3 adapter bandwidth)
- 2 x Fabric connections with 64% of the slot3 adapter bandwidth
- Set firmware update using a Synergy Service Pack with Firmware only installation method
- Set iLO settings:
     - Set Administrator local account password
     - Add a iLO local account
     - Add a directory group for directory authentication
- Set Bios settings:
    - Set Workload Profile to Virtualization - Max Performance

Requirements: 
- Latest HPEOneView PowerShell library
- OneView administrator account
  

 Author: lionel.jullien@hpe.com
 Date:  April 2022

   
#################################################################################
#        (C) Copyright 2022 Hewlett Packard Enterprise Development LP           #
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


# VARIABLES

# Server Profile Template Name
$ServerProfileTemplateName = "ESXi_Boot-from-Local - HPE Synergy 480 Gen10"

# Synergy Environment settings
$ServerHardwareTypeName = "SY 480 Gen10 4"
$EnclosureGroupName = "EG_1_Frame" 
$ManagementNetwork = "Management-Nexus"
$NetworkSet = "Production_network_set"
$FabricNetworkA = "FC-A"
$FabricNetworkB = "FC-B"

$StorageSystem = "3par.lj.lab"
$StoragePoolNameFCRAID5 = "FC_r5"
$StoragePoolNameFCRAID1 = "FC_r1"
$StoragePoolNameSSDRAID5 = "SSD_r5"

# Local Storage 
$LogicalDiskName = "ESXi_Boot"
$LogicalDiskRaidLevel = "RAID1" # RAID0, RAID1, etc.
$LogicalDiskNumberPhysDrives = 2
$LogicalDiskDriveType = "Auto"  # Auto, SAS, SATA, etc.
# Local Storage controller
$LogicalDiskControllerSlot = "Embedded"  # Embedded or with D3940: Mezz 1, Mezz 2, Mezz 3
$LogicalDiskControllerMode = "RAID" # HBA or RAID
$LogicalDiskControllerInitializeLD = $True #  Re-initialize controller on next profile application. With $True, any existing data on this controller will be lost


# Existing SAN Volumes to present to host
# ESXi Datastore
$SANDataVolume = "ESXi7 Frame4 VMFS1"  # name can be found using Get-OVStorageVolume
# ESXi Cluster Heartbeat
$SANHBVolume = "ESXi7 Datastore Heartbeat"


# Synergy Service Pack version 
$SSPBaselineVersion = "SY-2022.02.01"  # version can be found using Get-OVBaseline

# Local iLO account to create
$LocalIloUsername = "Ansible"
$LocalIloUserPasswordSecureString = Read-Host "Local iLO account password for $LocalIloUsername " -AsSecureString

# Local iLO Administrator account password to set
$LocalIloAdministratorPasswordSecureString = Read-Host "Local iLO account password for Administrator" -AsSecureString

# iLO Directory settings
$DirectoryServerAddress = "dc.lj.lab"  # network DNS name or IP address of the active directory server
$DistinguishedName = "CN=ilo Admins,CN=Users,DC=lj,DC=lab"


###################################################################################################################################################################

# OneView Credentials and IP
$OV_username = "Administrator"
$OV_IP = "composer.lj.lab"


# MODULES TO INSTALL

# HPEOneView
# If (-not (get-module HPEOneView.630 -ListAvailable )) { Install-Module -Name HPEOneView.630 -scope Allusers -Force }


##################################################################################################################################################################

 
# Connection to the OneView / Synergy Composer

if (! $ConnectedSessions) {

    $secpasswd = read-host  "Please enter the OneView password" -AsSecureString
    
    $credentials = New-Object System.Management.Automation.PSCredential ($OV_username, $secpasswd)

    try {
        Connect-OVMgmt -Hostname $OV_IP -Credential $credentials -ErrorAction stop | Out-Null    
    }
    catch {
        Write-Warning "Cannot connect to '$OV_IP'! Exiting... "
        return
    }
}

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force


##################################################################################################################################################################


$SHT = Get-OVServerHardwareTypes -Name $ServerHardwareTypeName -ErrorAction Stop
$EnclGroup = Get-OVEnclosureGroup -Name $EnclosureGroupName -ErrorAction Stop
    

$maxSpeedMbps = ((Get-OVServerHardwareType -Name $ServerHardwareTypeName).adapters | ? slot -eq 3).ports[0].maxSpeedMbps

$Eth1 = Get-OVNetwork -Name $ManagementNetwork | New-OVServerProfileConnection -ConnectionID 1 -Name 'Management-1' -RequestedBW ($maxSpeedMbps * 4 / 100)
$Eth2 = Get-OVNetwork -Name $ManagementNetwork | New-OVServerProfileConnection -ConnectionID 2 -Name 'Management-2' -RequestedBW ($maxSpeedMbps * 4 / 100)
$Eth3 = Get-OVNetworkSet -Name $NetworkSet | New-OVServerProfileConnection -ConnectionID 3 -Name 'Prod-NetworkSet-1' -RequestedBW ($maxSpeedMbps * 32 / 100)
$Eth4 = Get-OVNetworkSet -Name $NetworkSet | New-OVServerProfileConnection -ConnectionID 4 -Name 'Prod-NetworkSet-2' -RequestedBW ($maxSpeedMbps * 32 / 100)
  
$FC1 = Get-OVNetwork -Name $FabricNetworkA | New-OVServerProfileConnection -ConnectionID 5 -ConnectionType FibreChannel -RequestedBW ($maxSpeedMbps * 64 / 100)
$FC2 = Get-OVNetwork -Name $FabricNetworkB | New-OVServerProfileConnection -ConnectionID 6 -ConnectionType FibreChannel -RequestedBW ($maxSpeedMbps * 64 / 100)

$StoragePool = Get-OVStoragePool -Name $StoragePoolNameFCRAID5 -StorageSystem $StorageSystem -ErrorAction Stop

# Local Storage 
$LogicalDisk1 = New-OVServerProfileLogicalDisk -Name $LogicalDiskName -Raid $LogicalDiskRaidLevel -NumberofDrives $LogicalDiskNumberPhysDrives -DriveType $LogicalDiskDriveType -Bootable $True
$LogicalDisks = $LogicalDisk1
# Local Storage controller
if ($LogicalDiskControllerInitializeLD) {
    $Storagecontroller1 = New-OVServerProfileLogicalDiskController -ControllerID $LogicalDiskControllerSlot -Mode $LogicalDiskControllerMode -Initialize -LogicalDisk $LogicalDisks
 
}
else {
    $Storagecontroller1 = New-OVServerProfileLogicalDiskController -ControllerID $LogicalDiskControllerSlot -Mode $LogicalDiskControllerMode -LogicalDisk $LogicalDisks
    
}
$Storagecontrollers = $Storagecontroller1


# SAN Storage
# Permanent Shared SAN volumes
$SANVol1 = New-OVServerProfileAttachVolume -Name $SANDataVolume -StoragePool $StoragePool -LunIdType Auto -volumeid 1 -Permanent 
$SANVol2 = New-OVServerProfileAttachVolume -Name $SANHBVolume -StoragePool $StoragePool -LunIdType Auto -volumeid 2 -Permanent

$baseline = Get-OVBaseline | ? Version -eq $SSPBaselineVersion -ErrorAction stop


# -------------- Attributes for BIOS settings -------------------

# To display BIOS Settings use
# $SHT.biosSettings 
# To search BIOS Settings by name use
# $biosSettings = $SHT.biosSettings | ? { $_.name -match "power" }
# $biosSettings = $SHT.biosSettings | ? { $_.name -match "workload" }

$biosSettings = @(
    @{id = 'MinProcIdlePower'; value = 'NoCStates' },
    @{id = 'WorkloadProfile'; value = 'Virtualization-MaxPerformance' },
    @{id = 'IntelUpiPowerManagement'; value = 'Disabled' },
    @{id = 'MinProcIdlePkgState'; value = 'NoState' },
    @{id = 'EnergyPerfBias'; value = 'MaxPerf' },
    @{id = 'UncoreFreqScaling'; value = 'Maximum' },
    @{id = 'PowerRegulator'; value = 'StaticHighPerf' },
    @{id = 'SubNumaClustering'; value = 'Enabled' },
    @{id = 'CollabPowerControl'; value = 'Disabled' },
    @{id = 'EnergyEfficientTurbo'; value = 'Disabled' },
    @{id = 'NumaGroupSizeOpt'; value = 'Clustered' }
)

# ------------------- iLO Settings Policy -------------------

# Create a local iLO account with full administrative rights
$Account1 = New-OVIloLocalUserAccount `
    -Username $LocalIloUsername `
    -Password $LocalIloUserPasswordSecureString `
    -DisplayName $LocalIloUsername `
    -AdministerUserAccounts $true `
    -RemoteConsole $True `
    -VirtualMedia $True `
    -VirtualPowerAndReset $True `
    -ConfigureIloSettings $True `
    -Login $True `
    -HostBIOS $True `
    -HostNIC $True `
    -HostStorage $True

# Configure the iLO directory (Active Directory, LDAP, or Kerberos) to enable single sign-on.

# Create group1 object
$Group1 = New-OVIloDirectoryGroup `
    -GroupDN $DistinguishedName `
    -AdministerUserAccounts $true `
    -RemoteConsole $True `
    -VirtualMedia $True `
    -VirtualPowerAndReset $True `
    -ConfigureIloSettings $True 
    
# Set the local administrator password, add the specified local account, directory authentication and directory groups and set the iLO hostname.

$iloSettings = New-OVServerProfileIloPolicy -ManageLocalAdministratorAccount `
    -LocalAdministratorPassword $LocalIloAdministratorPasswordSecureString `
    -ManageLocalAccounts `
    -LocalAccounts $Account1 `
    -ManageIloHostname `
    -ManageDirectoryConfiguration `
    -LdapSchema DirectoryDefault `
    -DirectoryServerAddress $DirectoryServerAddress `
    -DirectoryUserContext $DistinguishedName `
    -ManageDirectoryGroups `
    -DirectoryGroups $Group1 `
    -IloHostname "{serverProfileName}-ilo" 
   

# -----------------------------------------------------------------------------------------------------------------
    
# Server Profile Template configuration object   

$serverProfileTemplateParams = @{
    Affinity                       = "Bay";
    Baseline                       = $Baseline;
    Bios                           = $true;
    BiosConsistencyChecking        = "Exact";
    BiosSettings                   = $biosSettings;
    BootMode                       = "UEFIOptimized";
    BootModeConsistencyChecking    = "Exact";
    BootOrder                      = "HardDisk";
    Connections                    = $Eth1, $Eth2, $Eth3, $Eth4, $FC1, $FC2;
    ConnectionsConsistencyChecking = "Minimum";
    Description                    = "Server profile template for $($ServerHardwareTypeName)";
    EnclosureGroup                 = $EnclGroup;
    Firmware                       = $True;
    FirmwareMode                   = "FirmwareOffline";
    HideUnusedFlexNics             = $true;
    HostOStype                     = "VMware";
    IloSettings                    = $iloSettings;
    IloSettingsConsistencyChecking = "Exact";
    LocalStorage                   = $True;
    ManageBoot                     = $true;
    ManageConnections              = $True;
    ManageIloSettings              = $true;
    Name                           = $ServerProfileTemplateName;
    SANStorage                     = $True;
    SecureBoot                     = "Disabled";
    ServerHardwareType             = $SHT;
    ServerProfileDescription       = "Server Profile for $($ServerHardwareTypeName) Compute Module with SAN Boot for ESX";
    StorageController              = $Storagecontrollers;
    StorageVolume                  = $SANVol1, $SANVol2
}

# Creation of the Server Profile Template

New-OVServerProfileTemplate @serverProfileTemplateParams | Wait-OVTaskComplete


Disconnect-OVMgmt