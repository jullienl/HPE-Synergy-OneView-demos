# Invoke-HPOVOSdeploymentServerBackup 
   This PowerShell function creates a backup bundle of a HPE Image Streamer with all the artifacts present on the appliance (Deployment Plans, Golden Images, Build plans and Plan Scripts) 
   and copy the backup bundle zip file to a destination folder.
   
   >The Image Streamer backup feature does not backup OS volumes, only the golden Images if present.
 
 The function supports common parameters `-verbose`, `-whatif`, and `-confirm`. 
       
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
