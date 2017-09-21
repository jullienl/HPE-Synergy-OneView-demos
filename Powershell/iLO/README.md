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
   
