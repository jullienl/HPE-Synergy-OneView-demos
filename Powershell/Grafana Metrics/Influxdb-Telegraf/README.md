# Influxdb/Telegraf/Grafana for HPE OneView 

This project uses Telegraf, InfluxData's data collection agent to collect and store the HPE OneView metric data in an Influxdb database. Metrics include carbon footprint emissions, Synergy Virtual Connect module throughputs, computer utilization (CPU, power and temperature) and enclosure (power and temperature). 

The Telegraf exec input plugin is used to execute PowerShell scripts with configurable intervals. 

> Note that Python scripts can also be used, provided that the Telegraf server is running Python.

![image](https://user-images.githubusercontent.com/13134334/204871401-9c350cac-d42d-4704-a02c-22e98e63eff9.png)


More information about the Exec input plugin can be found at https://github.com/influxdata/telegraf/tree/master/plugins/inputs/exec 

## Telegraf configuration 

File: `/etc/telegraf/telegraf.conf`

```
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
```

## Grafana Dashboard

To get a Grafana dashboard already configured for HPE OneView, simply import the JSON file `Grafana Dashboard for HPE OneView.json` into Grafana.


## Requirements
- Powershell on Linux, version 7 and later, see https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-linux?view=powershell-7.3
- Grafana configured with an InfluxDB data source
- InfluxDB (with an admin account for telegraf)
- Telegraf 


