# This script provides FC Logins information found on the Synergy Virtual Connect interconnect module for all Fibre Channel uplink ports 
#
# The script tells you how many servers are logged in to a given FC uplink port and what server profiles they are. 
#
#
# Example of the output :
#
#   Virtual Connect SE 40Gb F8 Module for Synergy in Frame1, interconnect 3:
#         Uplink = Q4:1
#         (4) FC Logins:
#           WWPN: 10:00:16:ab:60:20:00:14 - Server profile: ESX-1
#           WWPN: 10:00:16:ab:60:20:00:2c - Server profile: Gen10
#           WWPN: 10:00:16:ab:60:20:00:1c - Server profile: ESX-3
#           WWPN: 10:00:16:ab:60:20:00:18 - Server profile: ESX-2

#   Virtual Connect SE 40Gb F8 Module for Synergy in Frame2, interconnect 6:
#         Uplink = Q4:1
#         (3) FC Logins:
#           WWPN: 10:00:16:ab:60:20:00:16 - Server profile: ESX-1
#           WWPN: 10:00:16:ab:60:20:00:1a - Server profile: ESX-2
#           WWPN: 10:00:16:ab:60:20:00:1e - Server profile: ESX-3
          
# Script requirements: Composer 4.20+
# OneView Powershell Library is required
#
#############################################################################################################################

#IP address of OneView
$IP = "192.168.1.110" 

# OneView Credentials
$username = "Administrator" 
$password = "password"

$secpasswd = ConvertTo-SecureString $password -AsPlainText -Force
$credentials = New-Object System.Management.Automation.PSCredential ($username, $secpasswd)
    
Clear-Host

# Import the OneView PowerShell module if needed
# Import-Module hponeview.500

$ApplianceConnection = Connect-HPOVMgmt -appliance $IP -Credential $credentials 

$LinkedFCuplinkports = (Get-HPOVInterconnect | Where-Object model -match "40G").ports | Where-Object { $_.configPortTypes -match "FibreChannel" -and $_.portstatus -eq "Linked" }

foreach ($LinkedFCuplinkport in $LinkedFCuplinkports) {
   
    $myobject = @{ }

    $myobject.uplinkname = $LinkedFCuplinkport.name

    $association = "PORT_TO_INTERCONNECT"
    $uri = "/rest/index/associations?name={0}&parentUri={1}" -f $association, $LinkedFCuplinkport.uri
    Try {
        $_IndexResults = Send-HPOVRequest -Uri $Uri -Hostname $ApplianceConnection
    }
    Catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
  
    $childuri = $_IndexResults.members.childuri
    $_FullIndexEntry = Send-HPOVRequest -Uri $childuri -Hostname $ApplianceConnection

    $myobject.productName = $_FullIndexEntry.productName
    $myobject._Name = $_FullIndexEntry.Name

    $myobject.loginsCount = $LinkedFCuplinkport.fcPortProperties.loginsCount
    $myobject.Logins = $LinkedFCuplinkport.fcPortProperties.logins

    $wwns = $myobject.Logins.Split(",")
    
    $fclogins = @{ }

    foreach ($wwpn in $wwns) {
        $serverprofilename = (Get-HPOVServerProfile | Where-Object { $_.connectionSettings.connections.wwpn -eq $wwpn }).name
        $fclogins.add($wwpn, $serverprofilename)
    }
    
    $dis_fclogins = ($fclogins.GetEnumerator() | Sort-Object values | ForEach-Object { "`t  WWPN: $($_.name) - Server profile: $($_.value)" }) -join "`n"

    "{1} in {0}:`n`tUplink = {2}`n`t({3}) FC Logins:`n{4}`n" -f $myobject._Name, $myobject.productName, $myobject.uplinkname, $myobject.loginsCount, $dis_fclogins | Write-Host -ForegroundColor Yellow 

}

Disconnect-HPOVMgmt