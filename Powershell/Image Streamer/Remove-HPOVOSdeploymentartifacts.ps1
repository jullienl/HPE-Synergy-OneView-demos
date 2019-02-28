<#
.DESCRIPTION
   Remove-HPOVOSdeploymentartifacts deletes artifacts that are present in the Image Streamer appliance.
   Supports common parameters -verbose, -whatif, and -confirm. 
   Image Streamer modifications are done through HPE OneView
       
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
  case-insensitive name of the artifact to delete. 
  Accepts pipeline input ByValue and ByPropertyName. 

.PARAMETER partialsearch
  runs a search using partial name of the artifact to delete. 
    
.PARAMETER allartifacts
  deletes all Image Streamer artifacts: deployment plans, golden images, build plans, plan scripts and artifact bundles
  
.PARAMETER deploymentplan
  deletes deployment plan
  
.PARAMETER goldenimage
  deletes golden image
  
.PARAMETER OSbuildplan
  deletes build plan
  
.PARAMETER planscript
  deletes plan script
  
.PARAMETER artifactbundle
  deletes artifact bundle
  
.EXAMPLE
  PS C:\> Remove-HPOVOSdeploymentartifacts -IP 192.168.1.110 -username administrator -password password -name "HPE-Foundation - create empty OS Volume" -OSbuildplan -Confirm 
  Removes the OS build plan "HPE-Foundation - create empty OS Volume" and provides a prompt requesting confirmation of the deletion 
  
.EXAMPLE
  PS C:\> Remove-HPOVOSdeploymentartifacts -IP 192.168.5.1 -username administrator -password paswword -name "HPE-ESXi-simple host configuration with NIC HA" -deploymentplan 
  Removes without confirmation the deployment plan "HPE-ESXi-simple host configuration with NIC HA" 

.EXAMPLE
  PS C:\> Remove-HPOVOSdeploymentartifacts -IP 192.168.5.1 -username administrator -password paswword -name "HPE-ESXi-simple host configuration with NIC HA" -deploymentplan -OSbuildplan
  Removes without confirmation the deployment plan and OS Build plan "HPE-ESXi-simple host configuration with NIC HA" 

.EXAMPLE
  PS C:\> Remove-HPOVOSdeploymentartifacts -allartifacts -name "ESX" -Confirm -partialsearch
  Removes all artifacts (deployment plans, golden images, build plans, plan scripts and artifact bundles) containing the string "ESX" and provides a prompt requesting confirmation of the deletion 

.EXAMPLE
  PS C:\> Get-HPOVOSDeploymentPlan | where {$_.name -match "ESX"} | Remove-HPOVOSdeploymentartifacts -deploymentplan 
  Search for OS Deployment plans matching with the name "ESX" and remove them from the Image Streamer appliance 

.COMPONENT
  This script makes use of the PowerShell language bindings library for HPE OneView
  https://github.com/HewlettPackard/POSH-HPOneView

.LINK
    https://github.com/HewlettPackard/POSH-HPOneView
  
.NOTES
    Author: lionel.jullien@hpe.com
    Date:   April 2017 
    
