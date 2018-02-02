# Get-HPOVservertelemetry
   This PowerShell function provides average power consumption, CPU utilization and Temperature report from a Compute Module. 
     
   _Example of the telemetry output:_   
   
   ![](https://user-images.githubusercontent.com/13134334/29814096-72ed6360-8cac-11e7-8212-7af50ca4cb30.png)   
   
## Download

### [Click here to download the function (right click to save)](https://github.com/jullienl/OneView-demos/blob/master/Powershell/Compute/Get-HPOVservertelemetry.ps1)

   
## Parameter `IP`
  IP address of the Composer   
  Default: 192.168.1.110
  
## Parameter `username`
  OneView administrator account of the Composer   
  Default: Administrator
  
## Parameter `password`
  password of the OneView administrator account    
  Default: password
  
## Parameter `profile`
  Name of the server profile   
  This is normally retrieved with a 'Get-HPOVServerProfile' call like '(get-HPOVServerProfile).name'
  
## Example
  ```sh
  PS C:\> Get-HPOVservertelemetry -IP 192.168.1.110 -username Administrator -password password -profile "W2016-1" 
  ```
  Provides average power consumption, CPU utilization and Temperature report for the compute module using the server profile "W2016-1"
  
## Component
  This script makes use of the PowerShell language bindings library for HPE OneView   
  https://github.com/HewlettPackard/POSH-HPOneView/releases
  
  <br />
  <br />
  
 # Synergy-Inventory
   This PowerShell script generates a Synergy inventory report of all components managed by HPE OneView. 
     
   _Example of the generated report output:_   
   
   ![](https://user-images.githubusercontent.com/13134334/35727681-3dde836a-0809-11e8-9010-a59de28edbc8.png)   
   



  <br />
  <br />
  
 # Server-Firmware-Report
   This PowerShell script generates a firmware report of all Compute Modules managed by HPE OneView. 
     
   _Example of the generated report output:_   
   
   ![](https://user-images.githubusercontent.com/13134334/35335609-50ca1920-0116-11e8-9827-30dc9927d780.png)   
   
