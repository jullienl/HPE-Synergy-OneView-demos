# Invoke-HPOVefuse
  This PowerShell function efuses a component managed by HPE OneView, i.e. reset virtually (without physically reseting the server).
   An e-fuse reset causes the component to loose power momentarily as the e-fuse is tripped and reset.
   Supported components are : compute, interconnect, appliance and Frame Link Modules.
   A prompt requesting efuse confirmation is always provided.
 
   Supports common parameters `-verbose`, `-whatif`, and `-confirm`. 
   
   OneView administrator account is required. 

## Download

### [Click here to download the function (right click to save)](https://github.com/jullienl/OneView-demos/blob/master/Powershell/OneView/Invoke-HPOVeFuse.ps1)

## Parameter `composer`
  IP address of the Composer. Default: *192.168.1.110*
  
## Parameter `composerusername`
  OneView administrator account of the Composer. Default: *Administrator*
  
## Parameter `composerpassword`
  password of the OneView administrator account. Default: *password*
  
## Parameter `compute`
  The server hardware resource to efuse. This is normally retrieved with a `Get-HPOVServer` call.   
  Can also be the Server Hardware name, e.g. *Frame2-CN7515049L, bay 4*.   
  Accepts pipeline input `ByValue` and `ByPropertyName` 
  
## Parameter `interconnect`
  The interconnect hardware resource to efuse. This is normally retrieved with a `Get-HPOVInterconnect` call.   
  Can also be the Interconnect Hardware name, e.g. *Frame1-CN7516060D, interconnect 3*.
  
## Parameter `appliance`
  The serial number of the composable infrastructure appliance resource to efuse; e.g. *UH53CP0509*.
  This is normally retrieved with a `(Get-HPOVEnclosure).applianceBays.serialnumber` call.  
  
## Parameter `FLM`
  The serial number of the frame link module resource to efuse; e.g. *CN7514V012*.   
  This is normally retrieved with a `(Get-HPOVEnclosure).managerbays.serialnumber` call.
  
## Example
```sh
  PS C:\> Invoke-HPOVefuse -composer 192.168.1.110 -composerusername Administrator -composerpassword password -compute "CN7515049C, bay 5" 
```  
Efuses the compute module in frame CN7515049C in bay 5. 
  
## Example
```sh
  PS C:\> Invoke-HPOVefuse -composer 192.168.1.110 -composerusername Administrator -composerpassword password -interconnect "CN7516060D, interconnect 3"
```  
  Efuses the interconnect module in frame CN7516060D in interconnect bay 3. 
  
## Example
```sh
  PS C:\> Invoke-HPOVefuse -composer 192.168.1.110 -composerusername Administrator -composerpassword password -appliance "UH53CP0509"
```  
  Efuses the composable infrastructure appliance with the serial number UH53CP0509.
  
## Example
```sh
  PS C:\> Invoke-HPOVefuse -composer 192.168.1.110 -composerusername Administrator -composerpassword password -FLM "CN7514V012"
```  
  Efuses the frame link module with the serial number CN7514V012.

## Example
```sh
  PS C:\> Get-HPOVServer | ? {$_.name -match "Frame2"} | Invoke-HPOVefuse
```
Efuses all servers in the frame whose name matches with "Frame2" and provides a prompt requesting efuse confirmation for each server.
  
## Components
  This script makes use of the PowerShell language bindings library for HPE OneView.   
  https://github.com/HewlettPackard/POSH-HPOneView/releases

  
<br />
<br />

# New-ESXiserverprofiletemplate
  This PowerShell Script is an example of how to create a Server Profile Template using the HPE Image Streamer with OS Deployment Plan Attributes and required iSCSI Network connections.
 
## Download

### [Click here to download the function (right click to save)](https://github.com/jullienl/OneView-demos/blob/master/Powershell/OneView/New-ESXiserverprofiletemplate.ps1)

## Components
  This script makes use of the PowerShell language bindings library for HPE OneView.   
  https://github.com/HewlettPackard/POSH-HPOneView/releases
  

<br />
<br />

# New-ESXiserverprofilefromSPT
  This PowerShell Script is an example of how to create a Server Profile using the HPE Image Streamer with OS Deployment Plan Attributes. A Server Profile Template is required. The server profile template can be created using `New-ESXiserverprofiletemplate.ps1`
 
## Download

### [Click here to download the function (right click to save)](https://github.com/jullienl/OneView-demos/blob/master/Powershell/OneView/New-ESXiserverprofilefromSPT.ps1)

## Components
  This script makes use of the PowerShell language bindings library for HPE OneView.   
  https://github.com/HewlettPackard/POSH-HPOneView/releases
  


