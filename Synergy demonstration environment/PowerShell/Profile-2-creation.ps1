# -------------- Attributes for ServerProfile "Profile-1"
$name                       = "Profile-1"
$server                     = Get-HPOVServer -Name "Synergy-Encl-1, bay 11"
$affinity                   = "Bay"
# -------------- Attributes for connection "1"
$connID                     = 1
$connType                   = "Ethernet"
$netName                    = "ESX Mgmt"
$ThisNetwork                = Get-HPOVNetwork -Type Ethernet -Name $netName
$portID                     = "Mezz 3:1-a"
$requestedMbps              = 2500
$Conn1                      = New-HPOVServerProfileConnection -ConnectionID $connID -ConnectionType $connType -Network $ThisNetwork -PortId $portID -RequestedBW $requestedMbps
# -------------- Attributes for connection "2"
$connID                     = 2
$connType                   = "Ethernet"
$netName                    = "ESX Mgmt"
$ThisNetwork                = Get-HPOVNetwork -Type Ethernet -Name $netName
$portID                     = "Mezz 3:2-a"
$requestedMbps              = 2500
$Conn2                      = New-HPOVServerProfileConnection -ConnectionID $connID -ConnectionType $connType -Network $ThisNetwork -PortId $portID -RequestedBW $requestedMbps
# -------------- Attributes for connection "3"
$connID                     = 3
$connType                   = "Ethernet"
$netName                    = "Prod"
$ThisNetwork                = Get-HPOVNetworkSet -Name $netName
$portID                     = "Mezz 3:1-c"
$requestedMbps              = 2500
$Conn3                      = New-HPOVServerProfileConnection -ConnectionID $connID -ConnectionType $connType -Network $ThisNetwork -PortId $portID -RequestedBW $requestedMbps
# -------------- Attributes for connection "4"
$connID                     = 4
$connType                   = "Ethernet"
$netName                    = "Prod"
$ThisNetwork                = Get-HPOVNetworkSet -Name $netName
$portID                     = "Mezz 3:2-c"
$requestedMbps              = 2500
$Conn4                      = New-HPOVServerProfileConnection -ConnectionID $connID -ConnectionType $connType -Network $ThisNetwork -PortId $portID -RequestedBW $requestedMbps
$connections                = $Conn1, $Conn2, $Conn3, $Conn4
# -------------- Attributes for logical disk "OS_RAID(RAID1)"
$ldName                     = "OS_RAID"
$raidLevel                  = "RAID1"
$numPhysDrives              = 2
$driveTech                  = "Auto"
$LogicalDisk1               = New-HPOVServerProfileLogicalDisk -Name $ldName -Raid $raidLevel -NumberofDrives $numPhysDrives -DriveType $driveTech -Bootable $True
# -------------- Attributes for controller "Embedded" (Mixed)
$deviceSlot                 = "Embedded"
$controllerMode             = "Mixed"
$LogicalDisks               = $LogicalDisk1
$controller1                = New-HPOVServerProfileLogicalDiskController -ControllerID $deviceSlot -Mode $controllerMode -LogicalDisk $LogicalDisks
$controllers                = $controller1
# -------------- Attributes for BIOS Boot Mode settings
$manageboot                 = $True
$biosBootMode               = "UEFIOptimized"
# -------------- Attributes for BIOS order settings
$bootOrder                  = "HardDisk"
# -------------- Attributes for BIOS settings
$biosSettings               = @(
        @{id = 'WorkloadProfile'; value = 'Virtualization-MaxPerformance'},
        @{id = 'PowerRegulator'; value = 'StaticHighPerf'},
        @{id = 'MinProcIdlePower'; value = 'NoCStates'},
        @{id = 'MinProcIdlePkgState'; value = 'NoState'},
        @{id = 'EnergyPerfBias'; value = 'MaxPerf'},
        @{id = 'CollabPowerControl'; value = 'Disabled'},
        @{id = 'NumaGroupSizeOpt'; value = 'Clustered'},
        @{id = 'UncoreFreqScaling'; value = 'Maximum'},
        @{id = 'SubNumaClustering'; value = 'Enabled'},
        @{id = 'EnergyEfficientTurbo'; value = 'Disabled'},
        @{id = 'IntelUpiPowerManagement'; value = 'Disabled'}
)
# -------------- Attributes for advanced settings
New-HPOVServerProfile -Name $name -AssignmentType Server -Server $server -Affinity $affinity -Connections $connections -LocalStorage -StorageController $controllers -ManageBoot:$manageboot -BootMode $biosBootMode -BootOrder $bootOrder -Bios -BiosSettings $biosSettings -HideUnusedFlexNics $true