<# 

Script for importing multiple servers into HPE OneView.

Requirements: 
- HPE OneView administrator account
- HPE OneView Powershell Library
- CSV file with iLO information including iLO hostname or IP address, user account and password

CSV file must follow the format:

   hostname, account, password
   192.168.0.5, Administrator, 123456789
   192.168.0.19, Administrator, 0987654321

Once all import server tasks are executed, the script generates a log file ImportResult.txt which includes the following content:

   Server           Created              State     Percent Complete Status                                                 
   ------           -------              -----     ---------------- ------                                                 
   DL365G11-2-ILO   4/19/2024 9:51:07 AM Error                  100 Unable to add server: DL365G11-2-ILO                   
   ilo-LIOGW.lj.lab 4/19/2024 9:51:10 AM Completed              100 Add server: ilo-LIOGW.lj.lab.  


#################################################################################
#        (C) Copyright 2017 Hewlett Packard Enterprise Development LP           #
#################################################################################
#                                                                               #
# Permission is hereby granted, free of charge, to any person obtaining a copy  #
# of this software and associated documentation files (the "Software"), to deal #
# in the Software without restriction, including without limitation the rights  #
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell     #
# copies of the Software, and to permit persons to whom the Software is         #
# furnished to do so, subject to the following conditions:                      #
#                                                                               #
# The above copyright notice and this permission notice shall be included in    #
# all copies or substantial portions of the Software.                           #
#                                                                               #
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR    #
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,      #
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE   #
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER        #
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, #
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN     #
# THE SOFTWARE.                                                                 #
#                                                                               #
#################################################################################
#>


$CSV = "iLO-list.csv"
$serverProfileTemplatename = "RHEL_BFS_EG_100G"
$Hostname = "composer.lj.lab"

# )

if (-not(Test-Path $CSV -PathType Leaf)) {

    Write-Error ("The CSV parameter value {0} does not resolve to a file. Please check the value and try again." -f $CSV) -ErrorAction Stop

}

if (-not (get-module -ListAvailable HPEOneView.850)) {

    Import-Module HPEOneView.850

}

# First connect to the HPE OneView appliance
if (-not($ConnectedSessions)) {

    $ApplianceConnection = Connect-OVMgmt -hostname $Hostname -Credential (Get-Credential -Username Administrator -Title "OneView appliance")

}

#Read CSV of server iLO Addresses, with account credentials
[Array]$ServersList = Import-Csv $CSV -Delimiter ";"


filter timestamp { "$(Get-Date -Format o): $_" }

foreach ($server in $ServersList) {
       
    Write-Output "Powering off server $($server.hostname)" | Timestamp
     
    $OVServer = get-ovserver -Name $server.hostname
     
    if ($server.PowerState -ne "Off") {
        Write-Host "Server $($server.hostname) is $($OVServer.PowerState). Powering off..." | Timestamp
        Stop-OVServer -Server $OVServer -Force -Confirm:$false | Wait-OVTaskComplete
    }
        
     
    Write-Output "Server $($server.hostname) powered off" | Timestamp

    $serverProfileTemplate = get-ovserverprofiletemplate -Name $serverProfileTemplatename


    Write-Output "Assigning server profile template to $($server.hostname)" | Timestamp

    $SH = get-ovserver -Name $server.hostname

    $name = ($server.hostname).Replace(" ", "").Replace(",", "-")

    New-OVServerProfile -Name $name -ServerProfileTemplate $serverProfileTemplate -AssignmentType Server -Server $SH -Confirm:$False -Async
}

