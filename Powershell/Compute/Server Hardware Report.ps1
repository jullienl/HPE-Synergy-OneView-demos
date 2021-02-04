<#
 
This PowerShell script collects server information managed by HPE OneView
and generate a text file report providing the following information:

-------------------------------------------------------------------------------------------------------
Report generated on 11/25/2020 13:56:08

WIN-V9SBMGIUTGH [Serial number: MXQ828048H - iLO: 192.168.0.8]: 
	Model: Synergy 480 Gen10
	Total Memory: 128GB
	CPU: 1 x Intel(R) Xeon(R) Gold 6130 CPU @ 2.10GHz
	Memory configuration:
		PROC 1 DIMM 3: HPE DDR4 DRAM 16GB - Part Number=840756-091
		PROC 1 DIMM 5: HPE DDR4 DRAM 16GB - Part Number=840756-091
		PROC 1 DIMM 8: HPE DDR4 DRAM 16GB - Part Number=840756-091
		PROC 1 DIMM 10: HPE DDR4 DRAM 16GB - Part Number=840756-091
		PROC 2 DIMM 3: HPE DDR4 DRAM 16GB - Part Number=840756-091
		PROC 2 DIMM 5: HPE DDR4 DRAM 16GB - Part Number=840756-091
		PROC 2 DIMM 8: HPE DDR4 DRAM 16GB - Part Number=840756-091
		PROC 2 DIMM 10: HPE DDR4 DRAM 16GB - Part Number=840756-091
	Adapters configuration:
		1-Synergy 3820C 10/20Gb CNA: Part Number=782833-001 - Number of ports=4 - Position=NIC.Slot.3.1
	Array Controllers configuration:
		1-HPE Smart Array P416ie-m SR G10: Part Number=836275-001 - Logical Drives=3 - Position=Slot 1
			Logical drive-1: Capacity=279GB Disks=1 Status=OK RAID=0 State=Enabled Boot=No Encrypted=False
				Drive-1: Capacity=300GB Model=EG0300JFCKA Location=Port4I,Box1,Bay1
			Logical drive-2: Capacity=279GB Disks=1 Status=OK RAID=0 State=Enabled Boot=No Encrypted=False
				Drive-1: Capacity=300GB Model=EG0300JFCKA Location=Port4I,Box1,Bay2
			Logical drive-3: Capacity=279GB Disks=2 Status=OK RAID=1 State=Enabled Boot=Yes Encrypted=False
				Drive-1: Capacity=300GB Model=EG0300JFCKA Location=Port11,Box1,Bay1
				Drive-2: Capacity=300GB Model=EG0300JFCKA Location=Port11,Box1,Bay3

ESX5-2.lj.lab [Serial number: MXQ828049J - iLO: 192.168.0.10]: 
	Model: Synergy 480 Gen10
	Total Memory: 256GB
	CPU: 1 x Intel(R) Xeon(R) Gold 6134 CPU @ 3.20GHz
	Memory configuration:
		PROC 1 DIMM 8: HPE DDR4 DRAM 64GB - Part Number=840759-091
		PROC 1 DIMM 10: HPE DDR4 DRAM 64GB - Part Number=840759-091
		PROC 2 DIMM 3: HPE DDR4 DRAM 64GB - Part Number=840759-091
		PROC 2 DIMM 5: HPE DDR4 DRAM 64GB - Part Number=840759-091
	Adapters configuration:
		1-Synergy 3830C 16G FC HBA: Part Number=782829-001 - Number of ports=0 - Position=PCI.Slot.2.1
		2-Synergy 3820C 10/20Gb CNA: Part Number=782833-001 - Number of ports=2 - Position=NIC.Slot.3.1
	Array Controllers configuration:
        1-HPE Smart Array P204i-c SR Gen10: Part Number=836274-001 - Logical Drives=0 - Position=Slot 0
        
