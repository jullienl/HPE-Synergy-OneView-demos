<#
PowerShell script to generate a carbon footprint report of all resources managed by HPE Oneview appliances (Oneview Composers 
and OneView VMs) for a Grafana metrics dashboard via Telegraf/influxdb with Exec input plugin.

More information about the Exec input plugin can be found at https://github.com/influxdata/telegraf/tree/master/plugins/inputs/exec 

The script collects the energy consumed by all resources during 24 hours via the HPE OneView REST API and the carbon footprint is then calculated using the formula: 
Watt/hour * global carbon factor (non-geo-specific emissions factor, OECD average of 344.6 gCO2/kWh). 

The script provides the total and per server 24-hour carbon emissions from all OneView appliances.

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
            commands = ["pwsh /scripts/OneView-telegraf-Carbon-Footprint-collector.ps1"] 
            interval = "24h" 
            timeout = "120s" 
            data_format = "influx"  

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

Output example of the script with two appliances:
    composer.lj.lab_Carbon_Report Frame4_TotalEmissionsPerDay=2.75
    composer.lj.lab_Carbon_Report Frame3_TotalEmissionsPerDay=10.02
    composer.lj.lab_Carbon_Report Frame1_TotalEmissionsPerDay=6.28
    composer.lj.lab_Carbon_Report Frame2_TotalEmissionsPerDay=6.79
    oneview.lj.lab_Carbon_Report esx5-3-ilo.lj.lab_TotalEmissionsPerDay=2.73
    oneview.lj.lab_Carbon_Report ilo-fdz360g10-2.lj.lab_TotalEmissionsPerDay=1.58
    oneview.lj.lab_Carbon_Report ilo-LIOGW.lj.lab_TotalEmissionsPerDay=1.15
    oneview.lj.lab_Carbon_Report ilo-RDS.lj.lab_TotalEmissionsPerDay=0.97
    oneview.lj.lab_Carbon_Report esx5-2-ilo.lj.lab_TotalEmissionsPerDay=1.74
    OneView_Carbon_Report TotalEmissionsPerDay=34.01


Author: lionel.jullien@hpe.com
Date:   December 2022

   
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

# Non-geo-specific emissions factor (gCO2/kWh)
$CarbonEmissionsFactor = 344.6
# The non-geospecific carbon emission factor due to electricity generation according to the OECD average is 344.6 gCO2/kWh


# OneView information
$OVusername = "Administrator"
$OVpassword = "password"
$OVIPs = @("composer.lj.lab", "oneview.lj.lab")


# MODULES TO INSTALL
# NONE

#################################################################################

# Policy settings and self-signed certificate policy validation
# [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

#################################################################################

$totalCarbonEmissionsFor24h = 0

