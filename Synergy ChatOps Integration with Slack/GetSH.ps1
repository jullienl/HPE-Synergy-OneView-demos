<# -------------------------------------------------------------------------------------------------------

 Commands:
   getsp <name> - Get Server Hardware <name> information (e.g. Frame1, bay 2)

--------------------------------------------------------------------------------------------------------
#>
function getsh {
    [CmdletBinding()]
    Param
    (
        # name of the ressource to run a get request
        [Parameter()]
        $name = "" 
    )


    # OneView Credentials and IP
    $username = $env:OneView_username
    $password = $env:OneView_password
    $IP = $env:OneView_IP

    Import-Module HPOneview.420 

    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

    # Create a hashtable for the results
    $result = @{ }

    #Connecting to the Synergy Composer
    Try {
        Connect-HPOVMgmt -appliance $IP -UserName $username -Password $password | out-null
    }
    Catch {
        $env = "I cannot connect to OneView ! Check my OneView connection settings using ``find env``" 
        $result.output = "$($env)" 
        $result.success = $false
        
        return $result | ConvertTo-Json
    }

    #import-HPOVSSLCertificate -ApplianceConnection ($connectedSessions | ? {$_.name -eq $IP}) 

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
    
    # $name = "Frame1, bay 2"
    # $name = "Frame2, bay 2"
    
    Try {
        $sh = Get-HPOVServer -name $name -ErrorAction Stop

        $serverName = $sh.serverName
        
        #status
        $status = $sh.status

        # SP Name
        $serverProfileUri = $sh.serverProfileUri
        If ($serverprofileuri) { $serverProfileName = (send-HPOVRequest -uri $serverProfileUri).name } Else { $serverProfileName = "None" }
                
        # Power
        $powerState = $sh.powerState
               

        # Model
        $shortModel = $sh.shortModel
        
        # iLO IP
        $mpIpAddress = ($sh.mpHostInfo.mpIpAddresses | ? type -eq "DHCP").address
                
        # romVersion
        $romVersion = $sh.romVersion

        #processorInfo
        $processorType = $sh.processorType
        $processorCount = $sh.processorCount
        $processorCoreCount = $sh.processorCoreCount
        
        #memoryMb
        $memoryGB = $sh.memoryMb/1024


        # Device Slots
        If ($sh.portMap.deviceSlots) {
            $deviceSlots = $sh.portMap.deviceSlots | sort-Object -Property deviceNumber 
           
            $devices = @{ }
            foreach ($deviceSlot in $deviceSlots) {
                If ($deviceSlot.deviceName) {
                    $deviceName = $deviceSlot.deviceName
                    $deviceNumber = "``$($deviceslot.deviceNumber)``"
                    $devices.add($deviceName, $deviceNumber)
                }
            }
        }
        else { $devices = "" }
        
        # EnvironmentalConfiguration 
        
        $shuri = $sh.Uri 
        $utilization = (Send-HPOVRequest -Uri "$($shUri)/utilization").metricList
        
        $AmbientTemperature = (($utilization | ? metricname -eq AmbientTemperature).metricSamples)
        $AmbientTemperaturesize = (($utilization | ? metricname -eq AmbientTemperature).metricSamples).count
        $total1=$Null
        for ($i = 0; $i -lt $AmbientTemperaturesize; $i++) {
            $total1 += $AmbientTemperature[$i][1]
        }
        $AmbientTemperatureAverage = [math]::round(($total1/$AmbientTemperaturesize),1)

        $CpuUtilization = (($utilization | ? metricname -eq CpuUtilization).metricSamples)
        $CpuUtilizationsize = (($utilization | ? metricname -eq CpuUtilization).metricSamples).count
        for ($i = 0; $i -lt $CpuUtilizationsize; $i++) {
            $total2 += $CpuUtilization[$i][1]
        }
        $CpuUtilizationAverage = [math]::round($total2/$CpuUtilizationsize,1)

        $AveragePower = (($utilization | ? metricname -eq AveragePower).metricSamples)
        $AveragePowersize = (($utilization | ? metricname -eq AveragePower).metricSamples).count
        for ($i = 0; $i -lt $AveragePowersize; $i++) {
            $total3 += $AveragePower[$i][1]
        }
        $AveragePowerAverage = [math]::round($total3/$AveragePowersize,1)
  



        # Creation of the SP displaying object   
        $shdetails = "`n*Server Name*: ``{0}`` - *Status*: ``{1}`` - *Power State*: ``{2}`` `n*Processor*: ``{4}`` x {3} - ``{5}`` Cores `n*Memory*: ``{6}GB``  `n*Server Profile*: ``{7}`` `n*Model*: ``{8}`` `n*iLO*: ``{9}`` `n*ROM Version*: ``{10}`` `n{11}`n*Temp*: ``{12}`` - *Power*: ``{13}`` - *CPU*: ``{14}``" -f `
            $serverName, `
            $status, `
            $powerState , `
            $processorType, `
            $processorCount, `
            $processorCoreCount, `
            $memoryGB, `
            $serverProfileName, `
            $shortModel, `
            $mpIpAddress, `
            $romVersion, `
            ( & { if ($devices) { "*Mezz cards*:`n" + (( $devices.GetEnumerator() | Sort-Object Name | % { " - Slot $($_.value) : ``$($_.name)``" }) -join "`n") } else { "*Mezz cards:*: -" } } ), `
            $AmbientTemperatureAverage, `
            $AveragePowerAverage, `
            $CpuUtilizationAverage

        


        $result.output = "Information about *$($name)*: `n$($shdetails)" 
        $result.success = $true

    }

  

    Catch {

        $result.output = "Error, this Server Hardware does not exist !" 
        $result.success = $false

    }   



    # Return the result deleting SP and convert it to json
    #$script:resultsp = $result
    return $result | ConvertTo-Json


}