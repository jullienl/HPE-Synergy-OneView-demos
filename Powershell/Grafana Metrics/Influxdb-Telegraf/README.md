# Influxdb/Telegraf/Grafana for HPE OneView 

This project uses Telegraf, InfluxData's data collection agent to collect and store the HPE OneView metric data in an Influxdb database.

The Telegraf exec input plugin is used to run the PowerShell scripts. 

> Note that Python scripts can also be used, provided that the server is running Python.

More information about the Exec input plugin can be found at https://github.com/influxdata/telegraf/tree/master/plugins/inputs/exec 

## Telegraf configuration 

File: `/etc/telegraf/telegraf.conf`

```
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
```

## Requirements
 - Powershell on Linux, version 7 and later, see https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-linux?view=powershell-7.3
- Grafana configured with an InfluxDB data source
- InfluxDB (with an admin account for telegraf)
- Telegraf 


