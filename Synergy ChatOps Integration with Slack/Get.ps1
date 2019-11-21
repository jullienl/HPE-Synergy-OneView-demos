<# -------------------------------------------------------------------------------------------------------

List the resource avalaible in OneView 

 Commands:
   get <name> - List the resource available in OneView 

Supported resource names:

profile
network
enclosure
interconnect
LIG
LI
EG
LE
uplinkset
SPT
networkset
osdp
server
user
spp
alert

 --------------------------------------------------------------------------------------------------------
#>
function get {
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
        Connect-HPOVMgmt -appliance $IP -Credential $credentials -ErrorAction stop | out-null
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

       
    if ($name -eq "profile") {    
        
        $splist = Get-HPOVServerProfile | % { "`n- *$($_.Name)* : ``$($_.Status)``" } 
        $profilenb = (Get-HPOVServerProfile | measure-object ).count 

        if (! $splist) { 

            $result.output = "No Server profile found !" 
            $result.success = $false

        }   

        else {
     
            $result.output = "$($profilenb) Server profile(s) found: $($splist)" 
            $result.success = $true
        }
    }



    elseif ($name -eq "network") {    
        
        $networklist = Get-HPOVnetwork | ? category -NotMatch "fc-networks" | % { "`n- *$($_.Name)* : ``$($_.purpose)`` - VLAN: ``$($_.vlanid)``" } 
        $FCnetworklist = Get-HPOVnetwork -Type FibreChannel | % { "`n- *$($_.Name)* : ``$($_.fabrictype)``" } 

        $networknb = (Get-HPOVnetwork | ? category -NotMatch "fc-networks" | measure-object ).count + (Get-HPOVnetwork -Type FibreChannel | measure-object ).count

        $networklist = $networklist + $FCnetworklist

        if (! $networklist) { 

            $result.output = "No network found !" 
            $result.success = $false

        }   

        else {
     
            $result.output = "$($networknb) Network(s) found: $($networklist)" 
            $result.success = $true
        }

    }



    elseif ($name -eq "enclosure") {    
        
        $enclosurelist = Get-HPOVenclosure | % { "`n- *$($_.Name)* - Status: ``$($_.Status)``" } 
        $enclosurenb = (Get-HPOVenclosure | measure-object ).count 

        if (! $enclosurelist) { 

            $result.output = "No enclosure found !" 
            $result.success = $false

        }   

        else {
     
            $result.output = "$($enclosurenb) Enclosure(s) found: $($enclosurelist)" 
            $result.success = $true
        }
    }



    elseif ($name -eq "interconnect") {    
        
        $interconnectlist = Get-HPOVInterconnect | % { "`n- *$($_.Name)*: `n`t$($_.model) - Status: ``$($_.Status)``" } 
        $interconnectnb = (Get-HPOVInterconnect | measure-object ).count 

        if (! $interconnectlist) { 

            $result.output = "No interconnect found !" 
            $result.success = $false

        }   

        else {
     
            $result.output = "$($interconnectnb) Interconnect(s) found: $($interconnectlist)" 
            $result.success = $true
        }
    }



    elseif ($name -eq "LIG") {    
        
        $LIGlist = Get-HPOVLogicalInterconnectGroup | % { "`n- *$($_.Name)*" } 
        $LIGnb = (Get-HPOVLogicalInterconnectGroup | measure-object ).count 

        if (! $LIGlist) { 

            $result.output = "No LIG found !" 
            $result.success = $false

        }   

        else {
     
            $result.output = "$($LIGnb) LIG(s) found: $($LIGlist)" 
            $result.success = $true
        }
    }


    elseif ($name -eq "LI") {    
        
        $LIlist = Get-HPOVlogicalInterconnect | % { "`n- *$($_.Name)* : ``$($_.consistencyStatus)`` - Status: ``$($_.Status)``" } 
        $LInb = (Get-HPOVlogicalInterconnect | measure-object ).count 

        if (! $LIlist) { 

            $result.output = "No Logical Interconnect found !" 
            $result.success = $false

        }   

        else {
     
            $result.output = "$($LInb) Logical Interconnect(s) found: $($LIlist)" 
            $result.success = $true
        }
    }



    elseif ($name -eq "EG") {    
        
        $EGlist = Get-HPOVEnclosureGroup | % { "`n*Name*: ``$($_.Name)`` - *Status*: ``$($_.status)`` $(  $_.associatedLogicalInterconnectGroups | %  { Send-HPOVRequest -uri $_ } | % {"`n - *LIG*: ``$($_.Name)`` $( If ($_.redundancyType) {"- $($_.redundancyType)"} ) " } )" } 
        $EGnb = (Get-HPOVEnclosureGroup | measure-object ).count 

        if (! $EGlist) { 

            $result.output = "No EG found !" 
            $result.success = $false

        }   

        else {
     
            $result.output = "$($EGnb) EG(s) found: $($EGlist)" 
            $result.success = $true
        }
    }



    elseif ($name -eq "LE") {    
        
        $LEnb = (Get-HPOVLogicalEnclosure | measure-object ).count 
        $LElist = Get-HPOVLogicalEnclosure | % { "`n*Name*: ``$($_.Name)`` `n*State*: ``$($_.state)`` `n*Enclosure Group*: ``$( ($_.enclosureGroupUri | %  { Send-HPOVRequest -uri $_ }).Name )`` `n*Enclosures*: $(  $_.enclosureUris | %  { Send-HPOVRequest -uri $_ } | % { "`n- ``$($_.Name)`` " } )" } 

        if (! $LElist) { 

            $result.output = "No LE found !" 
            $result.success = $false

        }   

        else {
     
            $result.output = "$($LEnb) LE(s) found: $($LElist)" 
            $result.success = $true
        }
    }

    

    elseif ($name -eq "uplinkset") {    
        
        $uplinksetlist = Get-HPOVUplinkSet | % { "`n*$($_.Name)* - Status: ``$($_.status)``: $( if($_.networkUris ) { $(   $_.networkUris | % { Send-HPOVRequest -uri $_ } | % { "`n- ``$($_.Name)`` - VLAN: ``$($_.vlanid)`` " }   )} else {"-"}  )   " }   
        $uplinksetnb = (Get-HPOVUplinkSet | measure-object ).count 

        if (! $uplinksetlist) { 

            $result.output = "No Uplink Set found !" 
            $result.success = $false

        }   

        else {
     
            $result.output = "$($uplinksetnb) Uplink Set(s) found: $($uplinksetlist)" 
            $result.success = $true
        }
    }



    elseif ($name -eq "spt") {  

        $spts = Get-HPOVServerProfileTemplate
        $serverprofiletemplates = @{ }

        foreach ($spt in $spts) {
            $sptname = $spt.name
            $SPTUri = $spt.Uri
            $association = "server_profile_template_to_server_profiles"
            $uri = "/rest/index/associations?name={0}&parentUri={1}" -f $association, $SPTUri

            $server_profile_template_to_server_profiles = (Send-HPOVRequest -Uri $Uri).members
            If ($server_profile_template_to_server_profiles) {
                $serverprofileconsistency = @()
                Foreach ($server_profile_template_to_server_profile in $server_profile_template_to_server_profiles) {  
            
                    $serverprofilename = "*$((Send-HPOVRequest -Uri ($server_profile_template_to_server_profile.childUri) ) | % name)*"
                    If ( ((Send-HPOVRequest -Uri ($server_profile_template_to_server_profile.childUri) ) | % templateCompliance) -eq "Compliant" ) {
                        $templateCompliance = "``Consistent``"
                    }
                    Else { $templateCompliance = "``Inconsistent``" }

                    $serverprofileconsistency += ("- " + $serverprofilename + " : " + $templateCompliance)
                }

                $serverprofiletemplates.add($sptname, $serverprofileconsistency)
            }
            Else {

                $serverprofiletemplates.add($sptname, $Null)

            }
           
        }


        $sptlist = ( $serverprofiletemplates.GetEnumerator() | Sort-Object Name | % { if ($_.value) { " - ``$($_.name)`` : $( $_.value | % {"`n`t$($_)"} )   " } else { " - ``$($_.name)``" } }) -join "`n" 
        $spnb = (Get-HPOVServerProfileTemplate | measure-object ).count 

        if (! $sptlist) { 

            $result.output = "No Server Profile Template found !" 
            $result.success = $false

        }   

        else {
     
            $result.output = "$($spnb) Server Profile Template(s) found: `n$($sptlist)" 
            $result.success = $true
        }
    }



    elseif ($name -eq "networkset") {    
        
        $networksettlist = Get-HPOVNetworkSet | % { "`n*$($_.Name)* : $( $_.networkUris | % { Send-HPOVRequest -uri $_ } | % {"`n`t- ``$($_.Name)`` - VLAN: ``$($_.vlanid)`` " }   ) " }
        $networksetnb = (Get-HPOVNetworkSet | measure-object ).count 

        if (! $networksettlist) { 

            $result.output = "No network Set found !" 
            $result.success = $false

        }   

        else {
     
            $result.output = "$($networksetnb) Network Set(s) found: $($networksettlist)" 
            $result.success = $true
        }
    }



    elseif ($name -eq "OSDP") {    
        
        $OSDPlist = Get-HPOVOSDeploymentPlan | % { "`n- *$($_.Name)*" } 
        $OSDPnb = (Get-HPOVOSDeploymentPlan | measure-object ).count 

        if (! $OSDPlist) { 

            $result.output = "No OS Deployment plan found !" 
            $result.success = $false

        }   

        else {
     
            $result.output = "$($OSDPnb) OS Deployment plan(s) found: $($OSDPlist)" 
            $result.success = $true
        }

    }



    elseif ($name -eq "server") {    
        
        $serverlist = Get-HPOVServer | % { "`n*$($_.Name)* : $($_.Model) - Profile: ``$( if ( (Get-HPOVServerProfile| ? uri -eq $_.serverProfileUri) ) { (Get-HPOVServerProfile| ? uri -eq $_.serverProfileUri).name } else {"None"} )`` - Status: ``$($_.Status)``" } 
        $servernb = (Get-HPOVServer | measure-object ).count 

        if (! $serverlist) { 

            $result.output = "No server hardware found !" 
            $result.success = $false

        }   

        else {
     
            $result.output = "$($servernb) Server Hardware found: $($serverlist)" 
            $result.success = $true
        }

    }



    elseif ($name -eq "user") {    
        
        $userlist = Get-HPOVuser | % { "`n- *$($_.userName)*: ``$( If ($_.enabled) {"Enabled"} else {"Not enabled"})`` - Permissions: $( $_.permissions.rolename | % { "``$($_)`` "})" } 
        $usernb = (Get-HPOVuser | measure-object ).count 

        $ldapgroup = Get-HPOVLdapGroup | % { If ($_.egroup) { ":`n- *$($_.egroup)* - Permissions: $( $_.permissions.rolename | % { "``$($_)`` "}) - Directory: ``$($_.loginDomain)``" } else { } } 
        $ldapgroupnb = (Get-HPOVLdapGroup | measure-object ).count

        if (! $userlist) { 

            $result.output = "No user found !" 
            $result.success = $false

        }   

        else {
            if ($ldapgroup) { 
                $result.output = "$($usernb) Local User(s) found: $($userlist) `n$($ldapgroupnb) LDAP Group(s) found $($ldapgroup) " 
                
            }
            else {
                $result.output = "$($usernb) Local User(s) found: $($userlist)" 

            }
            $result.success = $true

        }

    }
    


    elseif ($name -eq "spp") {    
        
        $spplist = Get-HPOVBaseline | % { "`n- *$($_.Name)* - location: ``$($_.locations)``" } 

        $sppnb = (Get-HPOVBaseline | measure-object ).count 

        if (! $spplist) { 

            $result.output = "No SPP Baseline found !" 
            $result.success = $false

        }   

        else {
     
            $result.output = "$($sppnb) SPP Baseline(s) found: $($spplist)" 
            $result.success = $true
        }

    }



    elseif ($name -eq "alert") {    
        
        $alertlist = Get-HPOVAlert -alertstate active | % { "`n`n*$($_.description)* `n`tSeverity: ``$($_.severity)`` - Date: ``$( [datetime]$_.created )`` - State: ``$($_.alertstate)`` `n*Resolution*: $($_.correctiveAction)" } 
        $alertlist += Get-HPOVAlert -alertstate locked | % { "`n`n*$($_.description)* `n`tSeverity: ``$($_.severity)`` - Date: ``$( [datetime]$_.created )`` - State: ``$($_.alertstate)`` `n*Resolution*: $($_.correctiveAction)" } 

        $alertnb = ((Get-HPOVAlert -alertstate active) | measure-object ).count + ((Get-HPOVAlert -alertstate locked) | measure-object ).count 

        if (! $alertlist) { 

            $result.output = "No active alert found !" 
            $result.success = $false

        }   

        else {
     
            $result.output = "$($alertnb) Active alert(s) found: $($alertlist)" 
            $result.success = $true
        }

    }



    else {

        $result.output = "Sorry Master, I cannot execute this get resource request in OneView !" 
        $result.success = $false

    }



    # Return the result deleting SP and convert it to json
    #$script:resultsp = $result
    return $result | ConvertTo-Json


}