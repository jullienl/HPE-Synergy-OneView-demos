<#
.DESCRIPTION
   
   new-ESXserver provisions an ESX server using an Image Streamer deployment plan for ESXi.
   Several parameters can be used to customize the ESXi host like: Management IP address, SSH enabled, hostname, datastore, etc.

   Once the server is provisioned, the script can turn the server on and also add the ESXi host to a vcenter folder, datacenter or cluster.
       
   Supports common parameters -verbose, -whatif, and -confirm 
   
   OneView administrator account is required 

   Image Streamer artifacts for ESXi 5.x and ESXi 6.x must be installed
   See  https://github.com/HewlettPackard/image-streamer-esxi
  
   A deployment plan name must be provided. If not present, the script is looking for "ESXi - deploy with multiple management NIC HA config+FCoE"

   Latest OneView POSH Library must be used.

       
.PARAMETER Composer
  IP address of the Composer
  Default: 192.168.1.110
  
.PARAMETER ComposerUsername
  OneView administrator account of the Composer
  Default: Administrator
  
.PARAMETER ComposerPassword
  password of the OneView administrator account 
  Default: password

.PARAMETER Hostname
  Name of the ESXi Host (not the Fully Qualified Domain Name)
  ex: ESX6-1

.PARAMETER ServerHardware
  The server hardware resource where the new profile is to be applied. This is normally retrieved with a 'Get-HPOVServer' call, and the Server state property should be "NoProfileApplied"  
  Can also be the Server Hardware name, e.g. "Frame2-CN7515049L, bay 4"
  If not present, the script selects the first available healthy compute module
  Accepts pipeline input ByValue and byPropertyName
    
.PARAMETER HostnamePattern
  Pattern name used by the script to generate Server Profile names when the ServerHardware parameter is used as a pipeline input
  Pattern name "ESX" will generate the profile name "ESX-1" for the first server, "ESX-2" for the second server, etc.

.PARAMETER OSDeploymentPlanName
  Provides an Image Streamer deployment plan name 
  Default: "ESXi - deploy with multiple management NIC HA config+FCoE"

.PARAMETER profilename
  Name of the server profile that the script will generate.
  If not present, hostname is used to generate profilename  

.PARAMETER ManagementNIC
  Sets either a static IP address or use a DHCP to assign an IP address to the first Management NIC 
  Accepted values: 'DHCP' or an IPv4 address.  
  The selected OS Deployment plan must support 'DHCP' or static configuration
  If not present, the first Management NIC gets its IPv4 address from the OneView IPv4 address pool
  ESXi plan scripts get netmask, gateway and DNS values from the OneView IPv4 Subnet resource

.PARAMETER HostPassword
  Root password of the ESXi Host
  Password value must meet password complexity and minimum length requirements defined for ESXi 5.x, ESXi 6.x appropriately.
  Default: password

.PARAMETER HostDomainName
  Domain name of the ESXi Host

.PARAMETER SSHEnabled
  Enables SSH and ESXi shell on the ESXi Host

.PARAMETER Datastore
  Name of a StoreServ 3PAR or StoreVirtual datastore volume managed by OneView that will be presented to the ESXi Server 
  A Datastore is required when the ESXi host is joining a vSphere cluster

.PARAMETER vCenterServer
  Name of the vcenter server
  If present, powers-on automatically the server and adds it to be managed by the vCenter server system 

.PARAMETER vCenterUserName
  Username of the vcenter server
  Default: Administrator@vsphere.local

.PARAMETER vCenterPassword
  Password of the vcenter server
  Default: P@ssw0rd

.PARAMETER vCenterLocation
  Existing folder or datacenter on the vcenter server where the new ESX host is added
  If not present, a Synergy folder is created on the first datacenter found
  Default: Synergy  

.PARAMETER vCenterCluster
  Existing cluster on the vcenter server where the new ESX host is added
  If the resource is not present on the vcenter server, a vSphere cluster is created on the first datacenter found using the provided name
  Default: cluster-Synergy  

.PARAMETER PowerON
  Turns on the ESX server after the profile is created
  
.EXAMPLE
  PS C:\> New-ESXserver -composer 192.168.1.110 -composerusername Administrator -composerpassword password -hostname ESX6-1 -hostpassword HPEinvent -poweron
  Deploy an ESXi server named ESX6-1 using the Image Streamer default OS Deployment plan, and assign the password HPEinvent to the ESXi root user account
  Generate a OneView server profile named "ESX6-1"   
  Assign an IPv4 address to the first Management NIC using the OneView IPv4 address pool
  Turn on the server once the server profile is created in OneView

.EXAMPLE
  PS C:\> New-ESXserver -composer 192.168.1.110 -composerusername Administrator -composerpassword password -hostname ESX6-2 -ManagementNIC 192.168.2.22 
  Deploy an ESXi server named ESX6-2 using the Image Streamer default OS Deployment plan
  Assign the default password defined in the OS Deployment plan to the ESXi root user account
  The server profile is named using the name of the hostname "ESX6-2" 
  Assign a static IPv4 address "192.168.2.22" to the first Management NIC 
  Leave the server off once the profile is created in OneView

.EXAMPLE
  PS C:\> New-ESXserver -composer 192.168.1.110 -composerusername Administrator -composerpassword password -hostname ESX6-2 -ManagementNIC DHCP -SSHEnabled
  Deploy an ESXi server named ESX6-2 using the Image Streamer default OS Deployment plan, 
  Assign the default password defined in the OS Deployment plan to the ESXi root user account
  Generate a OneView server profile named "ESX6-2" 
  Assign a DHCP IPv4 address to the first Management NIC 
  Enable SSH and ESXi shell on the ESXi Host 
  Leave the server off once the profile is created in OneView

