<#
 
This PowerShell script collects server information managed by HPE OneView
and generate a text file report providing the following information:

-------------------------------------------------------------------------------------------------------
Report generated on 11/25/2020 13:56:08

ESX5-1.lj.lab [Serial number: xxxxx - iLO: xx.xx.xx.xx]: 
	Model: ProLiant DL360p Gen8
	Total Memory: 176GB
	CPU: 2 x  Intel(R) Xeon(R) CPU E5-2660 0 @ 2.20GHz       
	Memory configuration:
		PROC  1 DIMM  1 : HP RDIMM DDR3 16GB - Part Number=713756-081          
		PROC  1 DIMM  2 : HP RDIMM DDR3 8GB - Part Number=647651-081          
		PROC  1 DIMM  4 : HP RDIMM DDR3 16GB - Part Number=713756-081          
		PROC  1 DIMM  8 : HP RDIMM DDR3 8GB - Part Number=647651-081          
		PROC  1 DIMM  9 : HP RDIMM DDR3 8GB - Part Number=647650-071          
		PROC  1 DIMM 11 : HP RDIMM DDR3 16GB - Part Number=713756-081          
		PROC  1 DIMM 12 : HP RDIMM DDR3 8GB - Part Number=647650-071          
		PROC  2 DIMM  1 : HP RDIMM DDR3 16GB - Part Number=713756-081          
		PROC  2 DIMM  2 : HP RDIMM DDR3 8GB - Part Number=647651-081          
		PROC  2 DIMM  4 : HP RDIMM DDR3 16GB - Part Number=713756-081          
		PROC  2 DIMM  5 : HP RDIMM DDR3 8GB - Part Number=647651-081          
		PROC  2 DIMM  8 : HP RDIMM DDR3 8GB - Part Number=731657-081          
		PROC  2 DIMM  9 : HP RDIMM DDR3 8GB - Part Number=647650-071          
		PROC  2 DIMM 10 : HP RDIMM DDR3 8GB - Part Number=647651-081          
		PROC  2 DIMM 11 : HP RDIMM DDR3 16GB - Part Number=713756-081          
		PROC  2 DIMM 12 : HP RDIMM DDR3 8GB - Part Number=647650-071          
	Adapters configuration:
		1-HP FlexFabric 10Gb 2-port 554FLR-SFP+ Adapter: Part-Number=629142-B21 - Number-of-ports=2 - Position=N/A
	Array Controllers configuration:
		1-Smart Array P420i Controller: Part-Number=N/A - Logical-Drives=1 - Position=Slot 0
			Logical drive-1: Capacity=279GB Disks=2 Status=OK RAID=1 State=Enabled Boot=Yes Encrypted=False
				Drive-1: Capacity=300GB Model=EG0300FCSPH Location=Port1I,Box1,Bay1
				Drive-2: Capacity=300GB Model=EG0300FCSPH Location=Port1I,Box1,Bay2