foreach ($OVIP in $OVIPs) {
   
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

    # OneView or Synergy Composer?
    $appliance = Invoke-RestMethod "https://$OVIP/rest/appliance/nodeinfo/version" -Method GET -Headers $headers -SkipCertificateCheck

    # Collect enclosures if present in OneView appliance and if Synergy Composer
    $response = Invoke-RestMethod "https://$OVIP/rest/enclosures" -Method GET -Headers $headers -SkipCertificateCheck -SkipHttpErrorCheck

    # If enclosure(s), run a report for each frame
    if ($response.errorCode -notmatch "404") {

        $enclosures = $response.members

        foreach ($enclosure in $enclosures) {

            $enclosureUri = $enclosure.uri

            $enclosureName = $enclosure.name

            $url = 'https://{0}{1}/utilization?fields=AveragePower' -f $OVIP, $enclosureUri
            $enclosureMetricsamples = (Invoke-RestMethod $url -Method GET -Headers $headers -SkipCertificateCheck).metricList.metricsamples
    
            # The time value is represented as the number of milliseconds between the time and midnight January 1 1970.
            # Metricsamples cover 24 hours
            # New-Timespan –Start (([System.DateTimeOffset]::FromUnixTimeMilliseconds($enclosuremetricList.metricSamples[-1][0])).DateTime).ToString() -end    (([System.DateTimeOffset]::FromUnixTimeMilliseconds(   $enclosuremetricList.metricSamples[0][0] )).DateTime).ToString()
    
            $sumfor24h = 0
    
            foreach ($enclosureMetricsample in $enclosureMetricsamples) {
                # $enclosureMetricsample[1]
                $sumFor24h += $enclosureMetricsample[1]
            }
    
            # Average power 
            $avergePowerOver24h = $sumFor24h / ($enclosureMetricsamples.count - 1)
    
            # kWh per day (energy for 24 hours):
            # kWh = Average power (in Watt) /1000 * 24 
            $kWh = $avergePowerOver24h / 1000 * 24
   
            $carbonEmissionsFor24h = [math]::Round(($kWh * $CarbonEmissionsFactor / 1000), 2)

            $metric = "$($OVIP)_Carbon_Report $($enclosureName)_TotalEmissionsPerDay=$carbonEmissionsFor24h"
            Write-Host $metric

            # "{0} carbon emissions for 24h = {1} kgCO2e" -f $enclosureName, $carbonEmissionsFor24h 

            $totalCarbonEmissionsFor24h += $carbonEmissionsFor24h 
        }
    } 


    # If OneView appliance, we have standalone Computes as well to add to the carbon footprint report
    if ($appliance.family -match "OneView VM") {

        $response = Invoke-RestMethod "https://$OVIP/rest/server-hardware" -Method GET -Headers $headers -SkipCertificateCheck -SkipHttpErrorCheck

        # If compute(s), run a report for each compute
        if ($response.errorCode -notmatch "404") {

            $serverHardware = $response.members

            foreach ($SH in $serverHardware) {

                $SHUri = $SH.uri

                $SHName = $SH.name

                $url = 'https://{0}{1}/utilization?fields=AveragePower' -f $OVIP, $SHUri
                $SHMetricsamples = (Invoke-RestMethod $url -Method GET -Headers $headers -SkipCertificateCheck).metricList.metricsamples
    
                # The time value is represented as the number of milliseconds between the time and midnight January 1 1970.
                # Metricsamples cover 24 hours
                # New-Timespan –Start (([System.DateTimeOffset]::FromUnixTimeMilliseconds($SHMetricsamples[-1][0])).DateTime).ToString() -end (([System.DateTimeOffset]::FromUnixTimeMilliseconds($SHMetricsamples[0][0] )).DateTime).ToString()
    
                $sumfor24h = 0
    
                foreach ($SHMetricsample in $SHMetricsamples) {
                    # $enclosureMetricsample[1]
                    $sumFor24h += $SHMetricsample[1]
                }
    
                # Average power 
                $avergePowerOver24h = $sumFor24h / ($SHMetricsamples.count - 1)
    
                # kWh per day (energy for 24 hours):
                # kWh = Average power (in Watt) /1000 * 24 
                $kWh = $avergePowerOver24h / 1000 * 24

                # The non-geospecific carbon emission factor due to electricity generation according to the OECD average is 344.6 gCO2/kWh.)
    
                $carbonEmissionsFor24h = [math]::Round(($kWh * 344.6 / 1000), 2)

                $metric = "$($OVIP)_Carbon_Report $($SHName)_TotalEmissionsPerDay=$carbonEmissionsFor24h"
                Write-Host $metric

                # "{0} carbon emissions for 24h = {1} kgCO2e" -f $enclosureName, $carbonEmissionsFor24h 

                $totalCarbonEmissionsFor24h += $carbonEmissionsFor24h 
            }
        }
    }
}


# Total 24-hour carbon emissions from all OneView appliances
$metric = "OneView_Carbon_Report TotalEmissionsPerDay=$totalCarbonEmissionsFor24h"
Write-Host $metric


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