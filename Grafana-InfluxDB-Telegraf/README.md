# Telegraf/Influxdb/Grafana for HPE OneView sustainability data

The combination of Telegraf, InfluxDB, and Grafana (known as the TIG stack) forms a powerful toolset for collecting, storing, and visualizing HPE OneView sustainability data. 

- **Telegraf**: Telegraf acts as the collection agent, responsible for collecting sustainability data from HPE OneView. This is achieved through the execution of PowerShell scripts at customizable intervals. It provides flexibility to define the specific metrics to be gathered, the collection frequency, and the destination for the data aggregation. 

- **InfluxDB**: InfluxDB is a high-performance time-series database that specializes in storing and retrieving time-stamped data. It provides efficient storage mechanisms for handling large volumes of metrics data. Telegraf sends the collected metrics to InfluxDB, where they are stored and indexed based on time. InfluxDB also offers advanced querying capabilities, allowing you to perform complex queries, aggregations, and filtering operations on the data.

- **Grafana**: Grafana is a popular open-source platform used for visualization and monitoring. It connects to InfluxDB (and other data sources) and allows you to create rich, interactive dashboards to visualize your metrics data. With Grafana, you can build custom visualizations and charts, set up alerts and notifications based on metric thresholds, and share dashboards with others.  

This solution allows you to monitor the HPE OneView system consumptions, carbon emissions and network throughputs and identify trends, and make data-driven decisions. HPE OneView metrics include carbon footprint emissions, Synergy Virtual Connect module throughputs, compute utilization (CPU, power and temperature), enclosure (power and temperature) and iLO Overall Security dashboard status. 

> Note that Python scripts can also be used, provided that the Telegraf server is running Python.

![image](https://user-images.githubusercontent.com/13134334/204871401-9c350cac-d42d-4704-a02c-22e98e63eff9.png)


## Requirements
- Telegraf 
- InfluxDB (with an admin account for telegraf)
- Grafana configured with an InfluxDB data source
- Powershell on Linux, version 7 and later, see https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-linux?view=powershell-7.3
- HPE OneView user account


## Intallation of Telegraf, InfluxDB and Grafana

For the installation steps of the TIG stack ecosystem on Rocky Linux 9.3, you can refer to [Installation steps of the TIG stack ecosystem](https://github.com/jullienl/HPE-Synergy-OneView-demos/blob/master/Grafana-InfluxDB-Telegraf/Installation%20steps%20of%20the%20TIG%20stack%20ecosystem.md)


## Telegraf/Exec script for collecting sustainability data from HPE Compute Ops Management. 

In order to gather sustainability data from HPE OneView, you can use the different PowerShell scripts available in this folder. These scripts need to be executed periodically using the Exec plugin in Telegraf. 

> More information about the Exec input plugin can be found at https://github.com/influxdata/telegraf/tree/master/plugins/inputs/exec 

By running these scripts, you will be able to collect the sustainability metrics available from HPE OneView. They currently include:
 - Carbon footprint emissions
 - Synergy Virtual Connect module throughputs
 - Compute utilization (CPU, power and temperature)
 - Enclosure (power and temperature) 
 - iLO Overall Security dashboard status


**Note**: On Linux systems, official packages by default configure Telegraf to operate under the `telegraf` user and group. To guarantee that Telegraf has the necessary read and execute permissions for the PowerShell script while it runs with the `telegraf` user and group credentials, you might need to adjust the file permissions and ownership of the PowerShell script accordingly.


## Telegraf configuration 

Example of a Telegraf configuration running the PowerShell scripts every day with a 120-second timeout:

File: `/etc/telegraf/HPE_OneView.conf`


```
[[outputs.influxdb]]
  database = "telegraf"
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

## Grafana configuration

### Add InfluxDB data source 

To add a Grafana data source for InfluxDB, follow these steps:

1. Open your Grafana web interface and log in.
2. Click on the toggle menu and select **Administration** then **Plugins**
4. On the Plugins page, search for **InfluxDB** and click on it.
6. Then click on **Add new data source** and fill in the following information:
   - **URL**: Enter the base URL of your InfluxDB instance (e.g., http://localhost:8086).
   - **Auth**: Select the appropriate authentication parameters for your data source.
   - **Database**: Specify the name of the InfluxDB database you want to connect to (e.g., "telegraf" as defined in `/etc/telegraf/HPE_OneView.conf` ).
   - **User**: If authentication is enabled, enter the username (e.g., "telegraf" as configured in InfluxDB and defined in `/etc/telegraf/HPE_OneView.conf`).
   - **Password**: If authentication is enabled, enter the password (e.g., "xxxxxxxxxxxxxxx" as configured in InfluxDB and defined in `/etc/telegraf/HPE_OneView.conf`).
   - **HTTP Method**: Select the appropriate HTTP method for your InfluxDB instance.
7. Once you have filled in the required fields, click on the **Save & Test** button.


### Grafana Dashboard

To get a Grafana dashboard already configured for HPE OneView, you can import the [Grafana Dashboard for HPE OneView](https://github.com/jullienl/HPE-Synergy-OneView-demos/blob/master/Grafana-InfluxDB-Telegraf/Grafana%20Dashboard%20for%20HPE%20OneView.json) JSON file in Grafana. 


## Examples of Grafana Panels

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
