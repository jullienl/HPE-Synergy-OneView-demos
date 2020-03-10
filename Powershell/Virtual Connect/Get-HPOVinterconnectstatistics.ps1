<#
.DESCRIPTION
   Get-HPOVinterconnectstatistics gets the port statistics from a Virtual Connect SE 40Gb F8 Module for Synergy 
   A port name must be provided
       
.PARAMETER IP
  IP address of the Composer
    
.PARAMETER username
  OneView administrator account of the Composer
  Default: Administrator
  
.PARAMETER password
  password of the OneView administrator account 
  Default: password
  
.PARAMETER interconnect
  Name of the interconnect module
  This is normally retrieved with a 'Get-HPOVInterconnect' call like ' (get-HPovInterconnect | Where-Object {$_.name -match "interconnect 3" -and $_.model -match "Virtual" } ).name '

.PARAMETER portname
  case-insensitive name of the port to query for statistics
  - Downlink ports: d1, d2, d3, ... d60
  - Uplink ports: Q1, Q2, Q3:1, Q3:2, Q3:3, Q3:4, Q4, ... Q8 

.PARAMETER throughputstatistics 
  Provides the throughput statistics of the given port 
   
.PARAMETER QoS
  Provides the QoS statistics of the given port 

.PARAMETER FlexNic
  Provides the statistics of the FlexNICs of a given downlink port 

.EXAMPLE
  PS C:\> Get-HPOVinterconnectstatistics -IP 192.168.1.110 -username Administrator -password password -portname "Q2" -interconnect "Frame1-CN7516060D, interconnect 3"
  Provides the common statistics of 40Gb uplink port Q2 on the interconnect "Frame1-CN7516060D, interconnect 3"
  
.EXAMPLE
  PS C:\> Get-HPOVinterconnectstatistics -IP 192.168.1.110 -username administrator -password password -portname "d2" -interconnect "Frame2-CN7515049L, interconnect 6" -throughputstatistics
  Provides the throughput statistics of downlink port d2 on the interconnect "Frame2-CN7515049L, interconnect 6"
  
.EXAMPLE
  PS C:\> Get-HPOVinterconnectstatistics -IP 192.168.1.110 -username administrator -password password -portname "Q4:1" -interconnect "Frame2-CN7515049L, interconnect 6" -qos
  Provides the QoS statistics of 10G uplink port Q4:1 on the interconnect "Frame2-CN7515049L, interconnect 6"

.EXAMPLE
  PS C:\> Get-HPOVinterconnectstatistics -IP 192.168.1.110 -username administrator -password password -portname "d8" -interconnect "Frame2-CN7515049L, interconnect 6" -flexNICs
  Provides the FlexNICs statistics of downlink port d8 on the interconnect "Frame2-CN7515049L, interconnect 6"

.COMPONENT
  This script makes use of the PowerShell language bindings library for HPE OneView
  https://github.com/HewlettPackard/POSH-HPOneView

.LINK
    https://github.com/HewlettPackard/POSH-HPOneView
  
.NOTES
    Author: lionel.jullien@hpe.com
    Date:   August 2017 
    