esx-4.lj.lab [Serial number: CN76010B5T - iLO: 192.168.0.14]: 
	Model: Synergy 480 Gen9
	Total Memory: 64GB
	CPU: 2 x Intel(R) Xeon(R) CPU E5-2697A v4 @ 2.60GHz
	Memory configuration:
		PROC 1 DIMM 9: HP RDIMM DDR4 16GB - Part Number=752369-081
		PROC 1 DIMM 12: HP RDIMM DDR4 16GB - Part Number=752369-081
		PROC 2 DIMM 1: HP RDIMM DDR4 16GB - Part Number=752369-081
		PROC 2 DIMM 4: HP RDIMM DDR4 16GB - Part Number=752369-081
	Adapters configuration:
		1-Synergy 3820C 10/20Gb CNA: Part Number=777430-B21 - Number of ports=2 - Position=NIC.Slot.3.1
	Array Controllers configuration:
		1-Smart Array P240nr Controller: Part Number=Not available - Logical Drives=1 - Position=Slot 0
			Logical drive-1: Capacity=279GB Disks=2 Status=OK RAID=1 State=Enabled Boot=Yes Encrypted=False
				Drive-1: Capacity=300GB Model=EG0300FCSPH Location=Port1I,Box1,Bay1
				Drive-2: Capacity=300GB Model=EG0300FCSPH Location=Port1I,Box1,Bay2
		2-Smart Array P542D Controller: Part Number=Not available - Logical Drives=0 - Position=Slot 1        
 
<...>

-------------------------------------------------------------------------------------------------------

All information is collected using the iLO RedFish API. OneView is only used to collect the IPs of all iLOs managed by OneView.

Requirements:
- OneView administrator account is required. 
- HPE Oneview PowerShell library


Author: lionel.jullien@hpe.com
Date:   Nov 2020

--------------------------------------------------------------------------------------------------------

#################################################################################
#        (C) Copyright 2018 Hewlett Packard Enterprise Development LP           #
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
$username = "Administrator" 
$password = "password" 
$IP = "192.168.1.110"

$file = "Server_HW_Report.txt"


Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
#Import-Module hpeoneview.530 

# Connection to the OneView / Synergy Composer
$secpasswd = ConvertTo-SecureString $password -AsPlainText -Force
$credentials = New-Object System.Management.Automation.PSCredential ($username, $secpasswd)
Connect-OVMgmt -Hostname $IP -Credential $credentials | Out-Null

# Adding this to avoid the error: "The underlying connection was closed: Could not establish trust relationship for the SSL/TLS secure channel."
# when using Self-Signed Certificates
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
  
# Capture iLO4 and iLO5 IP adresses managed by OneView
$servers = Get-OVServer
# Gen10
#  $servers = Get-OVServer | ? name -eq "Frame1, bay 5"
# Gen9
#  $servers = Get-OVServer | ? name -eq "Frame3, bay 9"

$iloIPs = ($servers | where { $_.mpModel -eq "iLO4" -or "iLO5" }).mpHostInfo.mpIpAddresses | ? { $_.type -ne "LinkLocal" -and $_.type -ne "SLAAC" } | % address


"Report generated on $(get-date)" | Out-File $file 

