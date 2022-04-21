# 
# This script provides information about the FC logins found on the HPE Synergy Virtual Connect interconnect modules for all Fibre Channel uplink ports 
# 
# The script displays on the console how many servers are connected to a given FC uplink port and what are the server information (WWPN and server profiles)
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
          
#   Requirement:
#    - HPE OneView Powershell Library
#    - HPE OneView administrator account 
# 
#
#############################################################################################################################


# OneView Credentials and IP
$OV_username = "Administrator"
$OV_IP = "composer.lj.lab"

# MODULES TO INSTALL

# HPEOneView
# If (-not (get-module HPEOneView.630 -ListAvailable )) { Install-Module -Name HPEOneView.630 -scope Allusers -Force }


#################################################################################


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

# Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force


#################################################################################
    

$LinkedFCuplinkports = (Get-OVInterconnect | Where-Object { $_.model -match "40G" -or $_.model -match "100G" } ).ports |  Where-Object { $_.fcPortProperties -and $_.portstatus -eq "Linked" }

foreach ($LinkedFCuplinkport in $LinkedFCuplinkports) {
   
    $myobject = @{ }

    $myobject.uplinkname = $LinkedFCuplinkport.name

    $association = "PORT_TO_INTERCONNECT"
    $uri = "/rest/index/associations?name={0}&parentUri={1}" -f $association, $LinkedFCuplinkport.uri
    Try {
        $_IndexResults = Send-OVRequest -Uri $Uri 
    }
    Catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
  
    $childuri = $_IndexResults.members.childuri
    $_FullIndexEntry = Send-OVRequest -Uri $childuri 

    $myobject.productName = $_FullIndexEntry.productName
    $myobject._Name = $_FullIndexEntry.Name

    $myobject.loginsCount = $LinkedFCuplinkport.fcPortProperties.loginsCount
    $myobject.Logins = $LinkedFCuplinkport.fcPortProperties.logins

    if ($myobject.Logins) {
        $wwns = $myobject.Logins.Split(",")   
    
    
        $fclogins = @{ }

        foreach ($wwpn in $wwns) {
            $serverprofilename = (Get-OVServerProfile | Where-Object { $_.connectionSettings.connections.wwpn -eq $wwpn }).name
            $fclogins.add($wwpn, $serverprofilename)
        }
    
        $dis_fclogins = ($fclogins.GetEnumerator() | Sort-Object values | ForEach-Object { "`t  WWPN: $($_.name) - Server profile: $($_.value)" }) -join "`n"

        "{1} in {0}:`n`tUplink = {2}`n`t({3}) FC Logins:`n{4}`n" -f $myobject._Name, $myobject.productName, $myobject.uplinkname, $myobject.loginsCount, $dis_fclogins | Write-Host -ForegroundColor Yellow 
    }
}

Disconnect-OVMgmt
