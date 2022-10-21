# Grafana Dashboard for HPE OneView

![2022-10-21 15_18_30-HPE OneView using InfluxDB and PowerShell - Grafana — Mozilla Firefox](https://user-images.githubusercontent.com/13134334/197205198-643b505a-a67b-4ef4-8bec-c8be80515c32.png)

To learn more about how to monitor HPE OneView infrastructure with Grafana Metrics Dashboards and InfluxDB, see this [blog post](https://developer.hpe.com/blog/how-to-monitor-hpe-oneview-infrastructure-with-grafana-metrics-dashboards-and-influxdb/) on the HPE Developer Blog website.

These PowerShell scripts can be used to generate data for a Grafana metrics dashboard for any HPE Compute infrastructure managed by HPE OneView via an Influx database.

The scripts collect the utilization statistics of the given resource from HPE OneView and writes data to an Influx database 
by providing a hashtable of tags and values via the REST API.  

These scripts are written to run continuously so that metrics are collected for an indefinite period of time and can be run in the background
from a Windows machine by using the Task Scheduler and setting a "At system startup after a 30 second delay" trigger. 

The Influx database is created during execution if it does not exist on the InfluxDB server. For each resource, a database measure is generated.