#################################################################################
#                  Get-HPOVinterconnectstatistics.ps1                           #
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
function Get-HPOVinterconnectstatistics {

    [cmdletbinding(DefaultParameterSetName = ’All’, 
        SupportsShouldProcess = $True
    )]

    Param 
    (

        [parameter(ParameterSetName = "All")]
        [Alias('composer', 'appliance')]
        [string]$IP = "", #IP address of HPE OneView

        [parameter(ParameterSetName = "All")]
        [Alias('u', 'userid')]
        [string]$username = "Administrator", 

        [parameter(ParameterSetName = "All")]
        [Alias('p', 'pwd')]
        [string]$password = "password",

        [parameter(ParameterSetName = "All")]
        [string]$interconnect = "",

        [parameter(Mandatory = $true, ParameterSetName = "All")]
        [string]$portname = "",

        [parameter(ParameterSetName = "All")]
        [switch]$throughputstatistics ,

        [parameter(ParameterSetName = "All")]
        [switch]$QoS,

        [parameter(ParameterSetName = "All")]
        [switch]$FlexNICs
                               
    )
   
   
    # Import the OneView 3.1 library

    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

    if (-not (get-module HPOneview.500)) {  
        Import-module HPOneview.500
    }

   

    # Connection to the Synergy Composer

    $secpasswd = ConvertTo-SecureString $password -AsPlainText -Force
    $credentials = New-Object System.Management.Automation.PSCredential ($username, $secpasswd)
    Connect-HPOVMgmt -Hostname $IP -Credential $credentials | Out-Null

               

               
    import-HPOVSSLCertificate -ApplianceConnection ($connectedSessions | ? { $_.name -eq $IP })


    # Creation of the header

    $postParams = @{userName = $username; password = $password } | ConvertTo-Json 
    $headers = @{ } 
    #$headers["Accept"] = "application/json" 
    $headers["X-API-Version"] = "300"

    # Capturing the OneView Session ID and adding it to the header
    
    $key = $ConnectedSessions[0].SessionID 

    $headers["auth"] = $key

    # Added these lines to avoid the error: "The underlying connection was closed: Could not establish trust relationship for the SSL/TLS secure channel."
    # due to an invalid Remote Certificate
    add-type -TypeDefinition  @"
        using System.Net;
        using System.Security.Cryptography.X509Certificates;
        public class TrustAllCertsPolicy : ICertificatePolicy {
            public bool CheckValidationResult(
                ServicePoint srvPoint, X509Certificate certificate,
                WebRequest request, int certificateProblem) {
                return true;
            }
        }
"@
    [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy


    $IC = get-HPovInterconnect -Name $interconnect

    $uri = $IC.uri

    Write-Verbose "The interconnect is : $interconnect"
 
    $stat1 = Invoke-WebRequest -Uri "https://$IP$uri/statistics/$portname" -ContentType "application/json" -Headers $headers -Method GET # -UseBasicParsing 
 
    Write-Verbose "The general stats are $stat1"

    clear 


    $configporttype = ( (get-HPovInterconnect -Name $interconnect).ports | ? name -eq $portname ).configPortTypes

    $porttype = ( (get-HPovInterconnect -Name $interconnect).ports | ? name -eq $portname ).portType

    $portlinked = ( (get-HPovInterconnect -Name $interconnect).ports | ? name -eq $portname ).portStatus

    $moduletype = (get-HPovInterconnect -Name $interconnect).model



    if ($portlinked -eq "Unlinked") { 
        Write-host "" 
        Write-warning "`n`nPort $portname is unlinked ! No statistics is available !`n" 
        
        return
    }
    


    if ($throughputstatistics -eq $False -and $qos -eq $False -and $FlexNICs -eq $False -and $configporttype -notmatch "FibreChannel") {
        write-host "`nStatistics for $portname :"  -ForegroundColor Green
        ($stat1.Content | convertfrom-Json).commonStatistics 
    }
     




    if ($qos -eq $False -and $configporttype -match 'FibreChannel' -and $FlexNICs -eq $False -and $throughputstatistics -eq $False) {
       
        Write-host "`nPort $portname is a Fibre Channel uplink"
        write-host "`FC statistics:"  -ForegroundColor Green
        ($stat1.Content | convertfrom-Json).fcStatistics
    }

    
    
    if ($throughputstatistics -eq $True -and $FlexNICs -eq $False) {   
    
        if ($configporttype -match 'FibreChannel' -and $moduletype -match "Virtual Connect SE 40Gb F8 Module for Synergy") { 
            Write-host "" 
            Write-warning "`n`nThroughput statistics are currently not supported on a Fibre Channel Port on the HPE Virtual Connect SE 40Gb F8 Module for HPE Synergy !`n" 
        
            return
        }
        
        
        write-host "`nThroughput statistics:`n" -ForegroundColor Green
        write-host "`nKilobits per second received on port $portname in the last hour:"
        ($stat1.Content | convertfrom-Json).advancedStatistics.receiveKilobitsPerSec -split ":" 
        write-host "`nPackets per second received on port $portname in the last hour:"
        ($stat1.Content | convertfrom-Json).advancedStatistics.receivePacketsPerSec -split ":"     
    } 
   

        
    if ($qos.IsPresent) {   
        
        if ((($stat1.Content | convertfrom-Json).qosPortStatistics) -eq $Null) { 
            Write-host "" 
            Write-warning "`n`nThere is no QoS Statistics on $portname !`n" 
            return
                
        }
        
        write-host "`nQoS statistics:"  -ForegroundColor Green
           
        ($stat1.Content | convertfrom-Json).qosPortStatistics
    } 



    
    if ($FlexNICs.IsPresent) {   

        $subports = ( (get-HPovInterconnect -Name $interconnect).ports | ? name -eq $portname ).subports

        if ($porttype -match "Uplink") { 
            Write-host "" 
            Write-warning "`n`nThere is no FlexNIC on $portname as it is an uplink !`n" 
                
            return
        }

        if ($subports -eq $Null -and $porttype -notmatch "Uplink") { 
            Write-host "" 
            Write-warning "`n`nNo statistics is available as $portname has no FlexNIC configured !`n" 
                
            return
        }
    
        $count = (($stat1.Content | convertfrom-Json).subportStatistics).count
        
        write-host "`n$portname is configured with $count FlexNIC(s):"  -ForegroundColor Green


        if ($throughputstatistics.IsPresent) {
                                       
            ($stat1.Content | convertfrom-Json).subportStatistics.subportAdvancedStatistics | ForEach-Object {
          
                write-host ("`nKilobits per second received on $portname / FlexNIC" + $_.subportNumber + " in the last hour:" )
           
                ($_.receiveKilobitsPerSec -split ":" ) }


            ($stat1.Content | convertfrom-Json).subportStatistics.subportAdvancedStatistics | ForEach-Object {
          
                write-host ("`nPackets per second received on $portname / FlexNIC" + $_.subportNumber + " in the last hour:" )
           
                ($_.receivePacketsPerSec -split ":" ) }

        
        
        }

        else {

        
            (($stat1.Content | convertfrom-Json).subportStatistics) | ForEach-Object {
          
                write-host ("Statistics of $portname / FlexNIC" + $_.subportNumber + ":" )

                ($_.subportCommonStatistics) | select -Property rfc1213IfInOctets, rfc1213IfInUcastPkts, rfc1213IfInNUcastPkts, rfc1213IfOutOctets, rfc1213IfOutUcastPkts, rfc1213IfOutNUcastPkts | fl }
            
        
        }

    } 

    Disconnect-HPOVMgmt
}


