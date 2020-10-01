<# 

This PowerShell script changes the Product ID (from $badProductId to $goodProductId) to all powered off Synergy Gen10 servers managed by OneView 
If Product ID is changed then the Compute is Powered ON

Requirements: Latest HPEOneView and HPEBIOSCmdlets libraries - OneView administrator account.
 

  Author: lionel.jullien@hpe.com
  Date:   September 2020
    
#################################################################################
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


# MODULES TO INSTALL/IMPORT

import-module HPEBIOSCmdlets
import-module HPEoneView.530



$badProductId = "797740-B21"
$goodProductId = "871940-B21"



#IP address of OneView
$IP = "192.168.1.110" 

# OneView Credentials
$username = "Administrator" 
$password = "password"


$secpasswd = ConvertTo-SecureString $password -AsPlainText -Force
$credentials = New-Object System.Management.Automation.PSCredential ($username, $secpasswd)
Connect-OVMgmt -Hostname $IP -Credential $credentials | Out-Null
    

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -Confirm:$false 


$LogDir = "{0}\logs" -f $PSScriptRoot  

if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
}
$Logfile = "{0}\change_productid_{1}.log" -f $LogDir, (Get-date -Format "yyyyMMdd-HHmmss")


function Write-Log {
    [CmdletBinding()] 
    Param 
    ( 
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)] 
        [ValidateNotNullOrEmpty()] 
        [Alias("LogContent")] 
        [string]$Message, 
    
        [Parameter(Mandatory = $false)] 
        [Alias('LogPath')] 
        [string]$Path = $global:logfile, 
            
        [Parameter(Mandatory = $false)] 
        [ValidateSet("Error", "Warning", "Info")] 
        [string]$Level = "Info",
           
        [Parameter(Mandatory = $false)] 
        [switch]$toHost = $false
           
    ) 
   
    "{0} {1} {2}" -f ([datetime]::Now.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")), $Level, $Message | Out-File -FilePath $Path -Append 
           
    if ($toHost) {
        switch ($Level) {
            "Error" {
                $color = "Red"
            }
            "Warning" {
                $color = "Yellow" 
            }
            "Info" {
                $color = "Yellow"
            }
        }
        Write-Host -ForegroundColor $color $Message
    }
}

# To turn off with a confirmation window all Synergy 480 Gen10 with bad product ID number
#$computestoturnoff = Get-OVServer | Where-Object { $_.Model -eq "Synergy 480 Gen10" -and $_.partnumber -like $badProductId -and $_.powerState -eq "On"} 

# if ($computestoturnoff) {
#  $computestoturnoff | Stop-OVServer -Confirm  | Wait-OVTaskComplete
#}

# Get Powered Off SY480 Gen10 Computes
$computes = Get-OVServer | Where-Object { $_.Model -eq "Synergy 480 Gen10" -and $_.powerState -eq "Off" -and $_.partnumber -like $badProductId } 


if ($computes) {

    foreach ($compute in $computes) {

        $ip = $compute  | select -ExpandProperty mpHostInfo | Select -ExpandProperty mpIpAddresses | Where { $_.type -ne "LinkLocal" } | Select -ExpandProperty address

        $token = ($compute | Get-OVIloSso -IloRestSession).'X-Auth-Token'

        Write-Host -ForegroundColor Cyan "      Connecting to iLO:$($ip)..."
    
        ($connection = Connect-HPEBIOS -IP $ip -XAuthToken $token -DisableCertificateAuthentication) > $null

        if ($connection) {

            $biosSettings = Get-HPEBIOSSystemInfo -Connection $connection 

            if ( $biosSettings.ProductID -eq $badProductId) {
                        
                $msg = "{0} - SerialNumber={1} ProductID={2}" -f $compute.Name, $compute.SerialNumber, $biosSettings.ProductId
                Write-Log -LogContent $msg -LogPath $Logfile -Level "Info" -toHost
		    
                Set-HPEBIOSSystemInfo -Connection $connectionbios -ProductID $goodProductId # -SerialNumber MX12345678
        
                # Start Compute
                $msg = "{0} - Powering on server ..." -f $compute.Name
                Write-Log -LogContent $msg -LogPath $Logfile -Level "Info" -toHost
                $compute | Start-OVServer | Wait-OVTaskComplete

            }
        }
    
        Disconnect-HPEBIOS -Connection $connection

    }
}

else {
    Write-Host -ForegroundColor Yellow "Cannot find any Powered Off Synergy 480 Gen10 ... "
}

Disconnect-OVMgmt