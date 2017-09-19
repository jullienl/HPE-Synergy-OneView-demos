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
  https://github.com/HewlettPackard/POSH-HPOneView

  
<br />
<br />

# New-ESXiserverprofiletemplate
  This PowerShell Script creates a Server Profile Template using the HPE Image Streamer with OS Deployment Plan Attributes and required iSCSI Network connections.
 
## Download

### [Click here to download the function (right click to save)](https://github.com/jullienl/OneView-demos/blob/master/Powershell/OneView/New-ESXiserverprofiletemplate.ps1)

## Components
  This script makes use of the PowerShell language bindings library for HPE OneView.   
  https://github.com/HewlettPackard/POSH-HPOneView
  

<br />
<br />

# New-ESXiserverprofile
  This PowerShell Script creates a Server Profile using the HPE Image Streamer with OS Deployment Plan Attributes. A Server Profile Template is required. The server profile template can be created using 'New-ESXiserverprofiletemplate.ps1'
 
## Download

### [Click here to download the function (right click to save)](https://github.com/jullienl/OneView-demos/blob/master/Powershell/OneView/New-ESXiserverprofiletemplate.ps1)

## Components
  This script makes use of the PowerShell language bindings library for HPE OneView.   
  https://github.com/HewlettPackard/POSH-HPOneView
  


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
https://github.com/HewlettPackard/POSH-HPOneView
- The HPE 3PAR PowerShell Toolkit for HPE 3PAR StoreServ Storage.   
https://h20392.www2.hpe.com/portal/swdepot/displayProductInfo.do?productNumber=3PARPSToolkit 
  
