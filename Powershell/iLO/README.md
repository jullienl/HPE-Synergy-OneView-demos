# Generate new iLO Self-signed SSL certificate 

This PowerShell script generates a new self-signed SSL certificate on iLO 4 firmware 2.55 (or later) on every server having some certificate issue related to the advisory a00042194en_us: HP Integrated Lights-Out (iLO) - iLO 3 and iLO 4 Self-Signed SSL Certificate May Have an Expiration Date Earlier Than the Issued Date. See http://h41302.www4.hp.com/km/saw/view.do?docId=emr_na-a00042194en_us 

After a new certificate is regenerated, the iLO restarts then the new certificated is imported into OneView and a OneView refresh takes place to update the status of the server using the new certificate.

A RedFish REST command that was added in iLO 4 firmware 2.55 (or later) is used by this script to generate the new self-signed SSL certificate

>Requirements: The latest HPOneView 400 library and OneView administrator account are required. 
  
  ![image](https://user-images.githubusercontent.com/13134334/38316523-38c262d2-382b-11e8-94ed-f68c1852d240.png)

  
## Download

### [Click here to download the function (right click to save)](https://github.com/jullienl/HPE-Synergy-OneView-demos/blob/master/Powershell/iLO/Generate%20a%20new%20iLO%20self-signed%20SSL%20certificate.ps1)

## Components
  This script makes use of the PowerShell language bindings library for HPE OneView.   
  https://github.com/HewlettPackard/POSH-HPOneView/releases
  
<br />
<br />



# Add user to iLO

  This PowerShell Script creates a User account in all iLOs managed by HPE OneView without using the iLO Administrator local account.
  
  >iLO modification is done through OneView and iLO SSOsession key using REST POST method
  
  OneView administrator account is required. 
  
## Download

### [Click here to download the function (right click to save)](https://github.com/jullienl/OneView-demos/blob/master/Powershell/iLO/Add%20user%20to%20iLO.ps1)

## Components
  This script makes use of the PowerShell language bindings library for HPE OneView.   
  https://github.com/HewlettPackard/POSH-HPOneView/releases
  
<br />
<br />

# Change iLO Administrator password

This PowerShell Script changes the default Administrator account password in all iLOs managed by OneView without using any iLO local account.
  
  >iLO modification is done through OneView and iLO SSOsession key using REST POST method
  
  OneView administrator account is required. 
  
## Download

### [Click here to download the function (right click to save)](https://github.com/jullienl/OneView-demos/blob/master/Powershell/iLO/Change%20iLO%20Admin%20password.ps1)

## Components
  This script makes use of the PowerShell language bindings library for HPE OneView.   
  https://github.com/HewlettPackard/POSH-HPOneView/releases
  
<br />
<br />

# Upgrade iLO Firmware

This PowerShell Script upgrades all iLO FW managed by the OneView Composer using iLO local account so it is required to first use the *Add User to iLO* script.

>OneView administrator account is required and HPE iLO PowerShell module must be installed.
  
## Download

### [Click here to download the function (right click to save)](https://github.com/jullienl/OneView-demos/blob/master/Powershell/iLO/Change%20iLO%20Admin%20password.ps1)

## Components
  This script makes use of:
  - The PowerShell language bindings library for HPE OneView.   
    https://github.com/HewlettPackard/POSH-HPOneView/releases
  - The HPE iLO PowerShell Cmdlets.  
    https://www.hpe.com/us/en/product-catalog/detail/pip.5440657.html
   
