<#

This PowerShell can be used to generate data for a Grafana metrics dashboard for HPE BladeSystem Onboard Administrators via an Influx database.

The script collects the power usage data of all HPE BladeSystem Onboard Administrators and writes the power usage to an Influx database by providing a hashtable of 
tags and values via the REST API. 

This script is written to run continuously so that metrics are collected for an indefinite period of time and can be run in the background
from a Windows machine by using the Task Scheduler and setting a "At system startup after a 30 second delay" trigger. 
            
The Influx database is created during execution if it does not exist on the InfluxDB server. For each resource, a database measure is generated.


Requirements: 
    - PowerShell 7 or higher
    - Grafana configured with an InfluxDB data source
    - Influx Powershell Library (will be installed if it is not present)
    - HPEOACmdlets Powershell Library (will be installed if it is not present)    
    - InfluxDB 
         - With http Authentication enabled (auth-enabled = true in /etc/influxdb/influxdb.conf)
         - With port 8086 opened on the firewall (8086 is used for client-server communication over InfluxDB’s HTTP API) 
         - A user with an authentication password with ALL privileges (required to create the database if it does not exist) 
    - A Windows server to run this script. It can be executed automatically at startup using the Task Scheduler with:
        $trigger = New-JobTrigger -AtStartup -RandomDelay 00:00:30
        Register-ScheduledJob -Trigger $trigger -FilePath "C:\<path>\Grafana-Interconnect-monitoring.ps1" -Name GrafanaInterconnectMonitoring

  Author: lionel.jullien@hpe.com
  Date:   August 2023
    
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


$OA_List = @(
    "12.168.1.80",
    "12.168.1.81",
    "12.168.1.82",
    "12.168.1.83"
)

  
# InfluxDB 
$InfluxDBserver = "http://localhost:8086"
$influxdb_admin = "admin"
$influxdb_admin_password = "xxxxxxxxxxxx"
$Database = "oa_db"

# OA information
$OVAusername = "Administrator"
$OApassword = "xxxxxxxxxxxx"


# MODULES TO INSTALL

# HPEOACmdlets  
If (-not (get-module HPEOACmdlets -ListAvailable )) { Install-Module -Name HPEOACmdlets -scope CurrentUser -Force -Confirm:$False }
import-module HPEOACmdlets

# Influx  
If (-not (get-module Influx -ListAvailable )) { Install-Module -Name Influx -scope CurrentUser -Force -Confirm:$False }


#########################################################################################################

# InfluxDB database creation if not exist

$secpasswd = ConvertTo-SecureString -String $influxdb_admin_password -AsPlainText -Force
$credentials = New-Object System.Management.Automation.PSCredential ($influxdb_admin, $secpasswd)
        
# Query InfluxDB existing databases
$databases = ((Invoke-WebRequest -Uri "$InfluxDBserver/query?q=SHOW DATABASES" -Method GET -Credential $credentials -AllowUnencryptedAuthentication ).content | Convertfrom-Json).results.series.values

# If database does not exist, then let's create a new database
if ( -not ($databases | ? { $_ -eq $Database }) ) {
    Write-Debug "Database not found! Let's create one !"
    Invoke-WebRequest -Uri "$InfluxDBserver/query?q=CREATE DATABASE $Database" -Method POST -Credential $credentials -AllowUnencryptedAuthentication

}

#########################################################################################################


While ($true) {

    foreach ($OA in $OA_List) {

        $Metrics = @{}			

        $connection = $oa | Connect-HPEOA -Username $OVAusername -Password $OApassword 
    
        $PowerInfo = Get-HPEOAPower $connection
    
        $Hostname = $PowerInfo.Hostname
        [int]$PresentPower = $PowerInfo.PresentPower.Substring(0, $PowerInfo.PresentPower.length - 9)

        $Measure = $Hostname

        write-host "`nMeasure: $($Measure)"

        $Metrics += @{PresentPower = $PresentPower }					
        $Metrics | Out-Host

        Write-Influx -Measure $measure -Tags @{"OA" = $measure } -Metrics $Metrics -Database $Database -Server $InfluxDBserver -Verbose -Credential $credentials

        Disconnect-HPEOA $connection

    }

    # Gathering power data every five minutes
    Start-Sleep -Seconds 300

}
