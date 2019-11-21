<# -------------------------------------------------------------------------------------------------------

 Commands:
   getspt <name> - Get Server Profile Template <name> information 

--------------------------------------------------------------------------------------------------------
#>
function getspt {
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

    #Import-Module HPOneview.500  
    $secpasswd = ConvertTo-SecureString $password -AsPlainText -Force
    $credentials = New-Object System.Management.Automation.PSCredential ($username, $secpasswd)
    
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

    # Create a hashtable for the results
    $result = @{ }

    #Connecting to the Synergy Composer
    Try {
        Connect-HPOVMgmt -appliance $IP -Credential $credentials | out-null
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
    
    # $name = "RAID1-SPT"
    #$name = "SPT-660"
    #$name = "ESXi 6.5U2 deployment with Streamer"
    
    Try {
        $spt = Get-HPOVServerProfileTemplate -name $name -ErrorAction Stop

        $enclosureGroupuri = $spt.enclosureGroupUri

        $enclosuregroupname = (send-HPOVRequest -uri $enclosureGroupuri).name
                
        # SP - consistency   	
        $SPTUri = $spt.Uri
        $association = "server_profile_template_to_server_profiles"
        $uri = "/rest/index/associations?name={0}&parentUri={1}" -f $association, $SPTUri

        $server_profile_template_to_server_profiles = (Send-HPOVRequest -Uri $Uri).members
        If ($server_profile_template_to_server_profiles) {
            $serverprofileconsistency = @{ }
            Foreach ($server_profile_template_to_server_profile in $server_profile_template_to_server_profiles) {  
            
                $serverprofilename = (Send-HPOVRequest -Uri ($server_profile_template_to_server_profile.childUri) ) | % name
                If ( ((Send-HPOVRequest -Uri ($server_profile_template_to_server_profile.childUri) ) | % templateCompliance) -eq "Compliant" ) {
                    $templateCompliance = "Consistent"
                }
                Else { $templateCompliance = "Inconsistent" }

                $serverprofileconsistency.add($serverprofilename, $templateCompliance)
            }
        }
        Else {
            $serverprofileconsistency = ""
        }

              
        # OS Deployemnt
        $osdeploymenturi = $spt.osDeploymentSettings.osDeploymentPlanUri
        If ($osdeploymenturi) { $osdeploymentname = (send-HPOVRequest -uri $osdeploymenturi).name } else { $osdeploymentname = "-" }

        # FW
        $firmwareBaselineUri = $spt.firmware.firmwareBaselineUri
        If ($firmwareBaselineUri) { $firmwareBaseline = (send-HPOVRequest -uri $firmwareBaselineUri).name } else { $firmwareBaseline = "-" }


        # Network Connections         
        If ($spt.connectionSettings.connections) {
            $connectionsettings = $spt.connectionSettings.connections | sort-Object -Property id 
           
            $_Connection = @{ }
            foreach ($connectionsetting in $connectionsettings) {
                $connection1portID = " - $($connectionsetting.portId)"
                $networkname_bandwidth = "``$((send-HPOVRequest -uri $connectionsetting.networkUri).name)`` - Allocated bandwidth: ``$($connectionsetting.requestedMbps/1000)Gb``"
                $_connection.add($connection1portID, $networkname_bandwidth)
            }
        }
        else { $_connection = "" }
        
        # SAN Storage 
        $sanstoragevolumes = $spt.sanStorage.volumeAttachments      
       
        $_sanstorage = @{ }
        If ($sanstoragevolumes) {
            foreach ($sanstoragevolume in $sanstoragevolumes) {
                $sanstoragevolumelun = "LUN: ``$($sanstoragevolume.lunType)``"
                $sanstoragevolumename = "- ``$((send-HPOVRequest -uri $sanstoragevolume.volumeUri).name)``"
                $_sanstorage.add($sanstoragevolumename, $sanstoragevolumelun)
            }
        }
        else { $_sanstorage = "" }

        # Local Storage
        $localstoragelogicaldrives = $spt.localStorage.controllers.logicaldrives      
        
        $_localstorage = @{ }
        
        If ($localstoragelogicaldrives.count -ne 0) {
            
            #To bypass OV4.2 bug that creates an array with 2 elements when only one Logical drive is created
            If ( $localstoragelogicaldrives[0] -eq $null) {
                $localstoragelogicaldrivename = "  - ``$($localstoragelogicaldrives.name)``"
                $localstoragelogicaldriveraidlevel = "``$($localstoragelogicaldrives.raidlevel)``"
                $localstoragelogicaldrivesnbofdrives = " - $($localstoragelogicaldrives.numPhysicalDrives) drive(s)"
                If ($localstoragelogicaldrives.bootable -eq $True) { $localstoragelogicaldrivebootable = " - Bootable" }
          
                $_localstorage.add($localstoragelogicaldrivename, $localstoragelogicaldriveraidlevel + $localstoragelogicaldrivesnbofdrives + $localstoragelogicaldrivebootable)
            }
            Else {
                Foreach ($localstoragelogicaldrive in $localstoragelogicaldrives) {
                    $localstoragelogicaldrivename = "  - ``$($localstoragelogicaldrive.name)``"
                    $localstoragelogicaldriveraidlevel = "``$($localstoragelogicaldrive.raidlevel)``"
                    $localstoragelogicaldrivesnbofdrives = " - $($localstoragelogicaldrive.numPhysicalDrives) drive(s)"
                    If ($localstoragelogicaldrive.bootable -eq $True) { $localstoragelogicaldrivebootable = " - Bootable" }
          
                    $_localstorage.add($localstoragelogicaldrivename, $localstoragelogicaldriveraidlevel + $localstoragelogicaldrivesnbofdrives + $localstoragelogicaldrivebootable)
                }
            }
        }
        else { $_localstorage = $Null }

        # SAS Logical JBOD
        $sasLogicalJBODs = $spt.localStorage.sasLogicalJBODs      
        
        $_localJBODstorage = @{ }
        If ($sasLogicalJBODs) {

            foreach ($sasLogicalJBOD in $sasLogicalJBODs) {
           
                $sasLogicalJBODname = "  - ``$($sasLogicalJBOD.name)``"
                              
                [System.Collections.ArrayList]$_drivesinfo = @()
                              
                $driveMinSizeGB = $sasLogicalJBOD.driveMinSizeGB
                $driveMaxSizeGB = $sasLogicalJBOD.driveMaxSizeGB
                $driveTechnology = $sasLogicalJBOD.driveTechnology
                $persistent = $sasLogicalJBOD.persistent

                $_drivesinfo += " Min Size: ``$($driveMinSizeGB)GB`` - Max Size: ``$($driveMaxSizeGB)GB`` - Drive Technology: ``$($driveTechnology)`` - Persistent: ``$persistent``"

            }
                        
            $sasLogicalJBODnbofdrives = "$($sasLogicalJBOD.numPhysicalDrives) drive(s):`n" + (  ($_drivesinfo | % { "     $_" } ) -join "`n" )
                       
            $_localJBODstorage.add($sasLogicalJBODname, $sasLogicalJBODnbofdrives)
        }
        else { $_localJBODstorage = $Null }

        # Bios Settings
        $biossettings = $spt.bios
        
        If ($biossettings.manageBios -eq $True ) {
            $_biosoverriddenSettings = $biossettings.overriddenSettings
            Foreach ($_biosoverriddenSetting in $_biosoverriddenSettings) {
                $_biosSettings += "- $($_biosoverriddenSetting.id) : ``$($_biosoverriddenSetting.value)`` `n"
            }
        }
        else { $_biosSettings = $Null }
       
              
        


        # Creation of the SPT displaying object   
        $sptdetails = "`n*Enclosure group name*: ``{0}`` `n{1} `n {2} `n {3}`n*Local Storage*: `n{4}`n{5}`n*OS Deployment*: {6} `n*FW Baseline*: {7}`n{8}" -f `
            $enclosuregroupname, `
        ( & { if ($serverprofileconsistency) { "*Associated Server Profile(s)*:`n" + (( $serverprofileconsistency.GetEnumerator() | Sort-Object Name | % { " - $($_.name) : ``$($_.value)``" }) -join "`n") } else { "*Associated Server Profile(s)*: -" } } ), `
        ( & { if ($_connection) { "*Network connections*:`n" + (( $_connection.GetEnumerator() | Sort-Object Name | % { " $($_.name) : $($_.value)" }) -join "`n") } else { "*Network connections*: -" } } ), `
        ( & { if ($_sanstorage) { "*SAN Storage*:`n" + (( $_sanstorage.GetEnumerator() | Sort-Object Name | % { " $($_.name) - $($_.value)" }) -join "`n") } else { "*SAN Storage*: -" } } ), `
        ( & { if ($_localstorage) { " - Logical drive(s):`n" + (( $_localstorage.GetEnumerator() | Sort-Object Name | % { " $($_.name) - $($_.value)" }) -join "`n") } else { " - Logical drive(s): -" } } ), `
        ( & { if ($_localJBODstorage) { " - External logical JBOD(s):`n" + (( $_localJBODstorage.GetEnumerator() | Sort-Object Name | % { " $($_.name) - $($_.value)" }) -join "`n") } else { " - External logical JBOD(s): -" } } ), `
            $osdeploymentname, `
            $firmwareBaseline, `
        ( & { if ($_biosSettings) { "*Bios Settings*: `n " + $_biosSettings } else { "*Bios Settings*: -" } })


        $result.output = "Information about *$($name)*: `n$($sptdetails)" 
        $result.success = $true

    }

  

    Catch {

        $result.output = "Error, this Server Profile Template does not exist !" 
        $result.success = $false

    }   



    # Return the result deleting SP and convert it to json
    #$script:resultsp = $result
    return $result | ConvertTo-Json
    Disconnect-HPOVMgmt | out-null


}