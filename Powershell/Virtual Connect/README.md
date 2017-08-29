# Get-HPOVinterconnectstatistics
   This PowerShell function provides the network statistics of a given port from a Virtual Connect SE 40Gb F8 Module for Synergy.   
   A port name must be provided.
   _Example of the statistics output_
   ![](https://user-images.githubusercontent.com/13134334/29812587-64563b42-8ca7-11e7-9a05-d7fb21389a69.png)   
   _Example of the throughput output_
   ![](https://user-images.githubusercontent.com/13134334/29812596-6a0a3b56-8ca7-11e7-8a91-b6f0f4bab0c7.png)   
       
## Parameter `IP`
  IP address of the Composer.
    
## Parameter `username`
  OneView administrator account of the Composer.
  Default: Administrator
  
## Parameter `password`
  Password of the OneView administrator account. 
  Default: password
  
## Parameter `interconnect`
  Name of the interconnect module.  
  This is normally retrieved with a `Get-HPOVInterconnect` call like `(get-HPovInterconnect | Where-Object {$_.name -match "interconnect 3" -and $_.model -match "Virtual" } ).name`
  
## Parameter `portname`
  Case-insensitive name of the port to query for statistics:  
  - Downlink ports: d1, d2, d3, ... d60
  - Uplink ports: Q1, Q2, Q3:1, Q3:2, Q3:3, Q3:4, Q4, ... Q8 

## Parameter `throughputstatistics` 
  Provides the throughput statistics of the given port. 
   
## Parameter `QoS`
  Provides the QoS statistics of the given port. 

## Parameter `FlexNic`
  Provides the statistics of the FlexNICs of a given downlink port. 

## Example
  ```sh
  PS C:\> Get-HPOVinterconnectstatistics -IP 192.168.1.110 -username Administrator -password password -portname "Q2" -interconnect "Frame1-CN7516060D, interconnect 3"
  ```  
  Provides the common statistics of 40Gb uplink port Q2 on the interconnect "Frame1-CN7516060D, interconnect 3"
  
  ```sh
  PS C:\> Get-HPOVinterconnectstatistics -IP 192.168.1.110 -username administrator -password password -portname "d2" -interconnect "Frame2-CN7515049L, interconnect 6" -throughputstatistics
  ```
  Provides the throughput statistics of downlink port d2 on the interconnect "Frame2-CN7515049L, interconnect 6"
  
  ```sh
  PS C:\> Get-HPOVinterconnectstatistics -IP 192.168.1.110 -username administrator -password password -portname "Q4:1" -interconnect "Frame2-CN7515049L, interconnect 6" -qos
  ```
  Provides the QoS statistics of 10G uplink port Q4:1 on the interconnect "Frame2-CN7515049L, interconnect 6"

  ```sh
  PS C:\> Get-HPOVinterconnectstatistics -IP 192.168.1.110 -username administrator -password password -portname "d8" -interconnect "Frame2-CN7515049L, interconnect 6" -flexNICs
  ```
  Provides the FlexNICs statistics of downlink port d8 on the interconnect "Frame2-CN7515049L, interconnect 6"

## Components
  This script makes use of the PowerShell language bindings library for HPE OneView.  
  https://github.com/HewlettPackard/POSH-HPOneView

## Links
  https://github.com/HewlettPackard/POSH-HPOneView
  
