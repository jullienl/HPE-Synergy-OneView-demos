
   
#################################################################################
#                                Global Variables                               #
#################################################################################

# CSV File  
$csvfile = "networks_creation.csv"

#IP address of OneView
$IP = "192.168.56.101" 

# OneView Credentials
$username = "Administrator" 
$password = "password"

$LIG_UplinkSet = "US-Prod"
$networksetname = "Prod"
$LIGname = "LIG-FlexFabric"

#################################################################################


$secpasswd = ConvertTo-SecureString $password -AsPlainText -Force
$credentials = New-Object System.Management.Automation.PSCredential ($username, $secpasswd)


# Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -Confirm:$false 

# Connection to the Synergy Composer
Connect-HPOVMgmt -Hostname $IP -Credential $credentials | Out-Null

# Import of the CSV file containing VLAN name and VLAN ID
$data = (Import-Csv $csvfile)


#################################################################################
#              Creating Networks and adding them to the LIG uplink Set          #
#################################################################################


$LIG = Get-HPOVLogicalInterconnectGroup -Name $LIGname


if (!(($LIG | Measure-Object).Count -eq 1 )) { Write-Host "Failed to filter down to one LIG" -ForegroundColor Red | Break }

ForEach ($VLAN In $data) {
    New-HPOVNetwork -Name $VLAN.NetName -Type Ethernet -VLANId $VLAN.VLAN_ID -SmartLink $True | out-Null
    Write-host "`nCreating Network: " -NoNewline
    Write-host -f Cyan ($VLAN.netName) -NoNewline

    (($LIG.uplinkSets | where-object name -eq $LIG_UplinkSet | Where-Object { $_.ethernetNetworkType -eq "Tagged" }).networkUris) += (Get-HPOVNetwork -Name $VLAN.NetName).uri #Add NewNetwork to the networkUris Array
    Write-host "`nAdding Network: " -NoNewline
    Write-host -f Cyan ($VLAN.netName) -NoNewline
    Write-host " to Uplink Set: " -NoNewline
    Write-host -f Cyan $LIG_UplinkSet

}



try {
    Set-HPOVResource $LIG -ErrorAction Stop | Wait-HPOVTaskComplete #| Out-Null
}
catch {
    Write-Output $_ #.Exception
}



#################################################################################
#                            Updating LI from LIG                               #
#################################################################################

$LI = ((Get-HPOVLogicalInterconnect) | where-object logicalInterconnectGroupUri -eq $LIG.uri)


# Making sure the LI is not in updating state before we run a LI Update
$Interconnectstate = (((Get-HPOVInterconnect) | where-object productname -match "Virtual Connect") | where-object logicalInterconnectUri -EQ $LI.URI ).state  
if ($Interconnectstate -notcontains "Configured") {
    Write-host "`nWaiting for the running Interconnect configuration task to finish, please wait...`n" 
}
        
do { $Interconnectstate = (((Get-HPOVInterconnect) | where-object productname -match "Virtual Connect") | where-object logicalInterconnectUri -EQ $MyLI.uri).state }

until ($Interconnectstate -notcontains "Adding" -and $Interconnectstate -notcontains "Imported" -and $Interconnectstate -notcontains "Configuring")


Write-host "`nUpdating all Logical Interconnects from the Logical Interconnect Group: " -NoNewline
Write-host -f Cyan $LIG.name
Write-host "`nPlease wait..." 


try {
    Get-HPOVLogicalInterconnect -Name $LI.name | Update-HPOVLogicalInterconnect -confirm:$false -ErrorAction Stop | Wait-HPOVTaskComplete | Out-Null
}
catch {
    Write-Output $_ #.Exception
}


#################################################################################
#                       Adding Network to Network Set                           #
#################################################################################




ForEach ($VLAN In $data) {

    Write-host "`nAdding Network: " -NoNewline
    Write-host -f Cyan ($VLAN.netName) -NoNewline
    Write-host " to NetworkSet: " -NoNewline
    Write-host -f Cyan $networksetname
  
    
    $VLANuri = (Get-HPOVNetwork -Name $VLAN.NetName).uri
    $networkset = Get-HPOVNetworkSet -Name $networksetname
   
    $networkset.networkUris += (Get-HPOVNetwork -Name $VLAN.NetName).uri

  
    try {
        Set-HPOVNetworkSet $networkset -ErrorAction Stop | Wait-HPOVTaskComplete | Out-Null
    }
    catch {
        Write-Output $_
    }
 
 
 
    if ( (Get-HPOVNetworkSet -Name $NetworkSetname).networkUris -ccontains $VLANuri) {
        Write-host "`nThe network VLAN ID: " -NoNewline
        Write-host -f Cyan $VLAN.NetName -NoNewline
        Write-host " has been added successfully to all Server Profiles that are using the Network Set: " -NoNewline
        Write-host -f Cyan $networksetname 
    }
    else {
        Write-Warning "`nThe network VLAN ID: $($VLAN.VLAN_ID) has NOT been added successfully, check the status of your Logical Interconnect resource`n" 
    }

}
    
$ConnectedSessions | Disconnect-HPOVMgmt | Out-Null
Remove-Module (Get-Module -Name HPOneView*).Name