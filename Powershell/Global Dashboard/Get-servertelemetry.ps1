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

#Opening a login session with Global DashBoard
$session = invoke-webrequest -Uri "https://$globaldashboard/rest/login-sessions" -Headers $headers -Body $Body -Method Post 

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


#Capturing the OneView Global DashBoard Session ID and adding it to the header
$key = ($session.content | ConvertFrom-Json).sessionID
$headers["auth"] = $key

$ManagedAppliances = (invoke-webrequest -Uri "https://$globaldashboard/rest/appliances" -Headers $headers -Method GET) | ConvertFrom-Json

$OVappliances = $ManagedAppliances.members

echo "Appliance Name;Appliance IP;Appliance Model;Server Profile;Sample Time;Temperature;CPU Average;CPU Utilization;Average Power" > Server_Telemetry_Report.txt 

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
        $LastcpuuValue = echo $CurrentSamplecpuu[0][1]
        write-host "`t- CPU Utilization: " -NoNewline; write-host $LastcpuuValue -f Cyan

        $AveragePower = $OVserverhardwareuri + "/utilization?fields=AveragePower"
        $ResultAveragePower = invoke-webrequest -Uri "https://$OVIP$AveragePower" -Headers $OVheaders -Method Get | ConvertFrom-Json
        $CurrentSampleAveragePower = $ResultAveragePower.metricList.metricSamples
        #$SampleTimeAveragePower = [datetime]($ResultAveragePower.newestSampleTime)
        $LastAveragePowerValue = echo $CurrentSampleAveragePower[0][1]
        write-host "`t- Average Power: " -NoNewline; write-host "$($LastAveragePowerValue)W" -f Cyan

 
        "$($OVappliance.applianceName);$($OVappliance.applianceLocation);$($OVappliance.model);$($OVProfile.name);$SampleTimetemp;$LastTempValue;$LastcpuValue;$LastcpuuValue;$LastAveragePowerValue" | Out-File Server_Telemetry_Report.txt -Append
    }
}


import-csv Server_Telemetry_Report.txt -delimiter ";" | export-csv Server_Telemetry_Report.csv -NoTypeInformation
remove-item Server_Telemetry_Report.txt -Confirm:$false





