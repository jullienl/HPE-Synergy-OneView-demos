# Generates a CSV telemetry report with the last sample Temperature/CPU Utilization/Average Power values of all servers managed by HPE OneView Global Dashboard
#
# "Appliance Name", "Appliance IP", "Appliance Model", "Server Profile", "Server Hardware", "Sample Time", "Temperature", "CPU Utilization", "Average Power"
# "composer.lj.lab", "composer.lj.lab", "Synergy Composer", "rh-1", "Frame1, bay 2", "03/12/2020 07:55:00", "17", "1", "57"
# "composer.lj.lab", "composer.lj.lab", "Synergy Composer", "win-2", "Frame3, bay 4", "03/12/2020 08:00:00", "21", "0", "73"
# "composer.lj.lab", "composer.lj.lab", "Synergy Composer", "ESX-65U3.1", "Frame3, bay 5", "03/12/2020 08:00:00", "19", "0", "0"
# "composer.lj.lab", "composer.lj.lab", "Synergy Composer", "win-1", "Frame3, bay 1", "03/12/2020 08:00:00", "19", "0", "63"
# "composer.lj.lab", "composer.lj.lab", "Synergy Composer", "esx-1", "Frame3, bay 9", "03/12/2020 08:00:00", "20", "0", "82"
# "composer.lj.lab", "composer.lj.lab", "Synergy Composer", "RH75-SUT", "Frame1, bay 5", "03/12/2020 08:25:00", "20", "0", "57"
# "HPEOneView-DCS", "hpeoneview-dcs.lj.lab", "HPE OneView - Demo VM", "DL_380_2", "172.18.6.30", "03/12/2020 12:35:00", "0", "0", "0"
# "HPEOneView-DCS", "hpeoneview-dcs.lj.lab", "HPE OneView - Demo VM", "DL_380_1", "172.18.6.13", "03/12/2020 11:45:00", "0", "0", "0"



# Global Dashboard information
$username = "Administrator"
$password = "password"
$globaldashboard = "192.168.1.50"
 
#Creation of the header
$headers = @{ } 
$headers["content-type"] = "application/json" 
$headers["X-API-Version"] = "2"

#Creation of the body
#$Body = @{userName = $username; password = $password; authLoginDomain = "lj.lab" } | ConvertTo-Json 
$Body = @{userName = $username; password = $password; domain = "local" } | ConvertTo-Json 

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

#Opening a login session with Global DashBoard
$session = invoke-webrequest -Uri "https://$globaldashboard/rest/login-sessions" -Headers $headers -Body $Body -Method Post 

#Capturing the OneView Global DashBoard Session ID and adding it to the header
$key = ($session.content | ConvertFrom-Json).sessionID
$headers["auth"] = $key

$ManagedAppliances = (invoke-webrequest -Uri "https://$globaldashboard/rest/appliances" -Headers $headers -Method GET) | ConvertFrom-Json

$OVappliances = $ManagedAppliances.members[0]

echo "Appliance Name;Appliance IP;Appliance Model;Server Profile;Server Hardware;Sample Time;Temperature;CPU Utilization;Average Power" > Server_Telemetry_Report.txt 

Clear-Host

foreach ($OVappliance in $OVappliances) {

    Write-host "`nAppliance name: "-nonewline ; Write-Host $OVappliance.applianceName -f Green  
    Write-host "Appliance IP: "-nonewline ; Write-Host $OVappliance.applianceLocation -f Green  

    $OVIP = $OVappliance.applianceLocation
    $ID = $OVappliance.id

    #Creation of the header
    $OVheaders = @{ } 
    $OVheaders["content-type"] = "application/json" 
    $OVheaders["X-API-Version"] = "1000"
    
    do {
        $OVssoid = ((invoke-webrequest -Uri "https://$globaldashboard/rest/appliances/$ID/sso" -Headers $headers -Method GET) | ConvertFrom-Json).sessionID
    } while ($OVssoid -eq $Null)
    
    $OVheaders["auth"] = $OVssoid

    #Opening a login session with Composer
    $OVProfiles = (invoke-webrequest -Uri "https://$OVIP/rest/server-profiles" -Headers $OVheaders -Method Get | ConvertFrom-Json).members
     
    foreach ($OVProfile in $OVProfiles) {
          
        $OVserverhardwareuri = $OVProfile.serverHardwareUri
        $temperature = $OVserverhardwareuri + "/utilization?fields=AmbientTemperature"
        $Resulttemperature = Invoke-webrequest -Uri "https://$OVIP$temperature" -Headers $OVheaders -Method Get | ConvertFrom-Json
        $CurrentSampletemp = $Resulttemperature.metricList.metricSamples
        $SampleTimetemp = [datetime]($Resulttemperature.newestSampleTime)
        # Collecting the last Temperature sample value
        $LastTempValue = echo $CurrentSampletemp[0][1]


        $serverHardwareUri = $OVProfile.serverHardwareUri 
        $serverhardwarename = (Invoke-webrequest -Uri "https://$OVIP$serverHardwareUri" -Headers $OVheaders -Method Get | ConvertFrom-Json).name
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


import-csv Server_Telemetry_Report.txt -delimiter ";" | export-csv Server_Telemetry_Report.csv -NoTypeInformation
remove-item Server_Telemetry_Report.txt -Confirm:$false