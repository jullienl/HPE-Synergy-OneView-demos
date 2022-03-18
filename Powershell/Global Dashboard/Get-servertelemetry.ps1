<# 

This script generates a CSV telemetry report with the last sample Temperature/CPU Utilization/Average Power values of all servers managed by HPE OneView Global Dashboard

"Appliance Name", "Appliance IP", "Appliance Model", "Server Profile", "Server Hardware", "Sample Time", "Temperature", "CPU Utilization", "Average Power"
"composer","composer.lj.lab","Synergy Composer","Ansible-CentOS79-1","Frame1, bay 1","11/23/2021 11:15:00","18","0","0"
"composer","composer.lj.lab","Synergy Composer","WIN-BFS","Frame3, bay 4","12/03/2021 06:55:00","17","0","70"
"composer","composer.lj.lab","Synergy Composer","RH8.3-BFS-ISO_creations","Frame3, bay 3","12/03/2021 06:55:00","17","0","56"
"composer","composer.lj.lab","Synergy Composer","BfS with PXE","Frame1, bay 4","11/23/2021 15:10:00","19","0","0"
"composer","composer.lj.lab","Synergy Composer","gen10_test_fw","Frame1, bay 8","11/08/2021 19:50:00","18","0","0"
"composer2","composer2.lj.lab","Synergy Composer2","RHEL-1","Frame4, bay 4","12/03/2021 06:50:00","18","0","119"
"composer2","composer2.lj.lab","Synergy Composer2","WIN-2","Frame4, bay 1","12/03/2021 06:50:00","16","0","160"
"composer2","composer2.lj.lab","Synergy Composer2","ESXi7-2","Frame4, bay 2","12/03/2021 12:25:00","18","0","75"
"composer2","composer2.lj.lab","Synergy Composer2","WIN-1","Frame4, bay 5","12/03/2021 12:30:00","19","0","153"
"composer2","composer2.lj.lab","Synergy Composer2","ESX-1","Frame4, bay 3","12/03/2021 06:50:00","17","0","156"


Requirements:
   - HPE Global Dashboard administrator account 


  Author: lionel.jullien@hpe.com
  Date:   March 2018
    
#################################################################################
#                         Server FW Inventory in rows.ps1                       #
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


# Global Dashboard information
$username = "Administrator"
$globaldashboard = "oneview-global-dashboard.lj.lab"
 

#################################################################################

$secpasswd = read-host  "Please enter the OneView Global Dashboard password" -AsSecureString
 
# To avoid with self-signed certificate: could not establish trust relationship for the SSL/TLS Secure Channel – Invoke-WebRequest
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

################################################################################# 

#Creation of the header
$headers = @{ } 
$headers["content-type"] = "application/json" 

# Capturing X-API Version
$xapiversion = ((invoke-webrequest -Uri "https://$globaldashboard/rest/version" -Headers $headers -Method GET ).Content | Convertfrom-Json).currentVersion

$headers["X-API-Version"] = $xapiversion


$bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secpasswd)
$password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr) 

#Creation of the body
#$Body = @{userName = $username; password = $password; authLoginDomain = "lj.lab" } | ConvertTo-Json 
$Body = @{userName = $username; password = $password; domain = "local" } | ConvertTo-Json 


#Opening a login session with Global DashBoard
$session = invoke-webrequest -Uri "https://$globaldashboard/rest/login-sessions" -Headers $headers -Body $Body -Method Post 

#Capturing the OneView Global DashBoard Session ID and adding it to the header
$key = ($session.content | ConvertFrom-Json).sessionID
$headers["auth"] = $key

# Capturing managed appliances
$ManagedAppliances = (invoke-webrequest -Uri "https://$globaldashboard/rest/appliances" -Headers $headers -Method GET) | ConvertFrom-Json

$OVappliances = $ManagedAppliances.members

echo "Appliance Name;Appliance IP;Appliance Model;Server Profile;Server Hardware;Sample Time;Temperature;CPU Utilization;Average Power" > Server_Telemetry_Report.txt 

Clear-Host