.EXAMPLE
  PS C:\> New-ESXserver -composer 192.168.1.110 -composerusername Administrator -composerpassword password -hostname ESX6-3 -vcenterserver "vcenter.hpe.net" -vcenterusername "Administrator@vsphere.local" -vcenterpassword "HPEinvent" -vcenterlocation Synergy 
  Deploy an ESXi server using the Image Streamer default OS Deployment plan
  Assign the default password defined in the OS Deployment plan to the ESXi root user account
  Generate a OneView server profile named "ESX6-3" 
  Turn on automatically the ESXi Host once the server profile is created in OneView because the vCenterserver parameter is used
  Add the server to be managed by a vCenter server "vcenter.hpe.net" and import the server in the "Synergy" location, if not present, the location ressource is created 

.EXAMPLE
  PS C:\> New-ESXserver -composer 192.168.1.110 -composerusername Administrator -composerpassword password -hostname ESX6-4 -vcenterserver "vcenter.hpe.net" -vcenterusername "Administrator@vsphere.local" -vcenterpassword "HPEinvent" -vcentercluster Synergy-Cluster -datastore "vsphere-datastore" 
  Deploy an ESXi server using the Image Streamer default OS Deployment plan, assign the default password defined in the OS Deployment plan to the ESXi root user account
  Generate a OneView server profile named "ESX6-4" 
  Present the SAN Volume datastore "vsphere-datastore" to the server
  Turn on the server once the server profile is created in OneView
  Add the server to be managed by a vCenter server "vcenter.hpe.net" 
  Add the server to the "Synergy-Cluster" vSphere cluster, if not present, the cluster ressource is created 

.EXAMPLE
  PS C:\> New-ESXserver -composer 192.168.1.110 -composerusername Administrator -composerpassword password -hostname ESX6-5 -profilename "ESX-server-05" -OSDeploymentplanname "HPE - ESXi - deploy in single frame non-HA config- 2017-03-24" 
  Deploy an ESXi server named ESX6-5 using the Image Streamer OS Deployment plan "HPE - ESXi - deploy in single frame non-HA config- 2017-03-24"
  Assign the default password defined in the OS Deployment plan to the ESXi root user account
  Generate a OneView server profile named "ESX-server-05" 

.EXAMPLE
  PS C:\> "Frame1-CN7516060D, bay 3", "Frame1-CN7516060D, bay 4"  | New-ESXserver -HostnamePattern "ESX" -SSHEnabled -datastore "vsphere-datastore" -vCenterServer "vcenter.lj.mougins.net" -vcenterusername "Administrator@vsphere.local" -vcenterpassword "P@ssw0rd1" -vcentercluster Synergy-Cluster 
  Deploy two ESXi Hosts using the Image Streamer default OS Deployment plan in "Frame1-CN7516060D, bay 3" and "Frame1-CN7516060D, bay 4" 
  Generate Server Profile names according to the provided pattern name "ESX", i.e. "ESX-1" for the first server, "ESX-2" for the second server.
  Enable SSH and ESXi shell on the ESXi Hosts 
  Present the SAN Volume datastore "vsphere-datastore" to the servers
  Assign the default password defined in the OS Deployment plan to the ESXi root user account
  Assign an IPv4 address to the Management NIC1 using the OneView IPv4 address pool
  Turn on automatically the two ESXi Hosts once their server profiles are created in OneView because the vCenterserver parameter is used
  Add the ESXi Hosts to be managed by a vCenter server "vcenter.lj.mougins.net" 
  Add the ESXi Hosts to the "Synergy-Cluster" vSphere cluster, if not present, the cluster ressource is created 

.EXAMPLE
  PS C:\> Get-HPOVServer -noprofile |  ? {$_.name -match "Bay 5" -and $_.status -eq "ok"} | New-ESXserver -HostnamePattern "ESX" -SSHEnabled -PowerON
  Deploy ESXi server using the Image Streamer default OS Deployment plan on every compute module located in a "bay 5" with no server profile assigned and with an "ok" status
  Generate Server Profile names according to the provided pattern name "ESX", i.e. "ESX-1" for the first server, "ESX-2" for the second server, etc.
  Enable SSH and ESXi shell on the ESXi Hosts 
  Turn on the ESXi Hosts once their server profiles are created in OneView 


.COMPONENT
  This script makes use of the PowerShell language bindings library for HPE OneView
  https://github.com/HewlettPackard/POSH-HPOneView
  Make sure you use the latest version of the library
  
  Image Streamer artifacts for ESXi 5.x and ESXi 6.x must be installed
  https://github.com/HewlettPackard/image-streamer-esxi
  
  This script makes also use of VMware vSphere PowerCLI. It is installed by this script if not present. VMWare PowerCLI is used to add the ESX host into a vcenter server
  http://vmware.com/go/powercli

.LINK
    https://github.com/HewlettPackard/POSH-HPOneView
    https://github.com/HewlettPackard/image-streamer-esxi
    http://vmware.com/go/powercli
  
.NOTES
    Author: lionel.jullien@hpe.com
    Date:   Sept 2017 
    
