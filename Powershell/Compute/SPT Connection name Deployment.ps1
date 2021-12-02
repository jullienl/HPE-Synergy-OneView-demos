<#
# In OneView, adding connection names to network connections in a Server Profile Template, does not turn the associated Server profile(s) 
# as inconsistent therefore it is required to update all Server Profiles manually with the connection name. To avoid that, this script can be used to 
# deploy automatically the connection names present in the Server Profile Template to all associated server profiles.
#
# During the execution, the script displays a list of Server Profile Templates available in OneView and then ask the name of 
# the Server Profile Template that you want to use to propagate the connection name configuration across all associated server profiles.  
# 
# Notice: the script verifies that the same network connections present in Server profile template are also available in the server profiles 
# 
# Requirements:
#    - HPE OneView Powershell Library
#    - HPE OneView administrator account 
#
#  Author: lionel.jullien@hpe.com
#  Date:   March 2021
#
#
# Sample script output:
#
# Name            Status Server Hardware Type Enclosure Group Affinity Server Profiles
# ----            ------ -------------------- --------------- -------- ---------------
# CentOS7.8       OK     SY 480 Gen9 1        3_frame_EG      Bay      {Ansible-CentOS79-1, Ansible-CentOS82-1}
# CENTOS75-I3S    OK     SY 480 Gen9 1        3_frame_EG      Bay
# ESXi7-I3S       OK     SY 480 Gen10 1       3_frame_EG      Bay
# RAID1-SPT       OK     SY 480 Gen9 1        3_frame_EG      Bay
# RHEL7.8         OK     SY 480 Gen9 1        3_frame_EG      Bay      {Ansible-RH78-2, Ansible-RH78-1}
# RHEL75-I3S      OK     SY 480 Gen9 1        3_frame_EG      Bay      rh-3
# SLES12-I3S      OK     SY 480 Gen9 1        3_frame_EG      Bay
# WIN2016-I3S     OK     SY 480 Gen10 1       3_frame_EG      Bay      Test-Win_2016
# XENSERVER71-I3S OK     SY 480 Gen9 1        3_frame_EG      Bay
#
# Which Server Profile Template do you want to use to propagate the connection names accross all associated server profiles?: RHEL7.8
#
# Profile Ansible-RH78-2: Connection '1' connected to 'Management' must be renamed 'Management-1'
# Profile Ansible-RH78-2: Connection '2' connected to 'Management' must be renamed 'Management-2'
# Profile Ansible-RH78-2: Connection '3' connected to 'Production_network_set' is already named 'NetSet_1'
# Profile Ansible-RH78-2: Connection '4' connected to 'Production_network_set' must be renamed 'NetSet_2'
# Profile Ansible-RH78-2: Connection '5' connected to 'FC-A' is unnamed
# Profile Ansible-RH78-2: Connection '6' connected to 'FC-B' is unnamed
# All connections in profile 'Ansible-RH78-2' have been renamed successfully!
#
# Profile Ansible-RH78-1: Connection '1' connected to 'Management' is already named 'Management-1'
# Profile Ansible-RH78-1: Connection '2' connected to 'Management' is already named 'Management-2'
# Profile Ansible-RH78-1: Connection '3' connected to 'Production_network_set' is already named 'NetSet_1'
# Profile Ansible-RH78-1: Connection '4' connected to 'Production_network_set' is already named 'NetSet_2'
# Profile Ansible-RH78-1: Connection '5' connected to 'FC-A' is unnamed
# Profile Ansible-RH78-1: Connection '6' connected to 'FC-B' is unnamed
# WARNING: Profile 'Ansible-RH78-1' unchanged!
#
# Operation completed !
#    
#################################################################################
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


# OneView Credentials and IP
$OV_username = "Administrator"
$OV_IP = "composer2.lj.lab"


# MODULES TO INSTALL

# HPEOneView
# If (-not (get-module HPEOneView.630 -ListAvailable )) { Install-Module -Name HPEOneView.630 -scope Allusers -Force }


#################################################################################

$secpasswd = read-host  "Please enter the OneView password" -AsSecureString
 