foreach ($OVappliance in $OVappliances) {

    $OVssoid = $false
    Write-host "`nAppliance name: "-nonewline ; Write-Host $OVappliance.applianceName -f Green  
    Write-host "Appliance IP: "-nonewline ; Write-Host $OVappliance.applianceLocation -f Green  

    $OVIP = $OVappliance.applianceLocation
    $ID = $OVappliance.id
    $apiversion = $OVappliance.currentApiVersion

    #Creation of the header
    $OVheaders = @{ } 
    $OVheaders["content-type"] = "application/json" 
    $OVheaders["X-API-Version"] = $apiversion
    
    do {
        $OVssoid = ((invoke-webrequest -Uri "https://$globaldashboard/rest/appliances/$ID/sso" -Headers $headers -Method GET) | ConvertFrom-Json).sessionID
    } until ($OVssoid )
       
    $OVheaders["auth"] = $OVssoid

    #Opening a login session with Composer
    $OVProfiles = (invoke-webrequest -Uri "https://$OVIP/rest/server-profiles" -Headers $OVheaders -Method Get | ConvertFrom-Json).members 

     
    foreach ($OVProfile in $OVProfiles) {
          
        $OVserverhardwareuri = $OVProfile.serverHardwareUri

        if ($OVserverhardwareuri) {
            $temperature = $OVserverhardwareuri + "/utilization?fields=AmbientTemperature"
            $Resulttemperature = Invoke-webrequest -Uri "https://$OVIP$temperature" -Headers $OVheaders -Method Get | ConvertFrom-Json
            $CurrentSampletemp = $Resulttemperature.metricList.metricSamples
            $SampleTimetemp = [datetime]($Resulttemperature.newestSampleTime)
            # Collecting the last Temperature sample value
            $LastTempValue = echo $CurrentSampletemp[0][1]

            $serverhardwarename = (Invoke-webrequest -Uri "https://$OVIP$OVserverhardwareuri" -Headers $OVheaders -Method Get | ConvertFrom-Json).name
            write-host "`n > Server Profile: " -NoNewline; write-host -f Cyan $OVProfile.name -NoNewline; write-host " - Compute Module: " -NoNewline; write-host -f Cyan $serverhardwarename
            write-host "   Sample Time: " -NoNewline; write-host -f Cyan $SampleTimetemp
            $DegreeChar = [Char]0x00b0 
            write-host "`t- Temperature: " -NoNewline; Write-Host $LastTempValue$DegreeChar -f Cyan

            $cpuu = $OVserverhardwareuri + "/utilization?fields=CpuUtilization"
            $Resultcpuu = Invoke-webrequest -Uri "https://$OVIP$cpuu" -Headers $OVheaders -Method Get | ConvertFrom-Json
            $CurrentSamplecpuu = $Resultcpuu.metricList.metricSamples
            #$SampleTimecpuu = [datetime]($Resultcpuu.newestSampleTime)
            # Collecting the last CPU Utilization sample value
            $LastcpuuValue = echo $CurrentSamplecpuu[0][1]
            write-host "`t- CPU Utilization: " -NoNewline; write-host $LastcpuuValue -f Cyan

            $AveragePower = $OVserverhardwareuri + "/utilization?fields=AveragePower"
            $ResultAveragePower = invoke-webrequest -Uri "https://$OVIP$AveragePower" -Headers $OVheaders -Method Get | ConvertFrom-Json
            $CurrentSampleAveragePower = $ResultAveragePower.metricList.metricSamples
            #$SampleTimeAveragePower = [datetime]($ResultAveragePower.newestSampleTime)
            # Collecting the last Average Power sample value
            $LastAveragePowerValue = echo $CurrentSampleAveragePower[0][1]
            write-host "`t- Average Power: " -NoNewline; write-host "$($LastAveragePowerValue)W" -f Cyan

            "$($OVappliance.applianceName);$($OVappliance.applianceLocation);$($OVappliance.model);$($OVProfile.name);$serverhardwarename;$SampleTimetemp;$LastTempValue;$LastcpuuValue;$LastAveragePowerValue" | Out-File Server_Telemetry_Report.txt -Append
        }
    }

}

import-csv Server_Telemetry_Report.txt -delimiter ";" | export-csv Server_Telemetry_Report.csv -NoTypeInformation
remove-item Server_Telemetry_Report.txt -Confirm:$false

