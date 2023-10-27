# Grafana Dashboards for various HPE products and equipments 

This project uses PowerShell scripts to collect and store various metrics data in an Influxdb database to build Grafana metrics dashboards for:
- Any HPE Compute infrastructure managed by HPE OneView (HPE Rack and blade servers, frames, SD Flex - excluding HPE Superdome Flex) [capture power peak - power average - CPU - temperature]
- HPE Virtual Connect managed by HPE OneView [capture port utilization statistics]
- Brocade switches (using the FOS REST API) [capture total power usage]
- HPE BladeSystem via HPE Onboard Administrators [capture total power usage]

These scripts collect different usage statistics depending on the type of resource. See the comments section of each script for more details.

These scripts are written to run continuously so that metrics are collected for an indefinite period of time and can be run in the background from either: 
- A Windows machine by using the Task Scheduler and setting a "At system startup after a 30 second delay" trigger.  
- A Linux machine using Powershell on Linux with the crontab scheduler.

The Influx database is created during execution if it does not exist on the InfluxDB server. For each resource, a database measure is generated.


> To learn more on how to monitor HPE OneView infrastructure with Grafana Metrics Dashboards and InfluxDB, see this [blog](https://developer.hpe.com/blog/how-to-monitor-hpe-oneview-infrastructure-with-grafana-metrics-dashboards-and-influxdb/) on the HPE Developer website.

![2022-10-21 15_18_30-HPE OneView using InfluxDB and PowerShell - Grafana — Mozilla Firefox](https://user-images.githubusercontent.com/13134334/197205198-643b505a-a67b-4ef4-8bec-c8be80515c32.png)



## Alternative option: Telegraf + exec plugin

Telegraf is an InfluxData server agent that can be used to collect and send metrics to an influxdb database. To collect the metrics, the exec plugin can be used to run commands or scripts in parallel at each interval and can parse the metrics from their output into an influx input data format.

The advantage of Telegraf over the Windows task scheduler or the Linux crontab configuration is the ease of managing the execution of scripts via a configuration file in which you can define an execution interval for each script, which greatly facilitates automatic task management.

See [Influxdb/Telegraf/Grafana for HPE OneView](https://github.com/jullienl/HPE-Synergy-OneView-demos/tree/master/Grafana-InfluxDB-Telegraf)