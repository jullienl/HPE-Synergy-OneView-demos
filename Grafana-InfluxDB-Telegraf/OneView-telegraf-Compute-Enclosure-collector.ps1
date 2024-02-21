<#
PowerShell script to generate data for a Grafana metrics dashboard for servers and enclosures via Telegraf/InfluxDB with Exec input plugin.

More information about the Exec input plugin can be found at https://github.com/influxdata/telegraf/tree/master/plugins/inputs/exec 

The script collects the utilization statistics of the given resource from HPE OneView REST API. Supported resource are enclosure, server hardware and server profile.

The resource utilization metrics supported for server are CPU, power and temperature. For enclosure, it is only power and temperature.

For each resource, a database measure is generated.

Requirements: 
    - Powershell on Linux 7 and later, see https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-linux?view=powershell-7.3
    - Grafana configured with an InfluxDB data source
    - InfluxDB (with an admin account for telegraf)
    - Telegraf 
        - Configuration (/etc/telegraf/telegraf.conf):
            [[outputs.influxdb]]
            database = "telegraf"
            ## HTTP Basic Auth
            username = "telegraf"
            password = "xxxxxxxxxxxxxxx"

            [[inputs.exec]] 
            commands = ["pwsh /scripts/OneView-telegraf-Compute-Enclosure-collector.ps1"] 
            interval = "1h" 
            timeout = "120s" 
            data_format = "influx"  

            [[inputs.exec]] 
            commands = ["pwsh /scripts/OneView-telegraf-Interconnect-collector.ps1"] 
            interval = "1h" 
            timeout = "120s" 
            data_format = "influx"  

Output example of the script:
    Esx-1 CpuUtilization=30
    Esx-1 AveragePower=37
    Esx-1 AmbientTemperature=18
    Frame3-bay7 CpuUtilization=40
    Frame3-bay7 AveragePower=37
    Frame3-bay7 AmbientTemperature=18
    Frame3 AveragePower=1217
    Frame3 AmbientTemperature=21Frame2 AveragePower=819
    Frame2 AmbientTemperature=22
    Frame1 AveragePower=758
    Frame1 AmbientTemperature=23
    Frame3-bay12 CpuUtilization=13
    Frame3-bay12 AveragePower=52
    Frame3-bay12 AmbientTemperature=17
    Frame4 AveragePower=334
    Frame4 AmbientTemperature=20

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
      

# OneView information
$OVusername = "Administrator"
$OVpassword = "xxxxxxxxxxxx"
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


# Get appliance information
$appliance = Invoke-RestMethod "https://$OVIP/rest/appliance/nodeinfo/version" -Method GET -Headers $headers -SkipCertificateCheck 
$appliancetype = $appliance.platformtype

#########################################################################################################

