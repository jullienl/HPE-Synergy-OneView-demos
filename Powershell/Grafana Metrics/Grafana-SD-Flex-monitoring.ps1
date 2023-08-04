<#

This PowerShell can be used to generate data for a Grafana metrics dashboard for HPE Superdome Flex servers via an Influx database.

The script collects the power usage data of all chassis and writes the total power usage to an Influx database by providing a hashtable of 
tags and values via the REST API. 

This script is written to run continuously so that metrics are collected for an indefinite period of time and can be run in the background
from a Windows machine by using the Task Scheduler and setting a "At system startup after a 30 second delay" trigger. 
            
The Influx database is created during execution if it does not exist on the InfluxDB server. For each resource, a database measure is generated.


Requirements: 
    - PowerShell 7 or higher
    - Grafana configured with an InfluxDB data source
    - Influx Powershell Library (will be installed if it is not present)    
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

   
# InfluxDB 
$InfluxDBserver = "http://grafana.lab:8086"
$influxdb_admin = "admin"
$influxdb_admin_password = "password"
$Database = "ov_sdflex_db"

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
if ( -not ($databases | ? { $_ -eq $Database }) ) {
    Write-Debug "Database not found! Let's create one !"
    Invoke-WebRequest -Uri "$InfluxDBserver/query?q=CREATE DATABASE $Database" -Method POST -Credential $credentials -AllowUnencryptedAuthentication

}

#########################################################################################################

While ($true) {
     
    $url = 'https://{0}/rest/rack-managers' -f $OVIP

    $SDFlexFound = Invoke-RestMethod $url -Method GET -Headers $headers -SkipCertificateCheck
        
    foreach ($rackmanager in $SDFlexFound.members) {

        $Metrics = @{}
       
        $rackmanageruri = $rackmanager.uri
        [string]$Measure = $rackmanager.name

        $url = 'https://{0}{1}/chassis/utilization' -f $OVIP, $rackmanageruri

        $rackmanagerUtilization = Invoke-RestMethod $url -Method GET -Headers $headers -SkipCertificateCheck

        $chassisMetricList = $rackmanagerUtilization.chassisMetricData.metricList | ? metricname -eq ChassisPower

        if ($TotalChassisPower) {
            Clear-Variable  TotalChassisPower
        } 

        foreach ($chassisMetric in $chassisMetricList) {
                
            $ChassisPower = $chassisMetric.metricSamples[0][1]
            $TotalChassisPower = $TotalChassisPower + $ChassisPower 
            # "Chassis power: {0}" -f $ChassisPower 
            # "Total power: {0}" -f $TotalChassisPower

        }

        $Metrics += @{"Power" = $TotalChassisPower }
        # $Metrics | Out-Host
       
        Write-Influx -Measure $measure -Tags @{"SDFlex" = $measure } -Metrics $Metrics -Database $Database -Server $InfluxDBserver -Verbose -Credential $credentials

            
    }
         
}

# Utilization statistics are gathered and reported every five minutes by the API.
Start-Sleep -Seconds 300




# Manage your InfluxDB database
# See https://docs.influxdata.com/influxdb/v1.8/query_language/manage-database/

# Get Databases
# ((Invoke-WebRequest -Uri "$InfluxDBserver/query?q=SHOW DATABASES" -Method GET -Credential $credentials ).content | Convertfrom-Json).results.series.values

# Get a DB measurements
# $measurements = (((Invoke-WebRequest -Uri "$InfluxDBserver/query?db=$database&q=SHOW MEASUREMENTS" -Method GET -Credential $credentials).content | ConvertFrom-Json).results.series.values)

# Get all fields and tags
# ((Invoke-WebRequest -Uri "$InfluxDBserver/query?db=$database&q=SELECT * FROM 'Frame3-interconnect3'" -Method GET -Credential $credentials).content | ConvertFrom-Json).results.series

# Delete all points but not the series in the database that occur before July 20, 2022 
# https://docs.influxdata.com/influxdb/v1.8/query_language/manage-database/#delete-series-with-delete
# Invoke-WebRequest -Uri "$InfluxDBserver/query?db=$database&q=DELETE WHERE time < '2022-07-20'" -Method POST -Credential $credentials

# Delete a database with DROP DATABASE. This deletes all of the data, measurements, series, continuous queries, and retention policies from the specified database
# https://docs.influxdata.com/influxdb/v1.8/query_language/manage-database/#delete-a-database-with-drop-database
# Invoke-WebRequest -Uri "$InfluxDBserver/query?db=$database&q=DROP DATABASE $database" -Method POST -Credential $credentials