SYGW [Serial number: xxxxxx - iLO: xx.xx.xx.xx]: 
	Model: ProLiant DL360 Gen9
	Total Memory: 384GB
	CPU: 2 x Intel(R) Xeon(R) CPU E5-2680 v4 @ 2.40GHz
	Memory configuration:
		PROC 1 DIMM 1: HP RDIMM DDR4 32GB - Part Number=809083-091
		PROC 1 DIMM 4: HP RDIMM DDR4 32GB - Part Number=809083-091
		PROC 1 DIMM 8: HP RDIMM DDR4 32GB - Part Number=809083-091
		PROC 1 DIMM 9: HP RDIMM DDR4 32GB - Part Number=809083-091
		PROC 1 DIMM 11: HP RDIMM DDR4 32GB - Part Number=809083-091
		PROC 1 DIMM 12: HP RDIMM DDR4 32GB - Part Number=809083-091
		PROC 2 DIMM 1: HP RDIMM DDR4 32GB - Part Number=809083-091
		PROC 2 DIMM 4: HP RDIMM DDR4 32GB - Part Number=809083-091
		PROC 2 DIMM 8: HP RDIMM DDR4 32GB - Part Number=809083-091
		PROC 2 DIMM 9: HP RDIMM DDR4 32GB - Part Number=809083-091
		PROC 2 DIMM 11: HP RDIMM DDR4 32GB - Part Number=809083-091
		PROC 2 DIMM 12: HP RDIMM DDR4 32GB - Part Number=809083-091
	Adapters configuration:
		1-HP FlexFabric 10Gb 2-port 534FLR-SFP+ Adapter: Part-Number=700751-B21 - Number-of-ports=2 - Position=N/A
		2-HPE Ethernet 1Gb 4-port 331i Adapter #3: Part-Number= - Number-of-ports=4 - Position=N/A
	Array Controllers configuration:
		1-Smart Array P840ar Controller: Part-Number=N/A - Logical-Drives=1 - Position=Slot 0
			Logical drive-1: Capacity=2236GB Disks=6 Status=OK RAID=50 State=Enabled Boot=Yes Encrypted=False
				Drive-1: Capacity=600GB Model=EH0600JDXBC Location=Port2I,Box1,Bay1
				Drive-2: Capacity=600GB Model=EH0600JDXBC Location=Port2I,Box1,Bay2
				Drive-3: Capacity=600GB Model=EH0600JDXBC Location=Port2I,Box1,Bay3
				Drive-4: Capacity=600GB Model=EH0600JDXBC Location=Port2I,Box1,Bay4
				Drive-5: Capacity=600GB Model=EH0600JDXBC Location=Port2I,Box1,Bay5
				Drive-6: Capacity=600GB Model=EH0600JDXBC Location=Port2I,Box1,Bay6

esx5-3.lj.lab [Serial number: xxxxxxxx - iLO: xx.xx.xx.67]: 
	Model: ProLiant DL360 Gen10
	Total Memory: 768GB
	CPU: 1 x Intel(R) Xeon(R) Gold 6130 CPU @ 2.10GHz
	Memory configuration:
		PROC 1 DIMM 1: HPE DDR4 DRAM 64GB - Part Number=840759-091
		PROC 1 DIMM 3: HPE DDR4 DRAM 64GB - Part Number=840759-091
		PROC 1 DIMM 5: HPE DDR4 DRAM 64GB - Part Number=840759-091
		PROC 1 DIMM 8: HPE DDR4 DRAM 64GB - Part Number=840759-091
		PROC 1 DIMM 10: HPE DDR4 DRAM 64GB - Part Number=840759-091
		PROC 1 DIMM 12: HPE DDR4 DRAM 64GB - Part Number=840759-091
		PROC 2 DIMM 1: HPE DDR4 DRAM 64GB - Part Number=840759-091
		PROC 2 DIMM 3: HPE DDR4 DRAM 64GB - Part Number=840759-091
		PROC 2 DIMM 5: HPE DDR4 DRAM 64GB - Part Number=840759-091
		PROC 2 DIMM 8: HPE DDR4 DRAM 64GB - Part Number=840759-091
		PROC 2 DIMM 10: HPE DDR4 DRAM 64GB - Part Number=840759-091
		PROC 2 DIMM 12: HPE DDR4 DRAM 64GB - Part Number=840759-091
	Adapters configuration:
		1-PCIe Controller: Part-Number= - Number-of-ports=0 - Position=PCI.Slot.1.1
		2-HPE Ethernet 1Gb 4-port 331i Adapter - NIC: Part-Number= - Number-of-ports=4 - Position=NIC.LOM.1.1
		3-HPE Eth 10/25Gb 2p 631FLR-SFP28 Adptr: Part-Number=840133-001 - Number-of-ports=2 - Position=NIC.FlexLOM.1.1
	Array Controllers configuration:
		1-HPE Smart Array P408i-a SR Gen10: Part-Number=836260-001 - Logical-Drives=1 - Position=Slot 0
			Logical drive-1: Capacity=279GB Disks=2 Status=OK RAID=1 State=Enabled Boot=No Encrypted=False
				Drive-1: Capacity=300GB Model=EH000300JWCPK Location=Port1I,Box1,Bay1
				Drive-2: Capacity=300GB Model=EH000300JWCPK Location=Port1I,Box1,Bay2

