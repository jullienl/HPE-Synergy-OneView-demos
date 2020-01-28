# OneView Credentials and IP
$username = "Administrator" 
$password = "password" 
$IP = "192.168.56.101" 

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

#Connecting to the Synergy Composer
Connect-HPOVMgmt -appliance $IP -UserName $username -Password $password | Out-Null
               

$servers = Get-HPOVServer 

echo "Server Name; Rom Version;Component Name;Component FirmWare Version" > Server_FW_Report.txt 

foreach ($server in $servers) {

    $components = (Send-HPOVRequest -Uri ($server.uri + "/firmware")).components | % { $_.ComponentName }
    

    $name = (Get-HPOVServer -name $server.name ).name
    $romVersion = (Get-HPOVServer -name $server.name ).romVersion


    foreach ($component in $components) {

        $componentversion = (Send-HPOVRequest -Uri ($server.uri + "/firmware")).components | ? componentname -eq $component | select componentVersion | % { $_.componentVersion }
     
        "$name;$romVersion;$component;$componentversion" | Out-File Server_FW_Report.txt -Append
      
    }

}

import-csv Server_FW_Report.txt -delimiter ";" | export-csv Server_FW_Report.csv -NoTypeInformation
remove-item Server_FW_Report.txt -Confirm:$false