Foreach ($iloIP in $iloIPs) {
       
    #Capture of the SSO Session Key
    $SH = $servers | ? { ($_.mpHostInfo.mpIpAddresses | ? { $_.type -ne "LinkLocal" -and $_.type -ne "SLAAC" } | % address) -eq $iloIP }
    $serveruuid = $SH.uuid
    
    # $uri = "https://$IP/rest/server-hardware/$serveruuid/iloSsoUrl"
    # $ovsession = $ConnectedSessions.SessionID
    # $ilossourl = ((Invoke-webrequest -Method GET -Uri $uri -Headers @{"Auth" = $ovsession ; "X-API-Version" = "1600" }  ).content | Convertfrom-Json).iloSsoUrl

    # $ilosessionkey = (Invoke-webrequest -Method GET -Uri $ilossourl -Headers @{"Auth" = $ovsession ; "X-API-Version" = "1600" } -SessionVariable ws )
    # $ilosessionkey = ($ws.Cookies.GetCookies($ilossourl)).value

    #Capture of the SSO Session Key
    $ilosessionkey = ($SH  | Get-OVIloSso -IloRestSession)."X-Auth-Token"
        
    $iloModel = $SH | % mpModel
   
    #Manager information
    #$Manager = (((Invoke-webrequest -Method GET -Uri "https://$iloIP/redfish/v1/" -Headers @{"X-Auth-Token" = $ilosessionkey } ).content ).ToString().Replace("Type", "_Type") | ConvertFrom-Json).oem.Hpe.Manager.IPManager.ManagerProductName
    #if ($Manager -match "oneview") { <# Server managed by OneView #> } else { <# Not managed by Oneview #> }        
    
    #Hardware info   
    $request = (Invoke-webrequest -Method GET -Uri "https://$iloIP/redfish/v1/systems/1/" -Headers @{"X-Auth-Token" = $ilosessionkey } ).content | Convertfrom-Json

    if ($request -ne $Null) {

        #Hostname
        $hostname = $request.HostName 

        if ($hostname -match "host is unnamed") { $hostname = "Host is unnamed [Serial number: $($request.SerialNumber) - iLO: $iloIP]" } else { $hostname = "$($request.HostName) [Serial number: $($request.SerialNumber) - iLO: $iloIP]" }
        
        #Model
        $model = $request.Model

        #CPU
        if ($iloModel -eq "ILO4") { $cpu = $request.ProcessorSummary.Model } else { $cpu = $request.ProcessorSummary.Model }
        if ($iloModel -eq "ILO4") { $cpunb = $request.ProcessorSummary.Count } else { $cpunb = $request.Processors.'@odata.id'.count }
        
        #Total memory
        if ($iloModel -eq "ILO4") { $memoryinGB = $request.Memory.TotalSystemMemoryGB } else { $memoryinGB = $request.MemorySummary.TotalSystemMemoryGiB }

        #Memory information
        $memoryinfo = (Invoke-webrequest -Method GET -Uri "https://$iloIP/redfish/v1/Systems/1/Memory/" -Headers @{"X-Auth-Token" = $ilosessionkey }).content | Convertfrom-Json 
     
        # Adding memory information to report
        "`n" + $hostname + ": `n`tModel: " + $model + "`n`tTotal Memory: " + $memoryinGB + "GB" + "`n`tCPU: " + $cpunb + " x " + $cpu + "`n`tMemory configuration:"  | Out-File $file -Append
   
        foreach ( $dimm in $memoryinfo.Members.'@odata.id') {
         
            $memorydata = (Invoke-webrequest -Method GET -Uri "https://$iloIP$dimm" -Headers @{"X-Auth-Token" = $ilosessionkey }).content | Convertfrom-Json 
                                        
            $Manufacturer = ($memorydata.Manufacturer) -replace '\s', ''
            $PartNumber = $memorydata.PartNumber
        
            if ($iloModel -eq "iLO5" -and $memorydata.status.State -eq "Enabled") {
            
                $DIMMTechnology = $memorydata.MemoryDeviceType 
                $DIMMType = $memorydata.MemoryType 
                $SizeGB = $memorydata.CapacityMiB / 1024 
                $DIMMlocator = $memorydata.DeviceLocator

                $dimm_data = $Manufacturer + " " + $DIMMTechnology + " " + $DIMMType + " " + $SizeGB + "GB" + " - Part Number=" + $PartNumber
                
                "`t`t$($DIMMlocator): $($dimm_data)"  | Out-File $file -Append
            }
            if ($iloModel -eq "iLO4") {

                $DIMMTechnology = $memorydata.DIMMTechnology
                $DIMMType = $memorydata.DIMMType
                $SizeGB = $memorydata.SizeMB / 1024
                $DIMMlocator = $memorydata.SocketLocator

                $dimm_data = $Manufacturer + " " + $DIMMTechnology + " " + $DIMMType + " " + $SizeGB + "GB" + " - Part Number=" + $PartNumber
                
                "`t`t$($DIMMlocator): $($dimm_data)"  | Out-File $file -Append
            }
            
            

        }         




        # PCI network adapters information
        if ($iloModel -eq "ILO4") { $adaptersuri = "https://$iloIP/redfish/v1/Systems/1/NetworkAdapters/" } else { $adaptersuri = "https://$iloIP/redfish/v1/Systems/1/BaseNetworkAdapters/" }
    
        $adapterinfo = (Invoke-webrequest -Method GET -Uri $adaptersuri -Headers @{"X-Auth-Token" = $ilosessionkey }).content | Convertfrom-Json 

        $adapterdataId = $Null

        if ($adapterinfo.Members.'@odata.id') {

            "`tAdapters configuration:"  | Out-File $file -Append
        
            foreach ($adapter in $adapterinfo.Members.'@odata.id') {
            
                $adapterdata = (Invoke-webrequest -Method GET -Uri "https://$iloIP$adapter" -Headers @{"X-Auth-Token" = $ilosessionkey }).content | Convertfrom-Json 
            
                #$adapterdataId = $adapterdata.Id
                $adapterdataId += 1

                $AdapterName = $adapterdataId.ToString() + "-" + $adapterdata.Name 
                $PartNumber = $adapterdata.PartNumber
                $StructuredName = $adapterdata.StructuredName
                $Numberofports = ($adapterdata.PhysicalPorts).Count

                $adapter_data = "Part Number=" + $PartNumber + " - Number of ports=" + $Numberofports + " - Position=" + $StructuredName

                # Adding Adapters information to report
      
                "`t`t$($AdapterName): $($adapter_data)"  | Out-File $file -Append
            }

            
        }        




        # PCI ArrayControllers information
        $ArrayControllersuri = "/redfish/v1/Systems/1/SmartStorage/ArrayControllers/" 
    
        $ArrayControllersinfo = (Invoke-webrequest -Method GET -Uri "$iloIP$ArrayControllersuri" -Headers @{"X-Auth-Token" = $ilosessionkey }).content | Convertfrom-Json 

        $ArrayControllerdataId = $Null

        if ($ArrayControllersinfo.Members.'@odata.id') {

            "`tArray Controllers configuration:"  | Out-File $file -Append
        
            foreach ($ArrayController in $ArrayControllersinfo.Members.'@odata.id') {
                
                $ArrayControllerdata = (Invoke-webrequest -Method GET -Uri "https://$iloIP$ArrayController" -Headers @{"X-Auth-Token" = $ilosessionkey }).content | Convertfrom-Json 
            
                #$ArrayControllerdataId = $ArrayControllerdata.id
                $ArrayControllerdataId += 1 

                $ArrayControllerName = $ArrayControllerdataId.ToString() + "-" + $ArrayControllerdata.Model 
            
                if ($iloModel -eq "ILO4") { $PartNumber = "Not available" } else { $PartNumber = $ArrayControllerdata.ControllerPartNumber }
            
                # Logical drive info
                 
                $logicaldrivessuri = $ArrayController + "LogicalDrives/" 
                $logicaldrivesdata = (Invoke-webrequest -Method GET -Uri "https://$iloIP$logicaldrivessuri"  -Headers @{"X-Auth-Token" = $ilosessionkey }).content | Convertfrom-Json 
                $logicaldrives_nb = $logicaldrivesdata.'Members@odata.count'
            
                $ArrayController_data = "Part Number=" + $PartNumber + " - Logical Drives=" + $logicaldrives_nb + " - Position=" + $ArrayControllerdata.location
               
                # Adding Array controller to report
                "`t`t$($ArrayControllerName): $($ArrayController_data)"  | Out-File $file -Append

                if ($logicaldrives_nb -ge 1) {

                    foreach ($logicaldrive in  $logicaldrivesdata.Members.'@odata.id') {
                
                        $logicaldrivedata = (Invoke-webrequest -Method GET -Uri "https://$iloIP$logicaldrive"  -Headers @{"X-Auth-Token" = $ilosessionkey }).content | Convertfrom-Json 

                        $logicaldrivecapacityGB = [math]::Round($logicaldrivedata.CapacityMiB / 1024)
                        $logicaldriveid = "Logical drive-" + $logicaldrivedata.Id
                        
                        if ($iloModel -eq "ILO4") { $logicaldrive_href = $logicaldrivedata.links.DataDrives.href } else { $logicaldrive_href = $logicaldrivedata.links.DataDrives.'@odata.id' } 
                        
                                
                        $uri = "https://$iloIP$logicaldrive_href"
                        $logicaldrive_nb_of_disk = ((Invoke-webrequest -Method GET -Uri $uri  -Headers @{"X-Auth-Token" = $ilosessionkey }).content | Convertfrom-Json ).'Members@odata.count'
                        
                        $logicaldrive_raid = $logicaldrivedata.raid
                        $logicaldrive_status = $logicaldrivedata.Status.Health
                        $logicaldrive_encrypted = $logicaldrivedata.LogicalDriveEncryption
                        $logicaldrive_enabled = $logicaldrivedata.Status.state
                        if ($logicaldrivedata.LegacyBootPriority -eq "None") { $logicaldrive_boot = "No" } else { $logicaldrive_boot = "Yes" }
                                    
                        $logicaldriveinfo = "Capacity=" + $logicaldrivecapacityGB + "GB Disks=" + $logicaldrive_nb_of_disk + " Status=" + $logicaldrive_status + " RAID=" + $logicaldrive_raid + " State=" + $logicaldrive_enabled + " Boot=" + $logicaldrive_boot + " Encrypted=" + $logicaldrive_encrypted
                       
                        # Adding Logical Drive information to report
                        "`t`t`t$($logicaldriveid): $($logicaldriveinfo)"  | Out-File $file -Append

                        if ($logicaldrive_nb_of_disk -ge 1) {

                            # Drives info
     
                            foreach ($datadrive in $logicaldrive_href ) {
                                
                                $uri = "https://$iloIP$datadrive"
                                $Drivedata = ((Invoke-webrequest -Method GET -Uri $uri  -Headers @{"X-Auth-Token" = $ilosessionkey }).content | Convertfrom-Json ).Members.'@odata.id'
                                
                                $DriveId = $Null 
                                    
                                foreach ($item in $Drivedata) {

                                    $DriveId += 1                                     
                                    
                                    $uri = "https://$iloIP$item"
                                    $Drive = ((Invoke-webrequest -Method GET -Uri $uri  -Headers @{"X-Auth-Token" = $ilosessionkey }).content | Convertfrom-Json )
                                    
                                    $driveCapacityGB = $drive.CapacityGB
                                    $driveModel = $drive.Model
                                    $drivePort = $drive.Location.Split(":") | select -Index 0
                                    $driveBox = $drive.Location.Split(":") | select -Index 1
                                    $driveBay = $drive.Location.Split(":") | select -Index 2

                                    $driveinfo = "Capacity=" + $driveCapacityGB + "GB Model=" + $driveModel + " Location=Port" + $drivePort + ",Box" + $driveBox + ",Bay" + $driveBay
                                    
                                    # Adding Drives information to report
                                    "`t`t`t`tDrive-$($DriveId): $($driveinfo)"  | Out-File $file -Append
                                }
                            }
                        }
                    }
                }
            }           
        } 
    }

    Else {
        write-warning "iLO $iloIP cannot be contacted !"
        
    } 
}

write-host "Hardware report has been generated in $pwd\$file" -ForegroundColor Green

Disconnect-OVMgmt

#Read-Host -Prompt "Operation done ! Hit return to close" 