WIN-xxx [Serial number: xxxxxx - iLO: 192.168.0.8]: 
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
		1-Synergy 3820C 10/20Gb CNA: Part-Number=782833-001 - Number-of-ports=4 - Position=NIC.Slot.3.1
	Array Controllers configuration:
		1-HPE Smart Array P416ie-m SR G10: Part-Number=836275-001 - Logical-Drives=2 - Position=Mezz 1
			1-Logical Drive [Boot]: DriveMaxSizeGB=300GB Disks=2 Status=OK RAID=RAID1 Boot=Yes Erase-on-delete=False Permanent=True
				Drive-1: Capacity=300GB Model=EG0300JFCKA Location=Frame1,Bay11,Drive3
				Drive-2: Capacity=300GB Model=EG0300JFCKA Location=Frame1,Bay11,Drive1
			2-Logical JBOD [Data_VSAN]: DriveMaxSizeGB=300GB Disks=3 Status=OK Erase-on-delete=False Permanent=False
				Drive-1: Capacity=300GB Model=EG0300JFCKA Location=Frame1,Bay11,Drive8
				Drive-2: Capacity=300GB Model=EG0300JFCKA Location=Frame1,Bay11,Drive9
				Drive-3: Capacity=300GB Model=EG0300JFCKA Location=Frame1,Bay11,Drive10   
                
esx-4.lj.lab [Serial number: xxxxxx - iLO: 192.168.0.14]: 
	Model: Synergy 480 Gen9
	Total Memory: 64GB
	CPU: 2 x Intel(R) Xeon(R) CPU E5-2697A v4 @ 2.60GHz
	Memory configuration:
		PROC 1 DIMM 9: HP RDIMM DDR4 16GB - Part Number=752369-081
		PROC 1 DIMM 12: HP RDIMM DDR4 16GB - Part Number=752369-081
		PROC 2 DIMM 1: HP RDIMM DDR4 16GB - Part Number=752369-081
		PROC 2 DIMM 4: HP RDIMM DDR4 16GB - Part Number=752369-081
	Adapters configuration:
		1-Synergy 3820C 10/20Gb CNA: Part-Number=777430-B21 - Number-of-ports=2 - Position=NIC.Slot.3.1
	Array Controllers configuration:
		1-Smart Array P240nr Controller: Part-Number=N/A - Logical-Drives=1 - Position=Slot 0
			Logical drive-1: Capacity=279GB Disks=2 Status=OK RAID=1 State=Enabled Boot=Yes Encrypted=False
				Drive-1: Capacity=300GB Model=EG0300FCSPH Location=Port1I,Box1,Bay1
				Drive-2: Capacity=300GB Model=EG0300FCSPH Location=Port1I,Box1,Bay2
		2-Smart Array P542D Controller: Part-Number=N/A - Logical-Drives=0 - Position=Slot 1                
 
<...>

-------------------------------------------------------------------------------------------------------

Most information is collected using the iLO RedFish API except when a server profile is assigned to the server, 
in this case, the script collects the information from OneView.

OneView is also used to collect the iLO IP addresses of all the servers it manages.

This script is compatible with Gen8, Gen9 and Gen10 servers including Synergy and DL Proliant servers.

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
#Import-Module hpeoneview.550 

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
#   $servers = Get-OVServer | ? name -eq "Frame1, bay 5"
# Gen9
#  $servers = Get-OVServer | ? name -eq "Frame1, bay 2"



$iloIPs = ($servers | where { $_.mpModel -eq "iLO4" -or "iLO5" }).mpHostInfo.mpIpAddresses | ? { $_.type -ne "LinkLocal" -and $_.type -ne "SLAAC" } | % address


"Report generated on $(get-date)" | Out-File $file 

