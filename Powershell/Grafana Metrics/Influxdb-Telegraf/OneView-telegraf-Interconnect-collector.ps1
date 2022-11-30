<#
PowerShell script to generate data for a Grafana metrics dashboard for HPE Virtual Connect via Telegraf/influxdb with Exec input plugin.

More information about the Exec input plugin can be found at https://github.com/influxdata/telegraf/tree/master/plugins/inputs/exec 

The script collects the utilization statistics of the given interconnect port IDs from HPE OneView REST API.  

The interconnect port IDs utilization statistics supported are: Rx Kb/s, Rx KB/s, Rx Packets/s and Rx Non-Unicast Packets/s.
            
For each interconnect port, a database measure is generated.

Requirements: 
    - Powershell on Linux 7 and later, see https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-linux?view=powershell-7.3
    - Grafana configured with an InfluxDB data source
    - InfluxDB (with an admin account for telegraf)
    - Telegraf 
        - Configuration (/etc/telegraf/telegraf.conf):
            [[outputs.influxdb]]
            ## HTTP Basic Auth
            username = "telegraf"
            password = "xxxxxxxxxxxxxxx"

            [[inputs.exec]] 
            commands = ["pwsh /scripts/OneView-telegraf-Interconnect-collector.ps1"] 
            interval = "1h" 
            timeout = "120s" 
            data_format = "influx"  

            [[inputs.exec]] 
            commands = ["pwsh /scripts/OneView-telegraf-Compute-Enclosure-collector.ps1"] 
            interval = "1h" 
            timeout = "120s" 
            data_format = "influx"  


Author: lionel.jullien@hpe.com
Date:   November 2022

   
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
    "Frame3, Interconnect 3" = @("Q1", "Q2", "Q5:1", "Q5:2", "Q5:3" )
    "Frame3, Interconnect 6" = @("Q1", "Q2", "Q5:1", "Q5:2", "Q5:3", "Q5:4" )

}


# OneView information
$OVusername = "Administrator"
$OVpassword = "P@ssw0rd"
$OVIP = "composer.lj.lab"


# MODULES TO INSTALL
# NONE

#################################################################################

# Policy settings and self-signed certificate policy validation
# [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

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

foreach ($Interconnect in $Ports.GetEnumerator()) {

    $filter = "'name'='{0}'" -f $interconnect.Name

    $url = 'https://{0}/rest/interconnects/?filter="{1}"' -f $OVIP, $filter

    $response = Invoke-RestMethod $url -Method GET -Headers $headers -SkipCertificateCheck
    $VCuri = $response.members[0].uri

    # Write-Host $Interconnect.Name
    # Write-host $Interconnect.Value    

    foreach ($port in $Interconnect.Value) {
        
        $url = 'https://{0}{1}/statistics/{2}' -f $OVIP, $VCuri, $port

        $PortStatistics = Invoke-RestMethod $url -Method GET -Headers $headers -SkipCertificateCheck

        $Interconnectname = $interconnect.name.Replace(" ", "").Replace(",", "-")
        $portname = $port.Replace(":", "-")
        $measure = $Interconnectname + "-" + $portname
           
        # Advanced statistics
        $receiveKilobitsPerSec = $PortStatistics.advancedStatistics.receiveKilobitsPerSec.Split(":")[0] -as [int]
        $receiveKilobytesPerSec = $PortStatistics.advancedStatistics.receiveKilobytesPerSec.Split(":")[0] -as [int]
        $receiveNonunicastPacketsPerSec = $PortStatistics.advancedStatistics.receiveNonunicastPacketsPerSec.Split(":")[0] -as [int]
        $receivePacketsPerSec = $PortStatistics.advancedStatistics.receivePacketsPerSec.Split(":")[0] -as [int]
    

        $metric = "$measure receiveKilobitsPerSec=$receiveKilobitsPerSec"
        Write-Host $metric
        $metric = "$measure receiveKilobytesPerSec=$receiveKilobytesPerSec"
        Write-Host $metric
        $metric = "$measure receiveNonunicastPacketsPerSec=$receiveNonunicastPacketsPerSec"
        Write-Host $metric
        $metric = "$measure receivePacketsPerSec=$receivePacketsPerSec"
        Write-Host $metric

    }
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