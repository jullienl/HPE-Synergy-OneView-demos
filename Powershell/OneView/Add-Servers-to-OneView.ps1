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


[CmdletBinding()]
param
(

    [Parameter(Position = 0, Mandatory, HelpMessage = "Please provide the path and filename of the CSV file containing the server iLO's and crednetials.")]
    [ValidateNotNullorEmpty()]
    [string]$CSV = "iLO-list.csv",

    [Parameter(Position = 1, HelpMessage = "Provide the appliance FQDN or Hostname to connect to.")]
    [String]$Hostname = "oneview.lj.lab"

)

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
[Array]$ServersList = Import-Csv $CSV

$counter = 1

#Used to store the async task object for varification later
$AsyncTaskCollection = New-Object System.Collections.ArrayList

Write-Progress -ID 1 -Activity ("Adding Servers to {0}" -f $ConnectedSessions.Name) -Status "Starting" -PercentComplete 0

$i = 1

$ServersList | % {

    #Pause the processing, as only 64 concurrent async tasks are supported by the appliance
    if ($counter -eq 64) {

        Write-Host 'Sleeping for 120 seconds.'

        1..120 | % {

            Write-Progress -id 2 -parentid 1 -Activity 'Sleeping for 2 minutes' -Status ("{ 0:mm\:ss }" -f (New-TimeSpan -Seconds $_ ))-PercentComplete (($_ / 120) * 100)

            Start-Sleep -Seconds 1

        }

        Write-Progress -Activity 'Sleeping for 2 minutes' -Completed

        #Reset counter here
        $counter = 1

    }

    Write-Progress -ID 1 -Activity ("Adding Servers to {0}" -f $ConnectedSessions.Name) -Status ("Processing {0}" -f $_.hostname) -PercentComplete ($i / $ServersList.Count * 100)

    $Credential = [System.Management.Automation.PSCredential]::new($_.account, (ConvertTo-SecureString $_.password -AsPlainText -Force))

    $Resp = Add-OVServer -hostname $_.hostname -Credential $Credential -LicensingIntent OneViewNoiLO -Async

    [void]$AsyncTaskCollection.Add($Resp)

    $counter++

}

do {
    sleep 5
} until (
    ($AsyncTaskCollection[-1] | % { Send-OVRequest $_.uri }).percentComplete -eq 100
)
Clear-Host
Write-Host 'Operation completed.'
Write-Host ("{0} servers have been imported into {1}." -f $AsyncTaskCollection.Count, $Hostname)
Write-Host 'Task status have been captured in ImportResult.txt'

$AsyncTaskCollection | % { Send-OVRequest $_.uri } | select @{N = "Server"; E = { $_.associatedresource.resourceName } }, @{N = "Created"; E = { $_.created } }, @{N = "State"; E = { $_.taskState } }, @{N = "Percent Complete"; E = { $_.percentComplete } }, @{N = "Status"; E = { $_.taskStatus } } | Sort status -Descending | Format-Table | Out-File ImportResult.txt -Append

Write-Host 'Status of the tasks:'
Get-Content ImportResult.txt