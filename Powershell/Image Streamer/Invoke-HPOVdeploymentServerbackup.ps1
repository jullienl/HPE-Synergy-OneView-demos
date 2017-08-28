<#
.DESCRIPTION
   Invoke-HPOVOSdeploymentServerBackup creates a backup bundle with all the artifacts present on the appliance (Deployment Plans, Golden Images, Build plans and Plan Scripts) 
   and copy the backup bundle zip file to a destination folder
   Note that the Image Streamer backup feature does not backup OS volumes, only the golden Images if present.
   Supports common parameters -verbose, -whatif, and -confirm. 
       
.PARAMETER IP
  IP address of the Composer
  Default: 192.168.1.110
  
.PARAMETER username
  OneView administrator account of the Composer
  Default: Administrator
  
.PARAMETER password
  password of the OneView administrator account 
  Default: password

.PARAMETER name
  name of the backup file
  file is overwritten if already present 

.PARAMETER destination
  existing local folder to save the backup bundle ZIP file 
     
.EXAMPLE
  PS C:\> Invoke-HPOVOSdeploymentServerBackup -IP 192.168.5.1 -username administrator -password HPEinvent -name "Backup-0617" -destination "c:/temp" 
  Creates a backup bundle of the Image Streamer 192.168.1.5 and uploads that backup file named "Backup-0617.zip" to "c:/temp" 
  
.COMPONENT
  This script makes use of the PowerShell language bindings library for HPE OneView
  https://github.com/HewlettPackard/POSH-HPOneView

.LINK
    https://github.com/HewlettPackard/POSH-HPOneView
  
.NOTES
    Author: lionel.jullien@hpe.com
    Date:   June 2017 
    
#################################################################################
#                 Invoke-HPOVOSdeploymentServerBackup.ps1                       #
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
function Invoke-HPOVOSdeploymentServerBackup {

[cmdletbinding(
        DefaultParameterSetName=’Selection’, 
        SupportsShouldProcess=$True, 
        ConfirmImpact='Medium'
        )]

    Param 
    (

        [parameter(ParameterSetName="All")]
        [Alias('composer', 'appliance')]
        [string]$IP = "192.168.1.110",    #IP address of HPE OneView

        [parameter(ParameterSetName="All")]
        [Alias('u', 'userid')]
        [string]$username = "Administrator", 

        [parameter(ParameterSetName="All")]
        [Alias('p', 'pwd')]
        [string]$password = "password",

        [parameter(Mandatory=$true, ParameterSetName="All")]
        [string]$name="backup",

        [parameter(Mandatory=$true, ParameterSetName="All")]
        [string]$destination
                       
    )
   
   
  

## -------------------------------------------------------------------------------------------------------------
##
##                     Function Get-OVTaskError
##
## -------------------------------------------------------------------------------------------------------------

Function Get-HPOVTaskError ($Taskresult)
{
        if ($Taskresult.TaskState -eq "Error")
        {
            $ErrorCode     = $Taskresult.TaskErrors.errorCode
            $ErrorMessage  = $Taskresult.TaskErrors.Message
            $TaskStatus    = $Taskresult.TaskStatus

            write-host -foreground Yellow $TaskStatus
            write-host -foreground Yellow "Error Code --> $ErrorCode"
            write-host -foreground Yellow "Error Message --> $ErrorMessage"
        
           # To be used like:
           #   $result = Wait-HPOVTaskComplete $taskNetwork.Details.uri
           #   Get-HPOVTaskError -Taskresult $result
        
        
        }
}


# Import the OneView 3.0 library

# Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

    if (-not (get-module HPOneview.300)) 
    {  
    Import-module HPOneview.300
    }

# Connection to the Synergy Composer

    if ((test-path Variable:ConnectedSessions) -and ($ConnectedSessions.Count -gt 1)) {
        Write-Host -ForegroundColor red "Disconnect all existing HPOV / Composer sessions and before running script"
        exit 1
        }
    elseif ((test-path Variable:ConnectedSessions) -and ($ConnectedSessions.Count -eq 1) -and ($ConnectedSessions[0].Default) -and ($ConnectedSessions[0].Name -eq $IP)) {
        Write-Host -ForegroundColor gray "Reusing Existing Composer session"
        }
    else {
        #Make a clean connection
        Disconnect-HPOVMgmt -ErrorAction SilentlyContinue
        $Appplianceconnection = Connect-HPOVMgmt -appliance $IP -UserName $username -Password $password
        }


                
import-HPOVSSLCertificate -ApplianceConnection ($connectedSessions | ?{$_.name -eq $IP})

# Creation of the header

    $postParams = @{userName=$username;password=$password} | ConvertTo-Json 
    $headers = @{} 
    #$headers["Accept"] = "application/json" 
    $headers["X-API-Version"] = "300"

# Capturing the OneView Session ID and adding it to the header
    
    try     {
                $credentialdata = Invoke-WebRequest -Uri "https://$IP/rest/login-sessions" -Body $postParams -ContentType "application/json" -Headers $headers -Method POST -UseBasicParsing
            } 
    catch   {
                $reader = new-object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
                $responsebody = $reader.ReadToEnd()
            }

    $key = ($credentialdata.Content | ConvertFrom-Json).sessionId 

    $headers["auth"] = $key

# Capturing the Image Streamer IP address

    $I3sIP = (Get-HPOVImageStreamerAppliance).clusterIpv4Address[0]


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


#Creating the body with the deployment group URI
    $deploymentgroup = Invoke-WebRequest -Uri "https://$I3SIP/rest/deployment-groups" -ContentType "application/json" -Headers $headers -Method GET -UseBasicParsing
    $deploymentgroupURI = (($deploymentgroup.Content | ConvertFrom-Json).members).uri
    $body = '{"deploymentGroupURI":"' + $deploymentgroupURI + '"}' 

# Creating the backup bundle
    $Createbackup = Invoke-WebRequest -Uri "https://$I3SIP/rest/artifact-bundles/backups" -ContentType "application/json" -Headers $headers -Method POST -UseBasicParsing -Body $body 
    $tasklocation = $Createbackup.headers | % location 
      
    sleep 5
    
# Waiting until backup is completed
    Do  {
        #Monitoring the task resource obtained from the response to get the status of backup bundle create operation
        $uri = 'https://' + $I3SIP + $tasklocation 
        $Taskstatus = Invoke-WebRequest -Uri $uri -ContentType "application/json" -Headers $headers -Method GET -UseBasicParsing # -OutFile "c:\tasks.txt"
        $taskstate = ($Taskstatus.Content | Convertfrom-Json).taskstate   

        }
    until ($taskstate -eq "Completed")

    sleep 5

#Uploading the backup file to destination folder 
    $getbackups = Invoke-WebRequest -Uri "https://$I3SIP/rest/artifact-bundles/backups" -ContentType "application/json" -Headers $headers -Method GET -UseBasicParsing 
    $downloadURI = (($getbackups.Content | ConvertFrom-Json).members).downloadURI

    $OutFile = $destination + "\"+ $name + '.zip'
    $downloadbackup = Invoke-WebRequest -Uri "https://$I3SIP$downloadURI" -ContentType "application/json" -Headers $headers -Method GET -UseBasicParsing  -OutFile $OutFile


}
