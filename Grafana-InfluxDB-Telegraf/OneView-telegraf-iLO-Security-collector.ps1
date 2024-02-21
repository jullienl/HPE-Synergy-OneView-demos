<#
PowerShell script to produce data that can be used to create a Grafana dashboard for an iLO Security Dashboard through the use of Telegraf and InfluxDB. 
The script utilizes the Exec input plugin.

More information about the Exec input plugin can be found at https://github.com/influxdata/telegraf/tree/master/plugins/inputs/exec 

The script collects the status of the iLO overall security dashboard from all resources managed by HPE OneView. 

Supported resources are Gen10 and above.

An "iLOSecurityDashboard" measurement is created by the script which groups all iLOs together. 
Additionally, a unique database tag set is generated for each iLO, allowing them to be distinguished from one another.

Requirements: 
    - Powershell on Linux 7 and later, see https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-linux?view=powershell-7.3
    - Grafana configured with an InfluxDB data source
    - InfluxDB (with an admin account for telegraf)
    - Telegraf 
        - Configuration (/etc/telegraf/telegraf.conf):
            [[outputs.influxdb]]
            database = "telegraf"
            ## HTTP Basic Auth
            username = "telegraf"
            password = "xxxxxxxxxxxxxxx"

            [[inputs.exec]] 
            commands = ["pwsh /scripts/OneView-telegraf-iLO-Security-collector.ps1"] 
            interval = "1d" 
            timeout = "300s" 
            data_format = "influx"  

Note:
    This script uses the -SkipCertificateCheck parameter with Invoke-RestMethod to avoid connectivity issues with untrusted or self-signed 
    certificates from HPE OneView and iLO.

    If you use CA signed/issued certificates, you can remove the -SkipCertificateCheck parameter to improve the security of this script but 
    you would have to make sure the issuing CA, and CA chain, is exported to PEM format, and placed within the OS SSL cert trusts location. 

    Place the CA cert in PEM format (the cert format that starts with -----BEGIN CERTIFICATE-----) into:
    - For Ubuntu 18.04:     /usr/local/shared/ca-certificates
    - For CentOS/RHEL:      /etc/pki/ca-trust/source/anchors/ 
    
    Then execute 
    - For Ubuntu 18.04:     sudo update-ca-certificates
    - For CentOS/RHEL:      sudo update-ca-trust extract



Output example of the script:

iLOSecurityDashboard,iLO=RHEL83-1-ilo.lj.lab Status="Ignored"
iLOSecurityDashboard,iLO=RHEL83-2-ilo.lj.lab Status="Risk"
iLOSecurityDashboard,iLO=ILOCZ212406GK.lj.lab Status="Ignored"
iLOSecurityDashboard,iLO=ILOCZ212406GH.lj.lab Status="Risk"
iLOSecurityDashboard,iLO=ILOCZ221705V1.lj.lab Status="Ignored"
iLOSecurityDashboard,iLO=ESX200-ilo.lj.lab Status="Ignored"
iLOSecurityDashboard,iLO=ILOCZ221705V6.lj.lab Status="Ignored"
iLOSecurityDashboard,iLO=ILOCZ221705V5.lj.lab Status="Ignored"
...

Author: lionel.jullien@hpe.com
Date:   March 2023

   
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
      

# OneView information
$OVusername = "Administrator"
$OVpassword = "xxxxxxxxxxxx"
$OVIP = "composer.lj.lab"


# MODULES TO INSTALL
# NONE

#################################################################################

# Policy settings and self-signed certificate policy validation
# [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

#################################################################################

# Get-X-API-Version
$response = Invoke-RestMethod "https://$OVIP/rest/version" -Method GET -SkipCertificateCheck
$currentVersion = $response.currentVersion

# OneView Headers creation
$OVheaders = @{} 
$OVheaders["X-API-Version"] = "$currentVersion"
$OVheaders["Content-Type"] = "application/json"

# Payload creation
$body = @"
{
  "authLoginDomain": "Local",
  "password": "$OVpassword",
  "userName": "$OVusername"
}
"@

# Connection to OneView / Synergy Composer
$response = Invoke-RestMethod "https://$OVIP/rest/login-sessions" -Method POST -Headers $OVheaders -Body $body -SkipCertificateCheck

# Capturing the OneView Session ID
$sessionID = $response.sessionID

# Add AUTH to Headers
$OVheaders["auth"] = $sessionID

######################################################################################################### 

#################################################################################

# Capture iLO5 server hardware managed by HPE OneView

$url = "https://{0}/rest/index/resources/?category=server-hardware" -f $OVIP
    
$SH = (Invoke-RestMethod $url -Method GET -Headers $OVheaders -SkipCertificateCheck).members

$SH = $SH | ? { $_.Attributes.mpModel -eq "iLO5" } | select -first 8


#####################################################################################################################

foreach ($item in $SH) {

    $iLOIP = $item.multiAttributes.mpIpAddresses |  ? { $_ -NotMatch "fe80" }

    
    if ($item.attributes.mpHostName) {
        $iLO = $item.attributes.mpHostName
    }
    else {
        $iLO = $item.multiAttributes.mpIpAddresses |  ? { $_ -NotMatch "fe80" }

    }

   
    try {
        # $IloSso = $item | Get-OVIloSso -IloRestSession -SkipCertificateCheck -ErrorAction Stop
        $SHUri = $item.uri
        $url = "https://{0}{1}/remoteConsoleUrl" -f $OVIP, $SHUri

        $ilosessionkey = ((Invoke-RestMethod $url -Method GET -Headers $OVheaders -SkipCertificateCheck).remoteConsoleUrl).Split("=")[-1]

    }
    catch {
        $output = 'OverallSecurityStatus,iLO={0} Status="NotAccessible"' -f $iLO
        Write-Host $output
        Continue
    }

    if ($ilosessionkey) {

        # Creation of the iLO headers  
        $iLOheaders = @{} 
        $iLOheaders["OData-Version"] = "4.0"
        $iLOheaders["X-Auth-Token"] = $ilosessionkey 


        ## Get Overall Security Dashboard Status

        $uri = "/redfish/v1/Managers/1/SecurityService/SecurityDashboard"
        $method = "Get"

        try {
            $SecurityDashboard = Invoke-RestMethod -Uri "https://$iLOIP$uri"  -Headers $iLOheaders -Method $method -ErrorAction Stop -SkipCertificateCheck
        }
        catch {
            $output = 'OverallSecurityStatus,iLO={0} Status="NotAccessible"' -f $iLO
            Write-Host $output
            continue
        }

        $OverallSecurityStatus = $SecurityDashboard.OverallSecurityStatus
        

        # $output = '{0} OverallSecurityStatus="{1}"' -f $iLO, $OverallSecurityStatus
        $output = 'OverallSecurityStatus,iLO={0} Status="{1}"' -f $iLO, $OverallSecurityStatus

        Write-Host $output
    }
}
