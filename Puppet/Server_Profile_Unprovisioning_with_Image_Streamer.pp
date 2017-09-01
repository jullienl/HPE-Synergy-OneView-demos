#Vars
$server_profile_name='PUPPET-DEMO-1'
$server_hardware_name='Frame2-CN7515049L, bay 5'


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