Foreach ($iloIP in $iloIPs) {
       
    #Capture of the SSO Session Key
    $SH = $servers | ? { ($_.mpHostInfo.mpIpAddresses | ? { $_.type -ne "LinkLocal" -and $_.type -ne "SLAAC" } | % address) -eq $iloIP }
    $serveruuid = $SH.uuid
    
    #Capture of the SSO Session Key
    $ilosessionkey = ($SH  | Get-OVIloSso -IloRestSession)."X-Auth-Token"
        
    $iloModel = $SH | % mpModel
    
    #Frame name for blade
    if ( $sh.model -match "Synergy") { 
        $blade = $True
        $frame = $sh.name.split(",")[0]
    }   

   
    #Is the server managed by Oneview Server Profile?
    if ($SH.serverProfileUri) { $ManagedbyOneView = $True } else { $ManagedbyOneView = $False }        
    
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
                if ($PartNumber) {
                    $dimm_data = $Manufacturer + " " + $DIMMTechnology + " " + $DIMMType + " " + $SizeGB + "GB" + " - Part Number=" + $PartNumber
                }
                else {
                    $dimm_data = $Manufacturer + " " + $DIMMTechnology + " " + $DIMMType + " " + $SizeGB + "GB" + " - Part Number=N/A"
        
                }
                
                
                "`t`t$($DIMMlocator): $($dimm_data)"  | Out-File $file -Append
            }
            if ($iloModel -eq "iLO4") {

                $DIMMTechnology = $memorydata.DIMMTechnology
                $DIMMType = $memorydata.DIMMType
                $SizeGB = $memorydata.SizeMB / 1024
                $DIMMlocator = $memorydata.SocketLocator
                if ($PartNumber) {
                    $dimm_data = $Manufacturer + " " + $DIMMTechnology + " " + $DIMMType + " " + $SizeGB + "GB" + " - Part Number=" + $PartNumber
                }
                else {
                    $dimm_data = $Manufacturer + " " + $DIMMTechnology + " " + $DIMMType + " " + $SizeGB + "GB" + " - Part Number=N/A" 
                }
               
                
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
                if ($StructuredName) {
                    $adapter_data = "Part-Number=" + $PartNumber + " - Number-of-ports=" + $Numberofports + " - Position=" + $StructuredName
                }
                else {
                    $adapter_data = "Part-Number=" + $PartNumber + " - Number-of-ports=" + $Numberofports + " - Position=N/A"
                }
               

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
            
                if ($iloModel -eq "ILO4") { $PartNumber = "N/A" } else { $PartNumber = $ArrayControllerdata.ControllerPartNumber }
            
                # Logical drive info

                if ($ManagedbyOneView) {   
 
                    $serverprofileuri = $Sh.serverProfileUri
                    $serverprofile = Send-OVRequest -uri $serverprofileuri -method get

                    $localstorageitems = $serverprofile.localStorage.sasLogicalJBODs
                    $logicaldrives_nb = $localstorageitems.Count

                    $ArrayController_data = "Part-Number=" + $PartNumber + " - Logical-Drives=" + $logicaldrives_nb + " - Position=" + $item.deviceSlot
               
                    # Adding Array controller to report
                    "`t`t$($ArrayControllerName): $($ArrayController_data)"  | Out-File $file -Append
                    
                    if ($logicaldrives_nb -ge 1) {

                        foreach ($item in $localstorageitems) {

                            $logicaldrivename = $item.name
                            $logicaldrive_nb_of_disk = $item.numPhysicalDrives
                            $logicaldriveid = $item.id
                            $logicaldrivedriveMaxSizeGB = $item.driveMaxSizeGB
                            $logicaldrive_status = $item.status
                            $logicaldrivePermanent = $item.persistent
                            $logicaldriveEraseData = $item.eraseData

                            $Logicaldrive = $serverprofile.localStorage.controllers.logicalDrives | ? sasLogicalJBODId -eq $item.id

                            if ($Logicaldrive) { 

                                $logicaldrive_raid = $Logicaldrive.raidLevel
                                if ($Logicaldrive.bootable) { $logicaldrive_boot = "Yes" } else { $logicaldrive_boot = "No" }
                               
                                # $logicaldrive_encrypted : no encryption data

                                $logicaldriveinfo = "DriveMaxSizeGB=" + $logicaldrivedriveMaxSizeGB + "GB Disks=" + $logicaldrive_nb_of_disk + " Status=" + $logicaldrive_status + " RAID=" + $logicaldrive_raid + " Boot=" + $logicaldrive_boot + " Erase-on-delete=" + $logicaldriveEraseData + " Permanent=" + $logicaldrivePermanent
                       
                                # Adding Logical Drive information to report
                                "`t`t`t$($logicaldriveid)-Logical Drive [$logicaldrivename]: $($logicaldriveinfo)"  | Out-File $file -Append
    
                            }
                            else {

                                $logicalJBODinfo = "DriveMaxSizeGB=" + $logicaldrivedriveMaxSizeGB + "GB Disks=" + $logicaldrive_nb_of_disk + " Status=" + $logicaldrive_status + " Erase-on-delete=" + $logicaldriveEraseData + " Permanent=" + $logicaldrivePermanent
                       
                                "`t`t`t$($logicaldriveid)-Logical JBOD [$logicaldrivename]: $($logicalJBODinfo)"  | Out-File $file -Append

                            }

                            if ($logicaldrive_nb_of_disk -ge 1) {

                                $sasLogicalJBODUri = (Send-OVRequest -method GET -uri $item.sasLogicalJBODUri)
                        
                                # Drives info
                                $DriveId = $Null 
                        
                                foreach ($datadriveuri in $sasLogicalJBODUri.driveBayUris ) {
                            
                                    $DriveId += 1 

                                    $driveenclosurenamearray = $datadriveuri.split("/")

                                    $driveenclosureuri = "/" + $driveenclosurenamearray[1] + "/" + $driveenclosurenamearray[2] + "/" + $driveenclosurenamearray[3] 
                               
                                    $drivedata = ((Send-OVRequest -method GET -uri $driveenclosureuri).driveBays | ? { $_.uri -eq $datadriveuri }).drive
                               
                                    $driveCapacityGB = $drivedata.capacity
                                    $driveModel = $drivedata.model
                                    $drivePort = $drivedata.drivePaths[0].split(":")[2]
                                    $driveBay = $drivedata.drivePaths[0].split(":")[0]
                                    $driveBox = $drivedata.drivePaths[0].split(":")[1]

                                    if ($Blade) {
                                        $driveinfo = "Capacity=" + $driveCapacityGB + "GB Model=" + $driveModel + " Location=" + $frame + ",Bay" + $driveBay + ",Drive" + $drivePort
                                    }
                                    else {                             
                                
                                        $driveinfo = "Capacity=" + $driveCapacityGB + "GB Model=" + $driveModel + " Location=Port" + $drivePort + ",Box" + $driveBox + ",Bay" + $driveBay
                                                                      
                                    }
                                    # Adding Drives information to report
                                    "`t`t`t`tDrive-$($DriveId): $($driveinfo)"  | Out-File $file -Append
                                }
                            }
                        }
                    }
                }

                else {

                    $logicaldrivessuri = $ArrayController + "LogicalDrives/" 
                    $logicaldrivesdata = (Invoke-webrequest -Method GET -Uri "https://$iloIP$logicaldrivessuri"  -Headers @{"X-Auth-Token" = $ilosessionkey }).content | Convertfrom-Json 
                    $logicaldrives_nb = $logicaldrivesdata.'Members@odata.count'
            
                    $ArrayController_data = "Part-Number=" + $PartNumber + " - Logical-Drives=" + $logicaldrives_nb + " - Position=" + $ArrayControllerdata.location
               
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
    }

    Else {
        write-warning "iLO $iloIP cannot be contacted !"
        
    } 
}

write-host "Hardware report has been generated in $pwd\$file" -ForegroundColor Green

Disconnect-OVMgmt

#Read-Host -Prompt "Operation done ! Hit return to close" 



