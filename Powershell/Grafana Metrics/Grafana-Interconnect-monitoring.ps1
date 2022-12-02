<#

This PowerShell can be used to generate data for a Grafana metrics dashboard for HPE Virtual Connect via an Influx database.

The script collects the utilization statistics of the given interconnect port IDs from HPE OneView and writes data to an Influx database 
by providing a hashtable of tags and values via the REST API.  

This script is written to run continuously so that metrics are collected for an indefinite period of time and can be run in the background
from a Windows machine by using the Task Scheduler and setting a "At system startup after a 30 second delay" trigger. 

The interconnect port IDs utilization statistics supported are: Rx Kb/s, Rx KB/s, Rx Packets/s and Rx Non-Unicast Packets/s.
            
The Influx database is created during execution if it does not exist on the InfluxDB server. For each interconnect, a database measure is generated.


Requirements: 
    - PowerShell 7 or higher
    - Grafana configured with an InfluxDB data source
    - Influx Powershell Library (will be installed if it is not present)
    - InfluxDB 
         - With http Authentication enabled (auth-enabled = true in /etc/influxdb/influxdb.conf)
         - With port 8086 opened on the firewall (8086 is used for client-server communication over InfluxDB’s HTTP API) 
         - A user with an authentication password with ALL priviledges (required to create the database if it does not exist) 
    - A Windows server to run this script. It can be executed automatically at startup using the Task Scheduler with:
        $trigger = New-JobTrigger -AtStartup -RandomDelay 00:00:30
        Register-ScheduledJob -Trigger $trigger -FilePath "C:\<path>\Grafana-Interconnect-monitoring.ps1" -Name GrafanaInterconnectMonitoring

  Author: lionel.jullien@hpe.com
  Date:   July 2022
    
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


# Ports to monitor (Q1, Q2,..Q6 or d1, d2,..d12 or Q1:1, Q1:2, etc.)
$Ports = @{ 
    "Frame3, Interconnect 3" = @("Q1", "Q2", "Q5:1", "Q5:2", "Q5:3", "d1", "d2", "d3", "d4")
    "Frame3, Interconnect 6" = @("Q1", "Q2", "Q5:1", "Q5:2", "Q5:3", "Q5:4", "d1", "d2", "d3", "d4")
    "Frame1, Interconnect 3" = @("Q1", "Q2", "Q4:1", "Q5")

}
      
   
# InfluxDB 
$InfluxDBserver = "http://grafana.lab:8086"
$influxdb_admin = "admin"
$influxdb_admin_password = "password"
$Database = "ov_icm_db"


# OneView information
$OVusername = "Administrator"
$OVpassword = "password"
$OVIP = "composer.lab"


# MODULES TO INSTALL

# Influx  
If (-not (get-module Influx -ListAvailable )) { Install-Module -Name Influx -scope CurrentUser -Force -Confirm:$False }

#################################################################################

# Checking the PowerShell version
if ( $psversiontable.PSVersion.major -eq 5) {
    write-warning "PowerShell 5.x is not supported !"
    exit
}

# Policy settings and self-signed certificate policy validation
if ( $psversiontable.PSedition -ne "Core") {
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
}

#################################################################################

# Get-X-API-Version
$response = Invoke-RestMethod "https://$OVIP/rest/version" -Method GET -SkipCertificateCheck
$currentVersion = $response.currentVersion

# Headers creation
$headers = @{} 
$headers["X-API-Version"] = "$currentVersion"
$headers["Content-Type"] = "application/json"

# Payload creation
$body = @"
{
  "authLoginDomain": "Local",
  "password": "$OVpassword",
  "userName": "$OVusername"
}
"@

# Connection to OneView / Synergy Composer
$response = Invoke-RestMethod "https://$OVIP/rest/login-sessions" -Method POST -Headers $headers -Body $body -SkipCertificateCheck

# Capturing the OneView Session ID
$sessionID = $response.sessionID

# Add AUTH to Headers
$headers["auth"] = $sessionID

#########################################################################################################

# InfluxDB database creation if not exist

$secpasswd = ConvertTo-SecureString -String $influxdb_admin_password -AsPlainText -Force
$credentials = New-Object System.Management.Automation.PSCredential ($influxdb_admin, $secpasswd)
        
# Query InfluxDB existing databases
$databases = ((Invoke-WebRequest -Uri "$InfluxDBserver/query?q=SHOW DATABASES" -Method GET -Credential $credentials -AllowUnencryptedAuthentication ).content | Convertfrom-Json).results.series.values

