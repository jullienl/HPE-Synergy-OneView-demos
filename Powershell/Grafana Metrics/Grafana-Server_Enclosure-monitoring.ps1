
<#

This PowerShell can be used to generate data for a Grafana metrics dashboard for servers and enclosures via an Influx database.

The script collects the utilization statistics of the given resource from HPE OneView and writes data to an Influx database 
by providing a hashtable of tags and values via the REST API. Supported ressource are enclosure, server hardware and server profile.

This script is written to run continuously so that metrics are collected for an indefinite period of time and can be run in the background
from a Windows machine by using the Task Scheduler and setting a "At system startup after a 30 second delay" trigger. 

The resource utilization metrics supported for server are CPU, power and temperature. For enclosure, it is only power and temperature.
            
The Influx database is created during execution if it does not exist on the InfluxDB server. For each resource, a database measure is generated.

Note: HPE OneView and Influx Powershell Libraries will be installed if they are not installed.

Requirements: 
    - Grafana configured with an InfluxDB data source
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



# Resources to monitor
#    Resources utilization available: 
#      - Server or Server Profile : CPU, Power and Temperature
#      - Enclosure: Power and Temperature

$Resources = @{ 

    "Frame3, bay 7"  = @("CPU", "Power", "Temperature" )
    "Frame3, bay 12" = @("CPU", "Power", "Temperature" )
    "Frame1"         = @("Power", "Temperature")
    "Frame2"         = @("Power", "Temperature")
    "Frame3"         = @("Power", "Temperature")
    "Frame4"         = @("Power", "Temperature")
    "Esx-1"          = @("CPU", "Power", "Temperature" )

}
      
   
# InfluxDB 
$InfluxDBserver = "http://grafana.lab:8086"
$influxdb_admin = "admin"
$influxdb_admin_password = "password"
$Database = "ov_server_db"

# OneView 
$OneView = "composer.lab"     
$OV_username = "Administrator"
$OV_passwd = "password"

# MODULES TO INSTALL

# HPEOneView
If (-not (get-module HPEOneView.630 -ListAvailable )) { Install-Module -Name HPEOneView.630 -scope CurrentUser -Force -Confirm:$False }

# Influx  
If (-not (get-module Influx -ListAvailable )) { Install-Module -Name Influx -scope CurrentUser -Force -Confirm:$False }

#################################################################################

# Connection to HPE OneView

if (-not $ConnectedSessions) {

    try {

        #read-host  "Please enter the OneView password" -AsSecureString
        $secpasswd = ConvertTo-SecureString -String $OV_passwd -AsPlainText -Force

        # Connection to the OneView / Synergy Composer
        $credentials = New-Object System.Management.Automation.PSCredential ($OV_username, $secpasswd)
        Connect-OVMgmt -Hostname $OneView -Credential $credentials -ErrorAction stop | Out-Null    
    }
    catch {
    
        Disconnect-OVMgmt
        Connect-OVMgmt -Hostname $OneView -Credential $credentials -ErrorAction stop | Out-Null    

        #Write-Warning "Cannot connect to '$OneView'! Exiting... "
        #return
    }
}

#Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

add-type -TypeDefinition  @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@

[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy


   

#################################################################################

# InfluxDB database creation if not exist

$secpasswd = ConvertTo-SecureString -String $influxdb_admin_password -AsPlainText -Force
$credentials = New-Object System.Management.Automation.PSCredential ($influxdb_admin, $secpasswd)
        
# Query InfluxDB existing databases
$databases = ((Invoke-WebRequest -Uri "$InfluxDBserver/query?q=SHOW DATABASES" -Method GET -Credential $credentials ).content | Convertfrom-Json).results.series.values

# If database does not exist, then let's create a new database
if ( -not ($databases | ? { $_ -match $Database }) ) {
    Write-Debug "Database not found! Let's create one !"
    Invoke-WebRequest -Uri "$InfluxDBserver/query?q=CREATE DATABASE $Database" -Method POST -Credential $credentials

}


While ($true) {

    foreach ($Resource in $Resources.GetEnumerator()) {
       
        # write-host "`n$($resource.key) :"

        $Measure = $resource.key.Replace(" ", "").Replace(",", "-")

        write-host "`nMeasure: $($Measure)"

        $Metrics = @{}

        # If ressource is a frame
        if (Get-OVenclosure -name $Resource.Key -ErrorAction Ignore) {
            $type = "enclosure"
        }
        # If ressource is a server hardware
        elseif (Get-OVServer -name $Resource.Key -ErrorAction Ignore ) {
            $type = "server"
        }
        # If ressource is a server profile
        elseif (Get-OVProfile -name $Resource.Key -ErrorAction Ignore ) {
            $type = "serverprofile" 
        }

        # write-host "Type is $($type)"

        foreach ($metric in $Resource.Value) {
       
            if ( $type -eq "enclosure") {

                if ($metric -eq "CPU") {

                    Write-Warning "CPU metric is not supported for enclosures ! Exiting..."
                    return

                }
                elseif ($metric -eq "Power") {

                    $utilization = [int](Get-OVEnclosure -name $Resource.Key | Show-OVUtilization | % powercurrent | % watts)
                    $Metrics += @{Power = $utilization }

    
                }
                elseif ($metric -eq "Temperature") {

                    $utilization = [int](Get-OVEnclosure -name $Resource.Key | Show-OVUtilization | % AmbientTemperature | % Celsius)
                    $Metrics += @{Temperature = $utilization }

                }


            }
            elseif ($type -eq "server") {

                if ($metric -eq "CPU") {

                    $utilization = [int](Get-OVServer -name $Resource.Key | Show-OVUtilization | % CPUCurrent)
                    $Metrics += @{CPU = $utilization }

                }
                elseif ($metric -eq "Power") {

                    $utilization = [int](Get-OVServer -name $Resource.Key | Show-OVUtilization | % powercurrent | % watts)
                    $Metrics += @{Power = $utilization }
    
                }
                elseif ($metric -eq "Temperature") {

                    $utilization = [int](Get-OVServer -name $Resource.Key | Show-OVUtilization | % AmbientTemperature | % Celsius)
                    $Metrics += @{Temperature = $utilization }
                }
            }
            elseif ($type -eq "serverprofile") {
                
                if ($metric -eq "CPU") {

                    $utilization = [int](Get-OVServerProfile -name $Resource.Key | Show-OVUtilization | % CPUCurrent)
                    $Metrics += @{CPU = $utilization }

                }
                elseif ($metric -eq "Power") {

                    $utilization = [int](Get-OVServerProfile -name $Resource.Key | Show-OVUtilization | % powercurrent | % watts)
                    $Metrics += @{Power = $utilization }
    
                }
                elseif ($metric -eq "Temperature") {

                    $utilization = [int](Get-OVServerProfile -name $Resource.Key | Show-OVUtilization | % AmbientTemperature | % Celsius)
                    $Metrics += @{Temperature = $utilization }

                }

            }

            # write-host " - $($metric)"
                 
            
        }
        $Metrics | Out-Host

        Write-Influx -Measure $measure -Tags @{$type = $measure } -Metrics $Metrics -Database $Database -Server $InfluxDBserver -Verbose -Credential $credentials


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




