# -------------------------------------------------------------------------------------------------------
# --------------------------------------------------------------------------------------------------------

function deploy-rhelserver {
    [CmdletBinding()]
    Param
    (
        # Server name
        [Parameter(Mandatory = $true)]
        $name # ="rh"
    )
 
 
    # Server Profile Template name to use for the deployment
    $serverprofiletemplate = "RHEL7.3 deployment with Streamer"


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
        Connect-HPOVMgmt -appliance $IP -UserName $username -Password $password 
    }
    Catch {
        $env = "I cannot connect to OneView ! Check my OneView connection settings using ``find env``" 
        $result.output = "$($env)" 
        $result.success = $false
        
        return $result | ConvertTo-Json
    }


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

    # Verifying the SPT is present
    Try {
        $spt = Get-HPOVServerProfileTemplate -Name $serverprofiletemplate  -ErrorAction Stop

    }      
    catch {

        $result.output = "Deployment error ! I cannot find the Server Profile Template *$($serverprofiletemplate)* in OneView !"
        # Set a failed result
        $result.success = $false

        Disconnect-HPOVMgmt 

        # Return the result deleting SP and conver it to json
        #$script:resultsp = $result
        return $result | ConvertTo-Json
    
    }
 
    # Verifying the SP is not already present
    If (  (Get-HPOVServerProfile -Name $name -ErrorAction Ignore) ) {
        $result.output = "Deployment error ! A Server Profile *$($name)* already exists in OneView !"
        # Set a failed result
        $result.success = $false

        Disconnect-HPOVMgmt 

        # Return the result deleting SP and conver it to json
        #$script:resultsp = $result
        return $result | ConvertTo-Json    
    }


    $server = Get-HPOVServerProfileTemplate -Name $serverprofiletemplate | Get-HPOVServer -NoProfile | ? { $_.powerState -eq "off" -and $_.status -eq "ok" } | Select -first 1

    $osCustomAttributes = Get-HPOVOSDeploymentPlanAttribute -InputObject $spt
 
    $My_osCustomAttributes = $osCustomAttributes

    # An IP address is required here if 'ManagementNIC.constraint' = 'userspecified'
    # ($My_osCustomAttributes | ? name -eq 'ManagementNIC.ipaddress').value = ''   
     
    # 'Auto' to get an IP address from the OneView IP pool or 'Userspecified' to assign a static IP or 'DHCP' to a get an IP from an external DHCP Server
    #    ($My_osCustomAttributes | ? name -eq 'ManagementNIC.constraint').value = 'auto' 
    
    # 'True' must be used here if 'ManagementNIC.constraint' = 'DHCP'
    #    ($My_osCustomAttributes | ? name -eq 'ManagementNIC.dhcp').value = 'False'
    
    # '3' corresponds to the third connection ID number in the server profile connections
    #    ($My_osCustomAttributes | ? name -eq 'ManagementNIC.connectionid').value = '3'
    
    #   ($My_osCustomAttributes | ? name -eq 'ManagementNIC2.dhcp').value = 'False'
    
    #    ($My_osCustomAttributes | ? name -eq 'ManagementNIC2.connectionid').value = '4'
    
    #    ($My_osCustomAttributes | ? name -eq 'SSH').value = 'enabled'
    
    #    ($My_osCustomAttributes | ? name -eq 'Password').value = 'password'
 
    # We are using here the 'profile' token. The server will get its hostname from the server Profile name
    #($My_osCustomAttributes | ? name -eq 'Hostname').value = "{profile}"


    try {
         
        New-HPOVServerProfile -Name $name -ServerProfileTemplate $spt -Server $server -OSDeploymentAttributes $My_osCustomAttributes  -AssignmentType server -ErrorAction Stop | Wait-HPOVTaskComplete | Out-Null
               
        Get-HPOVServer -Name $server.name -ErrorAction Stop | Start-HPOVServer | out-null
        
        $ip = (get-hpovserverprofile -Name $name).osDeploymentSettings.osCustomAttributes | ? name -eq Team0NIC1.ipaddress | % value

        $result.output = "*$($name)* has been created successfully, the server is now starting.`nI have assigned the IP address ``$($IP)`` to the server." 

        # Set a successful result
        $result.success = $true
    
    }

    catch {

        $result.output = "*$($name)* cannot be created, please check in OneView for further information"
        # Set a failed result
        $result.success = $false

    }

    Disconnect-HPOVMgmt 

    # Return the result deleting SP and conver it to json
    #$script:resultsp = $result
    return $result | ConvertTo-Json


}