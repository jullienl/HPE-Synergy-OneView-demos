# Influxdb/Telegraf/Grafana for HPE OneView 

This project uses Telegraf, InfluxData's data collection agent to collect and store the HPE OneView metric data in an Influxdb database. 

Metrics include carbon footprint emissions, Synergy Virtual Connect module throughputs, computer utilization (CPU, power and temperature), enclosure (power and temperature) and iLO Overall Security dashboard status. 

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


## Samples of Grafana Panels

- Total Carbon Emissions in my datacenter:
 
  ![image](https://user-images.githubusercontent.com/13134334/230053661-da213aa3-0a78-4221-9573-34e8375aa106.png)

- Carbon emissions per system:

  ![image](https://user-images.githubusercontent.com/13134334/230054009-37294fa4-06e3-41cd-9b50-b54d0ba423b8.png)

- HPE iLO Overall Security Dashboard:
 
  ![image](https://user-images.githubusercontent.com/13134334/230054560-39f50864-2fa5-41ae-9e0c-4a0a6a77375a.png)

- HPE Virtual Connect Throughputs Statistics:
 
  ![image](https://user-images.githubusercontent.com/13134334/230056818-ad635d85-32eb-437a-90fa-4a3328c0a8c0.png)

- HPE Synergy Frames Ambiant Temperature:
 
  ![image](https://user-images.githubusercontent.com/13134334/230055820-862d631a-f0d1-44dc-b114-b630df0fcf5d.png)

- HPE Synergy Frames Power Consumption:
  ![image](https://user-images.githubusercontent.com/13134334/230056053-ee9dee86-a0d3-4a67-a5a9-1a0db70fe510.png)
