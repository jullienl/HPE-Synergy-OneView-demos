<# -------------------------------------------------------------------------------------------------------


 Commands:
   getsp <name> - Get Server Profile <name> information 

--------------------------------------------------------------------------------------------------------
#>
function getsp {
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
    
    # $name = "LD-Raid1-test"
    #$name = "win-1"
    # $name = "gen10"
    Try {
        $sp = Get-HPOVServerProfile -name $name -ErrorAction Stop

        $enclosureBay = $sp.enclosureBay

        $enclosurename = (send-HPOVRequest -uri $sp.enclosureUri).name
                
        # SPT - consistency
        $spturi = $sp.serverProfileTemplateUri
        If ( $spturi ) {
            $sptname = (send-HPOVRequest -uri $spturi).name 
            If ($sp.templateCompliance -eq "Compliant") { $consistency = "``Consistent``" } else { $consistency = "``Inconsistent``" }
        }
        

        # Power
        $serverHardwareUri = $sp.serverHardwareUri
        $serverHardwarePowerState = "``$((send-HPOVRequest -uri $serverHardwareUri).powerState)``"

        # OS Deployemnt
        $osdeploymenturi = $sp.osDeploymentSettings.osDeploymentPlanUri
        If ($osdeploymenturi) { $osdeploymentname = (send-HPOVRequest -uri $osdeploymenturi).name } else { $osdeploymentname = "-" }

        # FW
        $firmwareBaselineUri = $sp.firmware.firmwareBaselineUri
        If ($firmwareBaselineUri) { $firmwareBaseline = (send-HPOVRequest -uri $firmwareBaselineUri).name } else { $firmwareBaseline = "-" }


        # Network Connections         
        If ($sp.connectionSettings.connections) {
            $connectionsettings = $sp.connectionSettings.connections | sort-Object -Property id 
           
            $_Connection = @{ }
            foreach ($connectionsetting in $connectionsettings) {
                $connection1portID = " - $($connectionsetting.portId)"
                $networkname_bandwidth = "``$((send-HPOVRequest -uri $connectionsetting.networkUri).name)`` - Allocated bandwidth: ``$($connectionsetting.allocatedMbps/1000)Gb``"
                $_connection.add($connection1portID, $networkname_bandwidth)
            }
        }
        else { $_connection = "" }
        
        # SAN Storage 
        $sanstoragevolumes = $sp.sanStorage.volumeAttachments      
       
        $_sanstorage = @{ }
        If ($sanstoragevolumes) {
            foreach ($sanstoragevolume in $sanstoragevolumes) {
                $sanstoragevolumelun = "LUN: ``$($sanstoragevolume.lun)``"
                $sanstoragevolumename = "- ``$((send-HPOVRequest -uri $sanstoragevolume.volumeUri).name)``"
                $_sanstorage.add($sanstoragevolumename, $sanstoragevolumelun)
            }
        }
        else { $_sanstorage = "" }

        # Local Storage
        $localstoragelogicaldrives = $sp.localStorage.controllers.logicaldrives      
        
        $_localstorage = @{ }
        If ($localstoragelogicaldrives.count -ne 0) {
            foreach ($localstoragelogicaldrive in $localstoragelogicaldrives) {
                $localstoragelogicaldrivename = "  - ``$($localstoragelogicaldrive.name)``"
                $localstoragelogicaldriveraidlevel = "``$($localstoragelogicaldrive.raidlevel)``"
                $localstoragelogicaldrivesnbofdrives = " - $($localstoragelogicaldrive.numPhysicalDrives) drive(s)"
                If ($localstoragelogicaldrive.bootable -eq $True){ $localstoragelogicaldrivebootable = " - Bootable"}

                $_localstorage.add($localstoragelogicaldrivename, $localstoragelogicaldriveraidlevel + $localstoragelogicaldrivesnbofdrives + $localstoragelogicaldrivebootable)
            }
        }
        else { $_localstorage = $Null }

        # SAS Logical JBOD
        $sasLogicalJBODs = $sp.localStorage.sasLogicalJBODs      
        
        $_localJBODstorage = @{ }
        If ($sasLogicalJBODs) {

            foreach ($sasLogicalJBOD in $sasLogicalJBODs) {
           
                $sasLogicalJBODname = "  - ``$($sasLogicalJBOD.name)``"
                              
                [System.Collections.ArrayList]$_drivesinfo = @()
              
                $logicalJBODUri = $sasLogicalJBOD.sasLogicalJBODUri
                $association1 = "SAS_LOGICAL_JBOD_TO_DRIVEBAYS_ASSOCIATION"
                $uri = "/rest/index/associations?name={0}&parentUri={1}" -f $association1, $logicalJBODUri

                $SAS_LOGICAL_JBOD_TO_DRIVEBAYS_ASSOCIATION = (Send-HPOVRequest -Uri $Uri).members

                Foreach ($SAS_LOGICAL_JBOD_TO_DRIVEBAYS_ASSOCIATION in $SAS_LOGICAL_JBOD_TO_DRIVEBAYS_ASSOCIATION) {  
               
                    $driveenclosurename = (Get-HPOVDriveEnclosure) | ? { $_.drivebays.uri -eq $SAS_LOGICAL_JBOD_TO_DRIVEBAYS_ASSOCIATION.childUri } | % name
                
                    $drivecapacity = ((Get-HPOVDriveEnclosure -name $driveenclosurename ).drivebays | ? uri -eq $SAS_LOGICAL_JBOD_TO_DRIVEBAYS_ASSOCIATION.childUri).drive.capacity 

                    $drivestatus = ((Get-HPOVDriveEnclosure -name $driveenclosurename ).drivebays | ? uri -eq $SAS_LOGICAL_JBOD_TO_DRIVEBAYS_ASSOCIATION.childUri).drive.status

                    $drivebay = ((Get-HPOVDriveEnclosure -name $driveenclosurename ).drivebays | ? uri -eq $SAS_LOGICAL_JBOD_TO_DRIVEBAYS_ASSOCIATION.childUri).drive.driveLocation.locationEntries | ? type -eq Bay | % value
             
                    $_drivesinfo += "   ``$($drivecapacity)GB`` - Location: ``$($driveenclosurename)`` in Slot ``$($drivebay)`` - Status: ``$drivestatus``"

                }
                        
                $sasLogicalJBODnbofdrives = "$($sasLogicalJBOD.numPhysicalDrives) drive(s):`n" + (  ($_drivesinfo | % { "     $_" } ) -join "`n" )
                       
                $_localJBODstorage.add($sasLogicalJBODname, $sasLogicalJBODnbofdrives)
            }
        }
        else { $_localJBODstorage = $Null }

        # Bios Settings
        $biossettings = $sp.bios
        
        If ($biossettings.manageBios -eq $True ) {
            $_biosoverriddenSettings = $biossettings.overriddenSettings
            Foreach ($_biosoverriddenSetting in $_biosoverriddenSettings) {
                $_biosSettings += "- $($_biosoverriddenSetting.id) : ``$($_biosoverriddenSetting.value)`` `n"
            }
        }
        else { $_biosSettings = $Null }
       
        


        # Creation of the SP displaying object   
        $spdetails = "`n*Location*: ``{0}, Bay {1}`` - *Power State*: {2} `n*SPT*: {3} `n {4} `n {5}`n*Local Storage*: `n{6}`n{7}`n*OS Deployment*: {8} `n*FW Baseline*: {9}`n{10}" -f `
            $enclosurename, `
            $enclosureBay, `
            $serverHardwarePowerState, `
        ($sptname + " - " + $consistency), `
        ( & { if ($_connection) { "*Network connections*:`n" + (( $_connection.GetEnumerator() | Sort-Object Name | % { " $($_.name) : $($_.value)" }) -join "`n") } else { "*Network connections*: -" } } ), `
        ( & { if ($_sanstorage) { "*SAN Storage*:`n" + (( $_sanstorage.GetEnumerator() | Sort-Object Name | % { " $($_.name) - $($_.value)" }) -join "`n") } else { "*SAN Storage*: -" } } ), `
        ( & { if ($_localstorage) { " - Logical drive(s):`n" + (( $_localstorage.GetEnumerator() | Sort-Object Name | % { " $($_.name) - $($_.value)" }) -join "`n") } else { " - Logical drive(s): -" } } ), `
        ( & { if ($_localJBODstorage) {" - External logical JBOD(s):`n" + (( $_localJBODstorage.GetEnumerator() | Sort-Object Name | % { " $($_.name) - $($_.value)" }) -join "`n") } else { " - External logical JBOD(s): -" } } ), `
            $osdeploymentname, `
            $firmwareBaseline, `
        ( & { if ($_biosSettings) { "*Bios Settings*: `n " + $_biosSettings }else { "*Bios Settings*: -" } })


        $result.output = "Information about *$($name)*: `n$($spdetails)" 
        $result.success = $true

    }

  

    Catch {

        $result.output = "Error, this Server Profile does not exist !" 
        $result.success = $false

    }   



    # Return the result deleting SP and convert it to json
    #$script:resultsp = $result
    return $result | ConvertTo-Json


}