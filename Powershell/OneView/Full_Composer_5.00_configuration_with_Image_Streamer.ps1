<#
# -------------------------------------------------------------------------------------------------------
#   by lionel.jullien@hpe.com
#   Oct 2019
#
#   Script to configure a Synergy environment using a HPE Image Streamer from scratch. 
#   
#   Hardware Setup and Network settings are the two only steps that must be done first on the unconfigured Synergy Composer
#        
#   OneView administrator account is required. 
#
#   This script makes use of:
#
#   - The PowerShell language bindings library for HPE OneView
#     https://github.com/HewlettPackard/POSH-HPOneView
#
#   - The HPE 3PAR PowerShell Toolkit for HPE 3PAR StoreServ Storage
#     https://h20392.www2.hpe.com/portal/swdepot/displayProductInfo.do?productNumber=3PARPSToolkit      
# 
# --------------------------------------------------------------------------------------------------------
   
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

 
# OneView Credentials
$username = "Administrator" 
$secpasswd = read-host "Please enter the Composer password for Administrator" -AsSecureString

# OneView IP Address
$IP = "192.168.1.xx" 



Function Import-ModuleAdv {
    
    # Import a module that can be imported
    # If it cannot, the module is installed
    # When -update parameter is used, the module is updated 
    # to the latest version available on the PowerShell library
    #
    # ex: import-moduleAdv hponeview.500
    
    param ( 
        $module, 
        [switch]$update 
    )
   
    if (get-module $module -ListAvailable) {
        if ($update.IsPresent) {
            
            [string]$InstalledModule = (Get-Module -Name $module -ListAvailable).version
            
            Try {
                [string]$RepoModule = (Find-Module -Name $module -ErrorAction Stop).version
            }
            Catch {
                Write-Warning "Error: No internet connection to update $module ! `
                `nCheck your network connection, you might need to configure a proxy if you are connected to a corporate network!"
                return 
            }

            #$Compare = Compare-Object $Moduleinstalled $ModuleonRepo -IncludeEqual

            #If ( ( $Compare.SideIndicator -eq '==') ) {
            
            If ( [System.Version]$InstalledModule -lt [System.Version]$RepoModule ) {
                Try {
                    Update-Module -ErrorAction stop -Name $module -Confirm -Force | Out-Null
                    Get-Module $Module -ListAvailable | Where-Object -Property Version -LT -Value $RepoModule | Uninstall-Module 
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
        { Register-PSRepository -Default }
                
        Try {
            find-module -Name $module -ErrorAction Stop | out-Null
                
            Try {
                Install-Module -Name $module -Scope AllUsers -Force -AllowClobber -ErrorAction Stop | Out-Null
                Write-host "`nInstalling $Module ..." 
                Import-module $module
               
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

Import-ModuleAdv HPOneview.500 #-update
   
  

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force


$credentials = New-Object System.Management.Automation.PSCredential ($username, $secpasswd)
    

   
# Connection to the Synergy Composer

If ($connectedSessions -and ($connectedSessions | Where-Object{$_.name -eq $IP}))
{
    Write-Verbose "Already connected to $IP."
}

Else
{
    Try 
    {
        Connect-HPOVMgmt -appliance $IP -Credential $credentials | Out-Null
    }
    Catch 
    {
        throw $_
    }
}


   
                
import-HPOVSSLCertificate -ApplianceConnection ($connectedSessions | Where-Object {$_.name -eq $IP})

filter Timestamp {"$(Get-Date -Format G): $_"}




#Upload custom SPP Baseline
    #Add-HPOVBaseline $baseline1
    #Add-HPOVBaseline $baseline2


# Adding OneView licenses
    write-host "Adding OneView licenses"
      
    New-HPOVLicense -LicenseKey '9BAE DQEA H9PA GHUN...AL-N3R43A_NFR N3R43A_NFR Synergy_8Gb_FC_Upgrade_License_NFR EVAL-N3R43A_NFR"'

    New-HPOVLicense -LicenseKey 'ABYE DQEA H9PY GHW3...83 T45F NGG3 EHM4 "EVAL-N3R43A_NFR N3R43A_NFR Synergy_8Gb_FC_Upgrade_License_NFR EVAL-N3R43A_NFR"'
      
# Create the new users
    
    New-HPOVUser -UserName demopaq -fullName "demopaq"-password $Password -roles "Infrastructure administrator" 




# Add a SAN Manager

$username = "admin" 
$secpasswd = read-host "Please enter the Brocade admin password" -AsSecureString
$credentials = New-Object System.Management.Automation.PSCredential ($username, $secpasswd)

Add-HPOVSanManager -Type BrocadeFOS -Hostname brocade-32g.xx.lab -Credential $credentials -UseSsl
Add-HPOVSanManager -Type BrocadeFOS -Hostname brocade-16g.xx.lab -Credential $credentials -UseSsl




#Add a new LDAP directory

    $Server = New-HPOVLdapServer -Name dc.xx.lab -TrustLeafCertificate -Certificate D:\Kits\Microsoft\CA\Root_CA_Certificate_liogw.cer 

    Do {Start-Sleep 4} until  ( $server )
    
    $credentialAD = Get-Credential -UserName Administrator -Message "Please enter the password of xx\Administrator" 

    New-HPOVLdapDirectory -name xx.lab -AD -basedn "DC=xx,DC=lab" -servers $Server -Credential $credentialAD | out-null

    Do {Start-Sleep 4} until  ( Get-HPOVLdapDirectory )
    
    $Directory = Get-HPOVLdapDirectory -Name "xx.lab" 
    
    New-HPOVLdapGroup -Directory $Directory -Group "CN=OneView Users,CN=Users,DC=xx,DC=lab" -roles @("Software administrator", "Server administrator")  -Credential $credentialAD | Out-Null
   


#Add vcenter certificate not necessary becasue CA that has issued the vcenter certificate is already trusted hence not necessary to add leaf certificate.

# Add-HPOVApplianceTrustedCertificate -ComputerName "vcenter.xx.lab" -Port 443 -AliasName vcenter -Async | Wait-HPOVTaskComplete



#create IPv4 Pools for the Image Streamer

    #Pool for the management network
    New-HPOVAddressPoolSubnet -NetworkID 192.168.0.0 -Subnetmask 22 -Gateway 192.168.1.1 -Domain xx.lab -DNSServers xx.xx.xx.xx,xx.xx.xx.xx
    Get-HPOVAddressPoolSubnet -NetworkID 192.168.0.0  | New-HPOVAddressPoolRange -Name 'Management-Address-pool' -Start 192.168.3.180 -end 192.168.3.250  

    #Pool for the deployment network
    New-HPOVAddressPoolSubnet -NetworkID 192.168.8.0 -Subnetmask 24 -Gateway 192.168.8.1 -Domain streamer-deployment.net -DNSServers xx.xx.xx.xx,xx.xx.xx.xx
    Get-HPOVAddressPoolSubnet -NetworkID 192.168.8.0  | New-HPOVAddressPoolRange -Name 'iSCSI-Address-pool' -Start 192.168.8.50 -end 192.168.8.200  

    #Pool for the VLAN10 network
    New-HPOVAddressPoolSubnet -NetworkID 192.168.10.0 -Subnetmask 24 -Gateway 192.168.10.1 -Domain xx.lab -DNSServers xx.xx.xx.xx,xx.xx.xx.xx
    Get-HPOVAddressPoolSubnet -NetworkID 192.168.10.0  | New-HPOVAddressPoolRange -Name 'VLAN10-Address-pool' -Start 192.168.10.100 -end 192.168.10.135  

    #Pool for the VLAN20 network
    New-HPOVAddressPoolSubnet -NetworkID 192.168.20.0 -Subnetmask 24 -Gateway 192.168.20.1 -Domain xx.lab -DNSServers xx.xx.xx.xx,xx.xx.xx.xx
    Get-HPOVAddressPoolSubnet -NetworkID 192.168.20.0  | New-HPOVAddressPoolRange -Name 'VLAN20-Address-pool' -Start 192.168.20.100 -end 192.168.20.135  



#create Ethernet networks


    Write-host "     Creating Ethernet network for Management..."

    New-HPOVNetwork -Name Management -type Ethernet -vlanId 5 -privateNetwork $False -purpose Management -smartLink $False -typicalBandwidth 2500 -VLANType Tagged
    New-HPOVNetwork -Name Management-Nexus -type Ethernet -vlanId 1 -privateNetwork $False -purpose Management -smartLink $False -typicalBandwidth 2500 -VLANType Tagged
    
    New-HPOVNetwork -Name Production-10 -type Ethernet -vlanId 10 -privateNetwork $False -purpose General  -smartLink $False -MaximumBandwidth 5000 -typicalBandwidth 1000 -VLANType Tagged 
    New-HPOVNetwork -Name Production-20 -type Ethernet -vlanId 20 -privateNetwork $False -purpose General  -smartLink $False -MaximumBandwidth 5000 -typicalBandwidth 1000 -VLANType Tagged 
    New-HPOVNetwork -Name vSAN_Network -type Ethernet -vlanId 30 -privateNetwork $False -purpose General  -smartLink $False -MaximumBandwidth 20000 -typicalBandwidth 10000 -VLANType Tagged 


#create Ethernet network Sets

    New-HPOVNetworkSet -name "Production_network_set" -Networks Production-10, Production-20 -TypicalBandwidth 2500 -MaximumBandwidth 10000
    New-HPOVNetworkSet -name "Storage_network_set" -Networks vSAN_Network -TypicalBandwidth 10000 -MaximumBandwidth 20000
    New-HPOVNetworkSet -name "PVLAN_network_set" -Networks Management, Production-20 -TypicalBandwidth 10000 -MaximumBandwidth 20000


#create FC networks

   New-HPOVNetwork -Name FC-A -type FC -fabricType FabricAttach 
   Get-HPOVNetwork -Name "FC-A" | Set-HPOVNetwork -ManagedSan "Brocade-G620"
   New-HPOVNetwork -Name FC-B -type FC -fabricType FabricAttach 
   Get-HPOVNetwork -Name "FC-B" | Set-HPOVNetwork -ManagedSan "Brocade-6505"

    
#Associate Management Pool subnet to Management network

   $sub1 = Get-HPOVAddressPoolSubnet -NetworkId 192.168.0.0 
   Get-HPOVNetwork -Name Management | Set-HPOVNetwork  -IPv4Subnet $sub1

#Associate VLAN10 Pool subnet to Production-10 network

   $sub2 = Get-HPOVAddressPoolSubnet -NetworkId 192.168.10.0 
   Get-HPOVNetwork -Name Production-10 | Set-HPOVNetwork  -IPv4Subnet $sub2

#Associate VLAN20 Pool subnet to Production-20 network

   $sub3 = Get-HPOVAddressPoolSubnet -NetworkId 192.168.20.0 
   Get-HPOVNetwork -Name Production-20 | Set-HPOVNetwork  -IPv4Subnet $sub3


# Create a Deployment network for the Streamers    
    
   $sub2 = Get-HPOVAddressPoolSubnet -NetworkId 192.168.8.0 
   New-HPOVNetwork -Name iSCSI-Deployment -type Ethernet -VLANType Tagged -VlanId 8 -Purpose ISCSI -Subnet $sub2 -SmartLink $False


# Change frames names - MAX 3 frames
# Name change cannot be done during a frame refresh

    $numberofframes = @(Get-HPOVEnclosure).count

    if ($numberofframes -gt 0) {
    $interconnects =  Get-HPOVInterconnect     
    $whosframe1 = $interconnects | Where-Object {$_.partNumber -match "794502-B23" -and $_.name -match "interconnect 3"} | ForEach-Object {$_.enclosurename}
    if ($whosframe1 -ne "Frame1") {
        $frame1 = get-hpovenclosure -Name $whosframe1 
        #Set-HPOVEnclosure -Name "Frame1-$frame1SN" -Enclosure $frame1
        Set-HPOVEnclosure -Name "Frame1" -Enclosure $frame1

        }
    }

    if ($numberofframes -gt 1) {
    $whosframe2 = $interconnects | Where-Object {$_.partNumber -match "794502-B23" -and $_.name -match "interconnect 6"} |  ForEach-Object {$_.enclosurename}
    if ($whosframe2 -ne "Frame2") {
        $frame2 = get-hpovenclosure -Name $whosframe2
        #Set-HPOVEnclosure -Name "Frame2-$frame2SN" -Enclosure $frame2
        Set-HPOVEnclosure -Name "Frame2" -Enclosure $frame2
        }
    }

    if ($numberofframes -gt 2) {
    $frameswithsatellites = $interconnects | Where-Object -Property Partnumber -EQ -value "779218-B21" 
    $whosframe3 = $frameswithsatellites | group-object -Property enclosurename |  Where-Object-Object{ $_.Count -gt 1 } | ForEach-Object {$_.name}  
    if ($whosframe3 -ne "Frame3") {
        $frame3 = get-hpovenclosure -Name $whosframe3
        #Set-HPOVEnclosure -Name "Frame3-$frame3SN" -Enclosure $frame3
        Set-HPOVEnclosure -Name "Frame3" -Enclosure $frame3
        }
    }

    if ($numberofframes -gt 3) { Write-Host "This script does not support more than 3 frames to change frame names"}




#create Logical interconnect groups

    # Creating M-LAG Logical Interconnect Group

    $LIG_M_LAG_Name = "LIG-MLAG"
    $VCbays =  @{Frame1 = @{Bay3 = 'SEVC40f8' ; Bay6 = 'SE20ILM'};Frame2 = @{Bay3 = 'SE20ILM'; Bay6 = 'SEVC40f8' };Frame3 = @{Bay3 = 'SE20ILM'; Bay6 = 'SE20ILM'}}
    New-HPOVLogicalInterconnectGroup -Name $LIG_M_LAG_Name -InterconnectBaySet 3 -frameCount 3 -Bays $VCbays -FabricModuleType SEVC40F8 -FabricRedundancy HighlyAvailable

    # Creating SAS Logical Interconnect Group

    $LIG_SAS_Name = "LIG-SAS"
    $SASbays =  @{Frame1 = @{Bay1 = 'SE12SAS' ; Bay4 = 'SE12SAS'} } 
    New-HPOVLogicalInterconnectGroup -Name $LIG_SAS_Name -frameCount 1 -InterconnectBaySet 1 -Bays $SASbays -FabricModuleType 'SAS' 

    # Creating FC Logical Interconnect Group

    $LIG_FC_Name = "LIG-FC"
    $FCbays =  @{Frame1 = @{Bay2 = 'SEVC16GbFC' ; Bay5 = 'SEVC16GbFC'} } 
    New-HPOVLogicalInterconnectGroup -Name $LIG_FC_Name -frameCount 1 -InterconnectBaySet 2 -Bays $FCbays -FabricModuleType 'SEVCFC' 


#Create Ethernet Uplink Sets 

  
    $interconnects =  Get-HPOVInterconnect     
    $whosframe1 = $interconnects | Where-Object {$_.partNumber -match "794502-B23" -and $_.name -match "interconnect 3"} | ForEach-Object {$_.enclosurename}
    $whosframe2 = $interconnects | Where-Object {$_.partNumber -match "794502-B23" -and $_.name -match "interconnect 6"} |  ForEach-Object {$_.enclosurename}
    $frameswithsatellites = $interconnects | Where-Object -Property Partnumber -EQ -value "779218-B21" 
    $whosframe3 = $frameswithsatellites | group-object -Property enclosurename |  Where-Object{ $_.Count -gt 1 } | ForEach-Object {$_.name}  

   
    # MLAG Uplink Sets   
    #$AllNetworks = Get-HPOVNetwork -Name Management   
    $AllNetworks = "Management","Production-10","Production-20","vSAN_Network"
    Get-HPOVLogicalInterconnectGroup -name $LIG_M_LAG_Name | New-HPOVUplinkSet -Name "M-LAG-Comware" -Type Ethernet -Networks $AllNetworks -UplinkPorts "Enclosure1:Bay3:Q1","Enclosure2:Bay6:Q1" 
    $Nexusmanagement = Get-HPOVNetwork -Name Management-Nexus   
    Get-HPOVLogicalInterconnectGroup -name $LIG_M_LAG_Name | New-HPOVUplinkSet -Name "M-LAG-Nexus" -Type Ethernet -Networks $Nexusmanagement -UplinkPorts "Enclosure1:Bay3:Q5","Enclosure2:Bay6:Q5" 

    # FC Uplink Sets
    # Enclosure1 must be removed in new version
    $fca = Get-HPOVNetwork -Name "FC-A"   
    Get-HPOVLogicalInterconnectGroup -name $LIG_M_LAG_Name | New-HPOVUplinkSet -Name "FC-A"  -Type FibreChannel -Networks $fca -UplinkPorts "Enclosure1:Bay3:Q4.1" 
    $fcb = Get-HPOVNetwork -Name "FC-B"   
    Get-HPOVLogicalInterconnectGroup -name $LIG_M_LAG_Name | New-HPOVUplinkSet -Name "FC-B" -Type FibreChannel -Networks $fcb -UplinkPorts "Enclosure2:Bay6:Q4.1" 

   
#Create an uplink Set for the Image Streamer (Internal) 

    # Get-HPOVLogicalInterconnectGroup -name $LIG_M_LAG_Name -ErrorAction Stop | New-HPOVUplinkSet -Name "iSCSI-Deployment" -Type ImageStreamer -Networks "iSCSI-Deployment" -UplinkPorts "Enclosure1:Bay3:Q2.1","Enclosure1:Bay3:Q3.1","Enclosure2:Bay6:Q2.1","Enclosure2:Bay6:Q3.1" #| Wait-HPOVTaskComplete


    $ImageStreamerDeploymentNetwork = Get-HPOVNetwork -Name "iSCSI-Deployment" -ErrorAction Stop
   
    Get-HPOVLogicalInterconnectGroup -Name $LIG_M_LAG_Name -ErrorAction Stop | New-HPOVUplinkSet -Name 'ImageStreamer_Uplink_Set' -Type ImageStreamer -Networks $ImageStreamerDeploymentNetwork -UplinkPorts "Enclosure1:Bay3:Q2.1","Enclosure1:Bay3:Q3.1","Enclosure2:Bay6:Q2.1","Enclosure2:Bay6:Q3.1"




# Add Deployment Server

    # Takes 13mn to run !
    # Make sure each streamer is started and showing an Active status under the maintenance console 

    $ImageStreamerManagementNetwork = Get-HPOVNetwork -Name "Management" -ErrorAction Stop

    Get-HPOVImageStreamerAppliance | Select-Object -First 1 | New-HPOVOSDeploymentServer -Name "Image-Streamer_PAIR-1" -ManagementNetwork $ImageStreamerManagementNetwork


# Create Enclosure Group 


    $LIGMLAG = Get-HPOVLogicalInterconnectGroup -name $LIG_M_LAG_Name
    $LIGSAS = Get-HPOVLogicalInterconnectGroup -name $LIG_SAS_Name



    $LogicalInterConnectGroupMapping = @{
        Frame1 = $LIGSAS   , $LIGMLAG ;
        Frame2 = $LIGSAS   , $LIGMLAG ;
        Frame3 = $LIGSAS   , $LIGMLAG ; 
    } 


    New-HPOVEnclosureGroup -name "3_frame_EG" -LogicalInterconnectGroupMapping $LogicalInterConnectGroupMapping -DeploymentNetworkType Internal -EnclosureCount 3 -IPv4AddressType DHCP 
    #New-HPOVEnclosureGroup -name "EG" -LogicalInterconnectGroupMapping $LogicalInterConnectGroupMapping  -EnclosureCount 3 -IPv4AddressType DHCP 

     
  
# Installing Nimble Storage System Nimble.xx.lab 

    $username = "admin" 
    $secpasswd = read-host "Please enter the Nimble password for admin" -AsSecureString
    $credentials = New-Object System.Management.Automation.PSCredential ($username, $secpasswd)

    Add-HPOVStorageSystem -Hostname "nimble.xx.lab" -Credential $credentials -Family Nimble -VIPS "nimble.xx.lab" | Wait-HPOVTaskComplete 
     

# Add SY 3PAR System

    $3PARlibrary = "xx:\xx\_Scripts\_PowerShell\3PAR\3PAR-Powershell-master\3PAR-Powershell"


    Add-HPOVStorageSystem -hostname "3par.xx.lab" -username 3paradm -password 3pardata -Family StoreServ  | Wait-HPOVTaskComplete 
    Add-HPOVStoragePool -StorageSystem "3par.xx.lab" -Pool "FC_r5", "SSD_r5"  | Wait-HPOVTaskComplete
    
    #Import 3PAR library
    if (-not (get-module 3PAR-Powershell)) 
    {
    Import-Module  $3PARlibrary
    }
    
    $3PARcreds = Get-Credential -UserName 3paradm -Message "Please enter the 3PAR password"  
    Connect-3PAR -Server "3par.xx.lab"  -Credentials $3PARcreds

    
    #3PAR Volumes to import in OneView

    $volume1 = 'vSphere-datastore'
    #Set-HPOVStoragePool
    
    # Import 3PAR volumes
    $StorageDeviceName1 = Get-3PARVolumes -name $volume1 | ForEach-Object {$_.name}   

    Get-HPOVStorageSystem -SystemName "3par.xx.lab"  |  Add-HPOVStorageVolume   -VolumeName $volume1 -StorageDeviceName $StorageDeviceName1 -Shared | Wait-HPOVTaskComplete


# Creating a new Datacenter
    $NewDCParams = @{
    
        Name             = 'DC';
        Width            = 10000;
        Depth            = 15000;
        Millimeters      = $True;
        DefaultVoltage   = 220;
        PowerCosts       = 0.10;
        CoolingCapacity  = 350;
        Address1         = 'xx';
        Address2         = 'xx';
        City             = 'xx';
        Country          = 'xx';
        PostCode         = 'xx';
        TimeZone         = 'GMT+1';
    
    }

    New-HPOVDataCenter  @NewDCParams 

    

# Removing default datacenter 

   Get-HPOVDataCenter -Name "Datacenter 1" | remove-HPOVDataCenter -Confirm:$false



# Creating a rack
     
     $Params = @{
    
        Name         = 'Synergy-Rack';
        ThermalLimit = 10000;
        SerialNumber = 'AABB1122CCDD';
        PartNumber   = 'AF046A';
        Depth        = 1075;
        Height       = 2032;
        UHeight      = 36;
        Width        = 600
                   }

    New-HPOVRack @Params


# Adding frame ressources to rack

    $frame3 = Get-HPOVenclosure | Where-Object {$_.name -match "Frame3"}
    $frame2 = Get-HPOVenclosure | Where-Object {$_.name -match "Frame2"}
    $frame1 = Get-HPOVenclosure | Where-Object {$_.name -match "Frame1"}


    $Rack = Get-HPOVRack -Name Rack-Synergy -ErrorAction Stop
    $_U = 1
    Add-HPOVResourceToRack -InputObject $frame3 -Rack $Rack -ULocation $_U
    $_U += 10
    Add-HPOVResourceToRack -InputObject $frame2 -Rack $Rack -ULocation $_U
    $_U += 10
    Add-HPOVResourceToRack -InputObject $frame1 -Rack $Rack -ULocation $_U

    

# Adding rack to datacenter

    $DC = Get-HPOVDataCenter 
    $X = 1000
    $Y = 2000
    Get-HPOVRack -Name Rack-Synergy -ErrorAction Stop | Add-HPOVRackToDataCenter -DataCenter $DC -X $X -Y $Y -Millimeters
 
 
 
 # Adding remote backup location  
 
    $HostSSHKey = "ssh-rsa AAAAB3NzaC1yc2...XsPwcaIVgr"
    Set-HPOVAutomaticBackupConfig -Hostname xx.xx.lab -Username root -Password (ConvertTo-SecureString xxxxx -AsPlainText -Force) -Directory "composer_backup" -HostSSHKey $HostSSHKey -Protocol SFTP -Interval Weekly -Days 'SUN' -Time 18:00


# Adding an external repository

   New-HPOVExternalRepository -Name SPP-kits -Hostname xx.xx.lab -Directory '_HP/_SPP/Repository' -Http






# creating Logical Enclosure LE-3-frames using the latest SPP  !   22mn without Streamer - add 60mn for Streamer configuration

    $LE = '3_frame_LE'
    $interconnects =  Get-HPOVInterconnect     
    $whosframe1 = $interconnects | Where-Object {$_.partNumber -match "794502-B23" -and $_.name -match "interconnect 3"} | ForEach-Object {$_.enclosurename}

    $baseline = Get-HPOVBaseline | Sort-Object -Property @{Expression = "Version"; Descending = $True} | Select-Object -First 1
    $EG = Get-HPOVEnclosureGroup -Name "3_frame_EG"

    write-output "Creating the Logical Enclosure 'LE'" | Timestamp
    Get-HPOVEnclosure -Name  $whosframe1 | New-HPOVLogicalEnclosure -Name $LE -EnclosureGroup $EG -FirmwareBaseline $baseline -ForceFirmwareBaseline $true 
    write-output "Logical Enclosure 'LE' created " | Timestamp
    



   
# Add a new scope for OneView Users

    $scopename = "OneView Users"

    New-HPOVScope -Name $scopename

    $resources = @()
    $Resources += Get-HPOVLogicalEnclosure -Name $LE 
    $Resources += Get-HPOVEnclosureGroup -Name  $EG.name
    $Resources += Get-HPOVLogicalInterconnectGroup
    $Resources += Get-HPOVLogicalInterconnect 
    $Resources += Get-HPOVInterconnect 
    $Resources += Get-HPOVNetwork
    $Resources += Get-HPOVNetworkSet
    $Resources += Get-HPOVFabricManager
    $Resources += Get-HPOVServer | Where-Object model -NotMatch "660"
    $Resources += Get-HPOVOSDeploymentPlan
        
    Get-HPOVScope -Name $scopename | Add-HPOVResourceToScope -InputObject $Resources

    <#

    Get-HPOVScope -Name "OneView Users" | Select-Object members | ForEach-Object members

    #>

    $scope = Get-HPOVScope -Name $scopename

    $ScopePermissions = @(
    
        @{ Role = "Server administrator"; Scope = $scope }, 
        @{ Role = "Software administrator" ; Scope = $scope }
        
        )

    
    Get-HPOVLdapGroup -Name $scopename | Set-HPOVLdapGroupRole -ScopePermissions $ScopePermissions -Credential $credentialAD 



# Uploading OS Deployment plan to Image Streamer

    write-host "`nDownload the ESXi artifacts from https://github.com/HewlettPackard/image-streamer-esxi" -ForegroundColor Cyan
    write-host "`nThen add and extract this artifact bundle on the Image Streamer"
    pause
    # Latest artifact bundle for ESXi : https://github.com/HewlettPackard/image-streamer-esxi/blob/master/artifact-bundles/HPE-ESXi-2017-06-13.zip 

    
# Uploading Artifact bundles from admin's local drive to Image Streamer 
    
    # This operation is currently limited to supporting files less than 2G in size.


    # Path of the Artifact bundle ZIP FILES
    $filesPath = 'xx:\xx\xx\xx\Image Streamer\Artifacts Bundles\Latest'

    $I3sIP = (Get-HPOVOSDeploymentServer).primaryipv4

    function Failure {
        $global:helpme = $bodyLines
        $global:helpmoref = $moref
        $global:result = $_.Exception.Response.GetResponseStream()
        $global:reader = New-Object System.IO.StreamReader($global:result)
        $global:responseBody = $global:reader.ReadToEnd();
        Write-Host -BackgroundColor:Black -ForegroundColor:Red "Status: A system exception was caught."
        Write-Host -BackgroundColor:Black -ForegroundColor:Red $global:responsebody
        Write-Host -BackgroundColor:Black -ForegroundColor:Red "The request body has been saved to `$global:helpme"
        #break
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

    
    
    # Creation of the header
    $headers = @{} 
    $headers["Accept"] = "application/json" 
    $headers["X-API-Version"] = "1200"
    $key = $ConnectedSessions[0].SessionID 
    $headers["Auth"] = $key



    $ArtifactBundles = Get-childItem $filespath 
    
    Foreach ($ArtifactBundle in $ArtifactBundles) {
    
        $filePath = $ArtifactBundle.FullName
        $filename = $ArtifactBundle.Name

        # Creation of the webrequest       
        if ( (get-item $filePath).Length -lt 2gb) {

            Try {

                # Creation of the body
                $fileBin = [System.IO.File]::ReadAllBytes($filePath)
                $enc = [System.Text.Encoding]::GetEncoding("iso-8859-1")
                $fileEnc = $enc.GetString($fileBin)

                $boundary = [System.Guid]::NewGuid().ToString()
                $LF = "`r`n"

                $bodyLines = (
                    "--$boundary",
                    "Content-Disposition: form-data; name=`"file`"; filename=$filepath$LF",
                    $fileEnc,
                    "Content-Type: application/zip$LF",
                    "--$boundary--$LF"
                ) -join $LF

                #
                $result = Invoke-RestMethod -Uri "https://$I3sIP/rest/artifact-bundles" -Headers $headers -Body $bodyLines -ContentType "multipart/form-data; boundary=$boundary" -Method POST # -Verbose  
                write-host "Artifact bundle '$filename' has been uploaded successfully !" -ForegroundColor Green

            }
            catch {
                #failure
                write-host "`nArtifact bundle '$filename' upload error !" -ForegroundColor Red
                $error[0] #| Format-List *
            }
        }
        else {
            Write-warning "Artifact bundle '$filename' cannot be uploaded as it is greater than 2Gb"  
        }

    }





#creating a Server Profile Template for an ESX server using the Image Streamer 
#List of SPT
<#
CentOS 7.5 deployment with Streamer    
ESXi 6.5U1 deployment with Streamer   
ESXi 6.5U2 deployment with Streamer   
RHEL7.3 deployment with Streamer        
SLES 12 deployment with Streamer       
Win2016 deployment with Streamer - Gen9
XenServer 7.1 deployment with Streamer
#>

#List of OSDP
<#
    CentOS 7.5                                                      
    HPE - ESXi 6.5U1 - deploy with multiple management NIC HA config
    HPE - ESXi 6.5U2 - deploy with multiple management NIC HA config
HPE - Foundation 1.0 - create empty OS Volume-2017-10-13        
    RHEL7.3-personalize-and-NIC-teamings-LVM                        
    SLES-12-personalize-and-configure-NICs-LVM                      
    Windows 2016 - Deploy - HA - SY480Gen9                          
    Xenserver 7.1 - HA mgmt and add as 1st node in new pool
#>


    Write-Output "Creating Server Profile Template using the Image Streamer" | Timestamp




    # -------------- Attributes for ServerProfileTemplate "ESXi 6.5U2 deployment with Streamer"
$name                       = "NEW_ESXi 6.5U2 deployment with Streamer"
$description                = "Server Profile Template for HPE Synergy 480 Gen9 Compute Module using the Image Streamer"
$shtName                    = "SY 480 Gen9 1"
$sht                        = Get-HPOVServerHardwareType -Name $shtName
$egName                     = "3_frame_EG"
$eg                         = Get-HPOVEnclosureGroup -Name $egName
$affinity                   = "Bay"
# -------------- Attributes for connection "1"
$connID                     = 1
$connName                   = "Deployment Network A"
$connType                   = "Ethernet"
$netName                    = "iSCSI-Deployment"
$ThisNetwork                = Get-HPOVNetwork -Type Ethernet -Name $netName
$portID                     = "Mezz 3:1-a"
$requestedMbps              = 2500
$bootPriority               = "Primary"
$volSource                  = "UserDefined"
$addressSource              = "SubnetPool"
$Conn1                      = New-HPOVServerProfileConnection -ConnectionID $connID -Name $connName -ConnectionType $connType -Network $ThisNetwork -PortId $portID -RequestedBW $requestedMbps -Bootable -Priority $bootPriority -BootVolumeSource $volSource -IscsiIPv4AddressSource $addressSource
# -------------- Attributes for connection "2"
$connID                     = 2
$connName                   = "Deployment Network B"
$connType                   = "Ethernet"
$netName                    = "iSCSI-Deployment"
$ThisNetwork                = Get-HPOVNetwork -Type Ethernet -Name $netName
$portID                     = "Mezz 3:2-a"
$requestedMbps              = 2500
$bootPriority               = "Secondary"
$volSource                  = "UserDefined"
$addressSource              = "SubnetPool"
$Conn2                      = New-HPOVServerProfileConnection -ConnectionID $connID -Name $connName -ConnectionType $connType -Network $ThisNetwork -PortId $portID -RequestedBW $requestedMbps -Bootable -Priority $bootPriority -BootVolumeSource $volSource -IscsiIPv4AddressSource $addressSource
# -------------- Attributes for connection "3"
$connID                     = 3
$connType                   = "Ethernet"
$netName                    = "Management"
$ThisNetwork                = Get-HPOVNetwork -Type Ethernet -Name $netName
$portID                     = "Mezz 3:1-c"
$requestedMbps              = 2500
$Conn3                      = New-HPOVServerProfileConnection -ConnectionID $connID -ConnectionType $connType -Network $ThisNetwork -PortId $portID -RequestedBW $requestedMbps
# -------------- Attributes for connection "4"
$connID                     = 4
$connType                   = "Ethernet"
$netName                    = "Management"
$ThisNetwork                = Get-HPOVNetwork -Type Ethernet -Name $netName
$portID                     = "Mezz 3:2-c"
$requestedMbps              = 2500
$Conn4                      = New-HPOVServerProfileConnection -ConnectionID $connID -ConnectionType $connType -Network $ThisNetwork -PortId $portID -RequestedBW $requestedMbps
# -------------- Attributes for connection "5"
$connID                     = 5
$connType                   = "FibreChannel"
$netName                    = "FC-A"
$ThisNetwork                = Get-HPOVNetwork -Type FibreChannel -Name $netName
$portID                     = "Mezz 3:1-b"
$requestedMbps              = 2500
$Conn5                      = New-HPOVServerProfileConnection -ConnectionID $connID -ConnectionType $connType -Network $ThisNetwork -PortId $portID -RequestedBW $requestedMbps
# -------------- Attributes for connection "6"
$connID                     = 6
$connType                   = "FibreChannel"
$netName                    = "FC-B"
$ThisNetwork                = Get-HPOVNetwork -Type FibreChannel -Name $netName
$portID                     = "Mezz 3:2-b"
$requestedMbps              = 2500
$Conn6                      = New-HPOVServerProfileConnection -ConnectionID $connID -ConnectionType $connType -Network $ThisNetwork -PortId $portID -RequestedBW $requestedMbps
$connections                = $Conn1, $Conn2, $Conn3, $Conn4, $Conn5, $Conn6
# -------------- Attributes for OS deployment settings
$planName                   = "HPE - ESXi 6.5U2 - deploy with multiple management NIC HA config"
$osDeploymentPlan           = Get-HPOVOsDeploymentPlan -Name $planName
$planAttribs                = Get-HPOVOsDeploymentPlanAttribute -InputObject $osDeploymentPlan
$CustomAttribs              = @()
($planAttribs | Where-Object name -eq "DomainName").value = "xx.lab"
$CustomAttribs     += $planAttribs | Where-Object name -eq "DomainName"
$CustomAttribs              = @()
($planAttribs | Where-Object name -eq "Hostname").value = "{profile}"
$CustomAttribs     += $planAttribs | Where-Object name -eq "Hostname"
$CustomAttribs              = @()
($planAttribs | Where-Object name -eq "ManagementNIC.connectionid").value = "3"
$CustomAttribs     += $planAttribs | Where-Object name -eq "ManagementNIC.connectionid"
$CustomAttribs              = @()
($planAttribs | Where-Object name -eq "ManagementNIC.constraint").value = "auto"
$CustomAttribs     += $planAttribs | Where-Object name -eq "ManagementNIC.constraint"
$CustomAttribs              = @()
($planAttribs | Where-Object name -eq "ManagementNIC.networkuri").value = "/rest/ethernet-networks/89ad8bd5-718c-4f5c-be57-33acb49ff8d5"
$CustomAttribs     += $planAttribs | Where-Object name -eq "ManagementNIC.networkuri"
$CustomAttribs              = @()
($planAttribs | Where-Object name -eq "ManagementNIC.vlanid").value = "0"
$CustomAttribs     += $planAttribs | Where-Object name -eq "ManagementNIC.vlanid"
$CustomAttribs              = @()
($planAttribs | Where-Object name -eq "ManagementNIC2.connectionid").value = "4"
$CustomAttribs     += $planAttribs | Where-Object name -eq "ManagementNIC2.connectionid"
$CustomAttribs              = @()
($planAttribs | Where-Object name -eq "ManagementNIC2.constraint").value = "auto"
$CustomAttribs     += $planAttribs | Where-Object name -eq "ManagementNIC2.constraint"
$CustomAttribs              = @()
($planAttribs | Where-Object name -eq "ManagementNIC2.networkuri").value = "/rest/ethernet-networks/89ad8bd5-718c-4f5c-be57-33acb49ff8d5"
$CustomAttribs     += $planAttribs | Where-Object name -eq "ManagementNIC2.networkuri"
$CustomAttribs              = @()
($planAttribs | Where-Object name -eq "ManagementNIC2.vlanid").value = "0"
$CustomAttribs     += $planAttribs | Where-Object name -eq "ManagementNIC2.vlanid"
$CustomAttribs              = @()
($planAttribs | Where-Object name -eq "NTPSERVERS").value = "fr.pool.ntp.org"
$CustomAttribs     += $planAttribs | Where-Object name -eq "NTPSERVERS"
$CustomAttribs              = @()
($planAttribs | Where-Object name -eq "Password").value = Read-Host -Prompt "Provide required password"
$CustomAttribs     += $planAttribs | Where-Object name -eq "Password"
$CustomAttribs              = @()
($planAttribs | Where-Object name -eq "SSH").value = "enabled"
$CustomAttribs     += $planAttribs | Where-Object name -eq "SSH"
# -------------- Attributes for SAN Storage
$osType                     = "VMware"
# ----------- SAN volume attributes for volume ID "1"
$volId                      = 1
$lunIdType                  = "Auto"
$volName                    = "vSphere-datastore"
$volume1                    = Get-HPOVStorageVolume -Name $volName
$volume1                    = New-HPOVServerProfileAttachVolume -VolumeID $volId -LunIDType $lunIdType -Volume $volume1
$volumeAttachments          = $volume1
# -------------- Attributes for BIOS Boot Mode settings
$manageboot                 = $True
$biosBootMode               = "UEFIOptimized"
# -------------- Attributes for BIOS order settings
$bootOrder                  = "HardDisk"
# -------------- Attributes for advanced settings
New-HPOVServerProfileTemplate -Name $name -Description $description -ServerHardwareType $sht -EnclosureGroup $eg -Affinity $affinity -OSDeploymentPlan $osDeploymentPlan -OSDeploymentPlanAttributes $planAttribs -Connections $connections -ManageBoot $manageboot -BootMode $biosBootMode -SanStorage -HostOsType $osType -StorageVolume $volumeAttachments -BootOrder $bootOrder -HideUnusedFlexNics $true




































#-------------------------------------------------------------------------------------------------------------------



    $serverprofiletemplate = "ESXi 6.5U1 deployment with Streamer"
    $OSDeploymentplan = 'HPE - ESXi 6.5U1 - deploy with multiple management NIC HA config'
    $datastore = 'vSphere-datastore'
 


        $SY460SHT = Get-HPOVServerHardwareTypes -name "SY 480 Gen9 1"
        
        $enclosuregroup = Get-HPOVEnclosureGroup | Where-Object {$_.osDeploymentSettings.manageOSDeployment -eq $True} | Select-Object -First 1 
        
        $ManagementURI = Get-HPOVNetwork | Where-Object {$_.purpose -match "Management" -and $_.SubnetUri -ne $Null} | ForEach-Object Uri

        $OSDP = Get-HPOVOSDeploymentPlan -name $OSDeploymentplan
        $osCustomAttributes = Get-HPOVOSDeploymentPlan -name $OSDeploymentplan -ErrorAction Stop | Get-HPOVOSDeploymentPlanAttribute
        $OSDeploymentPlanAttributes = $osCustomAttributes 


        ($OSDeploymentPlanAttributes | Where-Object name -eq 'ManagementNIC.ipaddress').value = ''
        ($OSDeploymentPlanAttributes | Where-Object name -eq 'ManagementNIC.dhcp').value = 'False'
        ($OSDeploymentPlanAttributes | Where-Object name -eq 'ManagementNIC.connectionid').value = '3'
        ($OSDeploymentPlanAttributes | Where-Object name -eq 'DomainName').value = 'xx.lab'
        ($OSDeploymentPlanAttributes | Where-Object name -eq 'ManagementNIC2.dhcp').value = 'False'
        ($OSDeploymentPlanAttributes | Where-Object name -eq 'ManagementNIC2.connectionid').value = '4'
        ($OSDeploymentPlanAttributes | Where-Object name -eq 'ManagementNIC.networkuri').value = $ManagementURI
        ($OSDeploymentPlanAttributes | Where-Object name -eq 'ManagementNIC2.networkuri').value = $ManagementURI
        ($OSDeploymentPlanAttributes | Where-Object name -eq 'Hostname').value = "{profile}"

                      
        $ISCSINetwork = Get-HPOVNetwork | Where-Object {$_.purpose -match "ISCSI" -and $_.SubnetUri -ne $Null} 

        $IscsiParams1 = @{
               ConnectionID                  = 1;
               Name                          = "Deployment Network A";
               ConnectionType                = "Ethernet";
               Network                       = $ISCSINetwork;
               Bootable                      = $true;
               Priority                      = "Primary";
               IscsiIPv4AddressSource        = "SubnetPool"
                         }

        $ImageStreamerBootConnection1 = New-HPOVServerProfileConnection @IscsiParams1
        
        $IscsiParams2 = @{
               ConnectionID                  = 2;
               Name                          = "Deployment Network B";
               ConnectionType                = "Ethernet";
               Network                       = $ISCSINetwork;
               Bootable                      = $true;
               Priority                      = "Secondary";
               IscsiIPv4AddressSource        = "SubnetPool"
                         }

        $ImageStreamerBootConnection2 = New-HPOVServerProfileConnection @IscsiParams2

        
        $con3 = Get-HPOVNetwork | Where-Object {$_.purpose -match "Management" -and $_.SubnetUri -ne $Null} | New-HPOVServerProfileConnection -connectionId 3
        $con4 = Get-HPOVNetwork | Where-Object {$_.purpose -match "Management" -and $_.SubnetUri -ne $Null}  | New-HPOVServerProfileConnection -connectionId 4
        $con5 = Get-HPOVNetwork | Where-Object fabricType -match "FabricAttach" | Select-Object -Index 0 |  New-HPOVServerProfileConnection -ConnectionID 5 -ConnectionType FibreChannel 
        $con6 = Get-HPOVNetwork | Where-Object fabricType -match "FabricAttach" | Select-Object -Index 1 | New-HPOVServerProfileConnection -ConnectionID 6 -ConnectionType FibreChannel
        $volume1 = Get-HPOVStorageVolume -Name $datastore | New-HPOVServerProfileAttachVolume # -LunIdType Manual -LunID 0
  

  
        $params = @{
            Name                = $serverprofiletemplate;
            Description         = "Server Profile Template for HPE Synergy 480 Gen9 Compute Module using the Image Streamer";
            ServerHardwareType  = $SY460SHT;
            Affinity            = "Bay";
            Enclosuregroup      = $enclosuregroup;
            Connections         = $ImageStreamerBootConnection1, $ImageStreamerBootConnection2, $con3, $con4, $con5, $con6;
            Manageboot          = $True;
            BootMode            = "UEFIOptimized";
            BootOrder           = "HardDisk";
            HideUnusedFlexnics  = $True;
            SANStorage          = $True;
            OS                  = 'VMware';
            StorageVolume       = $volume1;
            OSDeploymentplan    = $OSDP;
            OSDeploymentPlanAttributes = $OSDeploymentPlanAttributes

            
             }


      try
          {
       
          New-HPOVServerProfileTemplate @params -ErrorAction Stop | Wait-HPOVTaskComplete

          }

      catch  
         {
       
         $error[0] | Format-List * -force 
               
         }
   


   Write-Output "Server Profile Template $serverprofiletemplate using Image Streamer Created" | Timestamp

   






#creating a Server Profile Template for an ESX server using the Image Streamer 
# Name "ESXi 6.5U2 deployment with Streamers"

    Write-Output "Creating Server Profile Template using the Image Streamer" | Timestamp


    $serverprofiletemplate = "ESXi 6.5U2 deployment with Streamer"
    $OSDeploymentplan = 'HPE - ESXi 6.5U2 - deploy with multiple management NIC HA config'
    $datastore = 'vSphere-datastore'
 


        $SY460SHT = Get-HPOVServerHardwareTypes -name "SY 480 Gen9 1"
        
        $enclosuregroup = Get-HPOVEnclosureGroup | Where-Object {$_.osDeploymentSettings.manageOSDeployment -eq $True} | Select-Object -First 1 
        
        $ManagementURI = Get-HPOVNetwork | Where-Object {$_.purpose -match "Management" -and $_.SubnetUri -ne $Null} | ForEach-Object Uri

        $OSDP = Get-HPOVOSDeploymentPlan -name $OSDeploymentplan
        $osCustomAttributes = Get-HPOVOSDeploymentPlan -name $OSDeploymentplan -ErrorAction Stop | Get-HPOVOSDeploymentPlanAttribute
        $OSDeploymentPlanAttributes = $osCustomAttributes 


        ($OSDeploymentPlanAttributes | Where-Object name -eq 'ManagementNIC.ipaddress').value = ''
        ($OSDeploymentPlanAttributes | Where-Object name -eq 'ManagementNIC.dhcp').value = 'False'
        ($OSDeploymentPlanAttributes | Where-Object name -eq 'ManagementNIC.connectionid').value = '3'
        ($OSDeploymentPlanAttributes | Where-Object name -eq 'DomainName').value = 'xx.lab'
        ($OSDeploymentPlanAttributes | Where-Object name -eq 'ManagementNIC2.dhcp').value = 'False'
        ($OSDeploymentPlanAttributes | Where-Object name -eq 'ManagementNIC2.connectionid').value = '4'
        ($OSDeploymentPlanAttributes | Where-Object name -eq 'ManagementNIC.networkuri').value = $ManagementURI
        ($OSDeploymentPlanAttributes | Where-Object name -eq 'ManagementNIC2.networkuri').value = $ManagementURI
        ($OSDeploymentPlanAttributes | Where-Object name -eq 'Hostname').value = "{profile}"

                      
        $ISCSINetwork = Get-HPOVNetwork | Where-Object {$_.purpose -match "ISCSI" -and $_.SubnetUri -ne $Null} 

        $IscsiParams1 = @{
               ConnectionID                  = 1;
               Name                          = "Deployment Network A";
               ConnectionType                = "Ethernet";
               Network                       = $ISCSINetwork;
               Bootable                      = $true;
               Priority                      = "Primary";
               IscsiIPv4AddressSource        = "SubnetPool"
                         }

        $ImageStreamerBootConnection1 = New-HPOVServerProfileConnection @IscsiParams1
        
        $IscsiParams2 = @{
               ConnectionID                  = 2;
               Name                          = "Deployment Network B";
               ConnectionType                = "Ethernet";
               Network                       = $ISCSINetwork;
               Bootable                      = $true;
               Priority                      = "Secondary";
               IscsiIPv4AddressSource        = "SubnetPool"
                         }

        $ImageStreamerBootConnection2 = New-HPOVServerProfileConnection @IscsiParams2

        
        $con3 = Get-HPOVNetwork | Where-Object {$_.purpose -match "Management" -and $_.SubnetUri -ne $Null} | New-HPOVServerProfileConnection -connectionId 3
        $con4 = Get-HPOVNetwork | Where-Object {$_.purpose -match "Management" -and $_.SubnetUri -ne $Null}  | New-HPOVServerProfileConnection -connectionId 4
        $con5 = Get-HPOVNetwork | Where-Object fabricType -match "FabricAttach" | Select-Object -Index 0 |  New-HPOVServerProfileConnection -ConnectionID 5 -ConnectionType FibreChannel 
        $con6 = Get-HPOVNetwork | Where-Object fabricType -match "FabricAttach" | Select-Object -Index 1 | New-HPOVServerProfileConnection -ConnectionID 6 -ConnectionType FibreChannel
        $volume1 = Get-HPOVStorageVolume -Name $datastore | New-HPOVServerProfileAttachVolume # -LunIdType Manual -LunID 0
  

  
        $params = @{
            Name                = $serverprofiletemplate;
            Description         = "Server Profile Template for HPE Synergy 480 Gen9 Compute Module using the Image Streamer";
            ServerHardwareType  = $SY460SHT;
            Affinity            = "Bay";
            Enclosuregroup      = $enclosuregroup;
            Connections         = $ImageStreamerBootConnection1, $ImageStreamerBootConnection2, $con3, $con4, $con5, $con6;
            Manageboot          = $True;
            BootMode            = "UEFIOptimized";
            BootOrder           = "HardDisk";
            HideUnusedFlexnics  = $True;
            SANStorage          = $True;
            OS                  = 'VMware';
            StorageVolume       = $volume1;
            OSDeploymentplan    = $OSDP;
            OSDeploymentPlanAttributes = $OSDeploymentPlanAttributes

            
             }


      try
          {
       
          New-HPOVServerProfileTemplate @params -ErrorAction Stop | Wait-HPOVTaskComplete

          }

      catch  
         {
       
         $error[0] | Format-List * -force 
               
         }
   


   Write-Output "Server Profile Template $serverprofiletemplate using Image Streamer Created" | Timestamp

   







#creating a Server Profile Template for an RHEL server using the Image Streamer 
# Name "RHEL73 deployment with Streamer"

    Write-Output "Creating Server Profile Template using the Image Streamer" | Timestamp


    $serverprofiletemplate = "RHEL7.3 deployment with Streamer2"
    $OSDeploymentplan = 'RHEL7.3-personalize-and-NIC-teamings-LVM'
 


        $SY460SHT = Get-HPOVServerHardwareTypes -name "SY 480 Gen9 1"
        
        $enclosuregroup = Get-HPOVEnclosureGroup | Where-Object {$_.osDeploymentSettings.manageOSDeployment -eq $True} | Select-Object -First 1 
        
        $ManagementURI = Get-HPOVNetwork | Where-Object {$_.purpose -match "Management" -and $_.SubnetUri -ne $Null} | ForEach-Object Uri

        $OSDP = Get-HPOVOSDeploymentPlan -name $OSDeploymentplan
        $osCustomAttributes = Get-HPOVOSDeploymentPlan -name $OSDeploymentplan -ErrorAction Stop | Get-HPOVOSDeploymentPlanAttribute
        $OSDeploymentPlanAttributes = $osCustomAttributes 


       # ($OSDeploymentPlanAttributes | Where-Object name -eq 'Team0NIC1.ipaddress').value = 'SubnetPool'
        #($OSDeploymentPlanAttributes | Where-Object name -eq 'TeamNIC2.ipaddress').value = 'SubnetPool'
        ($OSDeploymentPlanAttributes | Where-Object name -eq 'Team0NIC1.dhcp').value = $True
        ($OSDeploymentPlanAttributes | Where-Object name -eq 'Team0NIC1.connectionid').value = '3'
        ($OSDeploymentPlanAttributes | Where-Object name -eq 'Team0NIC2.dhcp').value = $True
        ($OSDeploymentPlanAttributes | Where-Object name -eq 'Team0NIC2.connectionid').value = '4'
        ($OSDeploymentPlanAttributes | Where-Object name -eq 'Team0NIC1.networkuri').value = $ManagementURI
        ($OSDeploymentPlanAttributes | Where-Object name -eq 'Team0NIC2.networkuri').value = $ManagementURI
        ($OSDeploymentPlanAttributes | Where-Object name -eq 'Hostname').value = "{profile}"
        ($OSDeploymentPlanAttributes | Where-Object name -eq 'TotalNICTeamings').value = '1'

        

        $OSDeploymentPlanAttributes = $OSDeploymentPlanAttributes | Where-Object { $_.name -notmatch  "Team1"  }
 
                      
        $ISCSINetwork = Get-HPOVNetwork | Where-Object {$_.purpose -match "ISCSI" -and $_.SubnetUri -ne $Null} 

        $IscsiParams1 = @{
               ConnectionID                  = 1;
               Name                          = "Deployment Network A";
               ConnectionType                = "Ethernet";
               Network                       = $ISCSINetwork;
               Bootable                      = $true;
               Priority                      = "Primary";
               IscsiIPv4AddressSource        = "SubnetPool"
                         }

        $ImageStreamerBootConnection1 = New-HPOVServerProfileConnection @IscsiParams1
        
        $IscsiParams2 = @{
               ConnectionID                  = 2;
               Name                          = "Deployment Network B";
               ConnectionType                = "Ethernet";
               Network                       = $ISCSINetwork;
               Bootable                      = $true;
               Priority                      = "Secondary";
               IscsiIPv4AddressSource        = "SubnetPool"
                         }

        $ImageStreamerBootConnection2 = New-HPOVServerProfileConnection @IscsiParams2

        
        $con3 = Get-HPOVNetwork | Where-Object {$_.purpose -match "Management" -and $_.SubnetUri -ne $Null} | New-HPOVServerProfileConnection -connectionId 3
        $con4 = Get-HPOVNetwork | Where-Object {$_.purpose -match "Management" -and $_.SubnetUri -ne $Null}  | New-HPOVServerProfileConnection -connectionId 4
        $con5 = Get-HPOVNetwork -Name "Production-10"  |  New-HPOVServerProfileConnection -ConnectionID 5  
        $con6 = Get-HPOVNetwork -Name "Production-10"  |  New-HPOVServerProfileConnection -ConnectionID 6
        
        $conList = @($ImageStreamerBootConnection1, $ImageStreamerBootConnection2, $con3, $con4, $con5, $con6)
      
      Get-HPOVCommandTrace -scriptblock { New-HPOVServerProfileTemplate -name $serverprofiletemplate -Connections $conList -sht $SY460SHT -eg $enclosuregroup -ManageBoot $True -BootMode UEFIOptimized -OSDeploymentPlanAttributes $OSDeploymentPlanAttributes -OSDeploymentPlan $osdp | Wait-HPOVTaskComplete }
  
        $params = @{
            Name                = $serverprofiletemplate;
            Description         = "Server Profile Template for HPE Synergy 480 Gen9 Compute Module using the Image Streamer";
            ServerHardwareType  = $SY460SHT;
            Affinity            = "Bay";
            Enclosuregroup      = $enclosuregroup;
            Connections         = $ImageStreamerBootConnection1, $ImageStreamerBootConnection2, $con3, $con4, $con5, $con6;
            Manageboot          = $True;
            BootMode            = "UEFIOptimized";
            BootOrder           = "HardDisk";
            HideUnusedFlexnics  = $True;
            #SANStorage          = $False;
            #OS                  = 'suse';
            #StorageVolume       = $False;
            OSDeploymentplan    = $OSDP;
            OSDeploymentPlanAttributes = $OSDeploymentPlanAttributes
            }


      try
          {
       
          New-HPOVServerProfileTemplate @params -ErrorAction Stop | Wait-HPOVTaskComplete

          }

      catch  
         {
       
         $error[0] | Format-List * -force 
               
         }
   


   Write-Output "Server Profile Template $serverprofiletemplate using Image Streamer Created" | Timestamp

   


