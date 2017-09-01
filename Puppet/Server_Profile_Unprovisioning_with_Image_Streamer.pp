#Vars
$server_profile_name='PUPPET-DEMO-1'
$server_hardware_name='Frame2-CN7515049L, bay 5'
$server_hardware_type='SY 480 Gen9 1'
$network_name_1='Management'
$network_name_2='iSCSI-Deployment'
$deployment_plan_name='RHEL-7.3-personalize-and-NIC-teamings'


oneview_server_hardware{'ServerHardwarePowerOn':
ensure=>'set_power_state',
data=>{
hostname=>$server_hardware_name,
power_state=>'off',
},
}


oneview_server_profile{'ServerProfileCreation':
ensure=>'absent',
data=>
{
name=>$server_profile_name,
}
}
