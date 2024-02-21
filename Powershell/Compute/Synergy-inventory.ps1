### Generates a Synergy inventory report 

# Created by DAVIDMARTINEZROBLES
# https://github.com/DAVIDMARTINEZROBLES 



#IP address of OneView
$IP = "192.168.1.110" 

# OneView Credentials
$username = "Administrator" 
$password = "xxxxxxxxxxxx" 

# Import the OneView 3.10 library

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -Confirm:$false

if (-not (get-module HPOneview.310)) {  
    Import-module HPOneview.310
}


# Connection to the Synergy Composer

If ($connectedSessions -and ($connectedSessions | ? { $_.name -eq $IP })) {
    Write-Verbose "Already connected to $IP."
}

Else {
    Try {
        Connect-OVMgmt -appliance $IP -UserName $username -Password $password | Out-Null
    }
    Catch {
        throw $_
    }
}

import-OVSSLCertificate -ApplianceConnection ($connectedSessions | ? { $_.name -eq $IP })

$file = "Synergy_inventory.txt"

$Linebreak = "########################################"

echo $Linebreak "RACK" $Linebreak >> $file
Get-OVRack | Get-OVRackMember | Sort-Object Ulocation >> $file
echo $Linebreak "ADDRESS POOL RANGE" $Linebreak >> $file
Get-OVAddressPoolRange >> $file
echo $Linebreak "ADDRESS POOL SUBNET" $Linebreak >> $file
Get-OVAddressPoolSubnet >> $file
echo $Linebreak "COMPOSER" $Linebreak >> $file
Get-OVComposerNode | ft Appliance, modelNumber, name, role, state, status, version, synchronizationPercentComplete >> $file
echo $Linebreak "IMAGE STREAMER" $Linebreak >> $file
Get-OVImageStreamerAppliance | ft oneViewIpv4Address, name, status, applianceserialnumber, imagestreamerversion, isactive, isprimary >> $file
echo $Linebreak "ENCLOSURE" $Linebreak >> $file
Get-OVEnclosure | Sort-Object -Property name >> $file
echo $Linebreak "SERVER RESUME" $Linebreak >> $file
Get-OVServer | Format-Table position, name, mpModel, mpFirmwareVersion, model, serialNumber, processorType, memoryMb, romVersion, intelligentProvisioningVersion, state, powerState | Sort-Object -Property locationUri, position >> $file
echo $Linebreak "DRIVE ENCLOSURE" $Linebreak >> $file
Get-OVDriveEnclosure | Format-Table name, bay, model, serialNumber, partNumber, productName, driveBayCount, firmwareVersion, ioAdapterCount, powerState | Sort-Object { [int]$_.bay }>> $file
echo $Linebreak "INTERCONNECT" $Linebreak >> $file
Get-OVinterconnect | Format-Table enclosureName, hostName, model, name, partNumber, serialNumber, interconnectIP, firmwareVersion, portCount, baseWWN | Sort-Object name >> $file
$Enclosures = Get-OVEnclosure | Sort-Object -Property name
Foreach ($Enclosure in $Enclosures) {
    echo $Linebreak "ENCLOSURE DETAIL" $Enclosure.name $Linebreak >> $file
    echo $Linebreak "Interconnect" $Enclosure.serialNumber $Linebreak >> $file
(Send-OVRequest -Uri ($Enclosure.uri)).interconnectBays | Format-Table bayNumber, interconnectModel, partNumber, serialNumber, ipv4Setting | Sort-Object -Property bayNumber >> $file
    echo $Linebreak "Appliance Bays" $Enclosure.serialNumber $Linebreak >> $file
(Send-OVRequest -Uri ($Enclosure.uri)).applianceBays | ft bayNumber, devicePresence, status, model, serialNumber, partNumber, poweredOn | Sort-Object -Property bayNumber >> $file
    echo $Linebreak "Manager Bays" $Enclosure.serialNumber $Linebreak >> $file
(Send-OVRequest -Uri ($Enclosure.uri)).managerBays | ft bayNumber, model, devicePresence, role, FwVersion, partNumber, sparePartNumber | Sort-Object -Property bayNumber >> $file
    echo $Linebreak "PowerSupply" $Enclosure.serialNumber $Linebreak >> $file
(Send-OVRequest -Uri ($Enclosure.uri)).powerSupplyBays | Format-Table | Sort-Object -Property bayNumber >> $file
    echo $Linebreak "Fan" $Enclosure.serialNumber $Linebreak >> $file
(Send-OVRequest -Uri ($Enclosure.uri)).fanBays | Format-Table bayNumber, devicePresence, fanBayType, model, serialNumber, partNumber, sparePartNumber | Sort-Object -Property bayNumber >> $file
}

$servers = Get-OVserver | Sort-Object locationuri, { [int]$_.position }


Foreach ($server in $servers) {
    echo $Linebreak "SERVER DETAIL" $server.name $Linebreak >> $file
(Send-OVRequest -Uri ($server.uri)).portMap.deviceSlots | Format-Table >> $file
(Send-OVRequest -Uri ($server.uri)).portMap.deviceSlots.physicalPorts | Format-Table type, portNumber, physicalInterconnectPort, interconnectport, mac >> $file
(Send-OVRequest -Uri ($server.uri)).mpHostInfo.mpIpAddresses | Format-Table type, address >> $file
(Send-OVRequest -Uri ($server.uri + "/firmware")).components | Format-Table componentLocation, componentName, componentVersion | Sort-Object componentLocation, componentName | Out-File $file -Append
}
$DriveEnclosures = Get-OVDriveEnclosure | Sort-Object name, { [int]$_.bay }
Foreach ($DriveEnclosure in $DriveEnclosures) {
    echo $Linebreak "DRIVE ENCLOSURE DETAIL" $DriveEnclosure.serialNumber $DriveEnclosure.name $Linebreak >> $file
(Send-OVRequest -Uri ($DriveEnclosure.uri)).ioadapters | Format-Table model, partnumber, serialnumber, firmwareversion, portcount, redundantIoModule >> $file
(Send-OVRequest -Uri ($DriveEnclosure.uri)).driveBays.drive | Format-Table name, serialNumber, model, deviceInterface, driveMedia, linkRateInGbs, drivePaths, firmwareVersion, status, temperature >> $file
}
