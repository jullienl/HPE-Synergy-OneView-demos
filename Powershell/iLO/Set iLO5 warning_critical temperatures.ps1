
# Script to set user defined warning and critical temperatures in iLO5
# Assembled by keenan.sugg@hpe.com May 2023
# Uses HPERedfish Cmdlets 1.1.0.0  in PowerShell 5.1 environment
# Loops through CSV input file of target iLOs
#
##### Some code sourced from https://github.com/jullienl/HPE-Compute-Ops-Management/blob/main/PowerShell/Connect-iLO-to-COM%20.ps1
#
# The content of the CSV must have the following format: 
# IP, Username, Password
#   192.168.3.191, Administrator, P@ssw0rd
#   192.168.3.193, Administrator, password
#
#################################################################################
#        (C) Copyright 2023 Hewlett Packard Enterprise Development LP           #
#################################################################################
#                                                                               #
# Permission is hereby granted, free of charge, to any person obtaining a copy  #
# of this software and associated documentation files (the "Software"), to deal #
# in the Software without restriction, including without limitation the rights  #
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell     #
# copies of the Software, and to permit persons to whom the Software is         #
# furnished to do so, subject to the following conditions:                      #
#                                                                               #
# The above copyright notice and this permission notice shall be included in    #
# all copies or substantial portions of the Software.                           #
#                                                                               #
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR    #
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,      #
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE   #
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER        #
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, #
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN     #
# THE SOFTWARE.                                                                 #
#                                                                               #
#################################################################################
#
##############################################
#
# This section commented out but let here for reference
#
# install-module  -Name HPERedfishCmdlets
# Import-Module -Name HPERedfishCmdlets
#
# $iLO = '192.168.1.80'
# $Username = "Administrator"
# $Password = ConvertTo-SecureString "HP1nvent" -AsPlainText -Force
# $Credentials = New-Object System.Management.Automation.PSCredential $Username,$Password
#
##############################################


# Update path to input file as needed

$iLO_collection = Import-Csv -Path .\iLOs.csv

##############################################

#  Begin Loop 

ForEach ($iLO in $iLO_Collection) {

  $session = Connect-HpeRedfish $iLO.IP -username $iLO.Username -password $iLO.Password -DisableCertificateAuthentication

  Write-Host "Session status"
  $session

  
  ##############################################

  # Redfish Target Warning:

  $url = "/redfish/v1/Chassis/1/Thermal/Actions/Oem/Hpe/HpeThermalExt.SetUserTempThreshold"

  #  HpeThermalExt.SetUserTempThreshold Parameters note temp is in Celcius

  $body = @"
{"AlertType":"Warning","SensorNumber":1,"ThresholdValue":20}
"@

  # Action

  $task = Invoke-HPERedfishAction -odataid $url -Data $body -session $session -DisableCertificateAuthentication

  ##############################################

  # Redfish Target Critical:

  $url = "/redfish/v1/Chassis/1/Thermal/Actions/Oem/Hpe/HpeThermalExt.SetUserTempThreshold"

  #  HpeThermalExt.SetUserTempThreshold Parameters

  $body = @"
{"AlertType":"Critical","SensorNumber":1,"ThresholdValue":33}
"@

  # Action

  $task = Invoke-HPERedfishAction -odataid $url -Data $body -session $session -DisableCertificateAuthentication

  ##############################################

  # Reset iLO

  # Get list of managers
  $managers = Get-HPERedfishDataRaw -odataid '/redfish/v1/Managers/' -Session $session  -DisableCertificateAuthentication
  foreach ($mgrOdataId in $managers.Members.'@odata.id') { # /redfish/v1/managers/1/, /redfish/v1/managers/2/
    # for possible operations on the manager check 'Actions' field in manager data
    $mgrData = Get-HPERedfishDataRaw -odataid $mgrOdataId -Session $session  -DisableCertificateAuthentication

    $resetTarget = $mgrData.Actions.'#Manager.Reset'.target

    #Since there is no other allowable values or options for iLO Reset, we do not provide -Data parameter value.
                
    # Send POST request using Invoke-HPERedfishAction
    $ret = Invoke-HPERedfishAction -odataid $resetTarget -Session $session  -DisableCertificateAuthentication
    Write-Host $ret.error
    # resetting iLO will delete all active sessions.

  }


}
