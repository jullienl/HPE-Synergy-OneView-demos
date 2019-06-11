# -------------------------------------------------------------------------------------------------------
# --------------------------------------------------------------------------------------------------------

function delete-server
{
    [CmdletBinding()]
    Param
    (
        # Server name
        [Parameter(Mandatory=$true)]
        $name #="win-1"
    )


    # OneView Credentials and IP
    $username = $env:OneView_username
    $password = $env:OneView_password
    $IP = $env:OneView_IP
    
    Import-Module HPOneview.420 

    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

    #Connecting to the Synergy Composer
    $ApplianceConnection = Connect-HPOVMgmt -appliance $IP -UserName $username -Password $password 
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

       

    # Create a hashtable for the results
    $result = @{}

    # Verifying the SP is present
    Try { 
                
        $serverprofileuri = Get-HPOVserverprofile -Name $name -ErrorAction stop | % uri  
    
    }
    
    Catch {

        $result.output = "Delete error ! I cannot find the Server Profile *$($name)* in OneView !"
        # Set a failed result
        $result.success = $false

        Disconnect-HPOVMgmt 

        # Return the result deleting SP and conver it to json
        #$script:resultsp = $result
        return $result | ConvertTo-Json

    }

    # Turning off the server hadware and deleting the SP
    try {
                    
        $server = Get-HPOVServer -ErrorAction stop | ? serverProfileUri -eq $serverprofileuri
         
        $server | Stop-HPOVServer -Force -Confirm:$false -ErrorAction Stop |  out-null

        Do { sleep 2 } until ( (Get-HPOVServer | ? serverProfileUri -eq $serverprofileuri ).powerstate -eq "Off")
        
        sleep 15

        Remove-HPOVServerProfile -ServerProfile $name -force -Confirm:$false -ErrorAction stop | Out-Null
             
            
        $result.output =  "*$($name)* is being deleted" 
            
        # Set a successful result
        $result.success = $true
    
    }

catch{
    $result.output =  "*$($name)* cannot be deleted, please check the OneView UI for further information"
    # Set a failed result
    $result.success = $false
    }

# Return the result deleting SP and conver it to json
#$script:resultsp = $result
Disconnect-HPOVMgmt
return $result | ConvertTo-Json


}