#################################################################################
#                 Remove-HPOVOSdeploymentartifacts.ps1                           #
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
function Remove-HPOVOSdeploymentartifacts {

[cmdletbinding(
        DefaultParameterSetName=’Selection’, 
        SupportsShouldProcess=$True, 
        ConfirmImpact='Medium'
        )]

    Param 
    (

        [parameter(ParameterSetName="Selection")]
        [parameter(ParameterSetName="All")]
        [Alias('composer', 'appliance')]
        [string]$IP = "192.168.1.110",    #IP address of HPE OneView

        [parameter(ParameterSetName="Selection")]
        [parameter(ParameterSetName="All")]
        [Alias('u', 'userid')]
        [string]$username = "Administrator", 

        [parameter(ParameterSetName="Selection")]
        [parameter(ParameterSetName="All")]
        [Alias('p', 'pwd')]
        [string]$password = "password",

        [parameter(Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, ParameterSetName="Selection")]
        [parameter(Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, ParameterSetName="All")]
        [string]$name="",

        [parameter(ParameterSetName="Selection")]
        [parameter(ParameterSetName="All")]
        [switch]$partialsearch,  

        [parameter(ParameterSetName="All")]
        [Alias('all')]
        [switch]$allartifacts,

        [parameter(ParameterSetName="Selection")]
        [switch]$deploymentplan,

        [parameter(ParameterSetName="Selection")]
        [switch]$goldenimage,

        [parameter(ParameterSetName="Selection")]
        [switch]$OSbuildplan,

        [parameter(ParameterSetName="Selection")]
        [switch]$planscript,

        [parameter(ParameterSetName="Selection")]
        [switch]$artifactbundle       

                       
    )
   
   
  
Function Get-HPOVTaskError ($Taskresult) {
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
   
        if (get-module $module -ListAvailable) {
            if ($update.IsPresent) {
            
                # Updates the module to the latest version
                [string]$Moduleinstalled = (Get-Module -Name $module).version
            
                Try {
                    [string]$ModuleonRepo = (Find-Module -Name $module -ErrorAction Stop).version
                }
                Catch {
                    Write-Warning "Error: No internet connection to update $module ! `
                `nCheck your network connection, you might need to configure a proxy if you are connected to a corporate network!"
                    return 
                }

                $Compare = Compare-Object $Moduleinstalled $ModuleonRepo -IncludeEqual

                If (-not $Compare.SideIndicator -eq '==') {
                    Try {
                        Update-Module -ErrorAction stop -Name $module -Confirm -Force | Out-Null
                    }
                    Catch {
                        write-warning "Error: $module cannot be updated !"
                        return
                    }
           
                }
                Else {
                    Write-host "You are using the latest version of $module !" 
                }
            }
            
            Import-module $module
            
        }

        Else {
            Write-host "$Module cannot be found, let's install it..." -ForegroundColor Cyan

        
            If ( !(get-PSRepository).name -eq "PSGallery" )
            {Register-PSRepository -Default}
                
            Try {
                find-module -Name $module -ErrorAction Stop | out-Null
                
                Try {
                    Install-Module –Name $module -Scope CurrentUser –Force -ErrorAction Stop | Out-Null
                    Write-host "`nInstalling $Module ..." 
                }
                catch {
                    Write-Warning "$Module cannot be installed!" 
                    $error[0] | FL * -force
                    pause
                    exit
                }

            }
            catch {
                write-warning "Error: $module cannot be found in the online PSGallery !"
                return
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




#####################################################################################
#            Capturing OS Deployment Server IP address managed by OneView           #
#####################################################################################


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








#####################################################################################
#                        Removing OS Deployment Plans                               #
#####################################################################################




if ($deploymentplan.IsPresent -or $allartifacts.IsPresent) 

{
   
    $Deploymentplans = Invoke-WebRequest -Uri "https://$I3SIP/rest/deployment-plans" -ContentType "application/json" -Headers $headers -Method GET -UseBasicParsing 

    $Deploymentplans = ($Deploymentplans | ConvertFrom-Json).members

    $Deploymentplanstoremove = ($Deploymentplans | where `
        {
    
            if ($partialsearch.IsPresent) 
            {
                $_.name -Match $name
            }
            else
            { 
                $_.name -Match "^$name$"
            }
            
         })
    

    if ($Deploymentplanstoremove) 

    {
        if ($partialsearch.IsPresent) 
        {
            write-host ""
            Write-host "The string of character $name has been found in the following deployment plan(s):"
            $Deploymentplanstoremove.name | sort-object
        }
        else
        {
            write-host ""
            Write-host "The deployment plan [$name] has been found" 
        }

        Foreach ($Deploymentplantoremove in $Deploymentplanstoremove)
             {

                $Deploymentplantoremoveid = $Deploymentplantoremove.id
                $Deploymentplantoremovename = $Deploymentplantoremove.name
 
    
                try {

                $error.clear()
                      
                if ($pscmdlet.ShouldProcess($IP,"deleting the deployment plan : $Deploymentplantoremovename"))   
                
                        {                
                            $delete = Invoke-WebRequest -Uri "https://$I3SIP/rest/deployment-plans/$Deploymentplantoremoveid" -ContentType "application/json" -Headers $headers -Method DELETE -UseBasicParsing 
                
                            if ($Error[0] -eq $Null) 
                            { 
                            write-host ""
                            Write-host -ForegroundColor Green "[$Deploymentplantoremovename] has been deleted" 
                            }  
                                                                      
                        }
                
                   }


                catch  {
        
                write-host ""
                Write-warning "[$Deploymentplantoremovename] cannot be deleted because it is used by a server profile or a server profile template !"

                pause

                       }


           }

    }
    
    else
    
    {
        write-host ""
        Write-warning "Cannot find any Deployment plan on the Streamer with a name containing: $name"
        pause
    }

   
}





#####################################################################################
#                         Removing Golden Images                                    #
#####################################################################################



if ($goldenimage.IsPresent -or $allartifacts.IsPresent) 

{

    $goldenimages = Invoke-WebRequest -Uri "https://$I3SIP/rest/golden-images" -ContentType "application/json" -Headers $headers -Method GET -UseBasicParsing
    
    $goldenimages = ($goldenimages | ConvertFrom-Json).members

    $goldenimagestoremove = ($goldenimages | where `
        {
    
            if ($partialsearch.IsPresent) 
            {
                $_.name -Match $name
            }
            else
            { 
                $_.name -Match "^$name$"
            }
            
         })
    
    if ($goldenimagestoremove) 
    
    {

        if ($partialsearch.IsPresent) 
        {
            write-host ""
            Write-host "The string of character $name has been found in the following golden image(s):"
            $goldenimagestoremove.name | sort-object
        }
        else
        {
            write-host ""
            Write-host "The golden image [$name] has been found" 
        }



        Foreach($goldenimagetoremove in $goldenimagestoremove)
        {

            $goldenimagestoremoveid = $goldenimagetoremove.id
            $goldenimagestoremovename = $goldenimagetoremove.name

            try {
            
                $error.clear()

                if ($pscmdlet.ShouldProcess($IP,"deleting the golden image : $goldenimagestoremovename"))   

                    {
                        $delete = Invoke-WebRequest -Uri "https://$I3SIP/rest/golden-images/$goldenimagestoremoveid" -ContentType "application/json" -Headers $headers -Method DELETE -UseBasicParsing 
                        if ($Error[0] -eq $Null) 
                            { 
                            write-host ""
                            Write-host -ForegroundColor Green "[$goldenimagestoremovename] has been deleted"
                            }
                    }
                }
            catch {
    
                write-host ""
                Write-warning "[$goldenimagestoremovename] cannot be deleted because it is being referenced by a deployment plan"
                pause
                  }
        }

    }
 
    else
  
    {
    write-host ""
    Write-warning "Cannot find any Golden Image on the Streamer with a name containing: $name"
    pause
    }
    
}




#####################################################################################
#                               Removing  OS Build Plans                               #
#####################################################################################

if ($OSbuildplan.IsPresent -or $allartifacts.IsPresent) 

{

    $OSbuildplans = Invoke-WebRequest -Uri "https://$I3SIP/rest/build-plans" -ContentType "application/json" -Headers $headers -Method GET -UseBasicParsing
    
    $OSbuildplans = ($OSbuildplans.ToString().Replace("eTag", "etag") | ConvertFrom-Json).members

    $OSbuildplanstoremove = ($OSbuildplans |  where `
        {
    
            if ($partialsearch.IsPresent) 
            {
                $_.name -Match $name
            }
            else
            { 
                $_.name -Match "^$name$"
            }
            
         })

    if ($OSbuildplanstoremove) 

    {
        if ($partialsearch.IsPresent) 
        {
            write-host ""
            Write-host "The string of character $name has been found in the following OS build plan(s):"
            $OSbuildplanstoremove.name | sort-object
        }
        else
        {
            write-host ""
            Write-host "The OS build plan [$name] has been found" 
        }
                
        Foreach($OSbuildplantoremove in $OSbuildplanstoremove)
        {

            $OSbuildplantoremoveid = $OSbuildplantoremove.buildPlanid
            $OSbuildplantoremovename = $OSbuildplantoremove.name

            try 
            {
                $error.clear()

                if ($pscmdlet.ShouldProcess($IP,"deleting the OS build plan : $OSbuildplantoremovename"))   
                {
                $delete = Invoke-WebRequest -Uri "https://$I3SIP/rest/build-plans/$OSbuildplantoremoveid" -ContentType "application/json" -Headers $headers -Method DELETE -UseBasicParsing 
                if ($Error[0] -eq $Null) 
                    { 
                        write-host ""
                        Write-host -ForegroundColor Green "[$OSbuildplantoremovename] has been deleted"
                    }
                }
            }
            
            catch 
            {
                write-host ""
                Write-warning "[$OSbuildplantoremovename] cannot be deleted because it is in use by one or more deployment plans"
                pause
            }
        }
   }

    else

    {

        write-host ""
        Write-warning "Cannot find any Build plan on the Streamer with a name containing: $name"
        pause

    }

}


#####################################################################################
#                              Removing  Plan Script                                #
#####################################################################################



if ($planscript.IsPresent -or $allartifacts.IsPresent) 

{

    $planscripts = Invoke-WebRequest -Uri "https://$I3SIP/rest/plan-scripts" -ContentType "application/json" -Headers $headers -Method GET -UseBasicParsing

    $planscripts = ($planscripts | ConvertFrom-Json).members

    $planscriptstoremove = ($planscripts |  where `
        {
    
            if ($partialsearch.IsPresent) 
            {
                $_.name -Match $name
            }
            else
            { 
                $_.name -Match "^$name$"
            }
            
         })

    if ($planscriptstoremove) 

    {

        if ($partialsearch.IsPresent) 
        {
            write-host ""
            Write-host "The string of character $name has been found in the following plan script(s):"
            $planscriptstoremove.name | sort-object
        }
        else
        {
            write-host ""
            Write-host "The plan script [$name] has been found" 
        }

        Foreach($planscripttoremove in $planscriptstoremove)
        {

            $planscripttoremoveid = $planscripttoremove.id
            $planscripttoremovename = $planscripttoremove.name

            try 
            {
                $error.clear()

                if ($pscmdlet.ShouldProcess($IP,"deleting the plan script : $planscripttoremovename"))   
                {
                    $delete = Invoke-WebRequest -Uri "https://$I3SIP/rest/plan-scripts/$planscripttoremoveid" -ContentType "application/json" -Headers $headers -Method DELETE -UseBasicParsing 
                    if ($Error[0] -eq $Null) 
                    { 
                        write-host ""
                        Write-host -ForegroundColor Green "[$planscripttoremovename] has been deleted"
                    }

                }

            }
            
            catch 
            
            {
    
                Write-warning "[$planscripttoremovename] cannot be deleted because it is in use by one or more deployment plans"
                pause
            }
        }

}

    else

    {
        write-host ""
        Write-warning "Cannot find any plan script on the Streamer with a name containing: $name"
        pause

    }

}



 
#####################################################################################
#                             Removing  Artifact Bundles                            #
#####################################################################################



if ($namebundle.IsPresent -or $allartifacts.IsPresent) 

{

    $artifactbundles = Invoke-WebRequest -Uri "https://$I3SIP/rest/artifact-bundles" -ContentType "application/json" -Headers $headers -Method GET -UseBasicParsing

    $artifactbundles = ($artifactbundles | ConvertFrom-Json).members

    $artifactbundlestoremove = ($artifactbundles | where `
        {
    
            if ($partialsearch.IsPresent) 
            {
                $_.name -Match $name
            }
            else
            { 
                $_.name -Match "^$name$"
            }
            
         })

    if ($artifactbundlestoremove)
     
    {
        
        if ($partialsearch.IsPresent) 
        {
            write-host ""
            Write-host "The string of character $name has been found in the following artifact bundle(s):"
            $artifactbundlestoremove.name | sort-object
        }
        else
        {
            write-host ""
            Write-host "The artifact bundle [$name] has been found" 
        }

        Foreach($artifactbundletoremove in $artifactbundlestoremove)
        {

            $artifactbundletoremoveid = $artifactbundletoremove.artifactsbundleID
            $artifactbundletoremovename = $artifactbundletoremove.name

            try 
            {
                $error.clear()

                if ($pscmdlet.ShouldProcess($IP,"deleting the artifact bundle : $artifactbundletoremovename"))   
                {
                    $delete = Invoke-WebRequest -Uri "https://$I3SIP/rest/artifact-bundles/$artifactbundletoremoveid" -ContentType "application/json" -Headers $headers -Method DELETE -UseBasicParsing 
                    if ($Error[0] -eq $Null) 
                    { 
                        write-host ""
                        Write-host -ForegroundColor Green "[$artifactbundletoremovename] has been deleted"
                    }
                }
            }
            
            catch 
            {
                Write-warning "[$artifactbundletoremovename] cannot be deleted because it is in use by one or more deployment plans"
                pause
            }
        }
    }

    else

    {
        write-host ""
        Write-warning "Cannot find any artifact bundle on the Streamer with a name containing: $name"
        pause
    }

}



#write-host ""
#Read-Host -Prompt "Operation done ! Hit return to close" 



}