<br />
<br />
 
# Full HPE OneView Composer Synergy configuration with HPE Image Streamer

This PowerShell Script creates a full Synergy environment configuration using the HPE Image Streamer from scratch.
 
> Hardware Setup and Network settings are the only two manual configuration steps that must be done on the unconfigured Composer before running this script
  
OneView administrator account is required. 

## Download

### [Click here to download the function (right click to save)](https://github.com/jullienl/OneView-demos/blob/master/Powershell/OneView/full_composer_configuration_with_Image_Streamer.ps1)

## Components
This script makes use of:
- The PowerShell language bindings library for HPE OneView.   
https://github.com/HewlettPackard/POSH-HPOneView/releases
- The HPE 3PAR PowerShell Toolkit for HPE 3PAR StoreServ Storage.   
https://h20392.www2.hpe.com/portal/swdepot/displayProductInfo.do?productNumber=3PARPSToolkit 
  


<br />
<br />
 
# New-ESXserver

   new-ESXserver provisions an ESX server using an Image Streamer deployment plan for ESXi.
   Several parameters can be used to customize the ESXi host like: Management IP address, SSH enabled, hostname, datastore, etc.

   Once the server is provisioned, the script can power on the server and also add the ESXi host to a vcenter folder, datacenter    or cluster.
       
   Supports common parameters `-verbose`, `-whatif`, and `-confirm`. 
   
   OneView administrator account is required 

   ImageStreamer artifacts for ESXi 5.x and ESXi 6.x must be installed
   See https://github.hpe.com/ImageStreamer/esxi/tree/master/artifact-bundles 
  
>   A deployment plan name must be provided using the 'OSDeploymentplanname' parameter. If not present, the script is looking for "*ESXi - deploy with multiple management NIC HA config+FCoE*"

   Latest OneView POSH Library must be used.
 
   OneView administrator account is required. 

## Download

### [Click here to download the function (right click to save)](https://github.com/jullienl/HPE-Synergy-OneView-demos/blob/master/Powershell/OneView/new-ESXserver.ps1)

## Configuration
  Global Variables at the begining of the script needs to be configured according to your environment:
  - `$ServerHardwareTypename` sets the type of server model name to use for the deployment e.g. '480' will select a server model 'Synergy 480 Gen9' or 'Synergy 480 Gen10'.  
  - `$myproxy` and `$myproxyport` set proxy settings (if required) to install the VMware PowerCLI library (if needed)
  - `$vcenterlicensename` sets the VMware license name to use on the ESXi host

## Components
This script makes use of:
- The PowerShell language bindings library for HPE OneView.   
https://github.com/HewlettPackard/POSH-HPOneView/releases

## Example 1
```sh
  PS C:\> New-ESXserver -hostname ESX-01 -ManagementNIC DHCP -poweron 
```  
Deploy an ESXi server named ESX-01, assign a DHCP Address to the first Management NIC and power on the server. 


## Example 2
```sh
  PS C:\> New-ESXserver -composer 192.168.1.110 -composerusername Administrator -composerpassword password -hostname ESX6-2 -hostpassword HPEinvent -ManagementNIC 192.168.2.22 
```  
Deploy an ESXi server named ESX6-2 and assign the password HPEinvent to the ESXi root user 
The server profile is named using the name of the hostname "ESX6-2" 
Assign a static IPv4 address "192.168.2.22" to the first Management NIC 
Leave the server off once the profile is created in OneView


## Example 3
```sh
  PS C:\> New-ESXserver -composer 192.168.1.110 -composerusername Administrator -composerpassword password -hostname ESX6-3 -hostpassword HPEinvent -vcenterserver "vcenter.hpe.net" -vcenterusername "Administrator@vsphere.local" -vcenterpassword "HPEinvent" -vcenterlocation Synergy  
```  
Deploy an ESXi server named ESX6-3, power on the server 
Add the server to be managed by a vCenter server "vcenter.hpe.net" and import the server in the "Synergy" location 



## Example 4
```sh
  PS C:\> New-ESXserver -composer 192.168.1.110 -composerusername Administrator -composerpassword password -hostname ESX6-4 -hostpassword HPEinvent -vcenterserver "vcenter.hpe.net" -vcenterusername "Administrator@vsphere.local" -vcenterpassword "HPEinvent" -vcentercluster Synergy-Cluster -SSHEnabled  
```  
Deploy an ESXi server named ESX6-4, power on the server 
Add the server to be managed by a vCenter server "vcenter.hpe.net" and add the server to the "Synergy-Cluster" vSphere cluster 
Enable SSH and ESXi shell on the ESXi Host 