# Connection to the OneView / Synergy Composer
$credentials = New-Object System.Management.Automation.PSCredential ($OV_username, $secpasswd)

try {
    Connect-OVMgmt -Hostname $OV_IP -Credential $credentials -ErrorAction stop | Out-Null    
}
catch {
    Write-Warning "Cannot connect to '$OV_IP'! Exiting... "
    return
}

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

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


#################################################################################


Get-OVServerprofiletemplate | Out-Host
        
$spt = read-host "Which Server Profile Template do you want to use to propagate the connection names accross all associated server profiles?"


#Capturing Server profiles under the SPT
$_spt = (Get-OVServerProfileTemplate -Name $spt) 

$association = "server_profile_template_to_server_profiles"

$uri = "/rest/index/associations?name={0}&parentUri={1}" -f $association, $_spt.uri


Try {

    $_IndexResults = Send-OVRequest -Uri $Uri -Hostname ${Global:ConnectedSessions}

}

Catch {

    $PSCmdlet.ThrowTerminatingError($_)

}

# Creating an object with Server profile data
$serverprofiles = New-Object System.Collections.ArrayList

foreach ($member in $_IndexResults.members) {
    $childuri = $member.childuri
    $_FullIndexEntry = Send-OVRequest -Uri $childuri -Hostname ${Global:ConnectedSessions}
    [void]$serverprofiles.Add($_FullIndexEntry)

}

Write-verbose "SPT Child Server list: $serverprofiles.name"

# Capturing connections names and network URI for each name enabled connection in SPT

$spt_connections = $_spt.connectionSettings.connections #| Where-Object -Property name

foreach ($serverprofile in $serverprofiles) {
    
    $Applyprofile = $False

    foreach ($spt_connection in $spt_connections) {
    
        $sp_connection = $serverprofile.connectionSettings.connections | Where-Object { $_.id -eq $spt_connection.id }
        $networkname = (Send-OVRequest -Uri $sp_connection.networkUri -Hostname ${Global:ConnectedSessions}).name 

        # Throwing error if SPT network connection not found in SP 
        if ( $sp_connection.networkUri -eq $spt_connection.networkUri) { 
          
            # If connection name already configured or empty, no profile change       
            If ( $sp_connection.name -eq $spt_connection.name ) {

                # If connection name is empty, no profile change    
                if (-not $sp_connection.name) {
                    write-host "Profile $($serverprofile.name): Connection '$($sp_connection.id)' connected to '$networkname' is unnamed"
                    if ($Applyprofile -ne $True) {
                        $Applyprofile = $False
                    }
                    
                }
                else {
                    write-host "Profile $($serverprofile.name): Connection '$($sp_connection.id)' connected to '$networkname' is already named '$($spt_connection.name)'"
                    if ($Applyprofile -ne $True) {
                        $Applyprofile = $False
                    }
                    
                }
            }
           
            #If connection name not found, profile modification is needed        
            Else {
        
                $Applyprofile = $True
        
                write-host "Profile $($serverprofile.name): Connection '$($sp_connection.id)' connected to '$networkname' must be renamed '$($spt_connection.name)'"
                           
                $sp_connection.name = $spt_connection.name
    
            }
   

        
        }
        else {  
            write-warning "Profile '$($serverprofile.name)': Connection '$($sp_connection.id)' is not attached to '$networkname' network!"
            if ($Applyprofile -ne $True) {
                $Applyprofile = $False
            }
            
        }
    }

             
    #Updating Server Profile if needed
    If ($Applyprofile -eq $True) {
      
        $task = Set-OVResource $serverprofile -Force -ApplianceConnection  ${Global:ConnectedSessions} | Wait-OVTaskComplete
            
        write-host "All connections in profile '$($serverprofile.name)' have been renamed successfully!`n" -ForegroundColor green
    }
    Else {
      
        write-verbose "$($task.taskErrors)"
        write-warning "Profile '$($serverprofile.name)' unchanged!`n" 

    }

   

}

Write-Host "Operation completed !"
Disconnect-OVMgmt
    