# If database does not exist, then let's create a new database
if ( -not ($databases | ? { $_ -match $Database }) ) {
    Write-Debug "Database not found! Let's create one !"
    Invoke-WebRequest -Uri "$InfluxDBserver/query?q=CREATE DATABASE $Database" -Method POST -Credential $credentials -AllowUnencryptedAuthentication

}


While ($true) {

    foreach ($Interconnect in $Ports.GetEnumerator()) {

        $filter = "'name'='{0}'" -f $interconnect.Name

        $url = 'https://{0}/rest/interconnects/?filter="{1}"' -f $OVIP, $filter
    
        $response = Invoke-RestMethod $url -Method GET -Headers $headers -SkipCertificateCheck
        $VCuri = $response.members[0].uri

        # Write-Host $Interconnect.Name
        # Write-host $Interconnect.Value    

        foreach ($port in $Interconnect.Value) {

            $url = 'https://{0}{1}/statistics/{2}' -f $OVIP, $VCuri, $port

            do {
                $PortStatistics = Invoke-RestMethod $url -Method GET -Headers $headers -SkipCertificateCheck
                
            } until (
                $PortStatistics
            )
        
            $Interconnectname = $interconnect.name.Replace(" ", "").Replace(",", "-")
            $portname = $port.Replace(":", "-")
            $measure = $Interconnectname + "-" + $portname
            
            "`nMeasure: {0} " -f $measure
    
            # Advanced statistics
            $receiveKilobitsPerSec = $PortStatistics.advancedStatistics.receiveKilobitsPerSec.Split(":")[0] -as [int]
            $receiveKilobytesPerSec = $PortStatistics.advancedStatistics.receiveKilobytesPerSec.Split(":")[0] -as [int]
            $receiveNonunicastPacketsPerSec = $PortStatistics.advancedStatistics.receiveNonunicastPacketsPerSec.Split(":")[0] -as [int]
            $receivePacketsPerSec = $PortStatistics.advancedStatistics.receivePacketsPerSec.Split(":")[0] -as [int]

            $Metrics = @{
                receiveKilobitsPerSec          = $receiveKilobitsPerSec
                receiveKilobytesPerSec         = $receiveKilobytesPerSec
                receiveNonunicastPacketsPerSec = $receiveNonunicastPacketsPerSec
                receivePacketsPerSec           = $receivePacketsPerSec
    
            }
            
            $Metrics | Out-Host
            
            # Write-Influx -Measure $measure -Tags @{Interconnect = $measure } -Metrics $Metrics -Database $Database -Server $InfluxDBserver -Verbose -Credential $credentials

        }

    }

    # Utilization statistics are gathered and reported every five minutes by the API.
    Start-Sleep -Seconds 300

}


# Manage your InfluxDB database
# See https://docs.influxdata.com/influxdb/v1.8/query_language/manage-database/

# Get Databases
# ((Invoke-WebRequest -Uri "$InfluxDBserver/query?q=SHOW DATABASES" -Method GET -Credential $credentials ).content | Convertfrom-Json).results.series.values

# Get a DB measurments
# $measurements = (((Invoke-WebRequest -Uri "$InfluxDBserver/query?db=$database&q=SHOW MEASUREMENTS" -Method GET -Credential $credentials).content | ConvertFrom-Json).results.series.values)

# Get all fields and tags
# ((Invoke-WebRequest -Uri "$InfluxDBserver/query?db=$database&q=SELECT * FROM 'Frame3-interconnect3'" -Method GET -Credential $credentials).content | ConvertFrom-Json).results.series

# Delete all points but not the series in the database that occur before July 20, 2022 
# https://docs.influxdata.com/influxdb/v1.8/query_language/manage-database/#delete-series-with-delete
# Invoke-WebRequest -Uri "$InfluxDBserver/query?db=$database&q=DELETE WHERE time < '2022-07-20'" -Method POST -Credential $credentials

# Delete a database with DROP DATABASE. This deletes all of the data, measurements, series, continuous queries, and retention policies from the specified database
# https://docs.influxdata.com/influxdb/v1.8/query_language/manage-database/#delete-a-database-with-drop-database
# Invoke-WebRequest -Uri "$InfluxDBserver/query?db=$database&q=DROP DATABASE $database" -Method POST -Credential $credentials