#################################################################################
#                             new-ESXserver.ps1                                 #
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
Function New-ESXserver {

[CmdletBinding( DefaultParameterSetName=’default’, 
                SupportsShouldProcess=$True)]
    Param 
    (
        [parameter(ParameterSetName="default")]
        [parameter(ParameterSetName="ServerHardwareGroup")]
        [string]$Composer = "192.168.1.110", 

        [parameter(ParameterSetName="default")]
        [parameter(ParameterSetName="ServerHardwareGroup")]
        [string]$ComposerUsername = "Administrator", 

        [parameter(ParameterSetName="default")]
        [parameter(ParameterSetName="ServerHardwareGroup")]
        [string]$ComposerPassword = "password",

        [parameter(Mandatory,ParameterSetName="default")]
        [string]$Hostname="",

        [parameter(ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName="default")]
        [parameter(ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName="ServerHardwareGroup")]
        [Alias('name')]
        [string]$ServerHardware="",

        [parameter(Mandatory, ParameterSetName="ServerHardwareGroup")]
        [string]$HostnamePattern="",

        [parameter(ParameterSetName="default")]
        [parameter(ParameterSetName="ServerHardwareGroup")]
        [string]$OSDeploymentPlanName = "ESXi - deploy with multiple management NIC HA config+FCoE",

        [parameter(ParameterSetName="default")]
        [string]$ProfileName="",
      
        [parameter(ParameterSetName="default")]
        [ValidateScript({($_ -eq "dhcp" -or $_ -match [IPAddress]$_  )})] # 'DHCP' or <IP> 
        [string]$ManagementNIC="",

        [parameter(ParameterSetName="default")]
        [parameter(ParameterSetName="ServerHardwareGroup")]
        [string]$HostPassword,

        [parameter(ParameterSetName="default")]
        [parameter(ParameterSetName="ServerHardwareGroup")]
        [string]$HostDomainName,

        [parameter(ParameterSetName="default")]
        [parameter(ParameterSetName="ServerHardwareGroup")]
        [switch]$SSHEnabled,
                     
        [parameter(ParameterSetName="default")]
        [parameter(ParameterSetName="ServerHardwareGroup")]
        [string]$Datastore, 
        
        [parameter(ParameterSetName="default")]
        [parameter(ParameterSetName="ServerHardwareGroup")]
        [string]$vCenterServer, 
    
        [parameter(ParameterSetName="default")]
        [parameter(ParameterSetName="ServerHardwareGroup")]
        [string]$vCenterUserName = "Administrator@vsphere.local",

        [parameter(ParameterSetName="default")]
        [parameter(ParameterSetName="ServerHardwareGroup")]
        [String]$vCenterPassword,

        [parameter(ParameterSetName="default")]
        [parameter(ParameterSetName="ServerHardwareGroup")]
        [String]$vCenterLocation,

        [parameter(ParameterSetName="default")]
        [parameter(ParameterSetName="ServerHardwareGroup")]
        [String]$vCenterCluster,
        
        [parameter(ParameterSetName="default")]
        [parameter(ParameterSetName="ServerHardwareGroup")]
        [switch]$PowerON      
                   
         
    )


#region Examples

<#

 # Static 
 New-ESXserver -hostname ESX-test-Static -ManagementNIC 192.168.2.225 -vcenterserver "vcenter.lj.mougins.net" -vcenterusername "Administrator@vsphere.local" -vcenterpassword "P@ssw0rd1" -vcenterlocation Synergy 

 # DHCP
 New-ESXserver -hostname ESX-test-DHCP -ManagementNIC DHCP -datastore "vSphere-datastore" -poweron 
 
 # Auto
 New-ESXserver -hostname ESX-6-1 -vcenterserver "vcenter.lj.mougins.net" -vcenterusername "Administrator@vsphere.local" -vcenterpassword "password" -vcenterlocation Synergy 
 
 
 New-ESXserver -hostname ESX-6-2 -vcenterserver "vcenter.lj.mougins.net" -vcenterusername "Administrator@vsphere.local" -vcenterpassword "P@ssw0rd1"  -SSHEnabled -datastore "vsphere-datastore" -vcentercluster "cluster-Synergy"

#>


#endregion

Begin
{

#region Global Variables   

[string]$HPOVMinimumVersion = "3.10.1471.1581"

# This is the server model name to use for the deployment e.g. '480' will select a server model 'Synergy 480 Gen9' or 'Synergy 480 Gen10'.   
$ServerHardwareTypename = "480"

# Corporate Proxy settings to install the VMware PowerCLI
$myproxy = "16.44.10.134"
$myproxyport = "8080"

# VMware license name to use on the ESXi host
$vcenterlicensename = "VMware vSphere 6 Enterprise Plus"
#endregion


#region Global Functions
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
        
        pause

        exit

        }
    }
#endregion


#region Import OneView Library and Connection to OneView
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -Confirm:$False

    if (-not (get-module HPOneview.310)) 
    {  
    Import-module HPOneview.310

    }


	

# Connection to the Synergy Composer

If ($connectedSessions -and ($connectedSessions | ?{$_.name -eq $composer})){
    write-verbose "[$($MyInvocation.InvocationName.ToString().ToUpper())] Already connected to $composer."
}

Else{
    Try {
    
        $connection = Connect-HPOVMgmt -hostname $composer -user $composerusername -password $composerpassword | Out-Null
    }
    
    Catch {
    
        throw $_
    }
}
import-HPOVSSLCertificate
#endregion  
        

#region Check oneview version

Check-HPOVVersion

clear
#endregion

#region Processing pipeline input

# If processing pipeline input, $HostnamePattern must be provided
if (-not $HostnamePattern -and $PSCmdlet.MyInvocation.ExpectingInput) 
        {
        write-warning 'For processing pipeline input, HostnamePattern parameter must be provided !'
        pause
        exit
        }
   
# If vcentercluster parameter, a datastore must be presented 
if ($PSboundParameters['vcentercluster'] -and !$datastore)
       {
       write-warning 'In order to support vcenter clustering, a datastore must be provided !'
       pause
       exit
       }
 
$counter = 0
#endregion
}

