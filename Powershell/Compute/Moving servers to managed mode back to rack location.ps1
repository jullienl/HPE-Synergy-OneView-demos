# Script to move all DL servers from OneView monitoring to OneView managed mode and place the server back to its rack location


#Set here the OneView license type: 
$ilolicensetype = "OneView"
# 'OneView' for OneView with iLO Advanced
# 'OneViewNoiLO'for OneView without iLO Advanced
#  Note: Rack mount servers without an iLO Advanced license cannot access the remote console.


$IP = "hpeoneview-dcs.lj.lab" 
$username = "Administrator" 
$password = "password"

$ilousername = "Administrator"
$ilopassword = "password"

$secpasswd = ConvertTo-SecureString $password -AsPlainText -Force
$credentials = New-Object System.Management.Automation.PSCredential ($username, $secpasswd)
Connect-HPOVMgmt -Hostname $IP -Credential $credentials | Out-Null

$secilopasswd = ConvertTo-SecureString $ilopassword -AsPlainText -Force
$ilocredentials = New-Object System.Management.Automation.PSCredential ($ilousername, $secilopasswd)


#$models = Get-HPOVServer | select model

do {
    clear
    write-host "Which model do you want to move to managed mode?"
    write-host "1 - ProLiant DL360 Gen10"
    write-host "2 - ProLiant DL380 Gen10"
    write-host ""
    write-host "X - Exit"
    write-host ""
    write-host -nonewline "Type your choice and press Enter: "
        
    $modeltomove = read-host
        
    write-host ""
        
    $ok = $modeltomove -match '^[12x]+$'
        
    if ( -not $ok) {
        write-host "Invalid selection"
        write-host ""
    }
   
} until ( $ok )



if ($modeltomove -eq 1) { $model = "ProLiant DL360 Gen10" }

if ($modeltomove -eq 2) { $model = "ProLiant DL380 Gen10" }

Write-host "`nSelected Model: " -NoNewline ; write-host $model -ForegroundColor Cyan


$serverstomove = Get-HPOVServer | where-object { $_.model -match $model -and $_.licensingIntent -eq "OneViewStandard" }
$nbservers = ($serverstomove | measure).count

if ($nbservers -eq $False) {
    Write-host "`nNo server found !"
}
else {
    Write-host "`nNumber of servers that will be moved: " -NoNewline ; write-host $nbservers -ForegroundColor Cyan
    Write-host "Server(s) found:"
    $serverstomove.name
}



foreach ($server in $serverstomove) {
    $serverIP = $server.mpHostInfo.mpIpAddresses | ? type -ne "LinkLocal" | % address
   
    $rack = Get-HPOVRack | Where-Object { $_.rackMounts.mountUri -eq $server.uri }
 
    $rackname = $rack.name
    $servertopUSlot = ($rack.rackMounts | Where-Object mountUri -eq $server.uri ).topUSlot

    write-host "`nRemoving from OneView management: " -NoNewline; Write-Host $server.name -f Cyan
    write-host "Please wait..."
    
    try {
        Remove-HPOVServer $server.name -confirm:$false -force | Wait-HPOVTaskComplete | out-null
    }
    catch {
        write-host "$($server.name)" -f Cyan -NoNewline; Write-Host " cannot be removed from OneView !" -ForegroundColor red
        break
    }

    try { 
        write-host "Adding back to OneView management in managed mode"
        write-host "Please wait..."
        Add-HPOVServer -hostname $serverIP -Credential $ilocredentials  -LicensingIntent $ilolicensetype | Wait-HPOVTaskComplete | out-Null 
    }
    catch {
        write-warning "iLO credentials are invalid ! Server cannot be added back to OneView !"
        write-host "$($server.name)" -f Cyan -NoNewline; Write-Host " cannot be moved from monitored to managed mode !" -ForegroundColor red
        break
    }

    if ($rack -eq $Null) {
        write-host ""
        write-warning "The server cannot be found in any rack ! Adding the server back to rack cannot be completed !"
        write-host "$($server.name)" -f Cyan -NoNewline; Write-Host " has been moved from monitored to managed mode !"
    } 
    else {
        # Add back to rack in the same location
        Try {
            
            Add-HPOVResourceToRack -Rack $rack -ULocation $servertopUSlot -InputObject $server | Out-Null
      
            write-host "$($server.name)" -f Cyan -NoNewline; Write-Host " has been added successfully in managed mode and placed back in rack " -NoNewline; write-host $rackname -f cy -NoNewline; write-host " in location U " -NoNewline; write-host $servertopUSlot -f Cyan
        }
        catch { 
            
            write-host "$($server.name)" -f Cyan -NoNewline; Write-Host " has been added successfully in managed mode but could not be placed back in rack " -NoNewline; write-host $rackname -f cy 
 
        }
    }

}

Disconnect-HPOVMgmt
