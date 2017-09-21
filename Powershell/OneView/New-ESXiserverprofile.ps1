# -------------------------------------------------------------------------------------------------------
#   by lionel.jullien@hpe.com
#   September 2017
#
#   Script to create a Server Profile using the HPE Image Streamer 
#   with OSDeploymentPlanAttributes.
#   
#   A Server Profile Template is required. The server profile template can be created using
#   New-ESXiserverprofiletemplate.ps1
#     
#   OneView administrator account is required. 
#   
#   Latest OneView POSH Library must be used.
# 
# --------------------------------------------------------------------------------------------------------
   
#################################################################################
#                         New-ESXiserverprofile.ps1                             #
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


[string]$HPOVMinimumVersion = "3.10.1443.2882"


function Check-HPOVVersion {
    #Check HPOV version
    #Encourge people to run the latest version
    $arrMinVersion = $HPOVMinimumVersion.split(".")
    $arrHPOVVersion=((Get-HPOVVersion ).LibraryVersion)
    if ( ($arrHPOVVersion.Major -gt $arrMinVersion[0]) -or
        (($arrHPOVVersion.Major -eq $arrMinVersion[0]) -and ($arrHPOVVersion.Minor -gt $arrMinVersion[1])) -or
        (($arrHPOVVersion.Major -eq $arrMinVersion[0]) -and ($arrHPOVVersion.Minor -eq $arrMinVersion[1]) -and ($arrHPOVVersion.Build -gt $arrMinVersion[2])) -or
        (($arrHPOVVersion.Major -eq $arrMinVersion[0]) -and ($arrHPOVVersion.Minor -eq $arrMinVersion[1]) -and ($arrHPOVVersion.Build -eq $arrMinVersion[2]) -and ($arrHPOVVersion.Revision -ge $arrMinVersion[3])) )
        {
        #HPOVVersion the same or newer than the minimum required
        }
    else {
        Write-Error "You are running a version of POSH-HPOneView that do not support this script. Please update your HPOneView POSH from: https://github.com/HewlettPackard/POSH-HPOneView/releases"
        
        exit
        }
    }




#################################################################################
#                                Global Variables                               #
#################################################################################


$serverprofiletemplate = "ESXi for I3S OSDEPLOYMENT"
$OSDeploymentplanname = "HPE - ESXi - deploy with multiple management NIC HA config"
$serverprofile = "ESXi-I3S"


# OneView Credentials
$username = "Administrator" 
$password = "password" 
$IP = "192.168.1.110" 


# Import the OneView 3.10 library

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

    if (-not (get-module HPOneview.310)) 
    {  
    Import-module HPOneview.310
    }

   
$PWord = ConvertTo-SecureString –String $password –AsPlainText -Force
$cred = New-Object –TypeName System.Management.Automation.PSCredential –ArgumentList $Username, $PWord


# Connection to the Synergy Composer

If ($connectedSessions -and ($connectedSessions | ?{$_.name -eq $IP}))
{
    Write-Verbose "Already connected to $IP."
}

Else
{
    Try 
    {
        Connect-HPOVMgmt -appliance $IP -PSCredential $cred| Out-Null
    }
    Catch 
    {
        throw $_
    }
}

               
import-HPOVSSLCertificate -ApplianceConnection ($connectedSessions | ?{$_.name -eq $IP})


# Check oneview version

Check-HPOVVersion



filter Timestamp {"$(Get-Date -Format G): $_"}


        
Write-Output "Creating Server Profile using the Image Streamer" | Timestamp

  # if (get-HPOVServerProfile -Name "ESXi-I3S" -ErrorAction SilentlyContinue) { Remove-HPOVServerProfile -ServerProfileTemplate "ESXi-I3S" }


        $spt = Get-HPOVServerProfileTemplate -Name $serverprofiletemplate  -ErrorAction Stop

        #$server = Get-HPOVServer -Name "Frame3-CN7515049C, bay 4"
        $server = Get-HPOVServer -NoProfile -InputObject $spt | Select -first 1
        
        $enclosuregroup = Get-HPOVEnclosureGroup | ? {$_.osDeploymentSettings.manageOSDeployment -eq $True} | select -First 1 




#$osCustomAttributes = Get-HPOVOSDeploymentPlan -name $OSDeploymentplanname -ErrorAction Stop | Get-HPOVOSDeploymentPlanAttribute
$osCustomAttributes = Get-HPOVOSDeploymentPlanAttribute -InputObject $spt

$My_osCustomAttributes = $osCustomAttributes

        #($My_osCustomAttributes | ? name -eq 'ManagementNIC.ipaddress').value = ''
        ($My_osCustomAttributes | ? name -eq 'ManagementNIC.dhcp').value = 'False'
        ($My_osCustomAttributes | ? name -eq 'ManagementNIC.connectionid').value = '3'
        ($My_osCustomAttributes | ? name -eq 'ManagementNIC2.dhcp').value = 'False'
        ($My_osCustomAttributes | ? name -eq 'ManagementNIC2.connectionid').value = '4'
        ($My_osCustomAttributes | ? name -eq 'SSH').value = 'enabled'
        ($My_osCustomAttributes | ? name -eq 'Password').value = 'password'
     
        # Hostname is by default the server Profile name
        # ($My_osCustomAttributes | ? name -eq 'Hostname').value = $serverprofile



New-HPOVServerProfile -Name $serverprofile -ServerProfileTemplate $spt -Server $server -OSDeploymentAttributes $My_osCustomAttributes  -AssignmentType server 

Write-Output "Server Profile $serverprofile using the Image Streamer has been created" | Timestamp


       