foreach ($Resource in $Resources.GetEnumerator()) {

    # write-host "`n$($resource.key) :"

    $Measure = $resource.key.Replace(" ", "").Replace(",", "-")

    # write-host "`nMeasure: $($Measure)"

    $filter = "'name'='{0}'" -f $Resource.Name

    if ($appliancetype -ne "vm") {
        $url = 'https://{0}/rest/enclosures/?filter="{1}"' -f $OVIP, $filter
        $frameFound = Invoke-RestMethod $url -Method GET -Headers $headers -SkipCertificateCheck 
    }
    
    $url = 'https://{0}/rest/server-hardware/?filter="{1}"' -f $OVIP, $filter
    $ServerFound = Invoke-RestMethod $url -Method GET -Headers $headers -SkipCertificateCheck
    $url = 'https://{0}/rest/server-profiles/?filter="{1}"' -f $OVIP, $filter
    $ServerProfileFound = Invoke-RestMethod $url -Method GET -Headers $headers -SkipCertificateCheck

    # If ressource is a frame
    if ($frameFound.count) {
        $type = "enclosure"
    }
    # If ressource is a server hardware
    elseif ($ServerFound.count) {
        $type = "server"
    }
    # If ressource is a server profile
    elseif ($ServerProfileFound.count) {
        $type = "serverprofile" 
    }
    else {
        Write-Warning "Resource $($Resource.Name) defined not found ! Exiting..."
        return
    }

    # write-host "Type is $($type)"

    foreach ($metric in $Resource.Value) {
       
        if ( $type -eq "enclosure") {

            $url = 'https://{0}/rest/enclosures/?filter="{1}"' -f $OVIP, $filter
            $frameUri = (Invoke-RestMethod $url -Method GET -Headers $headers -SkipCertificateCheck).members[0].uri 

            if ($metric -eq "CPU") {

                Write-Warning "CPU metric is not supported for enclosures ! Exiting..."
                return

            }
            elseif ($metric -eq "Power") {

                $url = 'https://{0}{1}/utilization?fields=AveragePower' -f $OVIP, $frameUri
                $AveragePower = (Invoke-RestMethod $url -Method GET -Headers $headers -SkipCertificateCheck).metricList.metricSamples[0][1]

                $metric = "$measure AveragePower=$AveragePower"
                Write-Host $metric

            }
            elseif ($metric -eq "Temperature") {

                $url = 'https://{0}{1}/utilization?fields=AmbientTemperature' -f $OVIP, $frameUri
                $AmbientTemperature = (Invoke-RestMethod $url -Method GET -Headers $headers -SkipCertificateCheck).metricList.metricSamples[0][1] 

                $metric = "$measure AmbientTemperature=$AmbientTemperature"
                Write-Host $metric

            }


        }
        elseif ($type -eq "server") {

            $url = 'https://{0}/rest/server-hardware/?filter="{1}"' -f $OVIP, $filter
            $SHUri = (Invoke-RestMethod $url -Method GET -Headers $headers -SkipCertificateCheck).members[0].uri 

            if ($metric -eq "CPU") {

                $url = 'https://{0}{1}/utilization?fields=CpuUtilization' -f $OVIP, $SHUri
                $CpuUtilization = (Invoke-RestMethod $url -Method GET -Headers $headers -SkipCertificateCheck).metricList.metricSamples[0][1] 

                $metric = "$measure CpuUtilization=$CpuUtilization"
                Write-Host $metric

            }
            elseif ($metric -eq "Power") {

                $url = 'https://{0}{1}/utilization?fields=AveragePower' -f $OVIP, $SHUri
                $AveragePower = (Invoke-RestMethod $url -Method GET -Headers $headers -SkipCertificateCheck).metricList.metricSamples[0][1] 

                $metric = "$measure AveragePower=$AveragePower"
                Write-Host $metric

            }
            elseif ($metric -eq "Temperature") {

                $url = 'https://{0}{1}/utilization?fields=AmbientTemperature' -f $OVIP, $SHUri
                $AmbientTemperature = (Invoke-RestMethod $url -Method GET -Headers $headers -SkipCertificateCheck).metricList.metricSamples[0][1] 

                $metric = "$measure AmbientTemperature=$AmbientTemperature"
                Write-Host $metric
            }
        }
        elseif ($type -eq "serverprofile") {
            
            $filter = "'name'='{0}'" -f $Resource.Name
            $url = 'https://{0}/rest/server-profiles/?filter="{1}"' -f $OVIP, $filter
            $SPuri = (Invoke-RestMethod $url -Method GET -Headers $headers -SkipCertificateCheck).members[0].uri 
            
            $url = 'https://{0}/rest/index/associations?parentUri={1}&name=server_profiles_to_server_hardware' -f $OVIP, $SPuri
            $SHUri = (Invoke-RestMethod $url -Method GET -Headers $headers -SkipCertificateCheck).members.childUri

            if ($metric -eq "CPU") {

                $url = 'https://{0}{1}/utilization?fields=CpuUtilization' -f $OVIP, $SHUri
                $CpuUtilization = (Invoke-RestMethod $url -Method GET -Headers $headers -SkipCertificateCheck).metricList.metricSamples[0][1] 

                $metric = "$measure CpuUtilization=$CpuUtilization"
                Write-Host $metric

            }
            elseif ($metric -eq "Power") {

                $url = 'https://{0}{1}/utilization?fields=AveragePower' -f $OVIP, $SHUri
                $AveragePower = (Invoke-RestMethod $url -Method GET -Headers $headers -SkipCertificateCheck).metricList.metricSamples[0][1] 

                $metric = "$measure AveragePower=$AveragePower"
                Write-Host $metric

            }
            elseif ($metric -eq "Temperature") {

                $url = 'https://{0}{1}/utilization?fields=AmbientTemperature' -f $OVIP, $SHUri
                $AmbientTemperature = (Invoke-RestMethod $url -Method GET -Headers $headers -SkipCertificateCheck).metricList.metricSamples[0][1] 

                $metric = "$measure AmbientTemperature=$AmbientTemperature"
                Write-Host $metric

            }

        }             
        
    }

}



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