Process
{


foreach ($item in $ServerHardware)
{
    
$counter++


write-verbose "HostnamePattern is : $HostnamePattern"
write-verbose "counter is : $counter"



if ($HostnamePattern) 
    {
     $hostname = $HostnamePattern + "-" +  $Counter

    }

write-verbose "serverprofilename is : $serverprofilename "

#region EG Selection
# Select the first enclosure group using the Image Streamer
$enclosuregroup = Get-HPOVEnclosureGroup | ? {$_.osDeploymentSettings.manageOSDeployment -eq $True} | select -First 1 
#endregion






#region Serverhardware selection or validation

  # If $serverhardware is provided, check that the server is present, compatible, healthy and without a profile assigned


 if ($PSboundParameters['serverhardware'] -or $PSCmdlet.MyInvocation.ExpectingInput)
 {
      
    # must be present
    
    try 
    { 
        $serverHardwareTypeUri= Get-HPOVServer -Name $serverhardware -ErrorAction Stop |  select serverHardwareTypeUri 
    }
    catch
    {
        write-host `n
        Write-warning "Server Hardware '$serverhardware' not found !"
        pause
		
		$counter = $counter - 1
        return
    }


    # must be a server with no profile assigned 

    if (((Get-HPOVServer -Name $serverhardware).state ) -eq "ProfileApplied")
    { 
        write-host `n
        Write-warning "A server profile is already applied to the selected Server Hardware ! '$serverhardware' cannot be used !"
        pause
        
	    $counter = $counter - 1
        return
    }
    

    # must be a server compatible with the ServerHardwareTypename

     if (((Get-HPOVServer -Name $serverhardware).model ) -notmatch $ServerHardwareTypename)
    { 
        write-host `n
        Write-warning "Server Hardware '$serverhardware' does not match with the ServerHardwareTypename '$ServerHardwareTypename' ! '$serverhardware' cannot be used !"
        pause
        $counter = $counter - 1
        return
    }

    # must be a healthy server 

     if (((Get-HPOVServer -Name $serverhardware).status ) -ne "ok")
    { 
        write-host `n
        Write-warning "The status of Server Hardware '$serverhardware' is '$((Get-HPOVServer -Name $serverhardware).status)' ! '$serverhardware' cannot be used !"
        pause
        $counter = $counter - 1
        return
    }
    
    # If pipeline input is null : does not throw an error 
    # It cannot be done in Process{}, only in Begining{} or End{}

    
    # if a string name is provided for serverhardware, we take the corresponding server object

    if ($serverhardware.GetType().Name -eq "PSCustomObject") 
    {
            
        $server = $serverhardware 
      
    } 
    else 
    {
        
        # if no server hardware found, throw an error
        try
        {
            $server = get-HPOVServer -Name $serverhardware -ErrorAction Stop
        }
        catch
        {
            
            write-host `n
            Write-warning "Server Hardware $serverhardware not found !"
            pause
            
			$counter = $counter - 1
            return
        }
    }

}
 
 
 # If $serverhardware is not provided, select the first compatible server, available, with no profile and healthy
 if (-not $PSboundParameters['serverhardware'] -and !$PSCmdlet.MyInvocation.ExpectingInput)
 {
    
    # List of available server with no profile, healthy and compatible
    $availableservers= Get-HPOVServer -NoProfile  | ? {$_.status -eq "ok" -and $_.model -match $ServerHardwareTypename}
    
    if (-not $availableservers) 
    { 
    write-host `n
    Write-Warning "No healthy server hardware matching with the defined server hardware type '$ServerHardwareTypename' is available ! "
    pause
    exit

    }

    Write-host -ForegroundColor Cyan "`n`n`n`n`n`nA server is going to be selected from your resource pool of $($availableservers.count) available server(s) !"  

    # Selecting the frist server in the pool of resources      
    # get-random could have be used here as well
    $server = $availableservers | select -First 1

    Write-Host -ForegroundColor Cyan "`n$($server.name) has been selected"

    
} 
#endregion


#region Turning server off if running
  
  if (((Get-HPOVServer -Name $server.name).powerState) -eq "On")
  {
    write-host "`nThe selected server is currently powered on, shuting down the server..."
    Get-HPOVServer -Name $server.name | Stop-HPOVServer -Force -Confirm:$False | Out-Null 
  } 
#endregion


#region ServerProfile Name definition  
# When $profilename is provided as a parameter, the name of the profile is $profilename otherwise we use the name of the hostname to generate the server profile name

if ($profilename) { $serverprofilename = $profilename } else { $serverprofilename = $hostname }
#endregion


#region Server Profile Network definition

Write-host "`n`nCreating server profile '$serverprofilename', please wait..." 

$ServerHardwareType = Get-HPOVServerHardwareTypes  | ? uri -match $server.serverHardwareTypeUri

$enclosuregroup = Get-HPOVEnclosureGroup | ? {$_.osDeploymentSettings.manageOSDeployment -eq "true"} | select -First 1


# Building the network connections

        
        # Connection 1
        $ISCSINetwork = Get-HPOVNetwork | ? {$_.purpose -match "ISCSI" -and $_.SubnetUri -ne $Null} 

        $IscsiParams1 = @{
               ConnectionID                  = 1;
               Name                          = "ImageStreamer Connection 1";
               ConnectionType                = "Ethernet";
               Network                       = $ISCSINetwork;
               Bootable                      = $true;
               Priority                      = "Primary";
               IscsiIPv4AddressSource        = "SubnetPool"
                         }

        $ImageStreamerBootConnection1 = New-HPOVServerProfileConnection @IscsiParams1
       
        # Connection 2
        $IscsiParams2 = @{
               ConnectionID                  = 2;
               Name                          = "ImageStreamer Connection 2";
               ConnectionType                = "Ethernet";
               Network                       = $ISCSINetwork;
               Bootable                      = $true;
               Priority                      = "Secondary";
               IscsiIPv4AddressSource        = "SubnetPool"
                         }

        $ImageStreamerBootConnection2 = New-HPOVServerProfileConnection @IscsiParams2

        # Connection 3
        $con3 = Get-HPOVNetwork | ? {$_.purpose -match "Management" -and $_.SubnetUri -ne $Null} | New-HPOVServerProfileConnection -Name 'Connection 3' `
            -connectionId 3 `
            -ConnectionType Ethernet

        # Connection 4
        $con4 = Get-HPOVNetwork | ? {$_.purpose -match "Management" -and $_.SubnetUri -ne $Null}  | New-HPOVServerProfileConnection -Name 'Connection 4' `
            -connectionId 4 `
            -ConnectionType Ethernet

        # Connection 5
        $con5 = Get-HPOVNetwork | ? fabricType -match "FabricAttach" | select -Index 0 |  New-HPOVServerProfileConnection -ConnectionID 5 -ConnectionType FibreChannel 

        # Connection 6
        $con6 = Get-HPOVNetwork | ? fabricType -match "FabricAttach" | select -Index 1 | New-HPOVServerProfileConnection -ConnectionID 6 -ConnectionType FibreChannel
#endregion


#region Server Profile SAN Volume definition

        # SAN Volume
        if ($datastore)
        {
        Try {
            $storagevolume = Get-HPOVStorageVolume -Name $datastore -ErrorAction stop | New-HPOVServerProfileAttachVolume # -LunIdType Manual -LunID 0
            }
        Catch
            {
            Write-Warning "The datastore volume name provided is not managed by the OneView appliance !"
            pause
            exit
            }
        }
#endregion


#region Server Profile Network OS Custom attributes definition

    # Does the OS deployment plan exist ? If not, exit
       
    try
        {
            $OSDeploymentplan = Get-HPOVOSDeploymentPlan -name $OSDeploymentplanname -ErrorAction Stop
            $OSDeploymentplanuri = $OSDeploymentplan.uri
        }
    catch
        {
            Write-Warning "The selected deployment plan '$OSDeploymentplanname' does not exist !"
            pause
            exit
        }

       
# Getting the OS deployment plan attributes of the selected OS deployment plan  

$OSdp_osCustomAttributes = $OSDeploymentplan | Get-HPOVOSDeploymentPlanAttribute

 
$ManagementNICnetworkuri = (Get-HPOVNetwork | ? {$_.purpose -match "Management" -and $_.SubnetUri -ne $Null}).uri

$I3S_managementnetwork = Get-HPOVNetwork | ?  Uri -eq ((Get-HPOVOSDeploymentServer).mgmtNetworkUri)
$I3S_managemensubnet =  Get-HPOVAddressPoolSubnet | ? {$_.associatedResources.resourceUri -eq ($I3S_managementnetwork.uri)}

$ManagementNICnetmask = $I3S_managemensubnet.subnetmask
$ManagementNICdns1 = $I3S_managemensubnet.dnsServers[0]
$ManagementNICdns2 = $I3S_managemensubnet.dnsServers[1]
$ManagementNICgateway = $I3S_managemensubnet.gateway
 

 Write-Verbose "The OS Deployment plan '$OSDeploymentplanname' has the following OS Custom Attributes:`n" 
 Write-Verbose  ( $OSdp_osCustomAttributes | Out-String)


   
# Generating the OS deployment plan customized attributes for the Server Profile

    # Static IPv4 Address management
    if ($ManagementNIC -and $ManagementNIC -ne "DHCP")

    {
     
         if (-NOT $OSdp_osCustomAttributes.where{$_.name  -eq "ManagementNIC.ipaddress"})
        {
            write-warning "The selected deployment plan does not support assigning a static IP address to the first Management NIC !"
            pause
            exit
        }
        else 
        {
        
        # Filter out attributes that are not applicable to static settings
        $OSdp_osCustomAttributes = $OSdp_osCustomAttributes | ? name -notmatch  "mac"

        # NIC1
        ($OSdp_osCustomAttributes | ? name -eq 'ManagementNIC.constraint').value = 'userspecified'
        ($OSdp_osCustomAttributes | ? name -eq 'ManagementNIC.dhcp').value = $False
        ($OSdp_osCustomAttributes | ? name -eq 'ManagementNIC.connectionid').value = $con3.id
        ($OSdp_osCustomAttributes | ? name -eq 'ManagementNIC.networkuri').value = $con3.networkUri
        ($OSdp_osCustomAttributes | ? name -eq 'ManagementNIC.vlanid').value = 0

        ($OSdp_osCustomAttributes | ? name -eq 'ManagementNIC.ipaddress').value = $ManagementNIC
        ($OSdp_osCustomAttributes | ? name -eq 'ManagementNIC.netmask').value = $ManagementNICnetmask
        ($OSdp_osCustomAttributes | ? name -eq 'ManagementNIC.dns1').value = $ManagementNICdns1
        ($OSdp_osCustomAttributes | ? name -eq 'ManagementNIC.dns2').value = $ManagementNICdns2
        ($OSdp_osCustomAttributes | ? name -eq 'ManagementNIC.gateway').value = $ManagementNICgateway
        
        #NIC2 
        # if OS Deployment plan is HA
        If ($OSdp_osCustomAttributes.where{$_.name  -match "ManagementNIC2"})
            {
            # NIC2
            ($OSdp_osCustomAttributes | ? name -eq "ManagementNIC2.constraint").value = 'auto'
            ($OSdp_osCustomAttributes | ? name -eq "ManagementNIC2.dhcp").value = $false
            ($OSdp_osCustomAttributes | ? name -eq "ManagementNIC2.connectionid").value = $con4.id
            ($OSdp_osCustomAttributes | ? name -eq "ManagementNIC2.networkuri").value = $con4.networkUri
            ($OSdp_osCustomAttributes | ? name -eq 'ManagementNIC2.vlanid').value = 0


            } 


        }             
        
    }

    
    # Auto IPv4 Address management
    if (-not $ManagementNIC)

    {
        
        # Removing the OS custom attributes auto-generated by OneView when auto is selected. Parameters are taken from the subnet associated with the connection
        
        # Removing attributes that are not applicable to Auto settings
        $OSdp_osCustomAttributes = $OSdp_osCustomAttributes | ? name -notmatch  "gateway|netmask|dns1|dns2|vlanid|ipaddress"

        #NIC1
        ($OSdp_osCustomAttributes | ? name -eq 'ManagementNIC.constraint').value = 'auto'
        ($OSdp_osCustomAttributes | ? name -eq 'ManagementNIC.dhcp').value = $false
        ($OSdp_osCustomAttributes | ? name -eq 'ManagementNIC.connectionid').value = $con3.id
        ($OSdp_osCustomAttributes | ? name -eq 'ManagementNIC.networkuri').value = $con3.networkUri
        #($OSdp_osCustomAttributes | ? name -eq 'ManagementNIC.vlanid').value = 0
        
        #NIC2 
        # if OS Deployment plan is HA
        If ($OSdp_osCustomAttributes.where{$_.name  -match "ManagementNIC2"})
            {
            # NIC2
            ($OSdp_osCustomAttributes | ? name -eq "ManagementNIC2.constraint").value = 'auto'
            ($OSdp_osCustomAttributes | ? name -eq "ManagementNIC2.dhcp").value = $false
            ($OSdp_osCustomAttributes | ? name -eq "ManagementNIC2.connectionid").value = $con4.id
            ($OSdp_osCustomAttributes | ? name -eq "ManagementNIC2.networkuri").value = $con4.networkUri

            } 


    }


    # DHCP IPv4 Address management
    if ($ManagementNIC -eq "DHCP")
    {

        # Filter out attributes that are not applicable to DHCP settings 
        $OSdp_osCustomAttributes = $OSdp_osCustomAttributes | ? name -NotMatch "gateway|netmask|dns1|dns2|ipaddress|vlanid"
        
        #NIC1
        ($OSdp_osCustomAttributes | ? name -eq 'ManagementNIC.constraint').value = 'DHCP'
        ($OSdp_osCustomAttributes | ? name -eq 'ManagementNIC.dhcp').value =  $True
        ($OSdp_osCustomAttributes | ? name -eq 'ManagementNIC.networkuri').value = $con3.networkUri
        ($OSdp_osCustomAttributes | ? name -eq 'ManagementNIC.connectionid').value = $con3.id
       #($OSdp_osCustomAttributes | ? name -eq 'ManagementNIC.vlanid').value = 0

        #NIC2 
        # if OS Deployment plan is HA
        If ($OSdp_osCustomAttributes.where{$_.name  -match "ManagementNIC2"})
            {
            # NIC2
            ($OSdp_osCustomAttributes | ? name -eq "ManagementNIC2.constraint").value = 'DHCP'
            ($OSdp_osCustomAttributes | ? name -eq "ManagementNIC2.dhcp").value = $True
            ($OSdp_osCustomAttributes | ? name -eq "ManagementNIC2.connectionid").value = $con4.id
            ($OSdp_osCustomAttributes | ? name -eq "ManagementNIC2.networkuri").value = $con4.networkUri
           #($OSdp_osCustomAttributes | ? name -eq 'ManagementNIC2.vlanid').value = 0

            } 


    }
#endregion


#region Server Profile General OS Custom attributes definition

    # setting the hostname
    ($OSdp_osCustomAttributes | ? name -eq 'Hostname').value = $hostname

  
    # setting the host password if present
    if ($hostpassword) 
     {
         ($OSdp_osCustomAttributes | ? name -eq 'Password').value = $hostpassword
     }

    
    # setting the domain name if present
    # $hostdomainname = "lj.mougins.net"
    if ($hostdomainname) 
     {
         ($OSdp_osCustomAttributes | ? name -eq 'DomainName').value = $hostdomainname
     }


    # Enabling SSH if present

    if ($SSHEnabled.IsPresent) 
    {
        ($OSdp_osCustomAttributes | ? name -eq 'SSH').value = 'Enabled'
    }
    else
    {
        ($OSdp_osCustomAttributes | ? name -eq 'SSH').value = 'Disabled'
    }
 


 Write-Verbose "The server profile has the following customized OS Custom Attributes just before the profile creation:"
 Write-Verbose  ( $OSdp_osCustomAttributes | Out-String)
#endregion


#region Server Profile Creation

  # Creation of the server profile using the deployment plan + osCustomAttributes

   
    # make sure the Server Profile ressource name is not already in use
    if (Get-HPOVServerProfile -Name $serverprofilename -ErrorAction SilentlyContinue) 
    { 
    write-host `n
    Write-Warning "The server profile '$serverprofilename' already exist !"
    pause
    exit
    }

    

      
        $params = @{
            Name                   = $serverprofilename;
            Description            = "Server Profile for HPE Synergy 480 Gen9 Compute Module using the Image Streamer";
            ServerHardwareType     = $ServerHardwareType;
            Affinity               = "Bay";
            Enclosuregroup         = $enclosuregroup;
            Connections            = $ImageStreamerBootConnection1, $con3;# $ImageStreamerBootConnection2, # $con4 , $con5, $con6;
            Manageboot             = $True;
            BootMode               = "UEFIOptimized";
            BootOrder              = "HardDisk";
            HideUnusedFlexnics     = $True;
            # SANStorage           = $True;
            # OS                   = 'VMware';
            # StorageVolume        = $storagevolume;
            OSDeploymentplan       = $OSDeploymentplan;
            OSDeploymentAttributes = $OSdp_osCustomAttributes;
            Assignmenttype         = 'server';
            server                 =  $server
                       
                 }

    
        if ($datastore) 
        {
            $params.add('OS','VMware')
            $params.add('SANStorage',$True)
            $params.add('StorageVolume',$storagevolume)
        }


        if ($ImageStreamerBootConnection2)
        {
            $params.Connections += $ImageStreamerBootConnection2
        }


        if ($con4)
        {
            $params.Connections += $con4
        }


        if ($con5)
        {
            $params.Connections += $con5
        }


        if ($con6)
        {
            $params.Connections += $con6
        }

Write-Verbose "The server profile has the following parameters just before the profile creation:"
Write-Verbose  ( $params | Out-String)

#pause

#<#   
    try
         {
          
          New-HPOVServerProfile @params -ErrorAction Stop | Wait-HPOVTaskComplete | out-Null

          $started = ((Get-HPOVServerProfile -Name $serverprofilename | Get-HPOVTask).created)
          $ended = ((Get-HPOVServerProfile -Name $serverprofilename | Get-HPOVTask).modified)

          $hour =  ([datetime]$ended - [datetime]$started ).hours 
          $min =  ([datetime]$ended - [datetime]$started ).Minutes 
          $sec = ([datetime]$ended - [datetime]$started ).seconds 

          write-host "`n'$serverprofilename' Server Profile using the Image Streamer has been created ! `n`nDuration : $hour h : $min min : $sec s "
          
         }
    
    catch [System.Management.Automation.ValidationMetadataException] 
        {

            write-warning "Error: Invalid Server Profile Arguments provided to create the Server Profile !"
            $error[0] | fl * -force 
            pause
            return    
    catch
         {
                 
            $error[0] | fl * -force 
            pause
            return
            
         }
#endregion    


#region IP Address Displaying
# Displaying the IP address assigned to the compute module when Auto or DHCP


# Getting the IP address assigned to the server
$host_osCustomAttributes = (Get-HPOVServerProfile -Name $serverprofilename).osdeploymentsettings.osCustomAttributes 

# If Static IP, the host IP address is the IP address of ManagementNIC
If ($ManagementNIC -and $ManagementNIC -ne "DHCP")
{ 
    $hostipaddress = $ManagementNIC
}
# Else, the IP address is taken from the server profile OS custom attributes 
Else
{
    $hostipaddress = ($host_osCustomAttributes | ? name -eq 'ManagementNIC.ipaddress').value
}


# If no IPv4 address found

    If ($hostipaddress -eq $Null) { 
    
        write-warning "The Windows server '$serverprofilename' has no assigned IPv4 address !"
        pause 
        return
        }

# If Auto 
If (-not $ManagementNIC -and $ManagementNIC -ne "DHCP") 
    {
        Write-Output "`n`nThe IPv4 address '$hostipaddress' has been assigned to the server"   
    }

# If DHCP
If ($ManagementNIC -eq "DHCP") 
    {
        Write-Output "`n`nThe ESXi Host has been configured with a DHCP IPv4 address"
    }

# If static, not displaying anything

#endregion

                 
#region Powering on the compute module 

 # Powering the server ON if requested or if vcenterserver is present

if ($poweron.IsPresent )
{
   
   Try {
   Get-HPOVServer -Name $server.name -ErrorAction Stop | Start-HPOVServer -ErrorAction Stop | out-null
   write-host "`nThe server has been turned on !`n" 
   }
   catch {
   write-warning "The server cannot be turned on !`n" 
   pause
   return
   }
}

if ($vcenterserver)
{
   Try{
   Get-HPOVServer -Name $server.name -ErrorAction Stop | Start-HPOVServer -ErrorAction Stop | out-null
   write-host "`nThe server is starting, please wait...`n" 
   }
   catch
   {
   write-warning "The server cannot be turned on !`n" 
   pause
   return
   }
}

#endregion


#region Prepartion for adding server to vcenter 

If ($PSboundParameters['vcenterserver'] -and $ManagementNIC -eq "DHCP" )
    {

       Write-Warning "Adding an ESXi host to vcenter is not supported when DHCP is used !"

    }


If ($PSboundParameters['vcenterserver'] -and $ManagementNIC -ne "DHCP" )
    { 

        $secpasswd = ConvertTo-SecureString $hostpassword -AsPlainText -Force
        $credentials = New-Object System.Management.Automation.PSCredential (“root”, $secpasswd)
#endregion
         

#region Import VMware PowerCLI Library

    Try {
        Import-Module -Name VMware.PowerCLI -ErrorAction Stop | out-Null
        }

    Catch
        {
        
        # VMware PowerCLI Online installation 
            
        [system.net.webrequest]::defaultwebproxy = new-object system.net.webproxy("http://$myproxy" + ":" + "$myproxyport") 
        [system.net.webrequest]::defaultwebproxy.credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials 
        [system.net.webrequest]::defaultwebproxy.BypassProxyOnLocal = $true

        if (Get-PackageProvider | ? name -eq "Nuget" ) 
        {
            if ((Get-PackageProvider -Name NuGet).version -lt "2.8.5.201") 
                {
                Install-PackageProvider -Name NuGet -Force 
                }
        }   
        else
        {
         Install-PackageProvider -Name NuGet -Force 
        }
   
        # If not present, registering PSGallery : https://www.powershellgallery.com 

        If ( !(get-PSRepository).name -eq "PSGallery" )
        {Register-PSRepository -Default}

        # Install and import the VMware.PowerCLI module
        Install-Module -Name VMware.PowerCLI -Scope CurrentUser  -Force | out-Null
        Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP $True -InvalidCertificateAction Ignore | out-Null
        # Import-Module -Name VMware.PowerCLI 
        Import-Module -Name VMware.VimAutomation.Core
     
        }
#endregion

 
#region Waiting until server is running with a good response time
  
    Do 
       {
     
       #$serveron = Test-Connection $hostipaddress -Count 1 -Quiet
       $responsetime = '150'
       #write-host "Testing the connection with '$hostipaddress'"
       $ping = Test-Connection $hostipaddress -Count 4 -Quiet -Delay 5
       
       If ($ping) {
            
                $responsetime = (Test-Connection $hostipaddress -Count 1 -ErrorAction SilentlyContinue | Measure-Object Responsetime -ErrorAction SilentlyContinue  -average).Average 
            
                   }

       } 

    Until ($responsetime -lt '100')

  
    write-host "`n'$hostipaddress' has starting to respond ! The server is ready to be added to vcenter"

#endregion

            
#region Connection to vCenter
    Try {
        $vcenterconnection = connect-viserver -server $vcenterserver -User $vcenterusername -Password $vcenterpassword -ErrorAction Stop
        write-host "`nSuccessful connection to vcenter server '$vcenterserver' "
        }
    catch
        {
        Write-Warning "Cannot connect to vcenter server '$vcenterserver'"
        return
        }

    }
#endregion


#region Adding ESXi host to a vcenter location
 
 #if not present, the folder is created
 If ($PSboundParameters['vcenterlocation'] -and $ManagementNIC -ne "DHCP")
    
    {
        
        if (-NOT (get-folder | ? {$_.Name -eq $vcenterlocation}))
             { 
                New-Folder -Name $vcenterlocation -Location (Get-Datacenter)[0] -Confirm:$false
             }

        $location = get-folder $vcenterlocation

        Add-VMHost  -Name $hostipaddress -Server $vcenterconnection -Location $location  -User $credentials.UserName -Password $credentials.GetNetworkCredential().Password -RunAsync -force | Wait-Task  | out-Null
        
        
        If (get-vmhost  $hostipaddress -ErrorAction SilentlyContinue)
            {        
            Write-Host -ForegroundColor GREEN "`nESXi host '$hostipaddress' has been added to vCenter '$vcenterserver' in '$vcenterlocation' folder"
            }
        Else
            {
            write-host `n
            Write-warning "ESXi host '$hostipaddress' cannot be added to vCenter '$vcenterserver' in '$vcenterlocation' folder"
            return
            }
    }

#endregion


#region Adding ESXi host to a vcenter cluster
  # If not present, the cluster is created
  If ($PSboundParameters['vcentercluster'] -and $ManagementNIC -ne "DHCP")

    { 
        
        if (-NOT (get-cluster | ? {$_.Name -eq $vcentercluster}))
             { 
                New-Cluster -Name $vcentercluster -Location (Get-Datacenter)[0] -HAEnabled -Confirm:$false | Out-Null
                sleep 10
             }
        
        $vcenterlocation = get-cluster -name $vcentercluster

        Write-Host "`nAdding ESX host to vcenter cluster '$vcentercluster'"
        sleep 60
        Add-VMHost -Name $hostipaddress -Server $vcenterconnection -Location $vcenterlocation  -User $credentials.UserName -Password $credentials.GetNetworkCredential().Password -RunAsync -force | wait-task #| out-Null
         
        If (get-vmhost  $hostipaddress -ErrorAction SilentlyContinue)
            {        
            Write-Host -ForegroundColor GREEN "`nESXi host '$hostipaddress' has been added to vCenter '$vcenterserver' in '$vcentercluster' cluster"
            }
        Else
            {
            write-host `n
            Write-warning "ESXi host '$hostipaddress' cannot be added to vCenter '$vcenterserver' in '$vcentercluster' cluster"
            return
            }


    }
#endregion


#region Licensing the ESXi host


If ($PSboundParameters['vcenterserver'] -and $ManagementNIC -ne "DHCP")
    {
        # $vcenterlicensename = "VMware vSphere 6 Enterprise Plus"
        
        $servInst = Get-View ServiceInstance

        $licMgr = Get-View $servInst.Content.licenseManager

        $licAssignMgr = Get-View $licMgr.licenseAssignmentManager

        
        $licenses = $licMgr.Licenses | where {$_.Name -eq $vcenterlicensename} 
        
        If ($licenses -eq $Null) { 
                
                Write-Warning "There is no valid license '$vcenterlicensename' found on your vcenter server ! The server will remain unlicensed ! "
                               }
        else {        
            try {
                $VMHostId = (Get-VMHost -ErrorAction Stop $hostipaddress | Get-View).Config.Host.Value
                $licAssignMgr.UpdateAssignedLicense($VMHostId, $licenses.LicenseKey, $licenses.name) | Out-Null
                Write-host "`nESXi '$hostipaddress' has been licensed with '$($licenses.name)' " -f Green
                }
            catch
                {
                write-host `n
                write-warning "The ESXi host '$hostipaddress' cannot be find in vcenter to be licensed ! " 
                }

            }
        
        # Cleaning up

        Disconnect-VIServer -Confirm:$false
   
        
 }
#endregion


#region Displaying the success of the provisioning 
if ($ManagementNIC -eq "DHCP")
    {
        Write-host "`nThe provisioning of ESXi '$hostname' using a DHCP IPv4 address is now completed !`n " -ForegroundColor Green

    }
else
    {



        Write-host "`nThe provisioning of ESXi '$hostname' using the IPv4 address '$hostipaddress' is now completed !`n " -ForegroundColor Green
    }

Pause

#endregion
}

#>
    

}
}

End
{            


#region Cleaning up
Disconnect-HPOVMgmt 
#endregion

}

}
