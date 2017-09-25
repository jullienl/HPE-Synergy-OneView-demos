#Vars
$server_profile_name   ='PUPPET-DEMO-1'
$server_hardware_name  ='Frame2-CN7515049L, bay 4'
$server_hardware_type  ='SY 480 Gen9 1'
$network_name_1        ='Management'
$network_name_2        ='iSCSI-Deployment'
$deployment_plan_name  ='RHEL-7.3-personalize-and-NIC-teamings'

# Powering off the server in order to apply the Server Profile
oneview_server_hardware{'Server Hardware Power Off':
    ensure => 'set_power_state',
    data   => {
      hostname    => $server_hardware_name,
      power_state => 'off',
    },
}

# Create and apply a Server Profile, using Image Streamer to deploy the OS
oneview_server_profile{'ServerProfileCreation':
ensure=>'present',
data=>
{
name                    =>$server_profile_name,
serverHardwareUri       =>$server_hardware_name,
serverHardwareTypeUri   =>$server_hardware_type,
osDeploymentSettings    =>{
 osDeploymentPlanUri    =>$deployment_plan_name,
 osCustomAttributes     => [
  {
  name              => 'DomainName',
  value             => "$server_profile_name.lj.mougins.net"
  },
  {
  name              => 'Team0NIC1.connectionid',
  value             => '3'
  },
  # 'True' must be used here if 'Team0NIC1.constraint' = 'DHCP'
  {
  name              => 'Team0NIC1.dhcp',
  value             => 'False'
  },
  {
  name              => 'Team0NIC2.connectionid',
  value             => '4'
  },
  # 'Auto' to get an IP address from the OneView IP pool or 'Userspecified' to assign a static IP
  {
  name              => 'Team0NIC1.constraint',
  value             => 'Auto'
  },
  # An IP address is required here if 'Team0NIC1.constraint' = 'userspecified'
  {
  name              => 'Team0NIC1.ipaddress',
  value             => ''
  },
  # network URIs are easily retrieved using PowerShell call: (Get-HPOVNetwork -Name Management ).uri 
  {
  name              => 'Team0NIC1.networkuri',
  value             => '/rest/ethernet-networks/fe781dae-d0ba-4ac6-986f-bd9ab60877b8'
  },
  {
  name              => 'Team0NIC2.networkuri',
  value             => '/rest/ethernet-networks/fe781dae-d0ba-4ac6-986f-bd9ab60877b8'
  },
  {
  name              => 'SSH',
  value             => 'Enabled'
  },
  {
  name              => 'DiskName',
  value             => '/dev/sda'
  },
  {
  name              => 'FirstNicTeamName',
  value             => 'team0'
  },
  {
  name              => 'FirstPartitionSize',
  value             => '10'
  },
  {
  name              => 'LogicalVolumeGroupName',
  value             => 'new_vol_group'
  },
  {
  name              => 'LogicalVolumeName',
  value             => 'new_vol'
  },
  {
  name              => 'LogicalVolumeSize',
  value             => '15'
  },
  {
  name              => 'NewUsers',
  value             => 'Lionel'
  },
  {
  name              => 'SecondPartitionSize',
  value             => '10'
  },
 ]
 },
boot                =>{
manageBoot          =>true,
order               =>['HardDisk']
},
bootMode            =>{
manageMode          =>true,
pxeBootPolicy       =>'Auto',
mode                =>'UEFIOptimized',
},
connections         =>[
{
id                  =>1,
name                =>'connection1',
functionType        =>'Ethernet',
networkUri          =>$network_name_2,
requestedMbps       =>2500,
requestedVFs        =>'Auto',
boot=>{
priority            =>'Primary',
initiatorNameSource =>'ProfileInitiatorName'
}
},
{
id                  =>2,
name                =>'connection2',
functionType        =>'Ethernet',
networkUri          =>$network_name_2,
requestedMbps       =>2500,
requestedVFs        =>'Auto',
boot=>{
priority            =>'Secondary',
initiatorNameSource =>'ProfileInitiatorName'
}
},
{
id                  =>3,
name                =>'connection3',
functionType        =>'Ethernet',
networkUri          =>$network_name_1,
requestedMbps       =>2500,
requestedVFs        =>'Auto',
boot=>{
priority            =>'NotBootable',
}
},
{
id                  =>4,
name                =>'connection4',
functionType        =>'Ethernet',
networkUri          =>$network_name_1,
requestedMbps       =>2500,
requestedVFs        =>'Auto',
boot=>{
priority            =>'NotBootable',
}
}
]
}
}

# Power on the Server Hardware after the Server Profile has been applied

oneview_server_hardware{'ServerHardwarePowerOn':
ensure              =>'set_power_state',
data                =>{
hostname            =>$server_hardware_name,
power_state         =>'on',
},
}
