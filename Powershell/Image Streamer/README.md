# Invoke-HPOVOSdeploymentServerBackup 
   This PowerShell function creates a backup bundle of a HPE Image Streamer with all the artifacts present on the appliance (Deployment Plans, Golden Images, Build plans and Plan Scripts) 
   and copy the backup bundle zip file to a destination folder.
   
   >The Image Streamer backup feature does not backup OS volumes, only the golden Images if present.
 
 The function supports common parameters `-verbose`, `-whatif`, and `-confirm`. 

## Download

### [Click here to download the function (right click to save)](https://github.com/jullienl/OneView-demos/blob/master/Powershell/Image Streamer/Invoke-HPOVdeploymentServerbackup.ps1)

## Parameter `IP`
  IP address of the Composer. Default: 192.168.1.110
  
## Parameter `username`
  OneView administrator account of the Composer. Default: Administrator
  
## Parameter `password`
  password of the OneView administrator account. Default: password

## Parameter `name`
  name of the backup file
  file is overwritten if already present 

## Parameter `destination`
  existing local folder to save the backup bundle ZIP file 
     
## Example
  ```sh
  PS C:\> Invoke-HPOVOSdeploymentServerBackup -IP 192.168.5.1 -username administrator -password HPEinvent -name "Backup-0617" -destination "c:/temp" 
  ```
  Creates a backup bundle of the Image Streamer 192.168.1.5 and uploads that backup file named "Backup-0617.zip" to "c:/temp" 
  
## Component
  This script makes use of the PowerShell language bindings library for HPE OneView
  https://github.com/HewlettPackard/POSH-HPOneView




# Remove-HPOVOSdeploymentartifacts
  This PowerShell function deletes artifacts that are present in the Image Streamer appliance.
  > Image Streamer modifications are done through HPE OneView
   Supports common parameters -verbose, -whatif, and -confirm. 
  
## Download

### [Click here to download the function (right click to save)](https://github.com/jullienl/OneView-demos/blob/master/Powershell/Image Streamer/Remove-HPOVOSdeploymentartifacts.ps1)

## Parameter `IP`
  IP address of the Composer. Default: 192.168.1.110
  
## Parameter `username`
  OneView administrator account of the Composer. Default: Administrator
  
## Parameter `password`
  Password of the OneView administrator account. Default: password
  
## Parameter `name`
  Case-insensitive name of the artifact to delete. Accepts pipeline input `ByValue` and `ByPropertyName`. 

## Parameter `partialsearch`
  Runs a search using partial name of the artifact to delete. 
    
## Parameter `allartifacts`
  Deletes all Image Streamer artifacts: deployment plans, golden images, build plans, plan scripts and artifact bundles
  
## Parameter `deploymentplan`
  Deletes deployment plan
  
## Parameter `goldenimage`
  Deletes golden image
  
## Parameter `OSbuildplan`
  Deletes build plan
  
## Parameter `planscript`
  Deletes plan script
  
## Parameter `artifactbundle`
  Deletes artifact bundle
  
## Example
  ```sh
  PS C:\> Remove-HPOVOSdeploymentartifacts -IP 192.168.5.1 -username administrator -password paswword -name "HPE-Foundation - create empty OS Volume" -OSbuildplan -Confirm 
  ```
  Removes the OS build plan "HPE-Foundation - create empty OS Volume" and provides a prompt requesting confirmation of the deletion 
  
## Example
  ```sh
  PS C:\> Remove-HPOVOSdeploymentartifacts -IP 192.168.5.1 -username administrator -password paswword -name "HPE-ESXi-simple host configuration with NIC HA" -deploymentplan 
    ```
  Removes without confirmation the deployment plan "HPE-ESXi-simple host configuration with NIC HA" 
  
## Example
  ```sh
  PS C:\> Remove-HPOVOSdeploymentartifacts -IP 192.168.5.1 -username administrator -password paswword -name "HPE-ESXi-simple host configuration with NIC HA" -deploymentplan -OSbuildplan
    ```
  Removes without confirmation the deployment plan and OS Build plan "HPE-ESXi-simple host configuration with NIC HA" 
  
## Example
  ```sh
  PS C:\> Remove-HPOVOSdeploymentartifacts -allartifacts -name "ESX" -Confirm -partialsearch
    ```
  Removes all artifacts (deployment plans, golden images, build plans, plan scripts and artifact bundles) containing the string "ESX" and provides a prompt requesting confirmation of the deletion 
  
## Example
  ```sh
  PS C:\> Get-HPOVOSDeploymentPlan | where {$_.name -match "ESX"} | Remove-HPOVOSdeploymentartifacts -deploymentplan 
  Search for OS Deployment plans matching with the name "ESX" and remove them from the Image Streamer appliance 
  
## Component
  This script makes use of the PowerShell language bindings library for HPE OneView
  https://github.com/HewlettPackard/POSH-HPOneView
