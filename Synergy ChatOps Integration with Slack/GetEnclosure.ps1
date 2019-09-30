<# -------------------------------------------------------------------------------------------------------

 Commands:
   getenclosure <name> - Get Frame <name> information (e.g. Frame1)

--------------------------------------------------------------------------------------------------------
#>
function getenclosure {
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
    
    # $name = "Frame1"
    # $name = "Frame2, bay 2"
    
    Try {
        $frame = Get-HPOVEnclosure -name $name -ErrorAction Stop

        #state
        $state = $frame.State
        
        #Model
        $enclosureModel = $frame.enclosureModel

        # LE Name
        $logicalEnclosureUri = $frame.logicalEnclosureUri
        If ($logicalEnclosureUri) { $logicalEnclosureName = (send-HPOVRequest -uri $logicalEnclosureUri).name } Else { $logicalEnclosureName = "None" }
        
        #serialNumber
        $serialNumber = $frame.serialNumber
        
        # EnvironmentalConfiguration 
        $frameuri = $frame.Uri 
        $utilization = (Send-HPOVRequest -Uri "$($frameUri)/utilization").metricList       
     
        $AmbientTemperature = (($utilization | ? metricname -eq AmbientTemperature).metricSamples)
        $AmbientTemperaturesize = (($utilization | ? metricname -eq AmbientTemperature).metricSamples).count
        $total1 = $Null
        for ($i = 0; $i -lt $AmbientTemperaturesize; $i++) {
            $total1 += $AmbientTemperature[$i][1]
        }
        $AmbientTemperatureAverage = [math]::round(($total1 / $AmbientTemperaturesize), 1)

        $PeakPower = (($utilization | ? metricname -eq PeakPower).metricSamples)
        $PeakPowersize = (($utilization | ? metricname -eq PeakPower).metricSamples).count
        for ($i = 0; $i -lt $PeakPowersize; $i++) {
            $total2 += $PeakPower[$i][1]
        }
        $PeakPowerAverage = [math]::round($total2 / $PeakPowersize, 1)

        $AveragePower = (($utilization | ? metricname -eq AveragePower).metricSamples)
        $AveragePowersize = (($utilization | ? metricname -eq AveragePower).metricSamples).count
        for ($i = 0; $i -lt $AveragePowersize; $i++) {
            $total3 += $AveragePower[$i][1]
        }
        $AveragePowerAverage = [math]::round($total3 / $AveragePowersize, 1)
  


        # Appliance Bays
        $applianceBays = $frame.applianceBays

        $appliances = @{ }
        foreach ($applianceBay in $applianceBays) {
            If (($applianceBay.devicePresence) -eq "Present") {
                $ApplianceName = $applianceBay.model
                $bayNumber = "``$($applianceBay.bayNumber)``"
                $appliances.add($ApplianceName, $bayNumber)
            }
        }


        # Interconnect Bays
        $interconnectBays = $frame.interconnectBays

        $interconnects = @{}
        foreach ($interconnectBay in $interconnectBays) {
            If ($interconnectBay.interconnectModel) {
               
                $interconnectName = "``$($interconnectBay.interconnectModel)``"
               
                $interconnectbayNumber = "``$($interconnectBay.bayNumber)``"
                
                $interconnects.add($interconnectbayNumber, $interconnectName)
            }
        }       




        # Creation of the SP displaying object   
        $framedetails = "`n*Frame Model*: ``{0}`` - *State*: ``{1}`` - *Serial Number*: ``{2}`` `n*Logical Enclosure Name*: ``{3}`` `n*Ambiant Temperature*: ``{4} °C`` `n*Peak Power*: ``{5}W``  `n*Average Power*: ``{6}W`` `n{7} `n{8}" -f `
            $enclosureModel, `
            $state, `
            $serialNumber , `
            $logicalEnclosureName, `
            $AmbientTemperatureAverage, `
            $PeakPowerAverage, `
            $AveragePowerAverage, `
            ( & { if ($appliances) { "*Management Appliances*:`n" + (( $appliances.GetEnumerator() | Sort-Object Name | % { " - Slot $($_.value) : ``$($_.name)``" }) -join "`n") } else { "*Management Appliances*: -" } } ), `
            ( & { if ($interconnects) { "*Interconnect Modules*:`n" + (( $interconnects.GetEnumerator() | Sort-Object Name | % { " - Slot $($_.name) : $($_.value)" }) -join "`n") } else { "*Interconnect Modules*: -" } } )
            

        


        $result.output = "Information about *$($name)*: `n$($framedetails)" 
        $result.success = $true

    }

  

    Catch {

        $result.output = "Error, this Frame does not exist !" 
        $result.success = $false

    }   



    # Return the result deleting SP and convert it to json
    #$script:resultsp = $result
    return $result | ConvertTo-Json


}