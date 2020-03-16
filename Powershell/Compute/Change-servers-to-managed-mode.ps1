# Script to move all DL servers from OneView monitoring to OneView managed mode 
 

$IP = "hpeoneview.lj.lab" 
$username = "Administrator" 
$password = "password"

$ilousername = "Administrator"
$ilopassword = "password"

$secpasswd = ConvertTo-SecureString $password -AsPlainText -Force
$credentials = New-Object System.Management.Automation.PSCredential ($username, $secpasswd)
Connect-HPOVMgmt -Hostname $IP -Credential $credentials | Out-Null

$secilopasswd = ConvertTo-SecureString $ilopassword -AsPlainText -Force
$ilocredentials = New-Object System.Management.Automation.PSCredential ($ilousername, $secilopasswd)


$servers = Get-HPOVServer | where-object { $_.model -match "DL" -and $_.licensingIntent -eq "OneViewStandard" }

foreach ($server in $servers) {
    $serverIP = $server.mpHostInfo.mpIpAddresses | ? type -ne "LinkLocal" | % address
    write-host "`nRemoving from OneView management: " -NoNewline; Write-Host $server.name -f Cyan
    write-host "Please wait..."
    Remove-HPOVServer $server.name -confirm:$false -force | Wait-HPOVTaskComplete
    Add-HPOVServer -hostname $serverIP -Credential $ilocredentials  -LicensingIntent OneView # or OneViewNoiLO
    write-host "`n$($server.name)" -f Cyan -NoNewline; Write-Host " has been moved from monitored to managed mode !"
}

Disconnect-HPOVMgmt
