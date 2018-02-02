
### Generates a Server Firmware report 

#IP address of OneView
$IP = "192.168.1.110" 

# OneView Credentials
$username = "Administrator" 
$password = "password" 

# Import the OneView 3.10 library

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -Confirm:$false

if (-not (get-module HPOneview.310)) {  
    Import-module HPOneview.310
}


# Connection to the Synergy Composer

If ($connectedSessions -and ($connectedSessions | ? {$_.name -eq $IP})) {
    Write-Verbose "Already connected to $IP."
}

Else {
    Try {
        Connect-HPOVMgmt -appliance $IP -UserName $username -Password $password | Out-Null
    }
    Catch {
        throw $_
    }
}

import-HPOVSSLCertificate -ApplianceConnection ($connectedSessions | ? {$_.name -eq $IP})


$servers = Get-HPOVserver | Sort-Object locationuri, {[int]$_.position}
$NewServer = "###################################################################### "
Foreach ($server in $servers)
{
echo $NewServer >> Server_FW_Report.txt
echo "              $($server.name)" >> Server_FW_Report.txt
echo $NewServer >> Server_FW_Report.txt
Get-HPOVServer -Name $server.name | Format-List position, name, mpModel, mpFirmwareVersion, model, serialNumber, processorType, memoryMb, romVersion, intelligentProvisioningVersion, state, powerState | Sort-Object -Property position | Out-File Server_FW_Report.txt -Append
(Send-HPOVRequest -Uri ($server.uri + "/firmware")).components | Format-Table componentName, componentLocation, componentVersion | Out-File Server_FW_Report.txt -Append
}


Get-Content .\Server_FW_Report.txt

