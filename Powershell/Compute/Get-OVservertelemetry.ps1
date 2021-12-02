<#
.DESCRIPTION
   Get-OVservertelemetry gets average power consumption, CPU utilization and Temperature report from a Compute Module 
   A server profile name must be provided
       
.PARAMETER IP
  IP address of the Composer
  Default: 192.168.1.110
  
.PARAMETER username
  OneView administrator account of the Composer
  Default: Administrator
  
.PARAMETER password
  password of the OneView administrator account 
  Default: password
  
.PARAMETER profile
  Name of the server profile
  This is normally retrieved with a 'Get-OVServerProfile' call like '(get-OVServerProfile).name'

.EXAMPLE
  PS C:\> Get-OVservertelemetry -IP 192.168.1.110 -username Administrator -password password -profile "W2016-1" 
  Provides average power consumption, CPU utilization and Temperature report for the compute module using the server profile "W2016-1"
  
.COMPONENT
  This script makes use of the PowerShell language bindings library for HPE OneView
  https://github.com/HewlettPackard/POSH-HPOneView

.LINK
    https://github.com/HewlettPackard/POSH-HPOneView
  
.NOTES
    Author: lionel.jullien@hpe.com
    Date:   August 2017 
    
#################################################################################
#                         Get-OVservertelemetry.ps1                           #
#                                                                               #
#        (C) Copyright 2017 Hewlett Packard Enterprise Development LP           #
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
#>
function Get-OVservertelemetry {

  [cmdletbinding(DefaultParameterSetName = "All",
    SupportsShouldProcess = $True
  )]

  Param 
  (

    [parameter(ParameterSetName = "All")]
    [Alias('composer', 'appliance')]
    [string]$IP = "192.168.1.110", #IP address of HPE OneView

    [parameter(ParameterSetName = "All")]
    [Alias('u', 'userid')]
    [string]$username = "Administrator", 

    [parameter(ParameterSetName = "All")]
    [Alias('p', 'pwd')]
    [string]$password = "password",

    [parameter(ParameterSetName = "All")]
    [string]$profile = "rh-1"

                               
  )
  
  Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
   
  # Connection to the Synergy Composer
  $secpasswd = ConvertTo-SecureString $password -AsPlainText -Force
  $credentials = New-Object System.Management.Automation.PSCredential ($username, $secpasswd)
  
  try {
    Connect-OVMgmt -Hostname $IP -Credential $credentials -ErrorAction stop | Out-Null    
  }
  catch {
    Write-Warning "Cannot connect to '$IP'! Exiting... "
    return
  }


  $profileuri = (Get-OVServerProfile | ? { $_.name -eq $profile }).uri

  $node = Get-OVServer | ? { $_.serverProfileUri -eq $profileuri }

  $URI = $node.uri
  $NAME = $node.Name
  $temp = $URI + "/utilization?fields=AmbientTemperature"

  $Resulttemp = Send-OVRequest $temp

  $CurrentSampletemp = $Resulttemp.metricList.metricSamples
  $SampleTimetemp = [datetime]($Resulttemp.newestSampleTime)
  $LastTempValue = echo $CurrentSampletemp[0][1]


  write-host "`nServer Profile: " -NoNewline; write-host -f Cyan $Profile
  write-host "Compute Module: " -NoNewline; write-host -f Cyan $Name
  write-host "`nSample Time: " -NoNewline; write-host -f Cyan $SampleTimetemp

  write-host "`nTemperature Reading: " -NoNewline; write-host $LastTempValue -f Cyan

  $cpu = $URI + "/utilization?fields=CpuAverageFreq"
  $Resultcpu = Send-OVRequest $cpu
  $CurrentSamplecpu = $Resultcpu.metricList.metricSamples
  $SampleTimecpu = [datetime]($Resultcpu.newestSampleTime)
  $LastcpuValue = echo $CurrentSamplecpu[0][1]

  write-host "CPU Average Reading: " -nonewline ; Write-Host $LastcpuValue -f Cyan

  $cpuu = $URI + "/utilization?fields=CpuUtilization"
  $Resultcpuu = Send-OVRequest $cpuu
  $CurrentSamplecpuu = $Resultcpuu.metricList.metricSamples
  $SampleTimecpuu = [datetime]($Resultcpuu.newestSampleTime)
  $LastcpuuValue = echo $CurrentSamplecpuu[0][1]

  write-host "CPU Utilization Reading: " -NoNewline; write-host $LastcpuuValue -f Cyan

  $AveragePower = $URI + "/utilization?fields=AveragePower"
  $ResultAveragePower = Send-OVRequest $AveragePower
  $CurrentSampleAveragePower = $ResultAveragePower.metricList.metricSamples
  $SampleTimeAveragePower = [datetime]($ResultAveragePower.newestSampleTime)
  $LastAveragePowerValue = echo $CurrentSampleAveragePower[0][1]

  write-host "Average Power Reading: " -NoNewline; write-host $LastAveragePowerValue -f Cyan
  Write-host ""

  Disconnect-OVMgmt
}
