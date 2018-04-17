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
  Password of the OneView administrator account 
  Default: password

.PARAMETER name
  Name of the backup file
  file is overwritten if already present 

.PARAMETER destination
  Existing local folder to save the backup bundle ZIP file 
     
.EXAMPLE
  PS C:\> Invoke-HPOVOSdeploymentServerBackup -IP 192.168.5.1 -username administrator -password HPEinvent -name "Backup-0617" -destination "c:/temp" 
  Creates a backup bundle of the Image Streamer 192.168.1.5 and uploads that backup file named "Backup-0617.zip" to "c:/temp" 
  
.COMPONENTS
  This script makes use of the PowerShell language bindings library for HPE OneView
  https://github.com/HewlettPackard/POSH-HPOneView

.LINKS
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

Function MyImport-Module {
    
    # Import a module that can be imported
    # If it cannot, the module is installed
    # When -update parameter is used, the module is updated 
    # to the latest version available on the PowerShell library
    
    param ( 
        $module, 
        [switch]$update 
           )
   
   if (get-module $module -ListAvailable)

        {
        if ($update.IsPresent) 
            {
            # Updates the module to the latest version
            [string]$Moduleinstalled = (Get-Module -Name $module).version
            [string]$ModuleonRepo = (Find-Module -Name $module -ErrorAction SilentlyContinue).version

            $Compare = Compare-Object $Moduleinstalled $ModuleonRepo -IncludeEqual

            If (-not $Compare.SideIndicator -eq '==')
                {
                Update-Module -Name $module -Confirm -Force | Out-Null
           
                }
            Else
                {
                Write-host "You are using the latest version of $module" 
                }
            }
            
        Import-module $module
            
        }

    Else

        {
        Write-Warning "$Module is not present"
        Write-host "`nInstalling $Module ..." 

        Try
            {
                If ( !(get-PSRepository).name -eq "PSGallery" )
                {Register-PSRepository -Default}
                Install-Module –Name $module -Scope CurrentUser –Force -ErrorAction Stop | Out-Null
                Import-Module $module
            }
        Catch
            {
                Write-Warning "$Module cannot be installed" 
            }
        }

}


# Import the OneView 4.00 library
MyImport-Module HPOneview.400 #-update


Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force


#Connecting to the Synergy Composer

if ($connectedSessions -and ($connectedSessions | ?{$_.name -eq $IP}))
{
    Write-Verbose "Already connected to $IP."
}

else
{
    Try 
    {
        Connect-HPOVMgmt -appliance $IP -UserName $username -Password $password | Out-Null
    }
    Catch 
    {
        throw $_
    }
}

               
import-HPOVSSLCertificate -ApplianceConnection ($connectedSessions | ?{$_.name -eq $IP})


# Creation of the header

    $postParams = @{userName=$username;password=$password} | ConvertTo-Json 
    $headers = @{} 
    #$headers["Accept"] = "application/json" 
    $headers["X-API-Version"] = "600"

    # Capturing the OneView Session ID and adding it to the header
    
    $key = $ConnectedSessions[0].SessionID 

    $headers["auth"] = $key

# Capturing the Image Streamer IP address

   $I3sIP = (Get-HPOVOSDeploymentServer).primaryipv4

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
    write-host "`nCreating the backup bundle, please wait..." -ForegroundColor Green
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

    $backupsize =  [math]::Round(((($getbackups.Content | ConvertFrom-Json).members).size /1GB),2)
    write-host "`nThe $($backupsize)GB Backup file is getting downloaded, please wait..." -for Green

    $OutFile = $destination + "\"+ $name + '.zip'
    $downloadbackup = Invoke-WebRequest -Uri "https://$I3SIP$downloadURI" -ContentType "application/json" -Headers $headers -Method GET -UseBasicParsing  -OutFile $OutFile
    
        write-host "`nThe Image Streamer backup file $name.zip has been succseefully uploaded in $destination" -back Green



}
